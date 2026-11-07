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
#        kg-speed.sh --gate       budgets only, no graph rows (checks:entry)
# Exit:  0 = measured / every budget met; 1 = a path failed or a budget missed
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

GATE=0
if [ "${1:-}" = "--gate" ]; then
  GATE=1
  shift
fi
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

# The gate takes the MINIMUM, not the mean: contention only ever adds time, so
# the fastest run is the run least distorted by whatever else the host is doing.
# Budgets are set at ~3x that minimum, which is the honest line: a lost cache
# layer costs 3-10x, a busy host costs tens of percent.
minr() {
  local label="$1" runs="$2"
  shift 2
  local i start d best=""
  for ((i = 0; i < runs; i++)); do
    start="$(now)"
    "$@" >/dev/null 2>&1 || {
      echo "kg-speed: '$label' failed" >&2
      return 1
    }
    d=$((($(now) - start) / 1000000))
    if [ -z "$best" ] || [ "$d" -lt "$best" ]; then best="$d"; fi
  done
  printf '%s' "$best"
}

# shellcheck source=lib/iets.sh
. scripts/task/lib/iets.sh
IETS="$(resolve_iets "$PWD" || true)"

# `--gate`: the entry reads only, min of 3, each row against a budget. This is
# `checks:entry`, and it is a regression gate, not a benchmark: each budget is
# ~2.5-3x the slower of two hosts measured 2026-11-07 (delphi 219/285/167 ms and
# frieren 687/741/336 ms for help/find/show, 211 notes, 616 tasks), because a
# lost layer costs several times and a busy host costs tens of percent. A slower
# host than frieren is not a regression — raise the budget here, in one place.
#
# The two comparisons that are not absolute are the two that matter most: `near`
# is the same eval as `show` plus ranking, so its budget is `show + 300` — the
# removed tokeniser cost 350 ms and would fail this on a host where an absolute
# budget would merely be noisy; and `iets` must be at most half the nix floor,
# because a cache that does not answer faster than `nix eval` is not a cache
# (falling back to nix measured 164 ms against 52).
if [ "${GATE:-0}" = 1 ]; then
  rc=0
  row() {
    local label="$1" value="$2" budget="$3" note="$4" verdict
    if [ "$value" -le "$budget" ]; then verdict=ok; else verdict=MISS; rc=1; fi
    printf '  %-14s %5s ms   budget %4s   %s   %s\n' "$label" "$value" "$budget" "$verdict" "$note"
  }
  fail() {
    printf '  %-14s %5s      budget %4s   %s   %s\n' "$1" n/a "$2" MISS "$3"
    rc=1
  }

  printf 'entry gate: min of 3, task startup included\n'
  t_help="$(minr help 3 task help)" || fail "task help" 1200 "the command did not run"
  t_find="$(minr find 3 task find:graph)" || fail "task find" 1200 "the command did not run"
  t_show="$(minr show 3 bash scripts/task/notes.sh show taskfile-plane-handmade)" || fail "notes show" 800 "the command did not run"
  t_near="$(minr near 3 bash scripts/task/notes.sh near "cache the graph read")" || fail "notes near" 800 "the command did not run"
  t_host="$(minr host 3 bash scripts/task/notes.sh host frieren)" || fail "notes host" 800 "the command did not run"
  t_leaf="$(minr leaf 3 nix eval --raw .#inventory.hosts.fern.role)" || fail "leaf nix" 600 "the command did not run"

  [ -n "${t_help:-}" ] && row "task help" "$t_help" 1200 "intent map + cached namespace list"
  [ -n "${t_find:-}" ] && row "task find" "$t_find" 1200 "substring search over the same cached list"
  [ -n "${t_show:-}" ] && row "notes show" "$t_show" 800 "one note, eval cache + jq"
  if [ -n "${t_near:-}" ] && [ -n "${t_show:-}" ]; then
    row "notes near" "$t_near" "$((t_show + 300))" "ranking on top of the same eval"
  fi
  [ -n "${t_host:-}" ] && row "notes host" "$t_host" 800 "byHost index, no ranking"
  [ -n "${t_leaf:-}" ] && row "leaf nix" "$t_leaf" 600 "flake resolution, the nix floor"

  if [ -n "$IETS" ] && [ -n "${t_leaf:-}" ]; then
    t_iets="$(minr iets 3 bash -c '. scripts/task/lib/iets.sh; iets_eval_json .#inventory.hosts.fern')" \
      || fail "leaf iets" "$((t_leaf / 2))" "the command did not run"
    [ -n "${t_iets:-}" ] && row "leaf iets" "$t_iets" "$((t_leaf / 2))" "half the nix floor, or the cache is not answering"
  else
    printf '  %-14s %5s      budget   --   skip   iets did not resolve; the nix rows still gate\n' "leaf iets" n/a
  fi

  if [ "$rc" = 0 ]; then
    printf 'entry gate: every read is on its layer\n'
  else
    printf 'entry gate: a read left its layer (see docs/nix-patterns.md, "The eval the graph reads")\n' >&2
  fi
  exit "$rc"
fi

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
