#!/usr/bin/env bash
# ci-wait.sh — block until CI for one commit is TERMINAL, then exit with its
# verdict. One call, no polling from a human or an agent.
#
# WHY
#   Watching a run by hand costs a round trip every few minutes for 10-30
#   minutes, which is how an afternoon disappears. The condition is exact —
#   every run for a commit is `completed` — so a loop can hold the answer.
#
# TWO SOURCES, ONE VERDICT
#   gh    authoritative: `gh run list --commit`, then `--log-failed` names the
#         failing lines. Costs API calls in a bounded loop (interval 20 s).
#   mail  the channel this repo already has: GitHub mails "Run failed: <wf> -
#         <branch> (<sha>)" on failure only. `--via mail` waits for that message
#         with himalaya, which is the only path that works without a gh token.
#
# WHAT IS NOT RECORDED
#   Nothing is committed. A run's verdict is one line in
#   `$XDG_STATE_HOME/nixconfig/ci-watch.log` — the repo is configuration, not a
#   log of the queue. A failure worth keeping becomes an `AGENTS.nix` note, and
#   that is a judgement, not an automatic commit.
#
# USAGE
#   ci-wait.sh [--commit SHA] [--timeout S] [--interval S] [--via gh|mail]
#              [--account NAME] [--repo OWNER/NAME]
#
# EXIT
#   0  every run for the commit succeeded
#   1  a run failed (the failing lines are printed)
#   2  could not ask: gh missing/unauthenticated, or the mail account has none
#   124 timed out with runs still in flight (they keep running; exit is not a verdict)
set -uo pipefail

COMMIT=""
TIMEOUT=2400
INTERVAL=20
VIA="gh"
ACCOUNT="jisifu"
REPO=""
START_EPOCH="$(date +%s)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

while [ $# -gt 0 ]; do
  case "$1" in
    --commit) COMMIT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --via) VIA="$2"; shift 2 ;;
    --account) ACCOUNT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "ci-wait: unknown argument $1" >&2; exit 2 ;;
  esac
done

[ -n "$COMMIT" ] || COMMIT="HEAD"
# gh filters on the FULL sha: a short one is accepted by git but returns no runs,
# which reads exactly like "CI never started".
FULL="$(git rev-parse "$COMMIT" 2>/dev/null || echo "$COMMIT")"
SHORT="$(git rev-parse --short=7 "$COMMIT" 2>/dev/null || echo "${COMMIT:0:7}")"
# `gh` wants OWNER/NAME: the remote may end in `.git` and may be scp-style.
REPO="${REPO:-$(git remote get-url origin | sed -E 's#\.git$##' | awk -F'[:/]' '{print $(NF-1)"/"$NF}')}"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nixconfig"
ledger="$state_dir/ci-watch.log"

record() {
  local verdict="$1"
  mkdir -p "$state_dir" 2>/dev/null
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) repo=${REPO} commit=${SHORT} via=${VIA} verdict=${verdict} waited_s=$(( $(date +%s) - START_EPOCH ))" >>"$ledger"
}

say() { printf '%s\n' "$*" >&2; }

deadline=$((START_EPOCH + TIMEOUT))

if [ "$VIA" = "gh" ]; then
  command -v gh >/dev/null || {
    say "ci-wait: gh is not installed — use --via mail for the email channel"
    exit 2
  }
  gh auth status >/dev/null 2>&1 || {
    say "ci-wait: gh is not authenticated — use --via mail"
    exit 2
  }

  seen=""
  while :; do
    if ! runs="$(gh run list --repo "$REPO" --commit "$FULL" --limit 20 \
      --json databaseId,status,conclusion,workflowName,event 2>&1)"; then
      say "ci-wait: gh refused the query: ${runs}"
      record error
      exit 2
    fi
    if [ -n "$runs" ] && [ "$runs" != "[]" ]; then
      pending="$(printf '%s' "$runs" | jq -r '[.[] | select(.status != "completed")] | length')"
      if [ "$pending" = "0" ]; then
        printf '%s' "$runs" | jq -r '.[] | "  \(.workflowName) (\(.event)) — \(.conclusion)"'
        failed="$(printf '%s' "$runs" | jq -r '[.[] | select(.conclusion != "success" and .conclusion != "skipped" and .conclusion != "neutral")] | length')"
        if [ "$failed" = "0" ]; then
          say "ci-wait: ${SHORT} green ($(printf '%s' "$runs" | jq 'length') run(s))"
          record success
          exit 0
        fi
        for id in $(printf '%s' "$runs" | jq -r '.[] | select(.conclusion != "success" and .conclusion != "skipped" and .conclusion != "neutral") | .databaseId'); do
          say "ci-wait: ${SHORT} FAILED — run ${id}"
          say "  https://github.com/${REPO}/actions/runs/${id}"
          gh run view "$id" --repo "$REPO" --log-failed 2>/dev/null |
            grep -E 'error:|FAIL|✗|Error:|##\[error\]' | head -12 | cut -c1-200 >&2
        done
        record failure
        exit 1
      fi
      summary="$(printf '%s' "$runs" | jq -r '[.[] | "\(.workflowName):\(.status)"] | join(" ")')"
      [ "$summary" = "$seen" ] || say "ci-wait: ${SHORT} in flight — ${summary}"
      seen="$summary"
    else
      say "ci-wait: ${SHORT} has no runs yet (dispatch lag) — waiting"
    fi
    [ "$(date +%s)" -lt "$deadline" ] || {
      say "ci-wait: timed out after ${TIMEOUT}s; the run continues, ask again later"
      record timeout
      exit 124
    }
    sleep "$INTERVAL"
  done
fi

if [ "$VIA" = "mail" ]; then
  command -v himalaya >/dev/null || {
    say "ci-wait: himalaya is not installed"
    exit 2
  }
  # GitHub mails failures only, so a quiet mailbox for this sha means "no
  # failure reported yet". The subject carries the short sha, which is what makes
  # this a per-commit signal instead of "some run failed".
  while :; do
    row="$(himalaya envelope list -a "$ACCOUNT" -s 30 2>/dev/null |
      grep -E "Run failed: .*\(${SHORT}\)" | head -1)"
    if [ -n "$row" ]; then
      id="$(printf '%s' "$row" | sed -E 's/^[^│]*│[[:space:]]*([0-9]+).*/\1/')"
      say "ci-wait: ${SHORT} FAILED (per ${ACCOUNT} mail)"
      himalaya message read "$id" -a "$ACCOUNT" 2>/dev/null |
        grep -E 'Workflow:|Duration:|Finished:|View results:|^\s+\* .*(failed|succeeded)' |
        sed 's/\r$//' >&2
      record failure
      exit 1
    fi
    [ "$(date +%s)" -lt "$deadline" ] || {
      say "ci-wait: no failure mail for ${SHORT} after ${TIMEOUT}s — that is not a pass, just no failure reported"
      record no-failure-mail
      exit 124
    }
    sleep "$((INTERVAL * 3))"
  done
fi

say "ci-wait: --via must be gh or mail"
exit 2
