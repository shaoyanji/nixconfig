#!/usr/bin/env bash
# bench.sh — build and measure the three read-path prototypes on ONE box.
#
# Read path only: static bytes, one history frame per connection, and a fan-out
# of new turns to every open stream. The prompt API is host-bound work (one
# hermes process per request) and identical in all three, so it is out of scope.
#
# What it reports, in the order the question was asked — build and deploy
# ergonomics first, then what holding streams costs:
#
#   cold build   clean toolchain caches; includes fetching dependencies
#   warm build   touch the main source, rebuild
#   artifact     bytes to ship (an Elixir release carries the ERTS)
#   cold start   spawn → first 200 on /healthz
#   idle RSS     after start, no clients
#   RSS @N       with N SSE readers connected
#   p50/p99      publish → reader, over N streams
#
# Run inside tools/turns-runtime's devShell, from the repository root:
#   bash tools/turns-runtime/bench.sh
# Env: CLIENTS=1000 LOAD_SECONDS=20
set -uo pipefail

HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
SITE="$ROOT/modules/services/turns-dashboard/web"
FIXTURE="$HERE/fixture/turns.json"
WORK=${WORK:-/tmp/turns-runtime-bench}
CLIENTS=${CLIENTS:-1000}
LOAD_SECONDS=${LOAD_SECONDS:-20}

mkdir -p "$WORK"
rm -f "$WORK/results.jsonl"

now_ms() { date +%s%3N; }
rss_kb() {
  local pid=$1
  {
    ps -o rss= -p "$pid" 2>/dev/null
    ps -o rss= --ppid "$pid" 2>/dev/null
  } | awk '{s += $1} END {print s + 0}'
}
say() { printf '\n== %s\n' "$*"; }

# Wait for /healthz, returning the milliseconds from $1 (a start stamp).
wait_up() {
  local port=$1 started=$2 i
  for i in $(seq 1 600); do
    if curl -sf -o /dev/null --max-time 1 "http://127.0.0.1:$port/healthz" 2>/dev/null; then
      echo $(( $(now_ms) - started ))
      return 0
    fi
    sleep 0.05
  done
  echo 0
  return 1
}

# One server's whole measurement. $1 = name, $2 = port, $3 = start command,
# $4 = artifact path (file or dir), $5 = process pattern for cleanup.
measure() {
  local name=$1 port=$2 cmd=$3 artifact=$4 pattern=$5
  local started pid up idle under load

  started=$(now_ms)
  eval "$cmd" >"$WORK/$name.server.log" 2>&1 &
  pid=$!
  up=$(wait_up "$port" "$started") || {
    echo "{\"runtime\":\"$name\",\"error\":\"never answered on $port\"}" >>"$WORK/results.jsonl"
    tail -5 "$WORK/$name.server.log" >&2
    kill "$pid" 2>/dev/null
    return
  }
  sleep 2
  idle=$(rss_kb "$pid")

  python3 "$HERE/load.py" --port "$port" --clients "$CLIENTS" --seconds "$LOAD_SECONDS" \
    >"$WORK/$name.load.json" 2>"$WORK/$name.load.err" &
  load=$!
  sleep 6
  under=$(rss_kb "$pid")
  wait "$load" 2>/dev/null
  load=$(cat "$WORK/$name.load.json" 2>/dev/null || echo '{}')

  kill "$pid" 2>/dev/null
  sleep 1
  pkill -f "$pattern" 2>/dev/null

  local size
  if [ -d "$artifact" ]; then
    size=$(du -sb "$artifact" | awk '{print $1}')
  elif [ -f "$artifact" ]; then
    size=$(stat -c %s "$artifact")
  else
    size=0
  fi

  jq -nc \
    --arg runtime "$name" \
    --argjson cold "$COLD_MS" --argjson warm "$WARM_MS" \
    --argjson size "$size" --argjson up "$up" \
    --argjson idle "$idle" --argjson under "$under" \
    --argjson load "$load" \
    '{runtime: $runtime, cold_build_ms: $cold, warm_build_ms: $warm, artifact_bytes: $size,
      cold_start_ms: $up, idle_rss_kb: $idle, load_rss_kb: $under} + $load' >>"$WORK/results.jsonl"
  say "$name: cold ${COLD_MS}ms warm ${WARM_MS}ms artifact ${size}B start ${up}ms idle ${idle}kB @${CLIENTS} ${under}kB"
}

