---
name: steward-cron
description: "Convert monitoring cron into self-driving steward agent."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['cron', 'steward', 'tmux', 'panes', 'monitor', 'self-driving']
---

# steward-cron — a monitoring cron that drives the fix, not the ping

A monitoring cron that only reports state to the user's chat is a reminder, not
a tool. The user's standing preference: a cron that watches for a condition
should act on that condition itself, not notify the user to act. When a cron
pings the user's chat with "X is idle / Y needs attention", that is the steward
slacking — the cron should drive the fix directly.

## Procedure: convert a no_agent script cron into a self-driving agent job

1. **Set `no_agent=false`** — the cron runs as an agent with tools, so it can act
   on the condition it detects.
2. **Write a self-contained imperative prompt**: run the detection script; if the
   condition is met, do the work (route decisions through jevdecide, execute the
   fix via tmux load-buffer/paste-buffer/Enter); if not, output nothing.
3. **Set `deliver=local`** — output goes to the job's own working state, never the
   user's chat. Without this, the agent job's output still lands in the chat.
4. **Load the skills the job needs** (`skills=[...]`) so the agent knows the
   procedure and pitfalls without re-deriving them.
5. **Land an xs post** (`task agents:xs:post ... OUTCOME=done COMMITS=<hash>
   SOURCE=<agent>`) when the job acts, so the turn is recorded.

## When to apply

- A cron that reports "X is idle / stale / broken" to the user's chat.
- A watchdog that detects a condition but leaves the response to a manual turn.
- Any scheduled check whose output is meant to prompt action.

## The pane-idle-watch example

`pane-idle-watch` (29bb63f1e2e1, every 2m) runs `pane-watch.sh` and reports each
pane `BUSY` / `IDLE` / `UNKNOWN`. Converted from `no_agent` script → self-driving
agent job. Its prompt runs `pane-watch.sh`, routes each IDLE pane's next task
through `jev-decide classify --provider typesafe`, sends via load-buffer/paste-
buffer/Enter, lands an xs post, and outputs nothing when all panes are BUSY. It
loads `tmux-pane-steward`, `agent-pane-session-recovery`, and `jevdecide`.

## Updating a steward's prompt in place

To change what an existing self-driving cron does (its detection rules, its
action procedure), edit the prompt rather than recreating the job:

```bash
hermes cron edit <job_id> --prompt '<new self-contained prompt>'
```

The prompt is the executable spec — a stale prompt (e.g. one that forbids an
action the script now reports as driveable) silently blocks the job from acting
even when the script is correct. After editing, confirm it persisted with
`jq -r '.jobs[] | select(.id=="<job_id>") | .prompt' ~/.hermes/cron/jobs.json`
before waiting on the next tick. `hermes cron edit --help` lists the other
fields (schedule, deliver, skills, script, model).

## When the steward goes silent (a stuck execution holds the slot)

A self-driving cron can stop firing while `last_status` still reads `ok` and the
schedule is intact: one execution row gets wedged in `running` (its worker
finished or died without writing a completion), and it holds the job's single
execution slot. While the slot is held, `hermes cron status` shows `next_run`
perpetually deferred and the job never fires — it looks healthy but is silent.

**Diagnose before re-running or recreating anything:**

```bash
# a 'running' row older than the healthy window (the 450s / 45-min flag) is stuck
sqlite3 ~/.hermes/cron/executions.db \
  "select id, datetime(started_at), status from executions
   where job_id='<job_id>' and status='running' order by started_at desc;"
hermes cron status 2>&1 | grep -i 'next run'   # not advancing = slot held
```

**Clear the stuck row with `hermes cron cancel <job_id>`.** It is cooperative
("the run stops at its next cancel check") — the row flips to `cancelled` and the
slot frees. Confirm `next_run` advances and the next tick fires. Do not recreate
or re-schedule the job; the schedule is intact, only the execution row was wedged.

## Pitfalls

- **`deliver=local` is what stops the user-chat spam.** Without it, the agent
  job's output still lands in the chat. Set it explicitly.
- **A `no_agent` cron that pings the user is the failure mode.** Do not keep it
  as a passive reporter. If the user says a cron is "a reminder for me",
  convert it to an agent job that acts.
- **The agent job needs full context to act.** Give it the detection script
  path, the action procedure, and the skills. A bare "check and report" prompt
  leaves it unable to drive the fix.
- **Empty output when nothing needs doing.** The job should output nothing when
  the condition is not met, so it does not generate noise.
- **`TMUX_TMPDIR` must be exported in `pane-watch.sh`.** A cron job does not
  inherit `TMUX_TMPDIR`, so `tmux capture-pane` finds no socket and every pane
  reports `UNKNOWN`. The script must export it itself:

  ```bash
  export TMUX_TMPDIR="${TMUX_TMPDIR:-/run/user/1000}"
  ```
- **`UNKNOWN` for every pane = dead tmux server, not a broken script.** The
  server socket is gone; rebuild the session and relaunch agents before re-
  driving.
- **`last_status=ok` does not mean the loop is firing.** A stuck `running`
  execution row holds the job's single execution slot, so `next_run` stays
  deferred and the job runs silently (see "When the steward goes silent").
  Before assuming the job works, check the execution log for a stale `running`
  row and confirm `next_run` actually advances; clear a stuck row with
  `hermes cron cancel <job_id>`.

## Verification

- Run `task cronjob_manage list` and confirm `deliver=local`, `no_agent=false`,
  `state=scheduled`, and `last_status=ok`.
- Run `env -u TMUX_TMPDIR -u TMUX bash pane-watch.sh` — it must report real
  pane states, not all-UNKNOWN.
- Confirm an IDLE pane receives a task via load-buffer/paste-buffer within one
  cron cycle (~2m), and an xs post lands with OUTCOME=done.

Truth: `scripts/task/pane-poll.sh`, `scripts/task/pane-nudge.sh` — the watch and the drive; this page is the doctrine.
