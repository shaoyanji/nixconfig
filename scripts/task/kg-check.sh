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
#                 (mentions: doc|skill -> host|skill; tagged: skill -> tag;
#                 references: doc -> doc; cites: doc|skill -> policy).
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

# The edge property set is closed. `routes` is the one edge that carries data
# beyond its endpoints (the playbook row's label); any other property is a field
# no pattern reads, i.e. data that looks queryable and is not.
check "edges carry only type/from/to/label" \
  'all(.edges[]; ((keys - ["type", "from", "to", "label"]) | length) == 0)'

check "routes edges carry a label" \
  'all(.edges[]; if .type == "routes" then ((.label // "") | length) > 0 else true end)'

# NB: inside `all(GEN; COND)` the input of COND is the element, and an `as`
# binding belongs in COND, not in GEN — `all(.edges[] as $e; …)` is a syntax
# error and silently failed this check the first time round.
check "edge endpoints resolve to nodes" \
  '(.nodes | map({(.id): true}) | add) as $n
   | all(.edges[]; (.from as $f | .to as $t | $n[$f] != null and $n[$t] != null))'

check "edge types are mentions|tagged|references|about|imports|cites|derives|supersedes|routes" \
  'all(.edges[]; .type == "mentions" or .type == "tagged" or .type == "references" or .type == "about" or .type == "imports" or .type == "cites" or .type == "derives" or .type == "supersedes" or .type == "routes")'

check "routes layer is populated (>=17 edges)" \
  '([.edges[] | select(.type == "routes")] | length) >= 17'

# An alias is a second name for a task that exists, so it must point at a node
# carrying the same description. An alias whose canonical vanished still answers
# `task <alias>` on the command line while the graph answers nothing.
check "alias task nodes point at a real task with the same desc" \
  '(.nodes | map({(.id): .}) | add) as $n
   | all(.nodes[];
         if .type == "task" and ((.aliasOf // "") != "") then
           ($n["task:" + .aliasOf] != null and $n["task:" + .aliasOf].desc == .desc)
         else true end)'

# A route is a table row naming the task it runs: prose points at the command,
# never the reverse. The task must be a compiled node, not a string the row got
# away with.
check "routes: (doc|skill) -> task" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "routes" then true
         else (.from as $f | .to as $to
               | ($t[$f] == "doc" or $t[$f] == "skill") and $t[$to] == "task")
         end)'

# A citation is the one edge quoting `flake/policies.nix#id`: prose points at the
# rule, never the reverse. If a doc or skill could SOURCE a policy, the graph
# would be claiming a rule lives in prose, which is the thing this layer denies.
check "cites: (doc|skill) -> policy" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "cites" then true
         else (.from as $f | .to as $to
               | ($t[$f] == "doc" or $t[$f] == "skill") and $t[$to] == "policy")
         end)'

# The layer can collapse to zero without anything else looking wrong: the marker
# is a literal string, so a reworded citation leaves every page in place and the
# edges gone. The floor makes that a failure.
check "cites layer is populated (>=20 edges)" \
  '([.edges[] | select(.type == "cites")] | length) >= 20'

# The doc-to-doc layer is the one relation that needs a parser rather than a token
# scan, so it is the one that can silently return zero: a wrong regex, a changed
# link style or a doc-set edit all leave every other check green. The floor is
# measured at 61 edges; 30 fails on a collapsed parser without tripping on prose.
check "references layer is populated (>=30 edges)" \
  '([.edges[] | select(.type == "references")] | length) >= 30'

check "references: doc -> doc" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "references" then true
         else (.from as $f | .to as $to | $t[$f] == "doc" and $t[$to] == "doc")
         end)'

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

# A draft names the entities it is about, and only those: the edge shape is the
# whole point of the layer, so a stray `about -> tag:` or an idea pointing at an
# idea fails here rather than answering a query nobody meant to ask.
check "imports: module -> module" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "imports" then true
         else (.from as $f | .to as $to | $t[$f] == "module" and $t[$to] == "module")
         end)'

# The import layer is the one that can return zero without anything else looking
# wrong: a changed path style (quoted interpolation, an `imports = map (…)`) leaves
# every other check green. Measured at 460 imports edges on this tree; the floor
# is what makes a silent parser collapse fail.
check "imports layer is populated (>=100 edges)" \
  '([.edges[] | select(.type == "imports")] | length) >= 100'

# A lineage edge is a claim two notes make about each other, and it is the only
# edge whose both ends are the same type. `derives` is SCHEMA's `from`; the name
# differs because `from` reads as a field in every query that prints an edge.
check "derives|supersedes: note -> note" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if (.type != "derives" and .type != "supersedes") then true
         else (.from as $f | .to as $to | $t[$f] == "note" and $t[$to] == "note")
         end)'

# The lineage layer is populated by construction — AGENTS.nix ships notes with
# `from` and `supersedes` — so zero edges means the emitter stopped reading them.
check "lineage layer is populated (>=1 edge)" \
  '([.edges[] | select(.type == "derives" or .type == "supersedes")] | length) >= 1'

