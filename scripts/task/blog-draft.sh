#!/usr/bin/env bash
# blog-draft.sh — hand a writer a skeleton with its citations already attached.
#
#   blog-draft.sh "why the graph needed references"
#
# The point is not to write the piece. A blank page is cheap; the expensive part
# is knowing which existing documents already say something about the topic, so
# that the draft argues with the tree instead of restating it. This walks the
# compiled knowledge graph two hops out from whatever node matches the topic,
# and writes `ideas/<slug>.md` whose frontmatter names those entities, so the
# draft is a node with edges the moment it exists (`ops:kg:blast`, `ops:kg:host`).
#
# Two hops rather than one: a hop-1 doc is the obvious citation, and a hop-2 doc
# is where the interesting disagreement lives — the page that shares a host or a
# skill with the seed without linking to it.
#
# What it does NOT do: search the vault or qmd. qmd is not installed on every
# host (`qmd-docs-index.sh` resolves it, delphi does not carry it), and a
# scaffold that silently skips half its sources is worse than one that says so.
# The task summary names the follow-up query for the operator.
#
# Usage: blog-draft.sh TOPIC [--force]
#   TOPIC    free text; matched against node ids and labels, tokens of 3+ chars
#   --force  overwrite an existing ideas/<slug>.md (default: refuse)
#   KG_GRAPH passthrough (see lib/kg-graph.sh)
#
# Exit: 0 = draft written; 1 = no usable seed or graph unavailable; 2 = usage,
# or the draft already exists.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# shellcheck source=lib/kg-graph.sh
. "$REPO/scripts/task/lib/kg-graph.sh"

usage() { sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

TOPIC=""
FORCE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "blog-draft: unknown option $1" >&2; exit 2 ;;
    *)
      [ -z "$TOPIC" ] || { echo "blog-draft: one topic per draft" >&2; exit 2; }
      TOPIC="$1"
      shift
      ;;
  esac
done
[ -n "$TOPIC" ] || { usage >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "blog-draft: jq required" >&2; exit 2; }

slug="$(
  printf '%s' "$TOPIC" | tr '[:upper:]' '[:lower:]' |
    sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//' | cut -c1-60
)"
[ -n "$slug" ] || { echo "blog-draft: topic '$TOPIC' has no slug-able characters" >&2; exit 2; }

out="$REPO/ideas/${slug}.md"
if [ -e "$out" ] && [ "$FORCE" = 0 ]; then
  echo "blog-draft: ideas/${slug}.md already exists (--force to replace it)" >&2
  exit 2
fi

graph="$(kg_graph_path)" || { echo "blog-draft: no graph" >&2; exit 1; }

# Scoring is deliberately dumb: token overlap on id+label, three seeds at most.
# A ranker smart enough to be wrong quietly would be worse than one an operator
# can predict, and the seeds are visible in the file it writes.
walk="$(
  jq -r --arg topic "$TOPIC" '
    ($topic | ascii_downcase | [splits("[^a-z0-9]+")] | map(select(length > 2))) as $t
    | [.nodes[]
       | . + {score: ([$t[] as $x
                       | select(((.id + " " + (.label // "")) | ascii_downcase | index($x)))] | length)}
      ] as $scored
    | ($scored | map(select(.score > 0)) | sort_by(-.score) | .[0:3] | map(.id)) as $seeds
    | (if ($seeds | length) == 0 then [] else
         [.edges[] | select((.from as $f | $seeds | index($f)) or (.to as $g | $seeds | index($g)))]
       end) as $e1
    | ($e1 | map(.from) + map(.to) | unique) as $n1
    | [.edges[] | select((.from as $f | $n1 | index($f)) or (.to as $g | $n1 | index($g)))] as $e2
    | ($n1 + ($e2 | map(.from)) + ($e2 | map(.to)) | unique) as $all
    | { seeds: $seeds,
        nodes: [.nodes[] | select(.id as $i | $all | index($i)) | {id, type, label, path: (.path // "")}] }
  ' "$graph"
)"

seed_count="$(jq -r '.seeds | length' <<<"$walk")"
if [ "$seed_count" = 0 ]; then
  echo "blog-draft: nothing in the graph matches '$TOPIC'" >&2
  echo "  try: task ops:kg:stats --top 10   # see the nodes with the most edges" >&2
  exit 1
fi

mkdir -p "$REPO/ideas"

# Frontmatter caps: a draft whose `about` names 40 entities has no thesis. Seeds
# first (they are what the topic resolved to), then the documents, then one line
# each for hosts and skills. `awk '!seen'` because a seed is usually also a
# hop-1 neighbour of another seed, and the same doc twice would be two identical
# edges in the graph — a duplicate the gate would rightly refuse to explain.
about="$(
  {
    jq -r '.seeds[]' <<<"$walk"
    jq -r '[.nodes[] | select(.type == "doc")][0:6][] | .id' <<<"$walk"
    jq -r '[.nodes[] | select(.type == "host")][0:3][] | .id' <<<"$walk"
    jq -r '[.nodes[] | select(.type == "skill")][0:3][] | .id' <<<"$walk"
  } | awk '!seen[$0]++'
)"

{
  printf -- '---\n'
  printf 'title: %s\n' "$TOPIC"
  printf 'about:\n'
  printf '%s\n' "$about" | sed 's/^/  - /'
  printf -- '---\n\n'
  printf '## The question\n\n'
  printf '## What the tree already says\n\n'
  jq -r '[.nodes[] | select(.type == "doc")][0:8][] | "- [\(.label)](../\(.path))"' <<<"$walk"
  printf '\n## What I am going to claim\n\n'
  printf '## Where this could be wrong\n\n'
  printf '## Next query\n\n'
  printf '```bash\nqmd search "%s" -c nixconfig\nqmd search "%s" -c vault\n```\n' "$TOPIC" "$TOPIC"
} >"$out"

# Staged, not committed: a flake evaluates the GIT tree, so an untracked draft
# has no node and the promise "a draft is a node the moment it exists" would be
# false until someone remembered to `git add`. Staging is additive and the
# operator still owns the commit.
git -C "$REPO" add -- "$out" 2>/dev/null || true

echo "blog-draft: wrote ${out#"$REPO"/} (staged: the graph reads the git tree)"
echo
sed -n '/^## What the tree already says/,/^## What I am going to claim/p' "$out" | sed '1d;$d' | sed '/^$/d' | sed 's/^/  /'
echo
echo "next: fill the sections, then  task dev:blog:export SLUG=$slug"
