---
name: tmux
description: "Keep a long agent process alive past tool-call cleanup by starting it in a detached tmux session or a systemd user unit. Measured here - tool shells have no TTY, so reptyr cannot attach, and plain &/nohup freeze."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['tmux', 'sessions', 'reptyr', 'systemd-run', 'long-running', 'agents', 'detach']
---

# tmux — put the process where cleanup cannot reach it

A tool call runs in a shell whose whole process group is torn down when the call
returns. `&`, `nohup` and `disown` do not change that. The answer is not to rescue
the process afterwards; it is to start it inside a session that owns its own
lifecycle: a detached tmux session for anything interactive, a transient systemd
unit for anything batch.

## What was measured on frieren (2026-10-21)

Three identical heartbeat loops, started in one tool call, read from a *later*
call:

| Start | Lines before the call ended | After the next call | Verdict |
| :--- | :--- | :--- | :--- |
| `tmux new-session -d -- bash -c 'while :; do date >> f; sleep 1; done'` | 4 | **14** | survived |
| `systemd-run --user --unit=… --collect bash -c '…'` | 3 | **14**, unit `active` | survived |
| `nohup bash -c '…' &` | 4 | **4**, process still listed | frozen — it exists and does nothing |

Two facts follow, and they decide the tool:

- **The tool shell has no TTY.** `tty` prints `not a tty`, `/proc/self/fd/0` is
  `/dev/null`, so `reptyr` refuses immediately: it needs a target that still owns
  a terminal. The common "suspend → `bg` → `disown` → `reptyr`" recipe fails at
  every step, and `disown` in particular only detaches the job table, not the
  process group — the frozen `nohup` row above is what that looks like.
- **`kernel.yama.ptrace_scope = 1`** on this fleet, so a non-ancestor cannot
  ptrace the process anyway; even a real TTY rescue needs root.

## Pick the tool

| The process is… | Use | Why |
| :--- | :--- | :--- |
| interactive, needs keystrokes later (an agent CLI, a shell, a TUI) | `tmux new-session -d` + `send-keys` / `capture-pane` | one detached session, driveable from any later call, a human can attach |
| long, non-interactive, wants logs and a restart policy | `systemd-run --user --unit=… --collect` | supervised, journaled, `systemctl --user` visible, survives logout |
| already running **with a real TTY** (a human's shell) | `reptyr` (last resort) | the only case where reparenting is right |
| already running **without** a TTY (anything an agent started) | restart it inside tmux | it cannot be rescued, and the state is on disk, so restart is lossless |

Anything that is really a *service* is systemd, and this repo has the precedent:
the DeepSeek harness began in a tmux pane and is now `dsh-web.service`
(`.agents/deploy/hosts/delphi.md`).

## Recipes

Start detached, named so it cannot collide with a human's sessions (`agent-`
prefix; this host already has sessions `1` and `hi`):

```bash
tmux new-session -d -s agent-build -c ~/Documents/nixconfig -- bash -lc 'just long thing'
```

Drive it from a later call, no attach:

```bash
tmux has-session -t agent-build 2>/dev/null || echo gone
tmux send-keys -t agent-build 'nix shell nixpkgs#hello -c hello' Enter
tmux capture-pane -p -t agent-build | tail -20      # what it printed
tmux attach -t agent-build                          # hand it over (Ctrl-b d leaves)
```

Capture past the visible pane when the output matters more than the screen:

```bash
tmux pipe-pane -o -t agent-build 'cat >> /tmp/agent-build.log'
```

## Status by name, not index

`tmux capture-pane -t 0:3.1` breaks the moment a lane opens or closes, and the
lanes here already carry names — `pane_title` (`~> hermes`) on the titled panes,
`window_name` otherwise. The named surface is `task agents:tmux`:

```bash
task agents:tmux                       # session:window map — names, titles, commands
task agents:tmux:show NAME=hermes      # tail the pane whose title or name matches
task agents:tmux:show NAME=devin LINES=60
```

`scripts/task/agents-tmux.sh` resolves the name to a `session:window_id` once
and captures that — no index arithmetic, no drift. It is the *live* view only:
xs (`task agents:xs:list`) stays the verified record, and a quiet pane proves
nothing either way.

Long batch job, no keystrokes, wants journald:

```bash
systemd-run --user --unit=agent-sweep --collect --working-directory="$PWD" \
  bash -lc 'task checks:host HOST=frieren'
systemctl --user status agent-sweep.service
journalctl --user -u agent-sweep.service -f
```

Rescue, only when the process still owns a TTY, and expect root:

```bash
ps -o pid,tty,stat,cmd -p <pid>                 # tty must be pts/N, not ?
nix shell nixpkgs#reptyr -c sudo reptyr <pid>   # run it inside the target tmux pane
```

No tmux on a fresh host or container: `nix shell nixpkgs#tmux -c tmux new-session
-d -s agent-x -- <cmd>` works, but the store path is only GC-rooted while the
`nix shell` runs. On a host you keep, enable tmux from `modules/shell/default.nix`.

## Driving another agent's pane — and leaving it alive

A worker pane is a TUI that owns a model session. Input arrives as keystrokes,
so a stray `Escape` or `Ctrl+C` is not "cancelling a prompt": it aborts the
worker's turn and can drop the session. Read the tail before typing: `working...`,
a spinner, a modal, a file browser, or `[response interrupted]` is BUSY.

```bash
task agents:tmux                        # name map: session:window, command, title
task agents:tmux:show NAME=devin        # tail that pane
printf '%s' '<task>' | tmux load-buffer -b task -
tmux paste-buffer -b task -t <target>
tmux send-keys -t <target> Enter
tmux capture-pane -p -t <target> | tail -15   # a fresh working line, not just text
```

Visible text in the input box is not proof of submission. Leaving a pane: let it
finish, detach (`Ctrl-b d`), or use the TUI's own quit at a clean prompt. Kill a
session only when it is confirmed dead, and say so in the turn log. The one
`Escape` exception is the released-session/stuck-reconnect recovery in
`agent-pane-session-recovery`.

## Rules

- **Never a bare `&` for work that must finish.** It freezes silently, which is
  worse than dying because it looks alive.
- **Name sessions `agent-*`** and say how to attach in your reply, so the human
  can take over without guessing.
- **Always give the teardown**: `tmux kill-session -t agent-x`, or
  `systemctl --user stop agent-x`. A session nobody owns is a leak.
- **Verify survival, do not assume it**: heartbeat into a file, return from the
  call, read the file in the next one. That is the table above.
- **Watch mode is not a long job.** `task checks:nix:watch` is a grandchild that
  outlives its launcher; stop it with `task checks:nix:watch:stop`, and remember a
  task's `cmds` do not run in bash (`kill` is unsupported there).

## Exit

The process writes to a file from a *later* tool call, and
`tmux has-session`/`systemctl --user is-active` still reports it running. If the
second check is missing, the start did not survive and the recipe was wrong.

Truth: `modules/config/shells/common-packages.nix` — what installs the tool; this page is the procedure.
