#!/usr/bin/env bash
# kg-check.sh — the gate under the knowledge-graph query surface.
#
# Why it exists: `lib/knowledge-graph.nix` (the projection) and
# `scripts/task/kg-query.sh` (the patterns) are two halves of one contract, and
# nothing in the type system holds them together. Rename `from` to `source`, emit
# `hosts` instead of `host`, or drop the `label` field, and every pattern still
# exits **0 with an empty answer** — the exact silent failure the 0-vs-2 exit
# contract exists to prevent, one level down. A gate is the only thing that
# notices at commit time instead of at question time.
#
# Three layers, cheapest first:
#   1. schema   — required fields, unique ids, endpoints resolve, edge shapes
#                 (mentions: doc|skill -> host|skill; tagged: skill -> tag).
#   2. patterns — each of the six returns rows for an anchor DERIVED from the
#                 graph, result ids are the expected node types, and the answer is
#                 cross-checked: everything `doc X` returns must list `doc:X`
#                 back. That reverse check is what catches a one-sided rename —
#                 each direction is a separate code path.
#   3. surface  — the six task names still exist in `task --list-all --json`, and
#                 a typo still fails with `error: "no_such_node"`.
#
# Cost: one `nix eval` (~1 s warm; it reads the projection and never builds — no
# remote build budget is spent) plus ~30 jq/script calls. Exit 0 = clean,
# 1 = drift.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
Q="$REPO/scripts/task/kg-query.sh"

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# One resolution for the whole gate, through the shared resolver. KG_GRAPH (a
# mutated copy) makes it skip nix entirely, which is how the drift tests below
# are meant to be run.
. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"
G="$(kg_graph_path)" || exit 1
[ -s "$G" ] || { echo "kg-check: no graph at $G" >&2; exit 1; }
export KG_GRAPH="$G"

check() { # name, jq predicate
  local name="$1" expr="$2"
  if jq -e "$expr" "$G" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi
}

echo "== schema =="

# A projection that silently stopped reading files still exits 0; the floor is
# what turns "the graph came back nearly empty" into a failed gate.
check "graph is non-trivial (>=100 nodes, >=100 edges)" \
  '(.nodes | length) >= 100 and (.edges | length) >= 100'

check "every node has id/type/label" \
  'all(.nodes[];
       (.id | type == "string" and length > 0)
       and (.type | type == "string" and length > 0)
       and (.label | type == "string"))'

check "node ids are unique" \
  '(.nodes | map(.id) | length) == (.nodes | map(.id) | unique | length)'

check "every edge has from/to/type" \
  'all(.edges[]; has("from") and has("to") and has("type"))'

# NB: inside `all(GEN; COND)` the input of COND is the element, and an `as`
# binding belongs in COND, not in GEN — `all(.edges[] as $e; …)` is a syntax
# error and silently failed this check the first time round.
check "edge endpoints resolve to nodes" \
  '(.nodes | map({(.id): true}) | add) as $n
   | all(.edges[]; (.from as $f | .to as $t | $n[$f] != null and $n[$t] != null))'

check "edge types are mentions|tagged" \
  'all(.edges[]; .type == "mentions" or .type == "tagged")'

check "mentions: (doc|skill) -> (host|skill)" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "mentions" then true
         else (.from as $f | .to as $to
               | ($t[$f] == "doc" or $t[$f] == "skill")
                 and ($t[$to] == "host" or $t[$to] == "skill"))
         end)'

check "tagged: skill -> tag" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "tagged" then true
         else (.from as $f | .to as $to | $t[$f] == "skill" and $t[$to] == "tag")
         end)'

check "stats agree with a recount of nodes and edges" \
  '(.nodes | map(select(.type == "host")) | length) as $h
   | (.nodes | map(select(.type == "skill")) | length) as $s
   | (.nodes | map(select(.type == "doc")) | length) as $d
   | .stats.hosts == $h and .stats.skills == $s and .stats.docs == $d
     and .stats.edges == (.edges | length)'

echo "== patterns =="

