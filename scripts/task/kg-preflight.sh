#!/usr/bin/env bash
# kg-preflight.sh — "what does this change reach?" before it is applied.
#
# Maps changed FILES to the graph anchors they are about, then prints the
# transitive dependents of each anchor. It is the pre-flight half of the sidecar:
# `ops:kg:blast` answers for a node you already named, this answers for a path
# you are about to edit.
#
# Why the mapping is small and explicit: the projection has nodes for hosts,
# skills, docs and tags — nothing else. A file under `hosts/<h>/` is about that
# host; a SKILL.md is that skill; a living document is that doc. Anything else
# (modules/, flake/, taskfiles/) is NOT a graph node, and pretending otherwise
# would produce a confident zero. Those are reported as unmapped, with the tool
# that can actually answer for them.
#
# Backends: the sidecar when it is already running (0.2-0.9 ms per query), else
# a jq transitive closure over the same graph — identical answer, ~40 ms, no
# daemon. A commit hook must not start a daemon, and this must work before one
# has ever been started.
#
# Usage: kg-preflight.sh [--staged] [--advisory] [FILE...]
#        --staged    use `git diff --cached --name-only`
#        --advisory  always exit 0 (pre-commit path; it reports, never blocks)
# Exit: 0 = reported; 1 = --strict and at least one mapped anchor; 2 = usage.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SOCKET="${KG_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/kg.sock}"
staged=0
advisory=1 # reporting by default; blocking is opt-in via --strict
files=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --staged) staged=1; shift ;;
    --advisory) advisory=1; shift ;;
    --strict) advisory=0; shift ;;
    -h | --help) kg_usage "${BASH_SOURCE[0]}"; exit 0 ;;
    --*) echo "kg-preflight: unknown option $1" >&2; exit 2 ;;
    *) files+=("$1"); shift ;;
  esac
done

. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"
G="$(kg_graph_path)" || exit 1
[ -s "$G" ] || { echo "kg-preflight: no graph at $G" >&2; exit 1; }

if [ "$staged" = 1 ]; then
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done \
    < <(git -C "$REPO" diff --cached --name-only --diff-filter=ACM)
fi

[ "${#files[@]}" -gt 0 ] || {
  echo "kg-preflight: no files given (use --staged or name paths)" >&2
  exit 2
}

node_exists() { jq -e --arg id "$1" '.nodes | map(.id) | index($id) != null' "$G" >/dev/null 2>&1; }

# file -> anchor id (empty when the path is not a graph node).
anchor_for() {
  local f="$1"
  case "$f" in
    hosts/*/*) local h="${f#hosts/}"; printf 'host:%s' "${h%%/*}" ;;
    hosts/*.nix) local b="${f#hosts/}"; printf 'host:%s' "${b%.nix}" ;;
    .agents/skills/*/*)
      local s="${f#.agents/skills/}"
      printf 'skill:%s' "${s%%/*}"
      ;;
    docs/*.md)
      # non-recursive, matching lib/knowledge-graph.nix
      case "${f#docs/}" in */*) : ;; *) printf 'doc:%s' "$f" ;; esac
      ;;
    AGENTS.md | MANUAL.md | ARCHITECTURE.md | AUDIT.md | TODO.md | HANDOFF.md | EXPERIMENTS.md | README.md)
      printf 'doc:%s' "$f"
      ;;
    inventory.toml | lib/knowledge-graph.nix) printf 'GRAPH-WIDE' ;;
  esac
}

# jq fallback: reverse-edge closure, the same walk blast_radius does. Array
# subtraction keeps the frontier finite on a graph with shared documents.
closure_jq() {
  # Parenthesise the whole state object before `until`: without the parens the
  # `|` binds inside the object literal and until() receives an array, which
  # fails with "Cannot index array with string (\"frontier\")".
  jq -r --arg a "$1" '
    .edges as $E
    | ({ seen: [$a], frontier: [$a] }
       | until(.frontier == [];
           .frontier as $f
           | ([ $E[] | select(.to as $t | $f | index($t)) | .from ] | unique) as $n
           | { frontier: ($n - .seen), seen: (.seen + $n) }))
    | (.seen - [$a]) | length
  ' "$G"
}

impacted_of() {
  local anchor="$1"
  if [ -S "$SOCKET" ] && curl -s -m 2 --unix-socket "$SOCKET" http://localhost/stats >/dev/null 2>&1; then
    curl -s -m 30 --unix-socket "$SOCKET" "http://localhost/blast-radius?id=$(jq -rn --arg s "$anchor" '$s|@uri')"
  else
    local n
    n="$(closure_jq "$anchor")"
    jq -cn --arg a "$anchor" --argjson n "$n" '{target: $a, impacted_count: $n, backend: "jq"}'
  fi
}

echo "kg-preflight: ${#files[@]} file(s); graph $(basename "$G")"
mapped=0
unmapped=0
declare -A seen_anchor=()
union=()

for f in "${files[@]}"; do
  anchor="$(anchor_for "$f")"
  if [ "$anchor" = "GRAPH-WIDE" ]; then
    printf '  %-46s graph-wide — %s feeds every node; no useful single blast radius\n' "$f" "$f"
    continue
  fi
  if [ -z "$anchor" ] || ! node_exists "$anchor"; then
    printf '  %-46s unmapped — not a graph node (use task dev:closure:* for closures)\n' "$f"
    unmapped=$((unmapped + 1))
    continue
  fi

  mapped=$((mapped + 1))
  if [ -n "${seen_anchor[$anchor]:-}" ]; then
    printf '  %-46s %-22s (same anchor as above)\n' "$f" "$anchor"
    continue
  fi
  seen_anchor[$anchor]=1

  res="$(impacted_of "$anchor")"
  n="$(jq -r '.impacted_count' <<<"$res")"
  us="$(jq -r '._latency_us // empty' <<<"$res")"
  how="$(jq -r '.backend // "sidecar"' <<<"$res")"
  if [ -n "$us" ]; then
    printf '  %-46s %-22s %3s impacted (%s, %s µs)\n' "$f" "$anchor" "$n" "$how" "$us"
  else
    printf '  %-46s %-22s %3s impacted (%s)\n' "$f" "$anchor" "$n" "$how"
  fi

  while IFS= read -r id; do
    union+=("$id")
    printf '      %s\n' "$id"
  done < <(jq -r '(.impacted_entities // [])[] | .id' <<<"$res" 2>/dev/null || true)
done

printf '\nkg-preflight: %s mapped, %s unmapped\n' "$mapped" "$unmapped"
if [ "${#union[@]}" -gt 0 ]; then
  printf 'kg-preflight: %s distinct impacted node(s)\n' \
    "$(printf '%s\n' "${union[@]}" | sort -u | wc -l)"
fi

if [ "$advisory" = 0 ] && [ "$mapped" -gt 0 ]; then
  exit 1
fi
exit 0