check "about: idea -> (doc|host|skill)" \
  '(.nodes | map({(.id): .type}) | add) as $t
   | all(.edges[];
         if .type != "about" then true
         else (.from as $f | .to as $to
               | $t[$f] == "idea"
                 and ($t[$to] == "doc" or $t[$to] == "host" or $t[$to] == "skill"))
         end)'

# A draft with no entities is a file the projection read and got nothing out of —
# exactly the failure the frontmatter parser has. It is not a style opinion:
# every draft `dev:blog:draft` writes has at least one seed.
check "every idea names at least one entity" \
  '(.nodes | map(select(.type == "idea") | .id) | sort) as $ideas
   | ([.edges[] | select(.type == "about") | .from] | unique) as $linked
   | ($ideas - $linked) | length == 0'

# The file count is the independent witness: the graph says how many drafts it
# parsed, the tree says how many exist. A parser that skipped a shape (a quoted
# list item, a CRLF checkout) shows up as a number that disagrees, not as a
# quietly smaller graph. The `.md` filter matches `ideas/*.md` only — the
# projection is non-recursive, so neither is this.
idea_files="$(ls "$REPO"/ideas/*.md 2>/dev/null | wc -l | tr -d ' ')"
idea_nodes="$(jq -r '[.nodes[] | select(.type == "idea")] | length' "$G")"
if [ "$idea_files" = "$idea_nodes" ]; then
  ok "every ideas/*.md is a node ($idea_nodes)"
else
  bad "ideas/*.md on disk ($idea_files) != idea nodes in the graph ($idea_nodes)"
fi

check "stats agree with a recount of nodes and edges" \
  '(.nodes | map(select(.type == "host")) | length) as $h
   | (.nodes | map(select(.type == "skill")) | length) as $s
   | (.nodes | map(select(.type == "doc")) | length) as $d
   | (.nodes | map(select(.type == "module")) | length) as $m
   | .stats.hosts == $h and .stats.skills == $s and .stats.docs == $d
     and .stats.modules == $m
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
seed_module="$(jq -r '[.edges[] | select(.type == "imports") | .to]
  | group_by(.) | sort_by(-length) | last | .[0] // "" | sub("^module:"; "")' "$G")"

rows "host frieren (inventory anchor)" host frieren
HOST_JSON="$LAST"
expect_types "host" "$HOST_JSON" 'doc|skill'

rows "doc AGENTS.md (living-doc anchor)" doc AGENTS.md
DOC_JSON="$LAST"
# A doc answers with four kinds of neighbour: the hosts and skills it mentions,
# the documents it links to (the `references` layer), and the rules it cites — the
# `cites` layer, which is what makes "who restates this rule" a query.
expect_types "doc" "$DOC_JSON" 'host|skill|doc|policy'

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

if [ -n "$seed_module" ]; then
  rows "module $seed_module (derived anchor)" module "$seed_module"
  expect_types "module" "$LAST" 'module'
else
  bad "module: no imports edge in the graph (cannot derive an anchor)"
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
  for t in host skill doc tag module comention stats blast task; do
    if jq -e --arg n "ops:kg:$t" '.tasks | map(.name) | index($n)' "$work/tasks.json" >/dev/null 2>&1; then
      ok "task ops:kg:$t exists"
    else
      bad "task ops:kg:$t is missing from the Taskfile"
    fi
  done
  # The graph's task nodes are the Taskfile's names and aliases, and nothing
  # else. yq and go-task parse the same YAML; a shard yq dropped, or an alias
  # list it read as a string, shows up as a set difference instead of a graph
  # that answers for a surface nobody can run.
  jq -r '.tasks[] | .name, (.aliases // [])[]' "$work/tasks.json" | sort -u >"$work/names.txt"
  jq -r '.nodes[] | select(.type == "task") | .id | sub("^task:"; "")' "$G" | sort -u >"$work/nodes.txt"
  if diff_out="$(diff -u "$work/names.txt" "$work/nodes.txt")"; then
    ok "task nodes are the Taskfile surface ($(wc -l <"$work/nodes.txt" | tr -d ' ') names and aliases)"
  else
    bad "task nodes disagree with go-task:"
    printf '%s\n' "$diff_out" | sed -n '3,12p' | sed 's/^/      /'
  fi

  # The alias map is the same claim in both directions: go-task reports which
  # name is an alias of which task, and each alias node must carry that aliasOf.
  jq -r '.tasks[] | select((.aliases // []) | length > 0) | .name as $c | .aliases[] | "\(.)\t\($c)"' \
    "$work/tasks.json" | sort >"$work/alias-want.txt"
  jq -r '.nodes[] | select(.type == "task" and ((.aliasOf // "") != "")) | "\(.id | sub("^task:"; ""))\t\(.aliasOf)"' \
    "$G" | sort >"$work/alias-got.txt"
  if diff -q "$work/alias-want.txt" "$work/alias-got.txt" >/dev/null; then
    ok "alias nodes carry their canonical task ($(wc -l <"$work/alias-got.txt" | tr -d ' '))"
  else
    bad "alias map disagrees with go-task: $(diff "$work/alias-want.txt" "$work/alias-got.txt" 2>&1 | head -4 | tr '\n' ' ')"
  fi
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
  echo "kg-check: ok — schema, patterns, and the task surface all agree"
else
  echo "kg-check: DRIFT — see the FAIL lines above"
fi
exit "$fail"