# ask <pattern> [name] — JSON on stdout, non-zero on failure.
ask() { bash "$Q" "$@" --json 2>/dev/null; }

# rows <label> <pattern> [name] — asserts a non-empty answer and reports the
# count, then leaves the JSON in $LAST for the type/reverse checks below.
rows() {
  local label="$1"
  shift
  if ! LAST="$(ask "$@")"; then
    bad "$label (query failed)"
    LAST=""
    return 1
  fi
  local n
  n="$(jq -r '.count' <<<"$LAST")"
  if [ "$n" -gt 0 ]; then
    ok "$label ($n rows)"
  else
    bad "$label (0 rows)"
  fi
}

# Type checks run on whatever the pattern returned; a wrong prefix means the
# filter matched the wrong node kind, which is drift even with rows present.
expect_types() { # label, json, allowed-prefix-alt
  local label="$1" json="$2" allowed="$3"
  [ -n "$json" ] || return 0
  if jq -e --arg re "^($allowed):" \
    '[.results[] | select(type == "object" | not) | select(test($re) | not)] | length == 0' \
    <<<"$json" >/dev/null 2>&1; then
    ok "$label result types"
  else
    bad "$label result types"
  fi
}

# Anchors are derived, not hardcoded — except the two that exist by construction
# (a host from inventory.toml, a living document from lib/knowledge-graph.nix).
seed_host="$(jq -r '[.edges[] | select(.type == "mentions" and (.to | startswith("host:"))) | .to]
  | group_by(.) | sort_by(-length) | last | .[0] // "" | sub("^host:"; "")' "$G")"
seed_skill="$(jq -r '[.edges[] | select(.type == "mentions" and (.to | startswith("skill:"))) | .to]
  | group_by(.) | sort_by(-length) | last | .[0] // "" | sub("^skill:"; "")' "$G")"
seed_tag="$(jq -r '[.edges[] | select(.type == "tagged") | .to]
  | group_by(.) | sort_by(-length) | last | .[0] // "" | sub("^tag:"; "")' "$G")"

rows "host frieren (inventory anchor)" host frieren
HOST_JSON="$LAST"
expect_types "host" "$HOST_JSON" 'doc|skill'

rows "doc AGENTS.md (living-doc anchor)" doc AGENTS.md
DOC_JSON="$LAST"
expect_types "doc" "$DOC_JSON" 'host|skill'

if [ -n "$seed_skill" ]; then
  rows "skill $seed_skill (derived anchor)" skill "$seed_skill"
  SKILL_JSON="$LAST"
  expect_types "skill" "$SKILL_JSON" 'doc|skill|tag'
else
  bad "skill: no skill mentioned anywhere (cannot derive an anchor)"
  SKILL_JSON=""
fi

if [ -n "$seed_tag" ]; then
  rows "tag $seed_tag (derived anchor)" tag "$seed_tag"
  TAG_JSON="$LAST"
  expect_types "tag" "$TAG_JSON" 'skill'
else
  bad "tag: no tagged edge in the graph (cannot derive an anchor)"
  TAG_JSON=""
fi

if [ -n "$seed_host" ]; then
  rows "comention $seed_host (derived anchor)" comention "$seed_host"
  CO_JSON="$LAST"
  expect_types "comention" "$CO_JSON" 'host'
  if [ -n "$CO_JSON" ] && jq -e --arg seed "host:$seed_host" \
    '[.results[] | select(.id == $seed)] | length == 0' <<<"$CO_JSON" >/dev/null 2>&1; then
    ok "comention excludes the seed host"
  else
    bad "comention returned the seed host itself"
  fi
else
  bad "comention: no host is mentioned by any document"
  CO_JSON=""
fi

