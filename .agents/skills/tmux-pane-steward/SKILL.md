---
name: tmux-pane-steward
description: "Steward tmux panes: keep busy, recover dead server."
version: 0.4.0
platforms: [linux]
metadata:
  hermes:
    tags: ['tmux', 'panes', 'steward', 'monitor', 'cron', 'recovery']
---

# tmux-pane-steward — keep the agent panes moving

The steward's job is to keep every coding-agent pane (freebuff, devin,
delphi-freebuff) busy on useful work, route each task through jev-decide,
and land every turn with an xs post. This skill carries the monitoring and
recovery mechanics that cost time when they go wrong.

**No `goal_judge`.** The auxiliary goal_judge system (deepseek/
deepseek-v4-flash at llm.onerouter.pro) is removed from this skill. Every
direction decision for an idle pane goes through `jev-decide decide` with
typesafe as provider — no other judge, no fallback to goal_judge. Feed the
context (recent xs turns, open claims, lane duties) as the `state` and the
candidate next directions as `criteria`; jev-decide selects the direction.

## The pane-idle-watch cron — now a self-driving steward agent job

The `pane-idle-watch` cron (every ~2m) runs `pane-watch.sh` and reports each
pane `BUSY` / `IDLE` / `UNKNOWN`. It is a **self-driving agent job**, not a
`no_agent` script: when it detects an `IDLE` pane, it drives that pane itself —
routes the next task through jev-decide, sends it via `load-buffer` +
`paste-buffer` + `Enter`, lands an xs post, and delivers to `local` (not the
operator chat). It does not ping the user; it acts as its own steward.

**Convert pattern** (when turning any `no_agent` monitor cron into a self-driving
job): set `no_agent=false`, give the cron its own prompt that calls the monitor
script and acts on the result, add the relevant skills (`tmux-pane-steward`,
`agent-pane-session-recovery`, `jevdecide`), set `deliver=local`, and add a
landing step (`task agents:xs:post` with OUTCOME=done, name commit + gate).

When it reports an `IDLE` pane, drive it immediately — do not wait for a nudge.

**Driving an idle pane** (procedure the cron agent follows — the micro-turn
scheme, 2026-11-25: one classify call, one ledger row, one-line nudges, one
consolidated poll; the pane pulls full detail from xs itself instead of
receiving prose):

1. Run `pane-watch.sh` to find IDLE panes. (`capture-pane` still detects the
   idle *prompt* — the ledger does not know that; status polling below is
   what replaces per-pane scrapes.)
2. For each IDLE pane, route its next task through
   `bash scripts/task/jev-route.sh` (stdin = the task sentence; stdout =
   `label|probability|margin`; exit 0 selected, 2 needs_review, 1 error).
   On needs_review drive the printed top choice — the row is already the
   record. The old `decide` flow with the duelling fallback still applies
   when the task itself needs a direction chosen, not just a lane label.
3. Post the route as a micro-turn:
   `SUBJECT=nixconfig:<id> CLAIM=<paths> ACTION="<route + gate, one line>"     OUTCOME=in_progress bash scripts/task/xs-micro-turn.sh`
   ACTION ≤ ~60 chars (hard cap 72 — truncated past it). The turn IS the
   brief; nothing longer is written anywhere.
4. Nudge the pane with the one-line reference, never the task prose:
   `TARGET=agents:<w> SUBJECT=<id> CLAIM=<paths> ACTION=<line>     bash scripts/task/pane-nudge.sh`
   Target windows in session `agents`: `agents:1` (devin), `agents:2`
   (freebuff), `agents:3` (delphi). The script clears half-typed input,
   load-buffer + paste-buffer + one Enter.
5. Verify with ONE consolidated poll instead of a capture per pane:
   `bash scripts/task/pane-poll.sh` — one `agents:xs:list LIVE=1` call, one
   row per live subject (in_progress/blocked/failed, age). A pane's newest
   turn is its state; a quiet pane proves nothing either way.
6. Land the pane's own xs post when its work finishes (done names commit +
   gate), push to origin/main. Re-drive on the next IDLE — a finished task
   drops the pane back to "Add to the current task".

