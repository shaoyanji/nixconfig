#!/usr/bin/env bash
# kg-evidence.sh — what every edge in the graph is worth, per relation.
#
# Reads `.?submodules=1#knowledgeGraph.evidence`: per relation the declared
# default tier, how many edges the graph emits, how many record their own tier
# over that default, and which claim kinds the effective tier may carry. The
# unresolved citations are the policy ids prose names that flake/policies.nix
# does not declare — the edges the graph drops, which `checks:ontology` fails on.
#
# Usage: kg-evidence.sh
# Env: FORMAT=json emits the object instead of the table.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO"

err="$(mktemp)"
trap 'rm -f "$err"' EXIT

# shellcheck source=lib/iets.sh
. scripts/task/lib/iets.sh
if ! data="$(iets_eval_json .?submodules=1#knowledgeGraph.evidence 2>"$err")"; then
  cat "$err" >&2
  echo "kg-evidence: could not evaluate .?submodules=1#knowledgeGraph.evidence" >&2
  exit 1
fi

if [ "${FORMAT:-}" = "json" ]; then
  jq . <<<"$data"
  exit 0
fi

printf '%-13s %-9s %6s %8s  %s\n' "RELATION" "DEFAULT" "EDGES" "OWN TIER" "CAN CARRY"
jq -r '
  .relations
  | to_entries
  | sort_by(-.value.edges, .key)
  | .[]
  | [.key, .value.defaultTier, .value.edges, .value.recorded, (.value.canCarry | join(","))]
  | @tsv
' <<<"$data" | while IFS=$'\t' read -r rel def edges rec carry; do
  printf '%-13s %-9s %6s %8s  %s\n' "$rel" "$def" "$edges" "$rec" "$carry"
done

jq -r '"", "\(.total) edges, \(.recorded) record their own tier"' <<<"$data"
jq -r '
  if (.unresolvedCitations | length) == 0
  then "no unresolved policy citations"
  else "UNRESOLVED CITATIONS:", (.unresolvedCitations[] | "  " + .)
  end
' <<<"$data"
