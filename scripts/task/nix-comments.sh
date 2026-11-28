#!/usr/bin/env bash
# nix-comments.sh — resolve every `task <name>` a Nix comment cites.
#
# A comment in a `.nix` file is a pointer, never a second home for the rule. The
# half this script owns is the one Nix cannot answer alone: a task name is a
# recipe, and the recipes are `taskfiles/*.yml`. `lib/nix-comments.nix` classifies
# the line (pointer | rule | dated | header), `flake/nix-comments.nix` records the
# ceilings; this compares them and resolves every pointer against the compiled
# task graph, so a prose line past the ratchet or a task nobody can run fails
# here instead of misleading the next reader.
#
# One reader (`nix eval .#nixComments`), one oracle (the compiled task graph that
# `checks:tasks` proves against go-task), so neither a stale cache nor a
# re-implemented scanner can disagree with the gate.
#
# Usage: nix-comments.sh [--json]
# Exit:  0 clean · 1 a breached ceiling, an unresolved pointer, or a rule line ·
#        2 the census or the oracle failed
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

json=0
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    *) echo "nix-comments: unknown argument $arg" >&2; exit 2 ;;
  esac
done

command -v nix >/dev/null 2>&1 || {
  echo "nix-comments: nix not on PATH; cannot read the census" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  echo "nix-comments: jq not on PATH" >&2
  exit 2
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! nix eval --json ".#nixComments" >"$work/census.json" 2>"$work/eval.err"; then
  echo "nix-comments: the census did not evaluate" >&2
  sed 's/^/  /' "$work/eval.err" >&2
  exit 2
fi

# The recipe book, read through the compiler that owns it (yq is its parser).
# `checks:tasks` proves that compiler's name set equals go-task's live set on
# every run, so this resolves against the same names without spawning a second
# go-task — a check must not race the gate it runs beside.
if ! python3 scripts/task/lib/taskfile_graph.py names 2>"$work/task.err" | sort -u >"$work/names"; then
  echo "nix-comments: the task graph could not be read (yq?)" >&2
  sed 's/^/  /' "$work/task.err" >&2
  exit 2
fi

# A wildcard shard resolves by its static prefix (`find:<word>` -> `find:*`), the
# same rule the contract page uses, so one pointer contract governs both surfaces.
jq -r '.taskCites[] | "\(.name)\t\(.file):\(.line)"' "$work/census.json" >"$work/cites"

unresolved="$work/unresolved"
: >"$unresolved"
while IFS=$'\t' read -r name where; do
  [ -n "$name" ] || continue
  if grep -Fxq -- "$name" "$work/names"; then
    continue
  fi
  prefix="${name%%\**}"
  if [ "$prefix" != "$name" ] && grep -q -- "^${prefix}" "$work/names"; then
    continue
  fi
  # A wildcard in the CITATION is the shard's static prefix; the name set carries
  # it with the star, so try that form before calling it unresolved.
  if grep -q -- "^${name%%:*}:\\*$" "$work/names"; then
    continue
  fi
  # `task checks:host:HOST` documents an invocation; a caps segment is a
  # placeholder, the same exclusion the contract page's `<name>` gets.
  if [[ "${name##*:}" =~ ^[A-Z]+$ ]]; then
    continue
  fi
  printf '%s\t%s\n' "$name" "$where" >>"$unresolved"
done <"$work/cites"

comment_total=$(jq -r '.comments' "$work/census.json")
pointer_total=$(jq -r '.pointers' "$work/census.json")
shadow_total=$(jq -r '.shadow' "$work/census.json")
header_total=$(jq -r '.header' "$work/census.json")
rule_total=$(jq -r '.rules' "$work/census.json")
dated_total=$(jq -r '.dated' "$work/census.json")
task_total=$(jq -r '.taskCites | length' "$work/census.json")
unresolved_total=$(wc -l <"$unresolved" | tr -d ' ')
ceiling=$(jq -r '.ceiling' "$work/census.json")
dated_ceiling=$(jq -r '.datedCeiling' "$work/census.json")
files=$(jq -r '.files' "$work/census.json")
names_total=$(wc -l <"$work/names" | tr -d ' ')

if [ "$json" = 1 ]; then
  out=$(jq -n \
    --argjson files "$files" \
    --argjson comments "$comment_total" \
    --argjson pointers "$pointer_total" \
    --argjson header "$header_total" \
    --argjson rules "$rule_total" \
    --argjson dated "$dated_total" \
    --argjson datedCeiling "$dated_ceiling" \
    --argjson ceiling "$ceiling" \
    --argjson taskCites "$task_total" \
    --argjson recipes "$names_total" \
    --rawfile unresolved "$unresolved" \
    '{
      files: $files,
      comments: $comments,
      pointers: $pointers,
      header: {measured: $header, ceiling: $ceiling, ok: ($header <= $ceiling)},
      dated: {measured: $dated, ceiling: $datedCeiling, ok: ($dated <= $datedCeiling)},
      rules: {measured: $rules, ok: ($rules == 0)},
      taskCites: $taskCites,
      recipes: $recipes,
      unresolved: ($unresolved | split("\n") | map(select(length > 0))),
      ok: ($header <= $ceiling and $dated <= $datedCeiling and $rules == 0
           and ($unresolved | split("\n") | map(select(length > 0)) | length) == 0)
    }')
  printf '%s\n' "$out"
  [ "$(jq -r '.ok' <<<"$out")" = true ] && exit 0
  exit 1
fi

echo "nix comments: ${comment_total} lines in ${files} files — ${pointer_total} pointers, ${shadow_total} shadow, ${header_total}/${ceiling} header, ${dated_total}/${dated_ceiling} dated, ${rule_total} rules"
echo "task pointers: ${task_total} citations of ${names_total} recipes"

# The ratchet is compared HERE, not only in `.githooks/pre-commit`: the hook is
# per-clone and one `--no-verify` skips it, which is how 2ca9a316 landed 18 prose
# lines past the ceiling while this gate printed `6513/6495` and exited 0 — and
# `checks:quick` carried it, so the cheap gate agreed with a tree CI refused.
if [ "$header_total" -gt "$ceiling" ]; then
  echo "== prose over the ceiling: ${header_total} > ${ceiling} — trim $((header_total - ceiling)) lines, or make them pointers; heaviest prose: =="
  jq -r '.headerPerFile | to_entries | sort_by(-.value) | .[:5][] | "  \(.value) lines  \(.key)"' "$work/census.json"
  echo "  A comment earns its place as a path, a task name, a policy id, or an attr."
  echo "  Rule: flake/policies.nix#nix-comments-are-pointers"
  exit 1
fi

if [ "$dated_total" -gt "$dated_ceiling" ]; then
  echo "== dated commentary over its ceiling: ${dated_total} > ${dated_ceiling} — what happened is a turn, not a comment =="
  exit 1
fi

if [ "$unresolved_total" -ne 0 ]; then
  echo "== unresolved task pointers (the recipe book has no such name) =="
  awk -F'\t' '{printf "  %-40s %s\n", $1, $2}' "$unresolved"
  echo "  A comment that names a task nobody can run is a door painted on a wall:"
  echo "  name a real task, or delete the sentence and let the code speak."
  exit 1
fi

echo "== task pointers: every cited recipe resolves =="

if [ "$rule_total" -ne 0 ]; then
  echo "== decorative rule lines (a banner with no text) — delete on sight =="
  jq -r '.ruleLines[] | "  \(.file):\(.line)  \(.body)"' "$work/census.json"
  exit 1
fi

echo "== census: every ceiling holds =="
exit 0