**`UNKNOWN` for every pane is the signature of a DEAD tmux server, not a broken
script.** `tmux capture-pane` returns nothing when the server socket is gone, so
every pane falls through to `UNKNOWN`. When the cron reports all-`UNKNOWN`,
check the server before touching the script:

```bash
tmux ls   # "no server running on ..."
ps aux | grep tmux | grep -v grep   # empty = no server
```

A gateway restart or host reboot kills the tmux server and all agent panes with
it — the panes are gone, not idle. Rebuild the session and relaunch the agents
before re-driving. The script is fine; do not rewrite it.

**The cron environment lacks `TMUX_TMPDIR`.** The tmux server socket lives under
`/run/user/1000/tmux-1000/`, but a cron job does not inherit `TMUX_TMPDIR`, so
`tmux` looks in `/tmp/tmux-1000/` and finds nothing. `pane-watch.sh` must export
it itself:

```bash
export TMUX_TMPDIR="${TMUX_TMPDIR:-/run/user/1000}"
```

Without that line the cron reports `UNKNOWN` for every pane even when the server
is alive. Verify by running the script with `env -u TMUX_TMPDIR -u TMUX bash
pane-watch.sh` — it must still report real states.

**An `ssh` pane that runs an agent TUI IS driveable through the tunnel — do not
blanket-skip it.** A window whose `pane_current_command` is `ssh` but whose
capture shows a freebuff/devin TUI (e.g. `ssh -t delphi... tmux attach`) is a
*remote* agent pane: `capture-pane` shows the remote TUI, and
`load-buffer`/`paste-buffer`/`send-keys -t <pane>` tunnel through ssh to drive
it. The old `awk '$2 != "ssh"'` filter in `pane-watch.sh` skipped these and left
the remote pane permanently idle. The fix: include ssh panes, but classify
`SKIP` (never typed into) only when the capture shows NO agent-TUI marker (a raw
remote shell). pane-watch reports `IDLE`/`BUSY` for an ssh pane showing an agent
TUI, `SKIP` for a raw shell. The steward prompt must say the same: drive ssh
panes that pane-watch reports IDLE/BUSY, never a SKIP.

## Standing-goal trigger (user's explicit instruction)

The user's standing goal is: **\"make sure pane 1 2 and 0 are always active and
not going idle. use jev decide for giving directions. just feed the context
for the decisions.\"** This is the primary trigger for the driving workflow,
distinct from the cron-job pattern above. The procedure is the same as the
cron procedure, but the agent is acting on a repeated user goal, not a
cron fire.

**Standing-goal procedure** (run this loop each time the user restates the
goal and the panes are idle):

1. Check pane state: `tmux capture-pane -t agents:<w> -p | tail -2` for
   each of windows 1, 2, 3. If a pane shows a `working...` / `Thinking ·`
   / `Running tools ·` timer, it is BUSY — skip it.
2. Pull fresh ledger context:
   ```bash
   set -a; . ~/.config/hermes/hermes.env 2>/dev/null; set +a
   AGENT_TURNS_TOKEN=\"$(sops -d modules/secrets.yaml | yq -r '.[\"agent-turns-token\"]')\"
   curl -sS -H \"Authorization: Bearer $AGENT_TURNS_TOKEN\" \\
     \"https://delphi.cloudforest-kardashev.ts.net:8449/v1/events?repo=nixconfig&limit=30\" \\
     | jq -r '.events[] | \"[\\(.ts)] (\\(.source)) \\(.subject) [\\(.outcome)]: \\(.action | .[0:120])\"'
   ```
   Extract each pane's recent turns for its `state` field.
3. Build a Jev JSON for each idle pane in `~/.hermes/cache/scratch` using the
   naming convention `jev-<pane>-<version>.json` (version increments per
   cycle, e.g. `jev-devin-110x.json`, `jev-freebuff-110x.json`,
   `jev-delphi-110x.json`). Schema: see
   `references/jev-decide-decision-format.md`.
