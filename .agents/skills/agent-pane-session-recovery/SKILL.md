---
name: agent-pane-session-recovery
description: "Recover a dropped agent TUI pane before nudging it."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['tmux', 'panes', 'recovery', 'reconnect', 'tui', 'agents']
---

# agent-pane-session-recovery — bring a dropped agent TUI back

A coding-agent pane (freebuff/DeepSeek, agy/Gemini, devin) runs a TUI whose
model connection can drop. The pane does not die — it shows a "session
released" dialog or loops in `working...` — and a nudge sent into that state is
silently swallowed. This is the recovery procedure and the trap that costs time.

## Detect the two failure states

Capture the pane and read the last lines:

```bash
tmux capture-pane -t default:3 -p | grep -v '^$' | tail -10
```

- **Released session**: a dialog "This session was released. Choose a model to
  start a new session" with `Enter: retry  Esc: back to draft`. The model
  connection dropped.
- **Stuck reconnect**: the pane shows `working...` with a growing seconds
  counter and never returns to a prompt. The model is not coming back on its
  own.

## Recover

1. **Released session** → press `Enter` to retry. If it comes back to a clean
   prompt, proceed.
2. **Stuck reconnect** (or retry loops past ~1 minute) → press `Esc` to cancel
   the reconnect and return to a clean prompt. `Esc` is the reliable escape
   hatch for both states.
3. **Verify a clean prompt** — the pane must show "Enter a coding task" (or
   the equivalent idle prompt), NOT `working...`, before you paste anything.

## The trap: pasting into a reconnecting pane

If you paste a task while the pane is mid-reconnect, the text lands in the input
box but the `Enter` is consumed by the reconnect, and the pane returns to a
clean prompt WITHOUT accepting the task. It looks like the nudge worked (the
text is visible) but nothing was submitted. The pane's scrollback may even show
a stale response from a previous task, making it look busier than it is.

Rule: **never paste until the pane is at a clean prompt.** If it is `working...`
or showing a released-session dialog, recover it first (Esc), then paste, then
verify the task text is in the input box, then send `Enter`.

## Verify the task actually started

After submitting, wait a few seconds and capture again. A pane that accepted the
task shows `working...` (now a fresh, short counter) or tool-run lines. A pane
that returned to a clean prompt without running anything means the paste did not
stick — recover and re-issue.

## Driving a remote pane (delphi)

The delphi freebuff pane is driven over ssh; its tmux socket is
`/run/user/1000/tmux-1000/default`, NOT `/tmp`:

```bash
ssh delphi.bountystash.com 'export TMUX_TMPDIR=/run/user/1000; \
  tmux capture-pane -t 0:1.1 -p | grep -v "^$" | tail -10'
# paste a task:
ssh delphi.bountystash.com 'export TMUX_TMPDIR=/run/user/1000; \
  printf "<task>" | tmux load-buffer -b task -; \
  tmux paste-buffer -t 0:1.1 -b task; tmux send-keys -t 0:1.1 Enter'
```

Use `load-buffer` + `paste-buffer` for long task text — `send-keys` with long
strings gets mangled by the TUI's escape handling.

## Pitfalls

- **A released session is not a dead pane.** Do not kill or restart the tmux
  window; the session state is on disk and `Enter`/`Esc` recovers it losslessly.
- **Do not trust the visible task text as proof of submission.** The paste can
  sit in the input box unsubmitted; only a fresh `working...` counter or tool
  lines after `Enter` confirm the task started.
- **A stale scrollback response is not current activity.** The pane may show an
  old answer while actually idle at a prompt; capture the bottom lines, not the
  history, to judge liveness.

Truth: `scripts/task/pane-nudge.sh` — the driving mechanics; this page is the recovery procedure.
