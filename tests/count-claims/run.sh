#!/usr/bin/env bash
# Regression fixture for `checks:counts` (scripts/task/count-claims.sh).
#
# A gate that cannot fail is the thing the sloppiness audit names, so every exit
# path is exercised: a matching claim (0), a wrong number (1), a claim that no
# longer matches (1) and an unknown source (1). Counts are in-memory and the
# claim files live in a temp dir, so this needs no host, no eval and no network.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
script="$repo/scripts/task/count-claims.sh"

command -v jq >/dev/null 2>&1 || { echo "fixture: jq required" >&2; exit 2; }
[ -f "$script" ] || { echo "fixture: $script missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'total_knobs = 2\n[knobs.a]\n[knobs.b]\n' >"$tmp/knobs.toml"
printf 'total_devices = 2\n[hosts.a]\n[hosts.b]\n' >"$tmp/hosts.toml"
COUNTS='{"knobs":2,"hosts":2}'

fail=0
cases=0
run() { # name want_rc claims
  local name="$1" want="$2" claims="$3" rc out
  cases=$((cases + 1))
  out="$(CLAIMS="$claims" COUNTS_JSON="$COUNTS" bash "$script" 2>&1)"
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL ${name}: exit ${rc}, want ${want}"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
  else
    echo "ok   ${name} (exit ${rc})"
  fi
}

printf '%s\t%s\t%s\t%s\n' "$tmp/knobs.toml" '^total_knobs = ([0-9]+)$' knobs 'knob total' >"$tmp/match.tsv"
run "matching claim exits 0" 0 "$tmp/match.tsv"

printf '%s\t%s\t%s\t%s\n' "$tmp/knobs.toml" '^total_knobs = ([0-9]+)$' knobs 'knob total' >"$tmp/wrong.tsv"
printf 'total_knobs = 3\n' >"$tmp/knobs.toml"
run "wrong number exits 1" 1 "$tmp/wrong.tsv"

printf 'total_knobs = 2\n' >"$tmp/knobs.toml"
printf '%s\t%s\t%s\t%s\n' "$tmp/knobs.toml" '^total_servers = ([0-9]+)$' knobs 'moved claim' >"$tmp/stale.tsv"
run "vanished claim exits 1" 1 "$tmp/stale.tsv"

printf '%s\t%s\t%s\t%s\n' "$tmp/hosts.toml" '^total_devices = ([0-9]+)$' ghosts 'unknown source' >"$tmp/unknown.tsv"
run "unknown source exits 1" 1 "$tmp/unknown.tsv"

echo "count-claims fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
