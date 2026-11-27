#!/usr/bin/env bash
# checks:agents:xs-post — offline cases for the COMMITS validation in
# scripts/task/xs-turn-post.sh. A space-separated COMMITS list is one element to
# the shim, whose commits array then fails validation with a 400 — and a 400 is
# poison in the queue replay, so the turn is parked in queue.rejected.jsonl and
# never sent (measured 2026-11-26: a devin turn lost that way). The script
# refuses that input at exit 2, and this test is what keeps the refusal wired.
#
# No endpoint, token or secrets plane is involved: AGENT_TURNS_TOKEN is a dummy,
# XS_TURNS_URL points at a closed port, so a valid input ends in the queue
# (exit 4) and its queued JSONL line is the proof the commas survived. Case 5 is
# the negative control: the same input against a copy of the script with the
# guard stripped must NOT exit 2, or this test proves nothing.
#
# Exit 0 = every case held, 1 = one did not.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT=$ROOT/scripts/task/xs-turn-post.sh
TEMPLATE=$ROOT/scripts/task/xs-turn.jq
TMP=$(mktemp -d "${TMPDIR:-/tmp}/xs-post-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'xs-post-test: FAIL: %s\n' "$*" >&2; exit 1; }

# run_case <name> <script> <commits-value>; prints the exit code, stderr captured
# to $TMP/<name>.err, state dir at $TMP/<name>.state
run_case() {
  local name=$1 script=$2 commits=$3
  local state=$TMP/$name.state
  mkdir -p "$state"
  set +e
  SUBJECT="nixconfig:test" ACTION="test case $name" SOURCE=test \
    COMMITS="$commits" \
    XS_TURN_TEMPLATE="$TEMPLATE" \
    AGENT_TURNS_TOKEN="dummy-token-for-offline-test-0123456789" \
    XS_TURNS_URL="http://127.0.0.1:1" \
    XDG_STATE_HOME="$state" \
    bash "$script" 2>"$TMP/$name.err"
  printf '%s' "$?"
  set -e
}

# 1. the incident input: two hashes separated by a space must be refused at
#    validation time, before anything is queued or sent.
rc=$(run_case bad "$SCRIPT" "abc1234 def5678")
[ "$rc" = 2 ] || fail "space-separated COMMITS exited $rc, expected 2"
grep -q "comma-separated" "$TMP/bad.err" ||
  fail "space-separated COMMITS exit 2 but without the comma-separated reason"

# 2/3/4. valid inputs pass validation: transport then fails against the closed
# port (exit 4) and the body lands in the queue with the commas intact.
check_good() { # <name> <commits-value> <expected-json-array>
  local name=$1 commits=$2 want=$3
  local rc
  rc=$(run_case "$name" "$SCRIPT" "$commits")
  [ "$rc" != 2 ] || fail "$name: valid COMMITS '$commits' was refused at validation"
  local queue=$TMP/$name.state/agent-turns/queue.jsonl
  [ -s "$queue" ] || fail "$name: no queued body to inspect (rc $rc)"
  local got
  got=$(jq -c '.commits' "$queue")
  [ "$got" = "$want" ] || fail "$name: queued commits are $got, expected $want"
}
check_good pair "abc1234,def5678" '["abc1234","def5678"]'
check_good single "abc1234" '["abc1234"]'
check_good empty "" '[]'

# 5. negative control: strip the guard from a copy in a mini-tree (the script
# resolves ROOT two levels up and sources lib/paths.sh from it) and prove the
# bad input is no longer refused — otherwise the cases above cannot detect the
# guard's removal.
MINI=$TMP/mini
mkdir -p "$MINI/scripts/task/lib"
cp "$SCRIPT" "$MINI/scripts/task/xs-turn-post.sh"
cp "$ROOT/scripts/task/lib/paths.sh" "$MINI/scripts/task/lib/paths.sh"
sed -i '/^# COMMITS is a list/,/^fi$/d' "$MINI/scripts/task/xs-turn-post.sh"
! grep -q "comma-separated hashes" "$MINI/scripts/task/xs-turn-post.sh" ||
  fail "the strip did not remove the guard; the negative control is meaningless"
rc=$(run_case stripped "$MINI/scripts/task/xs-turn-post.sh" "abc1234 def5678")
[ "$rc" != 2 ] ||
  fail "the stripped copy still refuses space-separated COMMITS — the test cannot detect the guard's removal"

printf 'xs-post-test: PASS: bad input refused at exit 2, valid input queued with commas intact, guard removal detected\n'