4. Run `jev-decide decide <file>.json --provider typesafe
   --min-probability 0.8 --min-margin 0.15` for each pane. On `needs_review`
   with margin < 0.3, duel the top two with a second call containing only
   those two criteria.
5. Feed each pane via `load-buffer` + `paste-buffer` + `sleep 1` +
   `send-keys Enter`. Verify with a 4 s sleep + capture-pane that each pane
   now shows a working/thinking timer.

**The Jev JSON `state` field should always reflect the CURRENT ledger
context, not a static template.** Re-pull the ledger before each cycle —
the panes' recent turns change fast, and a stale `state` gives jev-decide
the wrong picture of what the pane just finished.

## The codification phase (user meta-instruction)

The standing goal has a meta-phase the user triggers by explicit instruction:
instead of re-driving a lane with another Jev task, have the lane agent
**codify its own process** — "review your work and the underlying process,
author a taskfiles tool that builds the tool-call primitives chain so
replication is much easier and self-explanatory, author a skill mirroring a
proper taskfile summary and description, and keep going." When the user issues
this, feed each idle lane the same meta-brief tailored to that lane's process:
review the lane's own tool-call chain → author a NAMED taskfiles task wrapping
that chain as a self-explanatory entry point → author a matching `SKILL.md`
whose description mirrors the taskfile's summary/description → land both,
post an xs turn describing the chain, keep going. This converts the ad-hoc
repeated Jev loop into a durable task + skill pair — the user's standing
nixconfig convention (a skill mirrors its taskfile). Do not skip the xs turn:
the codified chain is the record a future steward reads.

## When the loop stops re-driving (stuck cycle or dead model)

If panes sit idle even though the pane-idle-watch cron is enabled and
`last_status=ok`, the loop is running but not effectively driving. Two root
causes — check them in this order.

**A stuck "running" cycle holds the single job slot.** A self-driving cron
job has one running slot; a cycle that started but did not complete (a long
agent turn, a wedged tool) leaves a `running` row in
`~/.hermes/cron/executions.db`. While a run is `running`, `next_run` is
deferred indefinitely and no new cycle fires. `hermes cron status` shows
`next_run` stuck far ahead while a run has been `running` for many minutes:

```bash
hermes cron status    # next_run deferred while a run is 'running'
sqlite3 ~/.hermes/cron/executions.db \
  "SELECT started_at,status FROM executions WHERE job_id='<id>' ORDER BY started_at DESC LIMIT 3"
```

When a `running` row is past ~450 s with no live child process doing work,
the cycle is stuck — free the slot with `hermes cron cancel <job_id>`
(cooperative: stops at the next cancel check; the slot clears and `next_run`
advances). That same "running for >450 s" row is exactly what
`hermes-check.sh` (`checks:hermes-cron`) flags.

**A dead or rate-limited LLM model stalls every cycle.** The cron agent runs
on a configured model; if that model 404s (deprecated) or 429s, hermes
retries it `api_max_retries` times with long backoff before failing over to
the next allowlist lane, so each cycle takes 10–17 min and often completes
without driving any pane. Check the gateway journal for the job's model
errors:

```bash
journalctl --user -u hermes-gateway --since '10 min ago' | grep -iE '429|404|RateLimit|model_deprecated'
```

Fix: verify a replacement model works with the same key (`curl` the chat
endpoint), then flip `~/.hermes/config.yaml` `model.default` AND
`providers.<provider>.default_model` to it and reorder the provider `models`
allowlist so the working model is first (keep the dead one as a failover
lane). A running gateway holds the old model in memory, so a gateway restart
makes it live — but the gateway restart is on the frieren deny-list
(no-venv crash-loop rule), so it may be a user action.

## Recovering a rate-limited agent (agy)

agy on the free Gemini tier (`agy-gemini` wrapper, `modelProvider=gemini`) hits a
hard daily quota (~20 requests/day) and returns HTTP 429 with a retry delay of
hours. The pane shows a `429` / `quota_exceeded` error and stops making progress.

**Restart agy on the account route to bypass the free-tier quota.** The plain
`agy` binary (no `--settings '{"modelProvider":"gemini"}'`) uses the Pro account
route, which is not rate-limited the same way. The account is authenticated via
`~/.gemini/antigravity-cli/antigravity-oauth-token`.

