#!/usr/bin/env bash
# taskfile-graph.sh — the task graph gate: yq compiles it, go-task confirms it.
#
# Two halves, because each can only prove one thing:
#   * scripts/task/lib/taskfile_graph.py compiles Taskfile.yml + the include graph
#     into data and asserts the rules a YAML reader cannot (duplicate keys,
#     dangling refs, wildcard arity, include cycles, exit-code drift). yq is the
#     parser; the rules are the script.
#   * go-task itself is the oracle for the parse: `task --list-all --json` is what
#     an agent/MCP client actually sees, so any name-set drift means the compiler
#     has stopped describing the tree.
#
# A gate that only ran one half would pass on a broken tree: yq alone cannot know
# go-task's real name set, and `task` alone cannot report a duplicate key it
# silently discarded.
#
# The fixture (tests/taskfile-graph) violates every bucket once, with its expected
# verdicts in expected.json: a bucket that has only ever been run against a clean
# tree is a bucket nobody knows the shape of.
#
# Usage: taskfile-graph.sh [--json]
# Exit:  0 clean · 1 hard violation or name drift · 2 the graph could not be read
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

json=0
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    *) echo "taskfile-graph: unknown argument $arg" >&2; exit 2 ;;
  esac
done

command -v yq >/dev/null 2>&1 || {
  echo "taskfile-graph: yq not on PATH; cannot parse the shards" >&2
  exit 2
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

compile() { python3 scripts/task/lib/taskfile_graph.py "$@"; }

if ! report=$(compile report 2>"$work/compile.err"); then
  echo "taskfile-graph: the graph could not be read" >&2
  cat "$work/compile.err" >&2
  exit 2
fi
printf '%s' "$report" >"$work/report.json"

count=$(jq -r '.count' "$work/report.json")
gate=$(jq -r '.gateFailures | length' "$work/report.json")
files=$(jq -r '.files | length' "$work/report.json")

# --- the fixture: every bucket fires exactly where expected --------------------
fixture_fail=0
if ! fixture=$(compile report --root tests/taskfile-graph 2>"$work/fixture.err"); then
  echo "taskfile-graph: the fixture graph could not be read" >&2
  cat "$work/fixture.err" >&2
  exit 2
fi
printf '%s' "$fixture" >"$work/fixture.json"
if ! mismatch=$(
  jq -n --slurpfile got "$work/fixture.json" --slurpfile want tests/taskfile-graph/expected.json '
    ($got[0].violations) as $v
    | [ ($want[0] | keys[]) as $k
        | select((($v[$k] // []) | sort) != ($want[0][$k] | sort))
        | {bucket: $k, expected: $want[0][$k], actual: ($v[$k] // [])} ]
    | .[]'
); then
  echo "taskfile-graph: cannot compare the fixture verdicts" >&2
  exit 2
fi
if [ -n "${mismatch//[$'\n\t ']/}" ]; then
  fixture_fail=1
fi

# --- the contract page cites only tasks the graph has -------------------------
cite_fail=0
cite_report=""
if ! cite_report=$(compile citations 2>"$work/cite.err"); then
  cite_fail=1
fi

# --- the oracle: go-task's own name set ---------------------------------------
jq -r '.names[]' "$work/report.json" | sort >"$work/nix"
drift=0
task_count=0
if command -v task >/dev/null 2>&1; then
  # --refresh: the oracle is the LIVE name set, and this run is also what rewrites
  # the cache `task help` / `task find:` read (taskfile-list.sh), so a stale list
  # cannot survive a push.
  bash scripts/task/taskfile-list.sh --refresh 2>/dev/null | jq -r '.tasks[].name' | sort >"$work/task" || true
  task_count=$(wc -l <"$work/task" | tr -d ' ')
  comm -23 "$work/nix" "$work/task" >"$work/only-nix"
  comm -13 "$work/nix" "$work/task" >"$work/only-task"
  drift=$(($(wc -l <"$work/only-nix") + $(wc -l <"$work/only-task")))
fi

if [ "$json" = 1 ]; then
  jq -n \
    --argjson report "$report" \
    --argjson count "$count" \
    --argjson taskTasks "$task_count" \
    --argjson files "$files" \
    --rawfile nixOnly "$work/only-nix" \
    --rawfile taskOnly "$work/only-task" \
    --argjson fixtureFail "$fixture_fail" \
    --argjson citeFail "$cite_fail" \
    --arg citations "$cite_report" \
    '{
      tasks: {compiled: $count, goTask: $taskTasks, files: $files},
      drift: {
        onlyCompiled: ($nixOnly | split("\n") | map(select(length > 0))),
        onlyInGoTask: ($taskOnly | split("\n") | map(select(length > 0)))
      },
      hard: {buckets: $report.gateBuckets, failures: $report.gateFailures},
      advisory: ($report.violations | delpaths([$report.gateBuckets[] | [.]])),
      fixture: {ok: ($fixtureFail == 0)},
      citations: {ok: ($citeFail == 0), report: $citations},
      ok: (($report.gateFailures | length) == 0
           and ($fixtureFail == 0)
           and ($citeFail == 0)
           and (($nixOnly | split("\n") | map(select(length > 0)) | length)
                + ($taskOnly | split("\n") | map(select(length > 0)) | length) == 0))
    }'
  [ "$gate" -eq 0 ] && [ "$drift" -eq 0 ] && [ "$fixture_fail" -eq 0 ] && [ "$cite_fail" -eq 0 ] && exit 0 || exit 1
fi

echo "task graph: ${count} tasks in ${files} files (go-task sees ${task_count})"

if [ "$fixture_fail" -ne 0 ]; then
  echo "== fixture (tests/taskfile-graph violates every bucket once) =="
  printf '%s' "$mismatch" | jq -r '"  \(.bucket)\n    expected: \(.expected | tojson)\n    actual:   \(.actual | tojson)"'
  echo "  Fix the detector, or update tests/taskfile-graph/expected.json with the new shape."
else
  echo "== fixture: every bucket fires where expected =="
fi

if [ "$cite_fail" -ne 0 ]; then
  echo "== contract page =="
  echo "  $cite_report"
  echo "  A citation nobody can run makes the door look closed: name a real task,"
  echo "  or a wildcard shard whose prefix matches."
else
  echo "== contract page: every 'task <name>' citation resolves =="
fi

if [ "$drift" -ne 0 ]; then
  echo "== name drift (the compiler no longer describes the tree) =="
  sed 's/^/  only compiled:  /' "$work/only-nix"
  sed 's/^/  only go-task:   /' "$work/only-task"
  echo "  A name only the compiler sees is parsed garbage; a name only go-task sees"
  echo "  is a task the graph is missing."
else
  echo "== name parity: exact =="
fi

if [ "$gate" -ne 0 ]; then
  echo "== hard violations =="
  jq -r '.gateFailures[]' "$work/report.json" | sed 's/^/  /'
else
  echo "== hard violations: none =="
fi

jq -r '
  .violations as $v
  | [["longSummary", ($v.longSummary | length)],
     ["longDesc", ($v.longDesc | length)],
     ["nameGrammar", ($v.nameGrammar | length)],
     ["proseRef", ($v.proseRef | length)]]
  | map(select(.[1] > 0))
  | if length == 0 then empty
    else "== advisory (reported, never fatal) ==",
         (.[] | "  \(.[1])\t\(.[0])")
    end' "$work/report.json"

[ "$gate" -eq 0 ] && [ "$drift" -eq 0 ] && [ "$fixture_fail" -eq 0 ] && [ "$cite_fail" -eq 0 ] && exit 0 || exit 1
