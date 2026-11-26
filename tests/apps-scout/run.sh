#!/usr/bin/env bash
# Fixture for scripts/task/apps-scout.sh — the one writer scouted leads go
# through, which had no test of its own.
#
# Everything here runs `--dry`, which apps-db.sh answers before it touches the
# network, so the cases assert the record a sweep would write without needing an
# archive: the origin a sweep gives vs the origin a family gives, the status line
# the owner rides on, the stage the status derives, and the refusals (an unknown
# family, a fit outside 1-5, a sweep id that is not a cycle, a missing summary).
# One case runs with the API pointed at a closed port, which is what proves a
# dry run is offline rather than accidentally green because the archive answered.
#
# Coverage is asserted both ways: a case listed in EXPECTED that no longer runs
# fails, and so does a case that runs without being listed.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
scout="$repo/scripts/task/apps-scout.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for cmd in jq bash; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "fixture: $cmd is required" >&2
    exit 2
  }
done
[ -f "$scout" ] || {
  echo "fixture: $scout is missing" >&2
  exit 2
}

EXPECTED=(
  "a sweep carries the cycle as its origin"
  "the family decides the origin without a sweep"
  "infra is spelled infrastructure"
  "the owner rides the status line"
  "a summary is flattened to one line"
  "the next action lands with the row"
  "a fit outside 1-5 is refused"
  "a sweep that is not a cycle is refused"
  "an unknown family is refused"
  "a missing summary is refused"
  "a dry run needs no archive"
)

ran=()
failed=0

# run <case> <argv...> — sets code, out (stdout), err (stderr).
run() {
  local case=$1
  shift
  ran+=("$case")
  code=0
  APPFLOW_API=http://127.0.0.1:9 APPS_DB_WRITE_LOG="$work/writes.log" \
    bash "$scout" "$@" --dry >"$work/out" 2>"$work/err" || code=$?
  out=$(cat "$work/out")
  err=$(cat "$work/err")
}

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  [ -n "${out:-}" ] && printf '  stdout: %s\n' "$(printf '%s' "$out" | head -c 300)" >&2
  [ -n "${err:-}" ] && printf '  stderr: %s\n' "$(printf '%s' "$err" | head -c 300)" >&2
  failed=1
}

field() { printf '%s' "$out" | jq -r "$1" 2>/dev/null; }

lead=(--company "Weflow" --role "Senior Platform Engineer" --summary "Berlin SaaS platform owner")

case="a sweep carries the cycle as its origin"
run "$case" --family platform "${lead[@]}" --sweep 2026-11-25s
if [ "$code" != 0 ]; then
  fail "$case" "exit $code, expected 0"
elif [ "$(field .origin)" != "scout-2026-11-25s" ]; then
  fail "$case" "origin $(field .origin)"
elif [ "$(field .status)" != "lead (sweep 2026-11-25s, platform, owner agent:apps)" ]; then
  fail "$case" "status $(field .status)"
elif [ "$(field .stage)" != "lead" ]; then
  # The sweep text used to promise `scouted`; the status the writer derives is
  # `lead (...)`, which stages as lead. This case pins the code's answer.
  fail "$case" "stage $(field .stage), expected lead"
fi

case="the family decides the origin without a sweep"
run "$case" --family SRE "${lead[@]}"
if [ "$code" != 0 ] || [ "$(field .origin)" != "scout:sre" ]; then
  fail "$case" "exit $code origin $(field .origin)"
elif [ "$(field .status)" != "lead (scout sre, owner agent:apps)" ]; then
  fail "$case" "status $(field .status)"
fi

case="infra is spelled infrastructure"
run "$case" --family Infra "${lead[@]}"
if [ "$code" != 0 ] || [ "$(field .origin)" != "scout:infrastructure" ]; then
  fail "$case" "exit $code origin $(field .origin)"
fi

case="the owner rides the status line"
run "$case" --family devops "${lead[@]}" --owner agent:mail --sweep 2026-11-25t
if [ "$code" != 0 ] || [ "$(field .status)" != "lead (sweep 2026-11-25t, devops, owner agent:mail)" ]; then
  fail "$case" "status $(field .status)"
fi

case="a summary is flattened to one line"
run "$case" --family platform --company "Weflow" --role "Senior Platform Engineer" \
  --summary "$(printf 'line one\nline two\ttabbed   spaced')"
notes=$(field .notes)
if [ "$code" != 0 ]; then
  fail "$case" "exit $code"
elif [ "$notes" != "${notes//[$'\n\t']/}" ]; then
  fail "$case" "notes kept a newline or tab: $notes"
elif [ "$notes" != "line one line two tabbed spaced" ]; then
  fail "$case" "notes: $notes"
fi

case="the next action lands with the row"
run "$case" --family platform "${lead[@]}" --next-action "Read the ad, nothing sends before 2026-12-07"
if [ "$code" != 0 ] || [ "$(field .nextAction)" != "Read the ad, nothing sends before 2026-12-07" ]; then
  fail "$case" "nextAction $(field .nextAction)"
fi

case="a fit outside 1-5 is refused"
for fit in 0 6 100; do
  run "$case" --family platform "${lead[@]}" --fit "$fit"
  if [ "$code" != 2 ]; then
    fail "$case" "fit $fit gave exit $code, expected 2"
  fi
done

case="a sweep that is not a cycle is refused"
run "$case" --family platform "${lead[@]}" --sweep 25s
if [ "$code" != 2 ] || ! printf '%s' "$err" | grep -q "must look like"; then
  fail "$case" "exit $code, stderr $(printf '%s' "$err" | head -c 120)"
fi

case="an unknown family is refused"
run "$case" --family data "${lead[@]}"
if [ "$code" != 2 ] || ! printf '%s' "$err" | grep -q "is not devops, sre, platform or infrastructure"; then
  fail "$case" "exit $code, stderr $(printf '%s' "$err" | head -c 120)"
fi

case="a missing summary is refused"
run "$case" --family platform --company "Weflow" --role "Senior Platform Engineer"
if [ "$code" != 2 ] || ! printf '%s' "$err" | grep -q -- "--summary is required"; then
  fail "$case" "exit $code, stderr $(printf '%s' "$err" | head -c 120)"
fi

case="a dry run needs no archive"
# The API is a closed port for every case, and this one says so out loud: a dry
# run that reached the archive would fail here instead of printing a record.
run "$case" --family platform "${lead[@]}"
if [ "$code" != 0 ] || [ -z "$(field .id)" ]; then
  fail "$case" "exit $code, record $(printf '%s' "$out" | head -c 120)"
elif [ -s "$work/writes.log" ]; then
  fail "$case" "a dry run wrote to the write log"
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
  echo "apps-scout: fixture failed" >&2
  exit 1
fi
printf 'ok   apps-scout: %d cases\n' "${#EXPECTED[@]}"
