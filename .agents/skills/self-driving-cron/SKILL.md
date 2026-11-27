---
name: self-driving-cron
description: "Use when a monitoring cron should act, not ping the user."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['cron', 'monitor', 'automation', 'nudge', 'steward']
---

# self-driving-cron — a monitoring cron does the work, not the pinging

A monitoring cron that only reports state to the user's chat is a reminder, not
a tool. The user's standing preference: **a cron that watches for a condition
should act on that condition itself, not notify the user to act.** When a cron
pings the user's chat with "X is idle / Y needs attention", that is the steward
slacking — the cron should drive the fix directly.

## The pattern: convert a `no_agent` script cron into an agent job

A `no_agent` cron runs a script and delivers its stdout verbatim to the chat. It
can detect a condition but cannot act on it — the acting is left to a
human-triggered turn, which is the slack. Convert it to an agent job:

1. **`no_agent=false`** — the cron runs as an agent with tools, so it can act.
2. **Prompt is self-contained and imperative**: run the detection script; if the
   condition is met, do the work (route decisions through jevdecide, execute the
   fix); if not, output nothing.
3. **`deliver=local`** — output goes to the job's own working state, never the
   user's chat. The cron is the agent's own nudge, not a user-facing reminder.
4. **Load the skills the job needs** (`skills=[...]`) so the agent knows the
   procedure and pitfalls without re-deriving them.
5. **Land an xs post** when the job acts, so the turn is recorded.

## When to apply

- A cron that reports "X is idle / stale / broken" to the user's chat.
- A watchdog that detects a condition but leaves the response to a manual turn.
- Any scheduled check whose output is meant to prompt action.

## Pitfalls

- **A `no_agent` cron that pings the user is the failure mode.** If the user
  says a cron is "a reminder for me" or "nudges for you that you're slacking",
  convert it to an agent job that acts — do not keep it as a passive reporter.
- **`deliver=local` is what stops the user-chat spam.** Without it the agent
  job's output still lands in the chat. Set it explicitly.
- **The agent job needs the full context to act.** Give it the detection script
  path, the action procedure, and the skills. A bare "check and report" prompt
  leaves it unable to drive the fix.
- **Empty output when nothing needs doing.** The job should output nothing when
  the condition is not met, so it does not generate noise.

Truth: `scripts/task/pane-poll.sh`, `scripts/task/pane-nudge.sh` — the watch and the drive; this page is the doctrine.
