#!/usr/bin/env bash
# kg-evidence.sh — what every edge in the graph is worth, per relation.
#
# Reads `.?submodules=1#knowledgeGraph.evidence`: per relation the declared
# default tier, how many edges the graph emits, how many record their own tier
# over that default, and which claim kinds the effective tier may carry. The
# unresolved citations are the policy ids prose names that flake/policies.nix
# does not declare — the edges the graph drops, which `checks:ontology` fails on.
#
# Usage: kg-evidence.sh [RELATION]
# Env: FORMAT=json emits the object instead of the table. RELATION narrows every
# count to one relation; an unknown one exits 2 and names the declared relations.
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

relation="${1:-}"
if [ -n "$relation" ]; then
  if ! jq -e --arg r "$relation" '.relations | has($r)' <<<"$data" >/dev/null; then
    echo "kg-evidence: no relation '$relation'; declared: $(jq -r '.relations | keys | join(", ")' <<<"$data")" >&2
    exit 2
  fi
  data="$(jq --arg r "$relation" '.relations = {($r): .relations[$r]} | .recordedEdges = [.recordedEdges[] | select(.type == $r)] | .total = .relations[$r].edges | .recorded = .relations[$r].recorded' <<<"$data")"
fi
unresolved="$(jq '.unresolvedCitations | length' <<<"$data")"
if [ "${FORMAT:-}" = "json" ]; then
  jq . <<<"$data"
  [ "$unresolved" -eq 0 ] || {
    echo "kg-evidence: ${unresolved} citation(s) resolve to nothing — checks:ontology fails on these" >&2
    exit 3
  }
  exit 0
fi

if [ "${FORMAT:-}" = "line" ]; then
  jq -r --arg rel "${relation:-all}" --argjson kinds "$(jq '.claimKinds | length' <<<"$data")" '
    (if $rel == "all" then "mixed"
     else (.relations[$rel].canCarry) as $c
       | if ($c | length) == $kinds then "all(\($kinds))" else ($c | join(",")) end end) as $carry
    | "relation=\($rel) edges=\(.total) recorded=\(.recorded) carries=\($carry) unresolved=\(.unresolvedCitations | length)"
  ' <<<"$data"
  [ "$unresolved" -eq 0 ] || exit 3
  exit 0
fi

full=0
if [ -n "$relation" ]; then full=1; fi
printf '%-13s %-9s %6s %8s  %s\n' "RELATION" "DEFAULT" "EDGES" "OWN TIER" "CAN CARRY"
jq -r --argjson kinds "$(jq '.claimKinds | length' <<<"$data")" --arg full "$full" '
  .relations
  | to_entries
  | sort_by(-.value.edges, .key)
  | .[]
  | [.key, .value.defaultTier, .value.edges, .value.recorded,
     (if $full == "1" then (.value.canCarry | join(","))
      elif (.value.canCarry | length) == $kinds then "all \($kinds)"
      else (.value.canCarry | join(",")) end)]
  | @tsv
' <<<"$data" | while IFS=$'\t' read -r rel def edges rec carry; do
  printf '%-13s %-9s %6s %8s  %s\n' "$rel" "$def" "$edges" "$rec" "$carry"
done

jq -r '"", "\(.total) edges, \(.recorded) record their own tier"' <<<"$data"
jq -r '
  if (.recordedEdges | length) == 0
  then "no edge records its own tier"
  else "RECORDED (over the relation default):",
       (.recordedEdges[] | "  \(.type) \(.from) -> \(.to) as \(.evidence)")
  end
' <<<"$data"
jq -r '
  if (.unresolvedCitations | length) == 0
  then "no unresolved policy citations"
  else "UNRESOLVED CITATIONS:", (.unresolvedCitations[] | "  " + .)
  end
' <<<"$data"
if [ "$unresolved" -gt 0 ]; then
  echo "kg-evidence: ${unresolved} citation(s) resolve to nothing — checks:ontology fails on these" >&2
  exit 3
fi