# The reverse check: each direction is a separate jq program, so a rename on one
# side shows up here even though both sides still "answer".
if [ -n "$DOC_JSON" ]; then
  reverse_bad=0
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    kind="${id%%:*}"
    name="${id#*:}"
    case "$kind" in host | skill) ;; *) continue ;; esac
    if ! ask "$kind" "$name" | jq -e --arg d "doc:AGENTS.md" '.results | index($d)' >/dev/null 2>&1; then
      bad "reverse: doc AGENTS.md -> $id, but $kind $name does not list it back"
      reverse_bad=1
    fi
  done < <(jq -r '.results[].id' <<<"$DOC_JSON" 2>/dev/null || true)
  [ "$reverse_bad" = 1 ] || ok "reverse consistency (doc AGENTS.md <-> its neighbours)"
fi

if [ -n "$TAG_JSON" ] && [ -n "$seed_tag" ]; then
  tag_reverse_bad=0
  while IFS= read -r id; do
    # A drifted answer can contain JSON nulls; they are not ids and must not be
    # reported as a broken reverse edge (they are already a type failure).
    case "$id" in "" | null) continue ;; esac
    if ! ask skill "${id#skill:}" | jq -e --arg t "tag:$seed_tag" '.results | index($t)' >/dev/null 2>&1; then
      bad "reverse: tag $seed_tag -> $id, but skill ${id#skill:} does not list it back"
      tag_reverse_bad=1
    fi
  done < <(jq -r '.results[]' <<<"$TAG_JSON" 2>/dev/null || true)
  [ "$tag_reverse_bad" = 1 ] || ok "reverse consistency (tag <-> skills)"
fi

# stats must describe the same graph the patterns just read.
if want="$(jq -r '"\(.nodes | length) \(.nodes | map(select(.type == "host")) | length) \(.nodes | map(select(.type == "skill")) | length) \(.nodes | map(select(.type == "doc")) | length) \(.nodes | map(select(.type == "tag")) | length) \(.edges | length)"' "$G")" &&
  got="$(ask stats | jq -r '.results[0] | "\(.nodes) \(.hosts) \(.skills) \(.docs) \(.tags) \(.edges)"')"; then
  if [ "$want" = "$got" ]; then
    ok "stats pattern agrees with the projection ($got)"
  else
    bad "stats pattern disagrees: script '$got' vs graph '$want'"
  fi
else
  bad "stats pattern failed"
fi

echo "== surface =="

# The Taskfile is the agent-facing interface; a renamed task breaks callers even
# when the script still works.
# `--dir` matters: called from anywhere but the repo root, go-task finds no
# Taskfile and the surface check fails for a reason that has nothing to do with
# the graph (caught by running the drift tests from /tmp).
if task --dir "$REPO" --list-all --json >"$work/tasks.json" 2>/dev/null; then
  for t in host skill doc tag comention stats; do
    if jq -e --arg n "ops:kg:$t" '.tasks | map(.name) | index($n)' "$work/tasks.json" >/dev/null 2>&1; then
      ok "task ops:kg:$t exists"
    else
      bad "task ops:kg:$t is missing from the Taskfile"
    fi
  done
else
  bad "could not read \`task --list-all --json\`"
fi

# A typo must fail, and it must fail in JSON when JSON was requested. Exit status
# is checked on the script, because go-task collapses every failure to 201.
if out="$(ask host friere)"; then
  bad "typo 'friere' did not fail (a misspelled name must not look like an empty answer)"
else
  rc=$?
  if [ "$rc" = 2 ]; then
    ok "typo exits 2"
  else
    bad "typo exits $rc (expected 2)"
  fi
  if jq -e '.error == "no_such_node"' <<<"$out" >/dev/null 2>&1; then
    ok "typo payload carries error:no_such_node"
  else
    bad "typo payload has no error field"
  fi
  # Suggestions come from node labels: if they vanish, the surface got worse even
  # though the failure is still loud.
  if jq -e '(.suggestions | length) > 0' <<<"$out" >/dev/null 2>&1; then
    ok "typo suggests near matches"
  else
    bad "typo returned no suggestions (labels missing?)"
  fi
fi

echo
if [ "$fail" = 0 ]; then
  echo "kg-check: ok — schema, six patterns, and the task surface all agree"
else
  echo "kg-check: DRIFT — see the FAIL lines above"
fi
exit "$fail"
