#!/usr/bin/env bash
# kg-query.sh — the EXPLICIT query surface over .?submodules=1#knowledgeGraph.
#
# Six patterns, no inference. Each one is a fixed traversal of the graph
# projection, i.e. the jq analogue of a Cypher MATCH:
#
#   host <h>        (Doc|Skill)-[:MENTIONS]->(Host)      "what touches frieren"
#   skill <s>       (Doc|Skill)-[:MENTIONS]->(Skill)     "where is nix-eval used"
#                   + (Skill)-[:TAGGED]->(Tag)
#   module <p>      (Module)-[:IMPORTS]->(Module)        "who imports modules/x.nix"
#   doc <p>         (Doc)-[:MENTIONS]->(Host|Skill)      "what does MANUAL.md name"
#   tag <t>         (Skill)-[:TAGGED]->(Tag)             "skills tagged nix"
#   comention <h>   (Doc)->(Host) and the same (Doc)->(Host')
#                                                        "who shares docs with X"
#   stats           counts, plus top out-degree with --top N
#   blast <id>      (Module|Doc|Skill|Host)-[:*]->(...)*        "who breaks with it"
#                   reverse closure, prefixed id (host:, skill:, doc:, tag:,
#                   module:); the one pattern the forward scans cannot answer
#
# The point is that a caller who knows which question it is asking never needs a
# classifier: `ops:ask` is sugar in front of these, not the other way round.
# Edges are stored `doc|skill -> host|skill|tag` only, so every pattern here is a
# forward scan — there is no reverse index to miss.
#
# Usage: kg-query.sh <pattern> [NAME] [--json] [--top N] [--min N]
#   --json   emit {pattern, arg, count, results} (results: strings, or
#            {id,shared} objects for comention, or one object for stats)
#   --top N  stats only: list the N nodes with the most outbound edges
#   --min N  comention only: drop hosts sharing fewer than N documents (default 1)
#   KG_GRAPH=<path>  use an existing graph JSON instead of evaluating
#
# One traversal path, not two. A resident Elixir sidecar used to answer these
# from a socket in 28 ms; measured 2026-11-07 the file-cache path answers in
# 53 ms (49 ms on `stats`), and the eval that fills the cache now goes through
# `iets` at 820 ms cold / 25 ms warm instead of `nix eval`'s 1.7 s. A daemon and
# a byte-parity gate to buy 25 ms did not clear its own rent, so it went. The
# frontier and the numbers: docs/nix-patterns.md, `task ops:kg:speed`.
#
# Exit: 0 = answer (possibly empty); 1 = graph unavailable; 2 = usage, or the
# named node does not exist. "Empty" and "typo" are deliberately different exit
# codes — a silent empty result is how a graph stops being trusted.
set -euo pipefail

PATTERN="${1:-}"
[ -n "$PATTERN" ] && shift || true

NAME=""
JSON=0
TOP=0
MIN=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --top) TOP="${2:-0}"; shift 2 ;;
    --min) MIN="${2:-1}"; shift 2 ;;
    -h | --help) sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "kg-query: unknown option $1" >&2; exit 2 ;;
    *)
      [ -z "$NAME" ] || { echo "kg-query: only one name per pattern" >&2; exit 2; }
      NAME="$1"; shift
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "kg-query: jq required" >&2; exit 2; }

# --top/--min feed `as $min` and slice arithmetic, so a non-number must fail here
# with a usage message rather than inside jq with a stack of context.
for pair in "TOP=$TOP" "MIN=$MIN"; do
  flag="${pair%%=*}"
  value="${pair#*=}"
  case "$value" in
    '' | *[!0-9]*) echo "kg-query: $flag needs a non-negative integer (got '$value')" >&2; exit 2 ;;
  esac
done

# --- graph ------------------------------------------------------------------
# Resolution is DEFERRED until the fast path misses (below). It is the expensive
# half on a dirty tree — the cache is deliberately bypassed there — so a live
# sidecar answering the same question should not pay for it first.