```bash
# Only when the pane is confirmed wedged (no output for minutes): quit the TUI
# with its own command at a clean prompt, then relaunch on the account route.
# Never Ctrl+C a pane that is working; it aborts the turn and can drop the
# session. If the TUI will not quit, kill that window deliberately and say so
# in the xs turn.
/nix/store/<hash>-antigravity-cli-<ver>/bin/agy
```

Verify the relaunch shows the account model (e.g. `Gemini 3.8 Flash`) rather
than the free-tier model (`Gemini 4 Hydrogen`). If the user says "back off" on a
rate-limited agent, leave it idle and move its workload to another pane rather
than fighting the quota.

## Driving a pane with long task text

Prefer `load-buffer` + `paste-buffer` over `send-keys` for any task text longer
than a few words. `send-keys` with a long string gets mangled by the TUI's
escape handling — an `Esc` sent earlier can leave a `^[` prefix on the next
paste, and the text can land in a vim editor (`-- INSERT --`) instead of the
prompt.

On tmux >=3.6 (fleet runs 3.8) `load-buffer -t` is target-**client**, not a
pane — the old `load-buffer -t <target> -` form misfires (loads a buffer, then
the paste targets the wrong thing). Use a named buffer:

```bash
tmux load-buffer -b task-<lane> '<task-file>'
tmux paste-buffer -b task-<lane> -t <target>
tmux send-keys -t <target> Enter
```

Then verify the pane is NOT in `-- INSERT --` and the text is in the input box
before the final Enter. agy opens a vim editor on Enter — exit with `Esc` then
`:wq` to submit.

See `references/jev-decide-decision-format.md` for the reusable jev-decide decision JSON schema used when feeding idle panes.

## Pitfalls

- **The entire TUI footer line is persistent chrome, not an idle indicator.** The bottom line (e.g. `SWE-2 High · bypass · 1 shell ↓  ctrl+o to expand edits` or `← for history · ? for help`) sits on every TUI screen whether the pane is working or idle. Devin can show `1 shell ↓` or `2 shells ↓` while actively running tools — these are TUI chrome, not pane-state signals. A pane is BUSY only when the `working... Ns ■ Esc` line or the `⠋ Thinking · Ns (esc twice to interrupt)` / `⠋ Running tools · Ns` spinner is visible ABOVE the footer; it is IDLE only when the composer shows "Enter a coding task" / "Add to the current task" with no working/thinking line. Do not scan a capture for the footer to decide idleness — look for the working/thinking line, not the footer. The timer lines are the same persistent chrome: after a task finishes, the pane can sit at a bare idle prompt while a stale large timer (`working… 4m 43s`) is still displayed. A large timer magnitude is not proof of BUSY — confirm BUSY by a small/resetting counter or fresh tool-output lines, and confirm IDLE by the composer prompt text, not timer magnitude.

