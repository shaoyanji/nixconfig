#!/usr/bin/env bash
# kg-iets-check.sh — the graph's fast evaluator must answer what nix answers.
#
# `iets` exists for one reason: nix never answers `nix eval` from a cache, so the
# graph read cost 1.7 s every time a tree moved. iets traces what an evaluation
# reads and answers the same attribute in ~25 ms warm. That is the whole
# argument, and it is only sound if the VALUE is identical — a faster evaluator
# that renders a different graph is a quieter answer, not a faster one.
#
# So: evaluate the graph and one leaf registry through both, and compare bytes.
# The graph is what `kg-query.sh` reads (via the file cache) and the leaf is the
# shape the task graph reads (`.#inventory.hosts.<h>`), so both paths an agent
# takes are covered.
#
# Exit: 0 = identical (or something could not be compared and said so),
#       1 = the two evaluators disagree, 2 = worse: nix itself failed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO"

# shellcheck source=lib/iets.sh
. scripts/task/lib/iets.sh

if ! IETS="$(resolve_iets "$REPO")" || [ -z "$IETS" ]; then
  echo "kg-iets: SKIP — iets did not resolve (IETS_BIN, PATH, or the flake.lock pin)"
  echo "kg-iets:  the graph still works through nix; this gate is what the fast path needs"
  exit 0
fi

fails=0
compare() {
  local label="$1" attr="$2" mode="$3" a b
  # `--no-cache` on the iets side: a comparison that lets the tracing cache hand
  # back the same bytes proves nothing about the evaluator.
  if ! a="$("$IETS" eval "$mode" --no-cache "$attr" 2>/dev/null)"; then
    echo "kg-iets: FAIL — iets could not evaluate $attr" >&2
    fails=$((fails + 1))
    return
  fi
  if ! b="$(nix eval "$mode" "$attr" 2>/dev/null)"; then
    echo "kg-iets: FAIL — nix could not evaluate $attr (the reference is broken)" >&2
    fails=$((fails + 1))
    return
  fi
  if [ "$a" = "$b" ]; then
    printf 'kg-iets: ok   %-28s %s bytes, identical\n' "$label" "${#b}"
  else
    echo "kg-iets: FAIL — $label differs between iets and nix" >&2
    diff <(printf '%s' "$a" | jq -S . 2>/dev/null || printf '%s' "$a") \
      <(printf '%s' "$b" | jq -S . 2>/dev/null || printf '%s' "$b") | head -10 >&2 || true
    fails=$((fails + 1))
  fi
}

compare "knowledgeGraph.graph" ".#knowledgeGraph.graph" --json
compare "inventory.hosts.delphi.role" ".#inventory.hosts.delphi.role" --raw
compare "epistemics.table" ".#epistemics.table" --json

[ "$fails" -eq 0 ] || {
  echo "kg-iets: $fails disagreement(s) — the fast eval may not carry a different value" >&2
  exit 1
}
echo "kg-iets: PASS — iets renders the same values as nix on all three attributes"
