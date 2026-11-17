#!/usr/bin/env bash
# shellcheck shell=bash
# Dispatch a subagent at one failing CI run, and mark the mail that reported it
# resolved once the run is green.
#
# This is the loop the CI notifications were always asking for: a GitHub failure
# is not a human's mail, it is a job for the agent that broke it. `dispatch`
# gathers the failing job and its log into one bounded prompt, then starts
# `hermes` in a detached tmux session — a tool-call shell has no TTY, so the
# agent must not be a plain background child.
#
# Usage:
#   ci-fix-dispatch.sh dispatch --run <id> [--mail <mid>] [--class <c>] [--dry-run]
#   ci-fix-dispatch.sh resolve  --mail <message_id>
set -euo pipefail

API="${EMAIL_ARCHIVE_API:-https://delphi.cloudforest-kardashev.ts.net:8450}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ci-fix"
LOG_CHARS="${CI_FIX_LOG_CHARS:-12000}"
SESSION_PREFIX="ci-fix"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ci-fix: missing $1" >&2; exit 2; }; }

usage() {
  sed -n '5,16p' "$0" | sed 's/^# \{0,1\}//'
}

dispatch() {
  local run="" mail="" class="" dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) run="${2:-}"; shift 2 ;;
      --mail) mail="${2:-}"; shift 2 ;;
      # trust | lint | assert | capacity (docs/issue-classes.md). Optional: the
      # caller often knows it from the failing job, and the agent records the
      # same line with what it found if the guess was wrong.
      --class) class="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) echo "ci-fix: unknown argument $1" >&2; exit 2 ;;
    esac
  done
  [ -n "$run" ] || { echo "ci-fix: --run is required" >&2; exit 2; }

  need gh
  need jq

  local meta failing
  meta="$(gh run view "$run" --json databaseId,name,workflowName,displayTitle,headBranch,headSha,conclusion,jobs)"
  failing="$(jq -r '[.jobs[] | select(.conclusion == "failure") | .name] | join(", ")' <<<"$meta")"
  [ -n "$failing" ] || { echo "ci-fix: run $run has no failing job"; exit 0; }

  # The log is the evidence the agent needs and the one thing it cannot cheaply
  # reproduce; everything else in the prompt is a pointer.
  local log
  log="$(gh run view "$run" --log-failed 2>/dev/null | tail -c "$LOG_CHARS" || true)"
  [ -n "$log" ] || log="(no failed-step log available; read the run with: gh run view $run)"

  local repo
  repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

  local branch sha title workflow
  branch="$(jq -r '.headBranch // "unknown"' <<<"$meta")"
  sha="$(jq -r '.headSha // ""' <<<"$meta")"
  title="$(jq -r '.displayTitle // ""' <<<"$meta")"
  workflow="$(jq -r '.workflowName // .name // "workflow"' <<<"$meta")"

  # The class is the part a dispatcher usually knows and the agent has to
  # re-derive. Recorded before the launch, so the ledger answers what breaks CI
  # even when the fix does not land.
  if [ -n "$class" ] && [ "$dry" = 0 ]; then
    CLASS="$class" SOURCE=ci-fix SUBJECT="ci:run-$run" OUTCOME=in_progress \
      EVIDENCE="$failing" FIX="pending: agent dispatched on run $run" \
      bash "$repo/scripts/task/issue-ledger.sh" record
  fi

  mkdir -p "$STATE"
  local prompt="$STATE/run-$run.md"
  cat >"$prompt" <<PROMPT
# Fix CI run $run — $workflow

Run: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo nixconfig)/actions/runs/$run
Title: $title
Branch: $branch @ ${sha:0:12}
Failing jobs: $failing
Repo: $repo

## What is expected

Fix the cause, not the gate. A check that fails on main is a real defect: do not
disable it, weaken an assertion, or push with --no-verify.

