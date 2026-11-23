#!/usr/bin/env bash
# Regression fixture for scripts/task/image-ship.sh — the no-spend guard.
#
# image-ship spends a real generation and a real deploy the moment PROMPT is
# set, so the PROMPT gate must fire before anything else runs — measured: an
# unset or empty PROMPT exits 1 naming the variable, and DETACH=1 cannot sneak
# past it into a unit either. A gate that only passed would be no gate: these
# cases prove it fails, and `timeout` proves it fails fast rather than
# blocking on a provider call.
#
# Exit: 0 every case refused fast, 1 a case leaked through, 2 fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
ship="$repo/scripts/task/image-ship.sh"

[ -f "$ship" ] || { echo "fixture: $ship missing" >&2; exit 2; }
command -v timeout >/dev/null 2>&1 || { echo "fixture: no timeout on PATH" >&2; exit 2; }

fail=0
check() { # name want_needle -- env assignments run before $ship
  local name="$1" needle="$2" out rc
  shift 2
  out="$(env -u PROMPT "$@" timeout 10 bash "$ship" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL $name: exited 0 — the spend guard did not fire" >&2
    fail=1
  elif [ "$rc" -eq 124 ]; then
    echo "FAIL $name: timed out — the refusal was not fast" >&2
    fail=1
  elif ! grep -q "$needle" <<<"$out"; then
    echo "FAIL $name: rc=$rc but output lacks '$needle'" >&2
    echo "$out" | head -3 >&2
    fail=1
  else
    echo "ok   $name (rc=$rc)"
  fi
}

# env -u PROMPT is the point: an inherited PROMPT would mask a missing gate.
check "unset PROMPT refuses fast" "PROMPT"
check "empty PROMPT refuses fast" "PROMPT" PROMPT=
check "DETACH cannot skip the gate" "PROMPT" DETACH=1

# The taskfile form is the same gate one level up: PROMPT="" must refuse
# before generation, not spend an image on an empty string.
if command -v task >/dev/null 2>&1; then
  out="$(cd "$repo" && env -u PROMPT timeout 30 task images:ship 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] || [ "$rc" -eq 124 ]; then
    echo "FAIL task images:ship: rc=$rc — the spend guard did not fire" >&2
    fail=1
  else
    echo "ok   task images:ship refuses an unset PROMPT (rc=$rc)"
  fi
fi

exit "$fail"
