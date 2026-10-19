#!/usr/bin/env bash
# ==============================================================================
# scripts/task/kg-sidecar.sh — Reactive Knowledge Graph Sidecar CLI & Runner
# ==============================================================================
# Controls the in-memory Elixir/OTP Knowledge Graph engine.
# Provides sub-millisecond graph queries over UNIX domain socket (AF_UNIX).
#
# Commands:
#   start          Start the sidecar daemon in the background
#   stop           Stop the running sidecar daemon
#   restart        Restart the sidecar daemon
#   status         Probe /stats endpoint and report memory/node metrics
#   node <id>      Get 1-hop connections for an entity (host:frieren, skill:...)
#   neighbors <id> [depth]  Get N-hop BFS subgraph
#   blast-radius <id>       Get transitive dependents and impact analysis
#   search <term>  Search entities by keyword
# ==============================================================================
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
SOCKET="${KG_SOCKET:-${RUNTIME_DIR}/kg.sock}"
PIDFILE="${RUNTIME_DIR}/kg-engine.pid"
ENGINE_SCRIPT="${REPO}/tools/kg-engine/kg_engine.exs"

cmd="${1:-status}"
[ "$#" -gt 0 ] && shift || true

is_alive() {
  [ -S "$SOCKET" ] && curl -s --unix-socket "$SOCKET" http://localhost/stats >/dev/null 2>&1
}

ensure_running() {
  if ! is_alive; then
    echo "kg-sidecar: sidecar not responding at $SOCKET. Starting daemon..." >&2
    start_daemon
    for _ in {1..50}; do
      if is_alive; then break; fi
      sleep 0.2
    done
    if ! is_alive; then
      echo "kg-sidecar: failed to start sidecar within 10 seconds" >&2
      exit 1
    fi
  fi
}

start_daemon() {
  if is_alive; then
    echo "kg-sidecar: already running at unix:$SOCKET"
    return 0
  fi

  rm -f "$SOCKET" "$PIDFILE"
  echo "kg-sidecar: launching Elixir/OTP engine on unix:$SOCKET..."

  setsid nohup nix shell nixpkgs#beamPackages.elixir -c elixir --erl "-noinput" "$ENGINE_SCRIPT" \
    --socket "$SOCKET" \
    --repo "$REPO" < /dev/null > "${RUNTIME_DIR}/kg-engine.log" 2>&1 &

  local pid=$!
  echo "$pid" > "$PIDFILE"
  echo "kg-sidecar: spawned PID $pid (logs: ${RUNTIME_DIR}/kg-engine.log)"
}

stop_daemon() {
  if [ -f "$PIDFILE" ]; then
    local pid
    pid="$(cat "$PIDFILE")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "kg-sidecar: stopping PID $pid..."
      kill "$pid" || true
    fi
    rm -f "$PIDFILE"
  fi
  rm -f "$SOCKET"
  echo "kg-sidecar: stopped."
}

case "$cmd" in
  start)
    start_daemon
    ;;

  stop)
    stop_daemon
    ;;

  restart)
    stop_daemon
    sleep 0.5
    start_daemon
    ;;

  status)
    ensure_running
    curl -s --unix-socket "$SOCKET" http://localhost/stats | jq .
    ;;

  node)
    [ "$#" -gt 0 ] || { echo "Usage: kg-sidecar.sh node <id>" >&2; exit 2; }
    ensure_running
    curl -s --unix-socket "$SOCKET" "http://localhost/node?id=$1" | jq .
    ;;

  neighbors)
    [ "$#" -gt 0 ] || { echo "Usage: kg-sidecar.sh neighbors <id> [depth]" >&2; exit 2; }
    local_id="$1"
    depth="${2:-1}"
    ensure_running
    curl -s --unix-socket "$SOCKET" "http://localhost/neighbors?id=${local_id}&depth=${depth}" | jq .
    ;;

  blast-radius)
    [ "$#" -gt 0 ] || { echo "Usage: kg-sidecar.sh blast-radius <id>" >&2; exit 2; }
    ensure_running
    curl -s --unix-socket "$SOCKET" "http://localhost/blast-radius?id=$1" | jq .
    ;;

  search|query)
    [ "$#" -gt 0 ] || { echo "Usage: kg-sidecar.sh search <term>" >&2; exit 2; }
    ensure_running
    curl -s --unix-socket "$SOCKET" "http://localhost/query?q=$1" | jq .
    ;;

  *)
    echo "Usage: kg-sidecar.sh {start|stop|restart|status|node <id>|neighbors <id> [depth]|blast-radius <id>|search <term>}" >&2
    exit 2
    ;;
esac