Classify the failure before you touch it (\`docs/issue-classes.md\`): \`trust\` (a
source declared without its proof — a substituter with no key), \`lint\` (an
artefact past its threshold), \`assert\` (an environment precondition nobody
stated) or \`capacity\` (the work exceeded a measured limit). A remedy from the
wrong class goes green and returns in another shape.

Write the class down before you start, so the record survives a fix that does
not land:

    task agents:ledger:record CLASS=<class> SUBJECT=ci:run-$run \
      EVIDENCE="<the line in the log that showed it>" FIX="<what you changed>"

Use the class the evidence supports, not the one this dispatch was opened with.

The two steps that fail most often here, and the class each belongs to:

- \`docs-budget\` / "Living documents within budget" — \`lint\`. \`bash scripts/task/docs-budget.sh\`
  from the repo root prints which document is over. Shorten the document, do not
  raise the budget.
- \`docs-budget\` / "Task graph gate" — \`lint\`. A shard violates a bucket (duplicate
  key, dangling reference, include cycle, orphan shard, MATCH arity, exit-code
  drift) or the name set disagrees with \`task --list-all --json\`. \`task checks:tasks\`
  names the bucket; fix the shard, not the gate.

Verification is phased and bounded: \`bash scripts/task/docs-budget.sh\` for a doc
change, \`task checks:host HOST=<host>\` for the one host a config change reaches.
Never build the fleet, never run \`nix flake check\` here.

**Do not commit or push.** Leave the fix in the working tree, verified, and print
the one command the operator runs to land it. An agent that pushes to main is how
the CI noise started; the fix is the deliverable, the push stays with a person.

Once the run is green, the mail that reported it is closed with:

    task agents:ci:resolve MESSAGE_ID=$mail

## The log (last $LOG_CHARS characters of the failed steps)

\`\`\`
$log
\`\`\`
PROMPT

  if [ "$dry" = 1 ]; then
    echo "ci-fix: prompt written to $prompt (dry run, nothing launched)"
    return 0
  fi

  need tmux
  # A launcher file, so the prompt never has to survive a second layer of shell
  # quoting on its way to the agent.
  local launcher="$STATE/run-$run.sh"
  cat >"$launcher" <<LAUNCH
#!/usr/bin/env bash
cd $(printf '%q' "$repo")
exec hermes -z "\$(cat $(printf '%q' "$prompt"))" --yolo
LAUNCH
  chmod +x "$launcher"

  local session="$SESSION_PREFIX-$run"
  if tmux has-session -t "$session" 2>/dev/null; then
    echo "ci-fix: session $session already exists — attach with: tmux attach -t $session"
    return 0
  fi
  tmux new-session -d -s "$session" "$launcher"

  cat <<DONE
dispatched  $session
prompt      $prompt
attach      tmux attach -t $session
failing     $failing
when green  task agents:ci:resolve MESSAGE_ID=$mail
DONE
}

resolve() {
  local mail=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --mail) mail="${2:-}"; shift 2 ;;
      *) echo "ci-fix: unknown argument $1" >&2; exit 2 ;;
    esac
  done
  [ -n "$mail" ] || { echo "ci-fix: --mail is required" >&2; exit 2; }
  need curl
  curl -fsS --max-time 15 -H 'content-type: application/json' \
    -d "$(jq -nc --arg m "$mail" '{messageId: $m}')" \
    "$API/api/triage-resolve" | jq -r '.[]? | "resolved  \(.tier)  \(.owner)"' || {
    echo "ci-fix: nothing open for $mail (already resolved?)" >&2
    exit 0
  }
}

[ $# -gt 0 ] || { usage; exit 2; }
command="$1"
shift
case "$command" in
  dispatch) dispatch "$@" ;;
  resolve) resolve "$@" ;;
  -h | --help | help) usage ;;
  *) echo "ci-fix: unknown command $command" >&2; usage >&2; exit 2 ;;
esac
