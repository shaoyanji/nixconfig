#!/usr/bin/env bash
# ==============================================================================
# scripts/task/kg-sidecar.sh — Reactive Knowledge Graph Sidecar CLI & Runner
# ==============================================================================
# Controls the in-memory Elixir/OTP Knowledge Graph engine (tools/kg-engine).
# Queries go over a UNIX domain socket; the graph itself is resolved through
# scripts/task/lib/kg-graph.sh, the ONE resolver the other kg:* scripts use, so
# the sidecar can never serve a graph the jq surface would disagree with.
#
# Commands:
#   start          Start the daemon and WAIT until it answers (exit 1 if not)
#   stop           Stop the daemon and verify it exited
#   restart        stop, then start
#   status         /stats — node/edge counts, engine, server-side latency
#   node <id>      One-hop in/out neighbourhood (host:frieren, skill:qmd, …)
#   neighbors <id> [depth]   N-hop BFS subgraph (depth capped at 4)
#   blast-radius <id>        Transitive dependents (reverse walk)
#   search <term>  Keyword search over ids/labels (multi-word safe)
#
# Arguments are percent-encoded before they reach the URL. They used to be pasted
# in raw, which lost everything after the first space in two independent places:
# the task layer split the argv, and the engine's request-line parser split on
# spaces as well — a multi-word search answered a different question with exit 0.
#
# Env: KG_SOCKET   socket path (default $XDG_RUNTIME_DIR/kg.sock)
#      KG_GRAPH    graph JSON to load (skips evaluation; same as the jq surface)
#      KG_ELIXIR   elixir binary; default: $PATH, else the store path if already
#                  present. Never builds — an absent interpreter is an error, not
#                  a compiler job (ops tasks must not spend build budget).
#
# Exit: 0 = answered (including an empty answer); 1 = sidecar/graph unavailable;
#       2 = usage. Errors from the engine carry a real HTTP status (400/404), so
#       `curl --fail` and any HTTP client can tell a typo from an empty answer.
# ==============================================================================
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
SOCKET="${KG_SOCKET:-${RUNTIME_DIR}/kg.sock}"
PIDFILE="${RUNTIME_DIR}/kg-engine.pid"
LOG="${RUNTIME_DIR}/kg-engine.log"
ENGINE_SCRIPT="${REPO}/tools/kg-engine/kg_engine.exs"

cmd="${1:-status}"
[ "$#" -gt 0 ] && shift || true

. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"

say() { printf 'kg-sidecar: %s\n' "$*" >&2; }

is_alive() {
  [ -S "$SOCKET" ] && curl -s -m 2 --unix-socket "$SOCKET" http://localhost/stats >/dev/null 2>&1
}

# Percent-encoding belongs here, once. `jq -rn --arg` is already a dependency of
# every other kg script, so this adds no new tool.
enc() { jq -rn --arg s "$1" '$s | @uri'; }

resolve_elixir() {
  if [ -n "${KG_ELIXIR:-}" ]; then
    printf '%s' "$KG_ELIXIR"
    return 0
  fi
  if command -v elixir >/dev/null 2>&1; then
    command -v elixir
    return 0
  fi
  # --offline: fail fast instead of fetching; --builders "": never dispatch to a
  # remote builder. A missing interpreter is reported, not compiled. `nix build
  # --print-out-paths` prints the STORE DIRECTORY, so the binary is /bin/elixir
  # inside it — handing the directory to `setsid nohup` fails with EACCES.
  local out
  out="$(nix build --no-link --offline --builders "" --print-out-paths nixpkgs#beamPackages.elixir 2>/dev/null | head -1)"
  [ -n "$out" ] && printf '%s' "$out/bin/elixir"
  return 0
}

wait_ready() {
  local i
  for i in {1..75}; do
    is_alive && return 0
    sleep 0.2
  done
  return 1
}

