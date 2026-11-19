#!/usr/bin/env bash
# count-claims.sh — a hand-typed count must equal the compiled one.
#
# The gate reads modules/config/count-claims.tsv (file, regex, source, label),
# evaluates the sources once, and fails three ways: a number that differs, a
# claim whose regex no longer matches (the statement moved or was deleted), and a
# row naming a source that does not exist. A count that is merely trusted is the
# thing this exists to stop.
#
# CLAIMS= points at another manifest and COUNTS_JSON= supplies the map directly,
# which is how the fixture exercises all three failures without a host or an eval.
#
# Exit: 0 every claim matches, 1 a mismatch/stale/unknown claim, 2 cannot run.
set -uo pipefail

repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo" || exit 2

claims="${CLAIMS:-modules/config/count-claims.tsv}"
counts_json="${COUNTS_JSON:-}"

if [ -z "$counts_json" ]; then
  counts_json="$(nix eval --impure --json --expr '
    let
      inv = builtins.fromTOML (builtins.readFile ./inventory.toml);
      mod = builtins.fromTOML (builtins.readFile ./modules.toml);
    in {
      hosts = builtins.length (builtins.attrNames inv.hosts);
      knobs = builtins.length (builtins.attrNames mod.knobs);
    }' 2>/dev/null)"
fi
if [ -z "$counts_json" ]; then
  echo "count-claims: cannot evaluate the compiled counts" >&2
  exit 2
fi
if [ ! -f "$claims" ]; then
  echo "count-claims: ${claims} missing" >&2
  exit 2
fi

fail=0
rows=0
while IFS=$'\t' read -r file regex source label; do
  case "$file" in '' | '#'*) continue ;; esac
  rows=$((rows + 1))
  want="$(jq -r --arg s "$source" '.[$s] // empty' <<<"$counts_json" 2>/dev/null)"
  if [ -z "$want" ]; then
    echo "FAIL ${file}: unknown count source '${source}' (${label})" >&2
    fail=1
    continue
  fi
  got="$(rg -o --no-filename --replace '$1' "$regex" "$file" 2>/dev/null | sort -u)"
  if [ -z "$got" ]; then
    echo "FAIL ${file}: no line matches the claim (${label}) — the statement moved or was deleted" >&2
    fail=1
    continue
  fi
  bad=0
  while read -r n; do
    [ -n "$n" ] || continue
    if [ "$n" != "$want" ]; then
      echo "FAIL ${file}: ${label} says ${n}, the compiled source says ${want}" >&2
      bad=1
      fail=1
    fi
  done <<<"$got"
  [ "$bad" = 0 ] && echo "ok   ${file}: ${label} = ${want}"
done <"$claims"

if [ "$rows" -eq 0 ]; then
  echo "count-claims: ${claims} names no claims" >&2
  exit 2
fi
[ "$fail" = 0 ] && echo "count-claims: ${rows} claim(s) match the compiled source"
exit "$fail"
