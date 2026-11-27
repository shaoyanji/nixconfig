---
name: subagent-orchestration
description: "Run subagent panes: roles, keep busy, poll xs, nudge."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['orchestration', 'subagents', 'tmux', 'xs-turns', 'steward', 'panes']
---

# subagent-orchestration — run the fleet of subagent panes

A set of tmux panes each runs a coding agent (freebuff/DeepSeek, agy/Gemini,
devin, delphi-freebuff). The orchestrator's job is to keep them all busy on
useful work, assign each the task it is best at, and consolidate the polling so
it does not babysit every pane.

## Role assignment (this user's division of labor)

Live layout on frieren (session `default`, 3 windows) and delphi (socket
`/run/user/1000/tmux-1000/default`):

| Host | Pane | Model | Use for | Avoid |
| :--- | :--- | :--- | :--- | :--- |
| frieren | freebuff (tab 1) | DeepSeek V4.1 Flash | high-technical nixconfig optimization, gated innovation, agent recall/knowledge fetches | email, light research |
| frieren | devin (tab 2) | Devin (500+ tok/s) | fast software-engineering build-outs, drafting, instabox/clanker builds | online research |
| frieren | tab 3 (ssh tunnel) | delphi freebuff (DeepSeek) | remote agent pane reached through `ssh -t delphi... tmux attach` — see "Driving a pane over an ssh tunnel" | a raw remote shell (never typed into) |
| delphi | freebuff (window 1) | DeepSeek | high-bandwidth ops (instabox, R2, caches), colocated postgres fetcher | — |

The layout is discovered, not hardcoded — an index from last week can now be an
ssh pane. Read the live window list (`tmux list-windows -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_current_command}'`) before trusting any row above; agy is not in the frieren layout and tab 3 is the delphi tunnel, not a local Gemini pane.

## Launching an agent pane — NEVER `-p` for a persistent worker

The single most destructive mistake: launching agy with `-p`/`--print`. Print
mode is **non-interactive** — it runs one prompt, prints the answer, and
**exits**, so the pane dies and there is nothing left to steer. A persistent
worker pane must be launched **interactive** (no `-p`), in auto mode:

```bash
# agy (frieren tab 3) — interactive, stays alive, auto-approves tools
nix run github:numtide/llm-agents.nix#antigravity-cli -- --dangerously-skip-permissions
# then type the task into the TUI prompt

# devin (frieren tab 2) — interactive TUI, bypass/permission mode
devin
# then type the task into the TUI prompt
```

Use `-p` ONLY for a one-shot headless call whose output you consume directly
(and pair it with `--output-format json` if another harness parses the result).
Interactive pane = no `-p`; one-shot = `-p` (+ `--json`).

## Keep every pane busy

Standing preference: do not let a pane sit idle. When one finishes, feed it the
next task immediately. Have a queue of candidate tasks ready (open AGENTS.nix
experiments, followups the agent itself flagged, pending DB work).

## The steward delegates, never executes

The steward's job is to route work to panes and keep them moving. A steward who
executes a task personally instead of handing it to an idle worker pane has
failed the role — the work still gets done, but no pane was driven and the
steward burned turns doing a worker's job.

- **If a pane is idle, delegate to it.** Write a brief (the task, the inputs,
  the gate, the expected output) and send it to that pane. Do not open a
  terminal and run the commands yourself.
- **If all panes are busy, queue the task.** Do not execute it yourself while
  waiting. Feed it to the first pane that reports IDLE.
- **If a background process is running (deploy, build, upload), delegate its
  completion check to an idle pane.** Do not poll the process yourself. The
  pane runs the wait + verify and reports back real output. Polling a long
  command yourself is the steward acting like a worker — it burns turns and is
  exactly what the role exists to prevent.
- **A worker pane's real output is the evidence.** Accept `tmux capture-pane`
  output, curl results, exit codes, and file listings from the pane as proof.
  Do not re-run the verification yourself "just to be sure."

## Poll via the xs ledger, not the pane

Agents that post their turns to xs (source `devji` for freebuff) can be watched
by polling the ledger for a NEW `done` turn instead of scraping the tmux pane:

```bash
# newest turn id + outcome for a source
task agents:xs:list REPO=nixconfig SOURCE=devji LIMIT=5 FORMAT=json \
  | sed '1{/^task:/d}' | jq -r '.turns[0] | {id, out, subj}'
```

