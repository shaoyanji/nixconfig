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

An agent's tool call runs in a shell whose whole process group is torn down when
the call returns. `&`, `nohup` and `disown` do **not** change that. The reliable
answer is not to rescue the process afterwards, it is to **start it inside a
session that owns its own lifecycle** — a detached tmux session for anything
interactive, a transient systemd unit for anything batch.

## What was measured on frieren (2026-10-21)

Three identical heartbeat loops, started in one tool call, checked from a *later*
tool call:

| Start | Lines written before the call ended | After the next call | Verdict |
| :--- | :--- | :--- | :--- |
| `tmux new-session -d -- bash -c 'while :; do date >> f; sleep 1; done'` | 4 | **14** | survived |
| `systemd-run --user --unit=… --collect bash -c '…'` | 3 | **14**, unit `active` | survived |
| `nohup bash -c '…' &` | 4 | **4**, process still listed | frozen — it exists and does nothing |

Two facts follow, and they decide the tool:

- **The tool shell has no TTY.** `tty` prints `not a tty`, `/proc/self/fd/0` is
  `/dev/null`. `reptyr` requires the target to still own a terminal, so a process
  spawned here **cannot** be reparented by reptyr at all — it fails before any
  ptrace discussion.
- **`kernel.yama.ptrace_scope = 1`** on this fleet: a non-ancestor cannot ptrace
  a process, so even a rescue of a real TTY process needs root.

## Pick the tool

| The process is… | Use | Why |
| :--- | :--- | :--- |
| interactive, needs keystrokes later (an agent CLI, a shell, a TUI) | `tmux new-session -d` + `send-keys` / `capture-pane` | one detached session, driveable from any later call, human can attach |
| long, non-interactive, wants logs and a restart policy | `systemd-run --user --unit=… --collect` | supervised, journaled, `systemctl --user` visible, survives logout |
| already running **with a real TTY** (a human's shell) | `reptyr` (last resort) | only case where reparenting is the right idea |
| already running **without** a TTY (anything an agent started) | restart it inside tmux | it cannot be rescued; the state is on disk, so restart is lossless |

For anything that is really a *service*, systemd wins outright — that is the
precedent in this repo: the DeepSeek harness began life in a tmux pane and is now
`dsh-web.service` (`.agents/deploy/hosts/delphi.md`). Use tmux for sessions a
person or an agent talks to, systemd for daemons.

## Recipes

Start detached, with a name that cannot collide with a human's sessions
(`agent-` prefix; this host already has sessions `1` and `hi`):

```bash
tmux new-session -d -s agent-build -c ~/Documents/nixconfig -- bash -lc 'just long thing'
```

Drive it from a later call, no attach needed:

```bash
tmux has-session -t agent-build 2>/dev/null || echo gone
tmux send-keys -t agent-build 'nix shell nixpkgs#hello -c hello' Enter
tmux capture-pane -p -t agent-build | tail -20      # what the process printed
tmux attach -t agent-build                          # hand it to the human (Ctrl-b d to leave)
```

Capture past the visible pane with a pipe, when the output matters more than the
screen:

```bash
tmux pipe-pane -o -t agent-build 'cat >> /tmp/agent-build.log'
```

Long batch job, no keystrokes, wants journald:

```bash
systemd-run --user --unit=agent-sweep --collect --working-directory="$PWD" \
  bash -lc 'task checks:host HOST=frieren'
systemctl --user status agent-sweep.service
journalctl --user -u agent-sweep.service -f
```

Rescue — only when the process still owns a TTY, and expect to need root for
`ptrace_scope=1`:

```bash
ps -o pid,tty,stat,cmd -p <pid>          # tty must be pts/N, not ?
nix shell nixpkgs#reptyr -c sudo reptyr <pid>   # run it *inside* the target tmux pane
```

If tmux is missing (fresh host, container), take it from nix without installing:
`nix shell nixpkgs#tmux -c tmux new-session -d -s agent-x -- <cmd>` — but check
whether the session outlives the `nix shell` invocation, since the store path is
only GC-rooted while it runs. On a host you intend to keep, enable
`modules/shell/base.nix`'s tmux rather than wrapping.

## Why the pasted reptyr workflow fails here

The common advice is *suspend → `bg` → `disown` → `tmux new` → `reptyr <pid>`*.
On an agent's own shell each step is wrong for a different reason:

1. **`disown` detaches from the job table, not from the process group.** Cleanup
   signals the group; the measured frozen `nohup` process above is what that
   looks like — present in `ps`, making no progress.
2. **There is no TTY to move to.** `reptyr` attaches a target that has a
   controlling terminal; `/dev/null` is not one, so it refuses immediately.
3. **`ptrace_scope=1`** means even a same-user rescue is permission-denied unless
   the rescuer is an ancestor or root.
4. `Ctrl-Z` is unavailable — there is no foreground job to suspend, and no
   keystrokes reach the tool shell.

## Rules

- **Never a bare `&` for work that must finish.** It will freeze silently, and a
  frozen process is worse than a dead one because it looks alive.
- **Name sessions `agent-*`** and say how to attach in the reply, so the human can
  take over without guessing.
- **Always give the teardown**: `tmux kill-session -t agent-x`, or
  `systemctl --user stop agent-x`. A session nobody owns is a leak.
- **Verify survival, do not assume it**: heartbeat into a file, return from the
  call, then read the file in the next call. That is exactly the table above.
- **Watch mode is not a long job.** `task checks:nix:watch` under `watch: true` is
  a grandchild that has survived its launcher for minutes; stop it with
  `task checks:nix:watch:stop`, and remember a task's `cmds` do not run in bash
  (`kill` is unsupported there — `bash -c 'kill "$1"' _ "$pid"`).

## Exit

The process writes to a file from a *later* tool call, and
`tmux has-session`/`systemctl --user is-active` still reports it running. If the
second check is missing, the start did not survive and the recipe was wrong.

Truth: `modules/config/shells/common-packages.nix` — what installs the tool; this page is the procedure.
