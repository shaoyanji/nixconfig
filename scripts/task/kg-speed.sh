#!/usr/bin/env bash
# Measure one graph question on both traversal paths.
#
# The claim this exists for: "the sidecar is faster than the jq surface". That
# is true only while the socket is live, and only for repeated questions; a
# number without a harness is a claim nobody can check. This runs the same
# query N times each way through kg-query.sh (the exact surface the tasks call)
# and prints the mean wall time, so the doc can cite a command instead of a
# memory.
#
# Usage: kg-speed.sh [NODE]        RUNS=N to change the sample (default 5)
# Exit:  0 = measured; 1 = kg-query failed
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

NODE="${1:-frieren}"
RUNS="${RUNS:-5}"
SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kg.sock"

run_path() {
  local mode="$1" i start end total=0
  for ((i = 0; i < RUNS; i++)); do
    start=$(date +%s%N)
    if [ "$mode" = "jq" ]; then
      KG_NO_SIDECAR=1 bash scripts/task/kg-query.sh host "$NODE" >/dev/null
    else
      bash scripts/task/kg-query.sh host "$NODE" >/dev/null
    fi
    end=$(date +%s%N)
    total=$((total + (end - start) / 1000000))
  done
  echo $((total / RUNS))
}

if [ ! -S "$SOCKET" ]; then
  echo "sidecar socket not live ($SOCKET): both columns will be the jq path." >&2
  echo "start it with: task ops:kg:sidecar start" >&2
fi

sidecar_ms=$(run_path sidecar)
jq_ms=$(run_path jq)

echo "query: host $NODE   runs: $RUNS"
printf '  sidecar %4s ms\n' "$sidecar_ms"
printf '  jq      %4s ms\n' "$jq_ms"
if [ "$sidecar_ms" -gt 0 ] && [ "$sidecar_ms" -lt "$jq_ms" ]; then
  printf '  ratio   %4sx faster\n' "$((jq_ms / sidecar_ms))"
fi