A watcher loop that records the newest id and exits when a new `done` appears
consolidates N pane polls into one tailnet API query. This only works when the
agent adheres to turn logging — so keep the AGENTS.md guidance strong and treat
the ledger as the primary signal, the pane as the fallback.

## Nudging a pane

- Local panes: `tmux send-keys -t 0:<win> '<prompt>' Enter`, then verify the
  text landed in the input box before pressing Enter (the TUI may be mid-
  redraw).
- **`send-keys` works on a detached pane.** The pane process owns the pty, not
  the client; `session_attached` only says whether a human is looking at it. Do
  not attach a background PTY just to type, and do not ask the human to attach.
  Verify input with `tmux capture-pane -p -t <target>`.
- **Leaving a pane is not part of the job.** Let it finish, detach (`Ctrl-b d`),
  or use its own `/quit`. Never send `Escape`/`Ctrl+C` to a pane that is
  working, and never kill a window to tidy up. A confirmed-dead session is
  killed, and that loss goes in the xs turn.
- **agy uses vim input mode** (from nixconfig). To type into agy you must first
  enter insert mode with `a` or `i`, and exit with `esc` before submitting.
  A bare `send-keys '<text>' Enter` races the vim mode: the leading characters
  get eaten as vim commands (`d` deletes, `i`/`a` enter insert) and the Enter
  lands as a newline inside the editor instead of submitting. Correct sequence:
  `send-keys 'i'` (enter insert) → `send-keys '<task text>'` → `send-keys Escape`
  (exit insert) → `send-keys Enter` (submit). Verify the pane is NOT in
  `-- INSERT --` mode before pressing Enter.
- Remote (delphi): `ssh devji@delphi.bountystash.com 'tmux -S
  /run/user/1000/tmux-1000/default send-keys -t 0:1.1 "..." Enter'`. The socket
  is under `TMUX_TMPDIR=/run/user/1000`, NOT `/tmp`. Select the pane first
  (`select-pane -t 0:1.1`) before sending.
- **Driving a pane over an ssh tunnel (preferred when a local pane is already
  attached).** When a local pane runs `ssh -t <host> tmux attach`, its
  `capture-pane` shows the *remote* TUI and a local `tmux send-keys -t 0:<win>` /
  `load-buffer -t 0:<win>` tunnels through ssh to the remote agent — no fresh
  `ssh` invocation needed. Verify the capture shows an agent-TUI marker (freebuff
  prompt, devin banner) before typing; a raw remote shell shows none and must
  never be driven. This is how the delphi freebuff pane is kept busy.
- After sending, verify the prompt landed in the input box before pressing
  Enter — a send that races the TUI's own typing can interleave and corrupt the
  input.

## Author zettels on pane performance

When orchestrating, capture impressions of each pane's quality/speed as a zettel
in the Obsidian vault (`/Volumes/data/projects/Obsidian-Git-Sync/zettels/`),
filename `YYYYMMDDHHMM-short-title.md`, with frontmatter (title, type: zettel,
created, tags, aliases), a Claim, Context, Evidence, and Links. Package evidence
(commit counts, adherence gaps, measured latencies) rather than vibes.

## Pitfalls

- **Do not fight a wedge.** If a pane does not react to `send-keys`, capture it:
  a modal, a released session, or a stuck reconnect is the cause (see
  `agent-pane-session-recovery`), not a missing attachment. Recover the TUI,
  then send. Never `Ctrl+C` your way out.
- **A stale watcher fires on an old task.** When you restart a watcher, kill the
  old one or it will notify on a stale idle/timeout. Track the current watcher
  pid and ignore notifications from superseded ones.
- **The xs ledger is only as good as adherence.** An agent that does not post
  turns (devin) must be watched by pane polling; an agent that posts but omits
  the commit (agy's first turn) needs a nudge to name it. Enforce the AGENTS.md
  guidance and correct the agent's own turn when it violates it.
- **Verify a nudge landed before Enter.** A send that races the TUI redraw can
  drop or interleave text; capture the pane and confirm the prompt is in the
  input box first.

Truth: `scripts/task/pane-nudge.sh`, `scripts/task/xs-turn-list.sh` — the nudge and the ledger; this page is the doctrine.