start_daemon() {
  if is_alive; then
    say "already running at unix:$SOCKET"
    return 0
  fi

  local elixir_bin graph
  elixir_bin="$(resolve_elixir)" || true
  if [ -z "$elixir_bin" ] || [ ! -x "$elixir_bin" ]; then
    say "no Elixir interpreter available offline (set KG_ELIXIR=/path/to/elixir)."
    say "Refusing to build one from a read path."
    return 1
  fi
  # Graph source: KG_GRAPH when the caller named one, otherwise the engine's
  # NATIVE builder. It used to resolve the graph through lib/kg-graph.sh, which
  # shells to `nix eval` (1-3 s) before the socket even exists — half of boot,
  # and repeated on every file change. The native builder reads the same files
  # in tens of milliseconds; checks:kg:sidecar proves it matches the projection.
  local graph_args=() graph_desc
  if [ -n "${KG_GRAPH:-}" ]; then
    graph_args=(--file "$KG_GRAPH")
    graph_desc="file $KG_GRAPH"
  else
    graph_args=(--native)
    graph_desc="native (no nix)"
  fi

  rm -f "$SOCKET" "$PIDFILE"
  say "launching engine on unix:$SOCKET (graph: $graph_desc)"
  setsid nohup "$elixir_bin" --erl "-noinput" "$ENGINE_SCRIPT" \
    --socket "$SOCKET" \
    "${graph_args[@]}" \
    --repo "$REPO" </dev/null >"$LOG" 2>&1 &
  echo "$!" >"$PIDFILE"

  if wait_ready; then
    say "ready (pid $(cat "$PIDFILE"))"
    return 0
  fi
  say "failed to become ready within 15s — last log lines:"
  tail -5 "$LOG" >&2 || true
  return 1
}

ensure_running() {
  is_alive && return 0
  say "not running; starting"
  start_daemon
}

stop_daemon() {
  local pid i
  if [ -f "$PIDFILE" ]; then
    pid="$(cat "$PIDFILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      for i in {1..25}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
      done
      if kill -0 "$pid" 2>/dev/null; then
        say "pid $pid did not exit; escalating"
        kill -9 "$pid" 2>/dev/null || true
        sleep 0.5
      fi
    fi
    rm -f "$PIDFILE"
  fi
  rm -f "$SOCKET"
  say "stopped"
}

# fetch <path-with-query> — the request goes through one place so encoding and
# the HTTP status contract cannot diverge between subcommands.
fetch() {
  local url="$1" body status
  body="$(mktemp)"
  status="$(curl -sS -m 60 --unix-socket "$SOCKET" -o "$body" -w '%{http_code}' "http://localhost${url}")" || {
    rm -f "$body"
    say "request failed: $url"
    return 1
  }
  if [ "$status" != "200" ]; then
    say "HTTP $status from $url"
    cat "$body" >&2
    echo >&2
    rm -f "$body"
    return 1
  fi
  jq . <"$body"
  rm -f "$body"
}

need_arg() {
  [ "$#" -gt 0 ] && [ -n "$1" ] || {
    say "usage: kg-sidecar.sh $cmd <id>"
    exit 2
  }
}

case "$cmd" in
  start) ensure_running ;;
  stop) stop_daemon ;;
  restart)
    stop_daemon
    start_daemon
    ;;

  status)
    ensure_running
    fetch "/stats"
    ;;

  node)
    need_arg "${1:-}"
    ensure_running
    fetch "/node?id=$(enc "$1")"
    ;;

  neighbors)
    need_arg "${1:-}"
    ensure_running
    fetch "/neighbors?id=$(enc "$1")&depth=$(enc "${2:-1}")"
    ;;

  blast-radius | blast)
    need_arg "${1:-}"
    ensure_running
    fetch "/blast-radius?id=$(enc "$1")"
    ;;

  search | query)
    need_arg "${1:-}"
    # A term is allowed to be a sentence; join the remaining words rather than
    # silently dropping them (`search nix eval` used to become `search nix`).
    term="$1"
    shift
    for w in "$@"; do term="$term $w"; done
    ensure_running
    fetch "/query?q=$(enc "$term")"
    ;;

  *)
    kg_usage "${BASH_SOURCE[0]}" >&2
    exit 2
    ;;
esac
