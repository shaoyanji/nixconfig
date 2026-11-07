#!/usr/bin/env bash
# Measure the knowledge-graph read paths, one column per candidate.
#
# The claim this exists for: "a resident sidecar is worth its rent". That was
# true on 2026-11-02 (28 ms against jq's 441 ms) and stopped being true when the
# graph read became a content-keyed file plus an eval cache: measured 2026-11-07
# the same question answers in 28 ms from a socket and 53 ms from the file, so
# the daemon bought 25 ms for 27 MB of BEAM, a 1383-line engine and a parity
# gate. It is gone. This harness is what makes that re-checkable rather than a
# memory: it times the surface the tasks actually call, and both evaluators.
#
# Usage: kg-speed.sh [NODE]        RUNS=N (default 5, evals at least 2)
# Exit:  0 = measured; 1 = a path failed
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

NODE="${1:-frieren}"
RUNS="${RUNS:-5}"

now() { date +%s%N; }

mean() {
  local label="$1" runs="$2"
  shift 2
  local i start total=0
  for ((i = 0; i < runs; i++)); do
    start="$(now)"
    "$@" >/dev/null 2>&1 || {
      echo "kg-speed: '$label' failed" >&2
      return 1
    }
    total=$((total + ($(now) - start) / 1000000))
  done
  printf '%s' "$((total / runs))"
}

one() {
  local start
  start="$(now)"
  "$@" >/dev/null 2>&1 || {
    echo "fail" >&2
    return 1
  }
  printf '%s' "$((($(now) - start) / 1000000))"
}

# shellcheck source=lib/iets.sh
. scripts/task/lib/iets.sh
IETS="$(resolve_iets "$PWD" || true)"

printf 'graph read: %s   runs: %s\n' "$NODE" "$RUNS"
printf '  query host    %5s ms   kg-query.sh over the graph file + jq\n' \
  "$(mean query "$RUNS" bash scripts/task/kg-query.sh host "$NODE")"
printf '  query stats   %5s ms   the same file, the widest traversal\n' \
  "$(mean stats "$RUNS" bash scripts/task/kg-query.sh stats)"

if [ -n "$IETS" ]; then
  printf '  eval warm     %5s ms   iets eval .#knowledgeGraph.graph (traced cache)\n' \
    "$(mean iets-warm "$RUNS" "$IETS" eval --json .#knowledgeGraph.graph)"
  printf '  eval no-cache %5s ms   the same eval with --no-cache, once\n' \
    "$(one "$IETS" eval --no-cache --json .#knowledgeGraph.graph)"
else
  printf '  eval warm        n/a   iets did not resolve (IETS_BIN, PATH, flake.lock pin)\n'
fi
printf '  eval nix      %5s ms   nix eval, which never answers from a cache, %s run(s)\n' \
  "$(mean nix-eval "$([ "$RUNS" -lt 2 ] && echo 2 || echo "$RUNS")" nix eval --json .#knowledgeGraph.graph)" \
  "$([ "$RUNS" -lt 2 ] && echo 2 || echo "$RUNS")"

# The entry surfaces, i.e. what a turn reads before it knows anything. Every row
# here was late enough once to be worth a cache, and each names the layer that
# moved it, so "the frontier is here" is a number rather than a feeling:
# `task help` was go-task's parse (2.3 s, via the panel's nested --list-all), the
# notes rows were a full 1 MB evaluation per query, and the leaf rows show where
# `nix eval` floors out (~150 ms of flake resolution) against iets.
printf '\nagent entry (three runs each, task startup included)\n'
printf '  task help     %5s ms   intent map + namespaces (taskfile-list.sh cache)\n' \
  "$(mean help 3 task help)"
printf '  find:<word>   %5s ms   over the same cached list\n' \
  "$(mean find 3 task find:graph)"
printf '  notes near    %5s ms   agentsNotes (iets) + jq ranking, the novel-task entry\n' \
  "$(mean near 3 bash scripts/task/notes.sh near "cache the graph read")"
printf '  notes show    %5s ms   one note out of the same cached document\n' \
  "$(mean show 3 bash scripts/task/notes.sh show taskfile-plane-handmade)"
printf '  notes host    %5s ms   byHost index, no ranking\n' \
  "$(mean nhost 3 bash scripts/task/notes.sh host frieren)"
printf '  leaf nix      %5s ms   .#inventory.hosts.fern.role, the nix floor\n' \
  "$(mean leaf-nix 3 nix eval --raw .#inventory.hosts.fern.role)"
printf '  leaf iets     %5s ms   the same leaf through the tracing cache\n' \
  "$(mean leaf-iets 3 bash -c '. scripts/task/lib/iets.sh; iets_eval_json .#inventory.hosts.fern')"
printf '\nRead it as a budget: an entry that is already under ~200 ms is paying\n'
printf 'process startup, not this tree. Re-run after changing a cache layer.\n'