# --- name normalisation -----------------------------------------------------
# Accept `frieren` or `host:frieren`, `docs/x.md` or `doc:docs/x.md`. The node
# ids are prefixed, so an untyped name has exactly one sensible reading per
# pattern.
node_id() {
  local kind="$1" n="$2"
  case "$kind:$n" in
    *:host:* | *:skill:* | *:doc:* | *:tag:* | *:module:*) printf '%s' "$n" ;;
    host:*) printf 'host:%s' "$n" ;;
    skill:*) printf 'skill:%s' "$n" ;;
    doc:*) printf 'doc:%s' "$n" ;;
    tag:*) printf 'tag:%s' "$n" ;;
    module:*) printf 'module:%s' "$n" ;;
    modules/* | hosts/* | flake/* | lib/*) printf 'module:%s' "$n" ;;
  esac
}

require_name() {
  [ -n "$NAME" ] || { echo "kg-query: pattern '$1' needs a name" >&2; exit 2; }
}

# A node that does not exist is a typo, not an empty answer: say which one it
# was and suggest the closest ids rather than printing nothing. In JSON mode the
# failure is still JSON — a machine caller that asked for JSON must not have to
# parse prose to discover it misspelled a name.
check_exists() {
  local id="$1" n="$2"
  local count hints
  count="$(jq --arg a "$id" '[.nodes[] | select(.id == $a)] | length' "$GRAPH")"
  [ "$count" = "0" ] || return 0

  # Two passes: substring first (a truncated name like `friere`), then a prefix
  # pass so a typo (`qmdd`) still lands near `qmd` instead of printing an empty
  # hint list.
  hints="$(
    {
      jq -r --arg n "$n" '
        .nodes[]
        | select((.label // "") | ascii_downcase | contains($n | ascii_downcase))
        | .id' "$GRAPH" 2>/dev/null
      jq -r --arg n "$n" '
        ($n | ascii_downcase | .[0:2]) as $p
        | .nodes[]
        | select((.label // "") | ascii_downcase | startswith($p))
        | .id' "$GRAPH" 2>/dev/null
    } | awk '!seen[$0]++' | head -5
  )"

  if [ "$JSON" = 1 ]; then
    jq -nc --arg p "$PATTERN" --arg a "$id" \
      --argjson s "$(printf '%s\n' "${hints:-}" | jq -R . | jq -sc 'map(select(. != ""))')" \
      '{pattern: $p, arg: $a, count: 0, results: [], error: "no_such_node", suggestions: $s}'
  else
    echo "kg-query: no node '$id' in the graph" >&2
    [ -z "$hints" ] || printf '%s\n' "$hints" | sed 's/^/  did you mean: /' >&2
  fi
  exit 2
}

# --- patterns ---------------------------------------------------------------
# Each case sets JQ to a filter producing a JSON array. Rendering is generic:
# objects with {id, shared} become TSV, strings pass through.
JQ=""
case "$PATTERN" in
  host)
    require_name host
    ID="$(node_id host "$NAME")"
    JQ='[.edges[] | select(.to == $a) | .from] | unique | sort'
    ;;
  doc)
    require_name doc
    ID="$(node_id doc "$NAME")"
    JQ='[.edges[] | select(.from == $a) | .to] | unique | sort'
    ;;
  skill)
    require_name skill
    ID="$(node_id skill "$NAME")"
    # Inbound mentions AND outbound tags: "everything connected to the skill",
    # the same promise ops:kg:host makes for hosts.
    JQ='[(.edges[] | select(.to == $a) | .from),
         (.edges[] | select(.from == $a) | .to)] | unique | sort'
    ;;
  tag)
    require_name tag
    ID="$(node_id tag "$NAME")"
    JQ='[.edges[] | select(.to == $a) | .from] | unique | sort'
    ;;
  module)
    require_name module
    ID="$(node_id module "$NAME")"
    # Inbound `imports` only: the one edge kind a module can have pointing at it.
    # A file is not "mentioned" by prose, so an empty answer here is a real
    # answer — nothing imports this file.
    JQ='[.edges[] | select(.type == "imports" and .to == $a) | .from] | unique | sort'
    ;;
  comention)
    require_name comention
    ID="$(node_id host "$NAME")"
    # Two hops without a join operator: the docs that name this host, then every
    # OTHER host those same docs name. This is the one pattern a single-hop
    # index cannot answer, and the reason it is worth having at all.
    JQ='([.edges[] | select(.to == $a) | .from] | unique) as $docs
        | [ .edges[]
            | select(.type == "mentions")
            | select(.from as $f | $docs | index($f))
            | select(.to | startswith("host:"))
            | select(.to != $a)
            | .to ]
        | group_by(.) | map({id: .[0], shared: length})
        | map(select(.shared >= $min))
        | sort_by(-.shared, .id)'
    ;;
  blast)
    # The reverse closure: the one traversal the forward scans above cannot
    # answer. It reads lib/kg-closure.jq — ONE definition, because the two
    # hand-written copies that used to exist disagreed (direct edges only in
    # one, a double-counted frontier in the other) and made a correct engine
    # look like drift. Needs a prefixed id (host:, skill:, doc:, tag:,
    # module:); a bare name is not guessed, because "who depends on qmd" and
    # "who depends on the qmd doc" are different graphs.
    require_name blast
    ID="$(node_id blast "$NAME")"
    BLAST=1
    ;;
  stats)
    # Kept as a one-object result so --json is stable; text mode below prints
    # the same line ops:kg has always printed.
    JQ='[{
          nodes: (.nodes | length),
          hosts: (.nodes | map(select(.type == "host")) | length),
          skills: (.nodes | map(select(.type == "skill")) | length),
          docs: (.nodes | map(select(.type == "doc")) | length),
          tags: (.nodes | map(select(.type == "tag")) | length),
          modules: (.nodes | map(select(.type == "module")) | length),
          edges: (.edges | length)
        }]'
    ;;
  "" | -h | --help)
    sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "kg-query: unknown pattern '$PATTERN' (host|skill|doc|tag|module|comention|stats)" >&2
    exit 2
    ;;
esac

# --- graph ------------------------------------------------------------------
. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"
GRAPH="$(kg_graph_path)" || exit 1

if [ -n "${ID:-}" ]; then check_exists "$ID" "$NAME"; fi

if [ "${BLAST:-0}" = 1 ]; then
  # One process, and lib/kg-closure.jq stays the only definition: the file emits
  # the impacted ARRAY, so `.[]` is appended to the filter rather than to the
  # graph (piping the array through -r prints `[` and `]` as lines).
  closure_filter="$(cat "${BASH_SOURCE[0]%/*}/lib/kg-closure.jq")"
  mapfile -t impacted < <(jq -r --arg root "$ID" "$closure_filter | .[]" "$GRAPH")
  if [ "$JSON" = 1 ]; then
    if [ "${#impacted[@]}" -eq 0 ]; then
      jq -cn --arg a "$ID" '{target: $a, impacted_count: 0, impacted_entities: [], backend: "jq"}'
    else
      printf '%s\n' "${impacted[@]}" |
        jq -Rsc --arg a "$ID" '{target: $a, impacted_count: (split("\n") | map(select(. != "")) | length), impacted_entities: (split("\n") | map(select(. != "")) | map({id: .})), backend: "jq"}'
    fi
    exit 0
  fi
  printf '%s impacted node(s) for %s\n' "${#impacted[@]}" "$ID"
  [ "${#impacted[@]}" -eq 0 ] || printf '  %s\n' "${impacted[@]}"
  exit 0
fi

RESULT="$(jq -c --arg a "${ID:-}" --argjson min "$MIN" "$JQ" "$GRAPH")"

if [ "$JSON" = 1 ]; then
  jq -c --arg p "$PATTERN" --arg a "${ID:-}" --argjson r "$RESULT" \
    '{pattern: $p, arg: $a, count: ($r | length), results: $r}' <<<"{}"
  exit 0
fi

if [ "$PATTERN" = "stats" ]; then
  jq -r '.[0] | "nodes: \(.hosts) hosts, \(.skills) skills, \(.docs) docs, \(.tags) tags, \(.modules) modules; edges: \(.edges)"' \
    <<<"$RESULT"
  if [ "$TOP" -gt 0 ] 2>/dev/null; then
    # Out-degree is the cheap "how central is this" measure; in-degree is what
    # `host`/`skill` print per node.
    jq -r '[.edges[] | .from] | group_by(.) | map({id: .[0], n: length})
           | sort_by(-.n) | .[:'"$TOP"'][] | "\(.n)\t\(.id)"' "$GRAPH" \
      | column -t -s$'\t'
  fi
  exit 0
fi

jq -r '.[] | if type == "object" then [.id, (.shared | tostring)] | @tsv else . end' \
  <<<"$RESULT" |
  if [ "$PATTERN" = "comention" ]; then column -t -s$'\t'; else cat; fi
