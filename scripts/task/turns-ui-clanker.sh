#!/usr/bin/env bash
# turns-ui-clanker.sh — run the turns browser suite on a host that is not us.
#
# The pattern this exists to demonstrate: a public demo needs a reader that is
# genuinely outside the fleet. `clanker` is that reader — an Instabox VM with no
# tailnet, no xs token and no way to publish — and `templates/agent-shell` gives
# it a real Chromium. The page under test is the public mount, so the demo also
# proves the read-only posture: rows render, prompts do not.
#
# Only one step is privileged: the post. It happens here, on delphi, where the
# token lives, and only after the suite says it is watching (it prints
# `PHASE toast-watch`). That line is the handshake — the suite waits up to
# WATCH_SECONDS for the toast, and this script turns that wait into a turn.
#
# Task: agents:xs:suite. Env: TARGET=, BOX=, TIMEOUT= (job start, default 900).
# Exit: 0 every check passed · 1 a check failed (the job's own status) ·
#       2 preflight, nothing was run or posted.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TARGET=${TARGET:-https://delphi.bountystash.com/turns/}
BOX=${BOX:-clanker}
TIMEOUT=${TIMEOUT:-900}
WATCH_SECONDS=${WATCH_SECONDS:-180}
SUBJECT=${SUBJECT:-nixconfig:turns-ui}

die() {
  printf 'suite: %s\n' "$*" >&2
  exit 2
}
say() { printf '%-9s %s\n' "$1" "$2"; }

command -v task >/dev/null || die "task is not on PATH"
curl -sfI --max-time 20 "$TARGET" >/dev/null || die "$TARGET does not answer"
[ -r "${TOKEN_FILE:-/run/secrets/agent-turns-token-dashboard}" ] ||
  die "cannot read the dashboard token: the post has to come from this host"

# The tree travels as `git archive HEAD`, so an uncommitted suite does not exist
# on the box. Say so instead of running yesterday's assertions.
git -C "$ROOT" diff --quiet -- scripts/task/turns-ui-suite.sh ||
  die "scripts/task/turns-ui-suite.sh has uncommitted changes — commit first (the box gets HEAD)"

say box "$BOX via templates/agent-shell (no tailnet, no token)"
cd "$ROOT"
id=$(timeout 180 task clanker:devshell -- \
  ./templates/agent-shell#default "TARGET=$TARGET bash scripts/task/turns-ui-suite.sh" |
  tail -1)
case $id in
'' | *[!0-9A-Za-z-]*) die "clanker:devshell did not return a job id (got '$id')" ;;
esac
say job "$id"

# Watch the job log for the handshake, then post. The suite is idle-polling at
# that point, so the turn lands while the page is open and parked at the bottom.
posted=0
finished=0
deadline=$((SECONDS + TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
  log=$(task clanker:logs -- "$id" 200 2>/dev/null || true)
  case $log in
  *"checks="*) finished=1; break ;;
  *"PHASE toast-watch"*)
    uuid=$(cat /proc/sys/kernel/random/uuid)
    say publish "$SUBJECT while the page is open on $BOX"
    SUBJECT="$SUBJECT" \
      ACTION="Public demo from $BOX: the suite was already parked at the bottom of $TARGET when this turn was posted from delphi" \
      RATIONALE="The reader is a host outside the fleet, so the demo has to look like a reader does: no token on the box, one POST from the host that owns it, and the toast proving the push." \
      OUTCOME=done SOURCE=turns-ui ID="$uuid" \
      bash "$ROOT/scripts/task/xs-turn-post.sh" >/dev/null ||
      die "the post failed; the suite is left waiting for a turn"
    posted=1
    break
    ;;
  esac
  sleep 3
done

[ "$posted" = 1 ] || say publish "not reached: the suite did not announce toast-watch within ${TIMEOUT}s"

[ "$finished" = 1 ] || task clanker:wait -- "$id" "$((WATCH_SECONDS + 300))" >/dev/null 2>&1 || true

printf '\n--- job %s log\n' "$id"
log=$(task clanker:logs -- "$id" 400 2>/dev/null || true)
printf '%s\n' "$log"
summary=$(printf '%s\n' "$log" | grep -o 'checks=[0-9]* fail=[0-9]*' | tail -1)
failures=$(printf '%s\n' "$summary" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')

printf '\n'
case "${failures:-1}" in
0) say result "PASS — every check passed on $BOX against $TARGET"; exit 0 ;;
*) say result "FAIL — ${summary:-the suite did not reach its summary}; see the log above"; exit 1 ;;
esac