- **A freebuff "Submit" dialog needs an `Enter` to confirm the task.** After
  pasting a task, freebuff can show a modal with a `Submit` button ("↑↓ navigate
  • Enter select"). The task is not accepted until you press `Enter` on that
  dialog; the pane then drops to "Add to the current task" and starts working.
  If the dialog persists after one `Enter`, press it again.
- **A released session is not a dead pane.** The pane shows "This session was
  released" — press `Enter` to retry, `Esc` to cancel. Do not kill the window.
  After pressing Enter to retry, wait ~3 s for the new session to initialize
  before pasting the task text — an immediate paste lands on the model-selection
  screen, not the composer, and the text is lost.
- **Do not trust visible task text as proof of submission.** Only a fresh
  `working...` counter or tool lines after `Enter` confirm the task started.
- **Route every next-task decision through jev-decide.** The user mandates it for
  all routing. On `needs_review`, duel the top two; if the margin is decisive
  (≥0.3) pick the top choice by margin; if the duel margin is still < 0.15,
  pick the top choice by margin and drive — never spin on a third decide call.
- **No goal_judge anywhere.** If any step references goal_judge, treat it as a
  stale reference and replace it with jev-decide decide.
- **Land every turn with an xs post** (OUTCOME=done, name commit + gate) and
  push commits to origin/main so the 04:00 autoUpgrade does not revert local
  state.
- **The agent/cron environment carries STALE exported `SUBJECT`/`ACTION`/`SOURCE`/`OUTCOME`/`RATIONALE` from a prior xs post, and `task agents:xs:post VAR=…` may not override them.** When go-task's `env: SUBJECT: "{{.SUBJECT}}"` resolves empty (a CLI var it did not register — long ACTION values containing `:`, `(`, `;` are a reliable trigger), the inherited environment value passes straight through and the post lands the PREVIOUS turn's subject/action under a fresh frame. Symptom: `task agents:xs:post` prints `http 201` but `subject` is a lane you never named (e.g. `nixconfig:job-search-delphi-lane`), and `~/.local/state/agent-turns/last-turn.json` still shows the old `id`/`ts`. Fix: bypass go-task and call the script directly with every var inline — `SUBJECT=… ACTION=… RATIONALE=… OUTCOME=done SOURCE=tmux-pane-steward bash scripts/task/xs-turn-post.sh`. Verify the landed turn with `SUBJECT=<lane> SOURCE=tmux-pane-steward bash scripts/task/xs-turn-list.sh` — the list defaults `source=delphi` and `subject=nixconfig:job-search-delphi-lane`, so a steward turn is invisible unless you pass both.
- **Devin's composer is multi-line — a pasted task may not submit on the first
  Enter.** A single-line `paste-buffer` + `Enter` can land as a newline inside
  devin's composer instead of submitting, so the task sits in the input box and
  the pane looks idle. Press `Enter` again; the pane is genuinely driven only
  when the BUSY spinner ("⠋ Typing · Ns (esc twice to interrupt)") appears —
  never because the text is visible in the box.
- **A detached tmux session silently drops pastes and send-keys.** `tmux capture-pane` still shows the pane, but `paste-buffer` / `send-keys -t` do nothing when `#{session_attached}` is 0 — the text vanishes with no error. Before driving, check `tmux display-message -p -t <session>:<win> '#{session_attached}'`; if `0`, run `tmux attach -t <session>` (background PTY) first, then paste and Enter.
- **Freebuff rejects repeated identical task text with an anti-automation block.** Freebuff detects "same message sent over and over" as scripted/automated use and shows an error dialog ("Freebuff did not send this message to the model. It breaks the usage policy.") instead of accepting the task. The block fires **within a single task cycle** (the agent has not finished processing the first submission); across separate idle periods — where the agent completed the task, went idle, and is being re-driven — the same text is fine and does not trigger the block. If the block does fire (repeated rejection in the same cycle), rephrase into a materially different framing (different wording, emphasis, or sub-task), then paste and submit once. Do not retry the same text more than twice — if the second attempt is also rejected, the pane may be rate-limited; back off and move that pane's workload elsewhere.
- **Delphi over ssh can ignore the first Enter after paste.** The pane captures task text but `send-keys Enter` doesn't trigger submission — the pane stays at "Enter a coding task or / for commands" even though the text is visible. Re-send `Enter` (or `C-m`) after a 2–3 s wait; if that fails, press `Escape` once to clear any modal state, then paste and Enter again. Visible text alone is not proof of submission — only `working...` confirms it started.
- **Verify task text landed before pressing Enter.** `paste-buffer` can silently fail to land text (especially on ssh-pane drives where the first paste may not appear in the input box). After `paste-buffer` but before `Enter`, check `tmux capture-pane -t <target> -p | grep -c '<task-keyword>'`; if the count is 0, re-paste before pressing Enter — otherwise Enter submits nothing and the pane stays idle. The mirror trap: if the count is already > 0, do NOT re-paste — pasting text that is already in the composer double-queues the task and the agent re-does it. Confirm the composer is actually empty before re-pasting.

Truth: `scripts/task/pane-nudge.sh`, `scripts/task/jev-route.sh` — the drive and the routing; this page is the doctrine.
