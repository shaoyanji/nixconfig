#!/usr/bin/env bash
# taskfile-graph.sh — the task graph gate: Nix compiles it, go-task confirms it.
#
# Two halves, because each can only prove one thing:
#   * lib/taskfile.nix compiles Taskfile.yml + the include graph into data and
#     asserts the rules a YAML reader cannot (duplicate keys, dangling refs,
#     wildcard arity, include cycles). Pure nix, no `task` needed.
#   * go-task itself is the oracle for the parse: `task --list-all --json` is
#     what an agent/MCP client actually sees, so any name-set drift means the
#     line grammar in lib/taskfile.nix has stopped describing the tree.
#
# A gate that only ran one half would pass on a broken tree: Nix alone cannot
# know go-task's real name set, and `task` alone cannot report a duplicate key
# it silently discarded.
#
# Usage: taskfile-graph.sh [--json] [--artifact]
# Env:   ARTIFACT=1 also build the minted artifact (."$system".taskfile-graph +
#        its selftest); OFFLOAD=1 hands that build to /etc/nix/machines and
#        builds nothing here; STRICT=1 refuses to build at all ("is it cached?").
# Exit:  0 clean · 1 hard violation or name drift · 2 the graph could not be read
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

json=0
artifact=${ARTIFACT:-0}
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    --artifact) artifact=1 ;;
    *) echo "taskfile-graph: unknown argument $arg" >&2; exit 2 ;;
  esac
done

# Same three routing modes as `checks:host`, for the same reason: the default
# must never be able to spend build budget, and the other two are deliberate.
build_flags=(--builders "")
if [ "${OFFLOAD:-0}" = "1" ]; then
  build_flags=(--max-jobs 0)
elif [ "${STRICT:-0}" = "1" ]; then
  build_flags=(--max-jobs 0 --builders "")
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "taskfile-graph: nix not on PATH; cannot compile the graph" >&2
  exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# One evaluation, one round-trip: asking for four attributes separately would
# pay the flake startup four times. stderr is kept OUT of the capture — the
# "Git tree has uncommitted changes" warning is not JSON and used to break jq.
if ! report=$(
  nix eval --json .#taskfileGraph \
    --apply 't: {inherit (t) names files version proseVersion violations gateFailures gateBuckets;}' 2>"$work/nix.err"
); then
  echo "taskfile-graph: nix eval failed" >&2
  cat "$work/nix.err" >&2
  exit 2
fi

version=$(printf '%s' "$report" | jq -r '.version')
prose=$(printf '%s' "$report" | jq -r '.proseVersion')
nix_count=$(printf '%s' "$report" | jq -r '.names | length')
gate=$(printf '%s' "$report" | jq -r '.gateFailures | length')
files=$(printf '%s' "$report" | jq -r '.files | length')

printf '%s' "$report" | jq -r '.names[]' | sort >"$work/nix"
drift=0
task_count=0
if command -v task >/dev/null 2>&1; then
  task --list-all --json 2>/dev/null | jq -r '.tasks[].name' | sort >"$work/task" || true
  task_count=$(wc -l <"$work/task" | tr -d ' ')
  comm -23 "$work/nix" "$work/task" >"$work/only-nix"
  comm -13 "$work/nix" "$work/task" >"$work/only-task"
  drift=$(( $(wc -l <"$work/only-nix") + $(wc -l <"$work/only-task") ))
fi

if [ "$json" = 1 ]; then
  jq -n \
    --arg version "$version" \
    --arg prose "$prose" \
    --argjson nixTasks "$nix_count" \
    --argjson taskTasks "$task_count" \
    --argjson files "$files" \
    --argjson report "$report" \
    --rawfile nixOnly "$work/only-nix" \
    --rawfile taskOnly "$work/only-task" \
    '{
      version: $version,
      proseVersion: $prose,
      tasks: {nix: $nixTasks, goTask: $taskTasks, files: $files},
      drift: {
        onlyInNix: ($nixOnly | split("\n") | map(select(length > 0))),
        onlyInGoTask: ($taskOnly | split("\n") | map(select(length > 0)))
      },
      hard: {buckets: $report.gateBuckets, failures: $report.gateFailures},
      advisory: ($report.violations | delpaths([$report.gateBuckets[] | [.]])),
      ok: (($report.gateFailures | length) == 0 and (($nixOnly | split("\n") | map(select(length > 0)) | length) + ($taskOnly | split("\n") | map(select(length > 0)) | length) == 0))
    }'
  if [ "$artifact" = "1" ]; then
    echo "--artifact is ignored with --json; ask for one or the other" >&2
  fi
  [ "$gate" -eq 0 ] && [ "$drift" -eq 0 ] && exit 0 || exit 1
fi

if [ "$artifact" = "1" ]; then
  system=$(nix eval --impure --raw --expr builtins.currentSystem 2>/dev/null) || {
    echo "taskfile-graph: cannot resolve the current system" >&2
    exit 2
  }
  echo "== artifact (${build_flags[*]})"
  if ! paths=$(nix build --no-link --print-out-paths -L "${build_flags[@]}" \
    ".?submodules=1#checks.${system}.taskfile-graph" ".?submodules=1#checks.${system}.taskfile-graph-selftest"); then
    echo "taskfile-graph: the artifact did not build" >&2
    exit 2
  fi
  # The path IS the agreement: an input-addressed derivation yields the same
  # store path whether CI, this host or the builder produced it, so printing it
  # (plus the digest and the JSON hash) is how two runs prove they agree.
  # `*-taskfile-graph-selftest` first: it also matches the graph pattern below,
  # and a self-test reported as "the artifact" would be reported as a version.
  while IFS= read -r p; do
    case "$(basename "$p")" in
      *-taskfile-graph-selftest)
        echo "  selftest: $p" ;;
      *-taskfile-graph-*)
        echo "  path:    $p"
        echo "  version: $(cat "$p/version")"
        echo "  prose:   $(cat "$p/prose")"
        echo "  sha256:  $(sha256sum "$p/graph.json" | cut -d' ' -f1)" ;;
      *)
        echo "  other:   $p" ;;
    esac
  done <<<"$paths"
fi

echo "task graph ${version} (prose ${prose}): ${nix_count} tasks in ${files} files (go-task sees ${task_count})"

if [ "$drift" -ne 0 ]; then
  echo "== name drift (lib/taskfile.nix no longer describes the tree) =="
  sed 's/^/  only in nix:      /' "$work/only-nix"
  sed 's/^/  only in go-task:  /' "$work/only-task"
  echo "  The line grammar in lib/taskfile.nix must be taught the shape, not"
  echo "  bypassed: a name only Nix sees is parsed garbage, a name only go-task"
  echo "  sees is a task the graph is missing."
else
  echo "== name parity: exact =="
fi

if [ "$gate" -ne 0 ]; then
  echo "== hard violations =="
  printf '%s' "$report" | jq -r '.gateFailures[]' | sed 's/^/  /'
else
  echo "== hard violations: none =="
fi

printf '%s' "$report" | jq -r '
  .violations as $v
  | [["longSummary", ($v.longSummary | length)],
     ["longDesc", ($v.longDesc | length)],
     ["noDesc", ($v.noDesc | length)],
     ["nameGrammar", ($v.nameGrammar | length)],
     ["proseRef", ($v.proseRef | length)]]
  | map(select(.[1] > 0))
  | if length == 0 then empty
    else "== advisory (reported, never fatal) ==",
         (.[] | "  \(.[1])\t\(.[0])")
    end'

[ "$gate" -eq 0 ] && [ "$drift" -eq 0 ] && exit 0 || exit 1
