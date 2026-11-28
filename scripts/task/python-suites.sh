#!/usr/bin/env bash
# python-suites.sh — every Python suite under tests/ runs and passes.
#
# Ten suites (322 cases) carried no task, no gate and no runner, so they rotted
# in place and two had already broken: a fixture let the host's exported
# FIRECRAWL_API_KEY replace its seeded value, and a helper's `run=subprocess.run`
# default was bound at definition, so its hung-browser case launched the real
# binary. Discovery is what covers a new suite the day it lands instead of the
# day someone remembers to wire it.
#
# Each suite runs in its own process — the directories are hyphenated, not
# packages, and three of them share the module name `test_cli`.
#
# SUITES_ROOT= judges another tree (the fixture uses it). Exit 0 = every suite
# passed, 1 = a suite failed (named, with its tail), 2 = no suite found, which
# is not a pass.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

root="${SUITES_ROOT:-tests}"
[ -d "$root" ] || { echo "python-suites: no $root directory" >&2; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

suites=0
failed=0
ran_total=0
failed_names=()

for dir in "$root"/*/; do
  dir="${dir%/}"
  compgen -G "$dir/test_*.py" >/dev/null || continue
  suites=$((suites + 1))
  name="$(basename "$dir")"
  log="$work/$name.log"
  python3 -m unittest discover -s "$dir" -p 'test_*.py' >"$log" 2>&1
  rc=$?
  ran=$(sed -n 's/^Ran \([0-9][0-9]*\) test.*/\1/p' "$log" | tail -1)
  ran_total=$((ran_total + ${ran:-0}))
  if [ $rc -eq 0 ] && [ -n "${ran:-}" ]; then
    echo "ok   $name ($ran)"
  else
    failed=$((failed + 1))
    failed_names+=("$name")
    echo "FAIL $name (rc=$rc)" >&2
    tail -20 "$log" >&2
  fi
done

if [ "$suites" -eq 0 ]; then
  echo "python-suites: no test_*.py suite under $root — nothing ran, which is not a pass" >&2
  exit 2
fi
if [ "$failed" -ne 0 ]; then
  echo "python-suites: $failed of $suites suite(s) failed: ${failed_names[*]}" >&2
  exit 1
fi
echo "python-suites: $suites suite(s), $ran_total tests, all pass"
