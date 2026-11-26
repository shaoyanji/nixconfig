#!/usr/bin/env bash
# Fixture for scripts/task/ops-health.sh — the gate says ok only while the
# sentinel keeps writing.
#
# Every case drives temp files through the env knobs the script documents, so
# the real verdict on this host is never read and never rewritten: a fresh `ok`
# passes, an `ok` older than the ceiling fails and says how old, a caller can
# move the ceiling, a degraded verdict prints the reasons from status.json, and
# a missing file is a failure rather than an empty pass.
#
# Coverage is asserted both ways: a case listed in EXPECTED that no longer runs
# fails, and so does a case that runs without being listed.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/ops-health.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for cmd in bash stat jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "fixture: $cmd is required" >&2
    exit 2
  }
done
[ -f "$gate" ] || {
  echo "fixture: $gate is missing" >&2
  exit 2
}

EXPECTED=(
  "a fresh ok passes and reports its age"
  "an ok older than the ceiling fails as stale"
  "the ceiling can be moved by the caller"
  "a degraded verdict prints its reasons"
  "a missing verdict is a failure"
  "a nonsense ceiling is refused"
)

ran=()
failed=0
code=0
out=""

run_gate() {
  local case=$1
  shift
  ran+=("$case")
  code=0
  out=$(env "$@" OPS_HEALTH_FILE="$work/health.txt" OPS_HEALTH_STATUS="$work/status.json" \
    bash "$gate" 2>&1) || code=$?
}

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  [ -n "${out:-}" ] && printf '  output: %s\n' "$(printf '%s' "$out" | head -c 300)" >&2
  failed=1
}

printf 'ok\n' >"$work/health.txt"
printf '{"state":"ok","reasons":[]}\n' >"$work/status.json"

case="a fresh ok passes and reports its age"
run_gate "$case"
if [ "$code" != 0 ] || ! printf '%s' "$out" | grep -q "sentinel: ok (0m ago)"; then
  fail "$case" "exit $code"
fi

case="an ok older than the ceiling fails as stale"
printf 'ok\n' >"$work/health.txt"
touch -d "2 hours ago" "$work/health.txt"
run_gate "$case"
if [ "$code" != 1 ] || ! printf '%s' "$out" | grep -q "stale"; then
  fail "$case" "exit $code, expected 1 with stale"
fi

case="the ceiling can be moved by the caller"
run_gate "$case" OPS_HEALTH_MAX_AGE_MIN=180
if [ "$code" != 0 ] || ! printf '%s' "$out" | grep -q "sentinel: ok (120m ago)"; then
  fail "$case" "exit $code, expected 0 at a 180m ceiling"
fi

case="a degraded verdict prints its reasons"
printf 'degraded\n' >"$work/health.txt"
printf '{"state":"degraded","reasons":["disk 94%% on /","psi full 12%%"]}\n' >"$work/status.json"
run_gate "$case"
if [ "$code" != 1 ]; then
  fail "$case" "exit $code, expected 1"
elif ! printf '%s' "$out" | grep -q "disk 94% on /"; then
  fail "$case" "reasons are missing from the output"
elif ! printf '%s' "$out" | grep -q "psi full 12%"; then
  fail "$case" "the second reason is missing from the output"
fi

case="a missing verdict is a failure"
rm -f "$work/health.txt"
run_gate "$case"
if [ "$code" != 1 ] || ! printf '%s' "$out" | grep -q "no health file"; then
  fail "$case" "exit $code, expected 1 naming the missing file"
fi

case="a nonsense ceiling is refused"
printf 'ok\n' >"$work/health.txt"
run_gate "$case" OPS_HEALTH_MAX_AGE_MIN=soon
if [ "$code" != 2 ] || ! printf '%s' "$out" | grep -q "whole number"; then
  fail "$case" "exit $code, expected 2"
fi

for case in "${EXPECTED[@]}"; do
  seen=0
  for ran_case in "${ran[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || fail "$case" "listed in EXPECTED but never ran"
done
for ran_case in "${ran[@]}"; do
  seen=0
  for case in "${EXPECTED[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || fail "$ran_case" "ran but is not in EXPECTED"
done

if [ "$failed" != 0 ]; then
  echo "ops-health: fixture failed" >&2
  exit 1
fi
printf 'ok   ops-health: %d cases\n' "${#EXPECTED[@]}"