# --- Go ---------------------------------------------------------------------
say "go"
cd "$ROOT/tools/turns-runtime/go" || exit 1
go clean -cache >/dev/null 2>&1
t0=$(now_ms); CGO_ENABLED=0 go build -o "$WORK/turns-go" ./main.go >"$WORK/go.build.log" 2>&1; COLD_MS=$(( $(now_ms) - t0 ))
touch main.go
t0=$(now_ms); CGO_ENABLED=0 go build -o "$WORK/turns-go" ./main.go >/dev/null 2>&1; WARM_MS=$(( $(now_ms) - t0 ))
measure go 9100 "cd '$ROOT' && '$WORK/turns-go' -addr 127.0.0.1:9100 -site '$SITE' -fixture '$FIXTURE'" "$WORK/turns-go" turns-go

# --- Rust -------------------------------------------------------------------
say "rust"
cd "$ROOT/tools/turns-runtime/rust" || exit 1
rm -rf target
t0=$(now_ms)
cargo build --release --quiet >"$WORK/rust.build.log" 2>&1
built=$(( $(now_ms) - t0 ))
if [ -x target/release/turns-bench ]; then
  COLD_MS=$built
  touch src/main.rs
  t0=$(now_ms); cargo build --release --quiet >/dev/null 2>&1; WARM_MS=$(( $(now_ms) - t0 ))
  measure rust 9101 "cd '$ROOT' && '$ROOT/tools/turns-runtime/rust/target/release/turns-bench' -addr 127.0.0.1:9101 -site '$SITE' -fixture '$FIXTURE'" "$ROOT/tools/turns-runtime/rust/target/release/turns-bench" turns-bench
else
  echo "rust: build failed" >&2
  tail -20 "$WORK/rust.build.log" >&2
  jq -nc --arg runtime rust --arg err "build failed" '{runtime: $runtime, error: $err}' >>"$WORK/results.jsonl"
fi

# --- Elixir -----------------------------------------------------------------
say "elixir"
cd "$ROOT/tools/turns-runtime/elixir" || exit 1
rm -rf _build deps
t0=$(now_ms)
{
  mix local.hex --force >/dev/null 2>&1
  mix local.rebar --force >/dev/null 2>&1
  mix deps.get >/dev/null 2>&1
  MIX_ENV=prod mix release --overwrite >/dev/null 2>&1
} >"$WORK/elixir.build.log" 2>&1
built=$(( $(now_ms) - t0 ))
rel="$ROOT/tools/turns-runtime/elixir/_build/prod/rel/turns_bench"
if [ -x "$rel/bin/turns_bench" ]; then
  COLD_MS=$built
  touch lib/turns_bench/router.ex
  t0=$(now_ms); MIX_ENV=prod mix release --overwrite >/dev/null 2>&1; WARM_MS=$(( $(now_ms) - t0 ))
  measure elixir 9102 "cd '$ROOT' && PORT=9102 SITE='$SITE' FIXTURE='$FIXTURE' '$rel/bin/turns_bench' start" "$rel" turns_bench
else
  echo "elixir: build failed" >&2
  tail -25 "$WORK/elixir.build.log" >&2
  jq -nc --arg runtime elixir --arg err "build failed" '{runtime: $runtime, error: $err}' >>"$WORK/results.jsonl"
fi

# --- report -----------------------------------------------------------------
say "results"
jq -s '.' "$WORK/results.jsonl" >"$WORK/results.json"
cat "$WORK/results.json"

printf '\n%-8s %10s %10s %12s %10s %10s %12s %8s %8s\n' \
  runtime cold_ms warm_ms artifact_B start_ms idle_kB load_kB p50 p99
jq -r '.[] | select(.error | not) |
  [.runtime, .cold_build_ms, .warm_build_ms, .artifact_bytes, .cold_start_ms,
   .idle_rss_kb, .load_rss_kb, .p50_ms, .p99_ms] | @tsv' "$WORK/results.json" |
  while IFS=$'\t' read -r a b c d e f g h i; do
    printf '%-8s %10s %10s %12s %10s %10s %12s %8s %8s\n' "$a" "$b" "$c" "$d" "$e" "$f" "$g" "$h" "$i"
  done

# Third-party crates/packages each one needs to fetch and pin.
printf '\ndependencies: go=0 (stdlib) rust=%s (Cargo.lock) elixir=%s (mix.exs)\n' \
  "$(grep -c '^name = ' "$ROOT/tools/turns-runtime/rust/Cargo.lock" 2>/dev/null || echo 0)" \
  "$(grep -c '^[[:space:]]*{:[a-z_]*, "' "$ROOT/tools/turns-runtime/elixir/mix.exs" 2>/dev/null || echo 0)"
