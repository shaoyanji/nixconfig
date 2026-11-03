#!/usr/bin/env bash
# selector-sidecar.sh — lifecycle and client for the resident stage 1.
#
# tools/selector/serve.py holds the trained model and answers question -> query
# object on $SELECTOR_SOCKET. `q.sh --question` asks it first and falls back to the
# interpreter, so this is a speed setting, not a correctness one: nothing breaks on
# a host without the unit, it just pays ~80 ms more per question.
#
# Why a unit at all: stage 1's cold cost is the interpreter plus a 1 MB model, and
# a refusal paid all of it to say nothing — the predesign's abstention bar is a
# refusal cheaper than the call it saves. The resident copy answers in ~1 ms and
# reloads the artifact when `ops:q:train` rewrites it, so a retrained model is
# picked up at the next question rather than at the next login.
#
# Commands: start (wait for readiness) · stop (verify it exited) · restart ·
#           status (/stats as JSON) · ask <question> (the query object, or the
#           stage-1 refusal, exactly as `model.py predict` prints it).
#
# Env: SELECTOR_SOCKET  socket path (default $XDG_RUNTIME_DIR/selector.sock)
#      Q_MODEL          the trained artifact (default $XDG_CACHE_HOME/nixconfig/selector/selector-nb.json)
#      SELECTOR_PYTHON  interpreter; default: python3 on PATH, else refuse — an ops
#                       path never builds, so a missing interpreter is reported
#                       rather than substituted.
#
# Socket, pidfile and log are ONE instance and are named from the socket, so a
# caller that overrides SELECTOR_SOCKET (the parity gate) cannot stop the login
# daemon by accident.
#
# Exit: 0 = done/answered; 1 = not running / could not start / request failed;
#       2 = usage.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
SOCKET="${SELECTOR_SOCKET:-${RUNTIME_DIR}/selector.sock}"
INSTANCE="${SOCKET%.sock}"
PIDFILE="${INSTANCE}.pid"
LOG="${INSTANCE}.log"
MODEL="${Q_MODEL:-${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig/selector/selector-nb.json}"
SERVER="${REPO}/tools/selector/serve.py"

cmd="${1:-status}"
[ "$#" -gt 0 ] && shift || true

say() { printf 'selector-sidecar: %s\n' "$*" >&2; }

is_alive() {
  [ -S "$SOCKET" ] && curl -s -m 2 --unix-socket "$SOCKET" http://localhost/stats >/dev/null 2>&1
}

resolve_python() {
  if [ -n "${SELECTOR_PYTHON:-}" ]; then
    printf '%s' "$SELECTOR_PYTHON"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return 0
  fi
  say "no python3 on PATH (set SELECTOR_PYTHON=/path/to/python3)."
  say "Refusing to build one from a read path."
  return 1
}

wait_ready() {
  for _ in {1..50}; do
    is_alive && return 0
    sleep 0.1
  done
  return 1
}

start_daemon() {
  if is_alive; then
    say "already running at unix:$SOCKET"
    return 0
  fi
  local python
  python="$(resolve_python)" || return 1
  [ -s "$MODEL" ] || {
    say "no trained model at $MODEL (task ops:q:train)"
    return 1
  }

  rm -f "$SOCKET" "$PIDFILE"
  say "launching on unix:$SOCKET (model $MODEL)"
  # setsid: the daemon outlives the shell that started it, which is what makes the
  # unit's ExecStart a one-shot that leaves something running.
  setsid nohup "$python" "$SERVER" \
    --socket "$SOCKET" --model "$MODEL" --repo "$REPO" \
    </dev/null >"$LOG" 2>&1 &
  echo "$!" >"$PIDFILE"

  if wait_ready; then
    say "ready (pid $(cat "$PIDFILE"))"
    return 0
  fi
  say "failed to become ready within 5s — last log lines:"
  tail -5 "$LOG" >&2 || true
  return 1
}

stop_daemon() {
  local pid
  if [ -f "$PIDFILE" ]; then
    pid="$(cat "$PIDFILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      for _ in {1..25}; do
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

fetch() {
  local path="$1" body status
  body="$(mktemp)"
  status="$(curl -sS -m 10 --unix-socket "$SOCKET" -o "$body" -w '%{http_code}' "http://localhost${path}")" || {
    rm -f "$body"
    say "request failed: $path"
    return 1
  }
  if [ "$status" != "200" ]; then
    say "HTTP $status from $path"
    cat "$body" >&2 || true
    echo >&2
    rm -f "$body"
    return 1
  fi
  cat "$body"
  rm -f "$body"
}

case "$cmd" in
  start) start_daemon ;;
  stop) stop_daemon ;;
  restart)
    stop_daemon
    start_daemon
    ;;

  status)
    is_alive || {
      say "not running"
      exit 1
    }
    fetch /stats
    echo
    ;;

  ask)
    [ -n "${1:-}" ] || {
      say "usage: selector-sidecar.sh ask <question>"
      exit 2
    }
    question="$1"
    shift
    for w in "$@"; do question="$question $w"; done
    is_alive || {
      say "not running (start it, or ask q.sh — it falls back to the interpreter)"
      exit 1
    }
    # The request body is built by jq, so a quote in the question is escaped once.
    body="$(jq -nc --arg q "$question" '{question: $q}')"
    fetch_out="$(mktemp)"
    status="$(curl -sS -m 10 --unix-socket "$SOCKET" -o "$fetch_out" -w '%{http_code}' \
      -H 'Content-Type: application/json' -d "$body" http://localhost/predict)" || {
      rm -f "$fetch_out"
      say "request failed"
      exit 1
    }
    if [ "$status" != "200" ]; then
      say "HTTP $status"
      cat "$fetch_out" >&2
      rm -f "$fetch_out"
      exit 1
    fi
    jq -c . <"$fetch_out"
    rm -f "$fetch_out"
    ;;

  *)
    say "usage: selector-sidecar.sh start|stop|restart|status|ask <question>"
    exit 2
    ;;
esac
