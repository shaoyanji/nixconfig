#!/usr/bin/env bash
# edge-sidecar.sh — needle3 resident, so a prefetch pays prefill and not process
# start. The dispatcher (toolcall.sh) uses this when it is up and falls back to a
# one-shot engine call when it is not, because a warm caller is an optimisation,
# never a dependency.
#
# Why it exists (measured on this host, 2026-11-02, six-tool surface)
# ------------------------------------------------------------------
#   one-shot `needle --prompt`                1370-1430 ms
#   resident, POST /complete                  750-900 ms    (same picks, same
#                                                           confidences)
#   resident + --tool-index, one tool          246 ms
#
# ~600 ms of the one-shot cost is starting the process and loading the weights;
# the rest is real work at ~600-700 tok/s prefill. `--tool-index` caches the tool
# schemas' embeddings and helps most on a small surface.
#
# A resident engine is STATEFUL: without a reset its context grows and every call
# gets slower (measured 1147 -> 1811 ms over five calls). So `ask` resets first,
# every time, which is why an `ask` is one dispatch and not a conversation.
#
# Usage
#   edge-sidecar.sh status
#   edge-sidecar.sh ensure <tools.json>     # start/reuse, prints the port
#   edge-sidecar.sh ask <tools.json> <prompt>   # ensure + reset + complete
#   edge-sidecar.sh stop
#
# Exit: 0 ok, 1 unavailable (no engine, no weights, port taken by a stranger),
# 2 usage. `ask` prints the engine's own JSON on stdout and nothing else.
set -euo pipefail

STATE="${EDGE_STATE:-${XDG_RUNTIME_DIR:-/tmp}/nixconfig-edge}"
PORT="${EDGE_PORT:-18930}"
PIDFILE="$STATE/pid"
KEYFILE="$STATE/tools-key"
USEDFILE="$STATE/last-used"
LOGFILE="$STATE/log"
IDLE="${EDGE_IDLE_SECONDS:-1800}"

usable() {
  [ -s "$PIDFILE" ] || return 1
  local pid
  pid="$(cat "$PIDFILE")"
  kill -0 "$pid" 2>/dev/null || return 1
  curl -s -m 1 -o /dev/null -X POST "http://127.0.0.1:$PORT/reset" 2>/dev/null
}

find_engine() {
  NEEDLE_ENGINE="${NEEDLE_ENGINE:-$(ls -d /nix/store/*-needle-3/bin/needle 2>/dev/null | tail -1)}"
  NEEDLE_WEIGHTS="${NEEDLE_WEIGHTS:-$(ls /nix/store/*-needle3.cact 2>/dev/null | tail -1)}"
  [ -n "$NEEDLE_ENGINE" ] && [ -x "$NEEDLE_ENGINE" ] && [ -n "$NEEDLE_WEIGHTS" ]
}

key_of() { sha1sum "$1" | cut -d' ' -f1; }

stop_quiet() {
  # The idle watchdog belongs to the server: it must die with it, or the next
  # start inherits a reaper that stops the server it just launched.
  if [ -s "$STATE/reaper" ]; then
    kill "$(cat "$STATE/reaper")" 2>/dev/null || true
    rm -f "$STATE/reaper"
  fi
  if [ -s "$PIDFILE" ]; then
    local pid
    pid="$(cat "$PIDFILE")"
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.05
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
}

case "${1:-status}" in
status)
  if usable; then
    printf '{"status":"up","port":%s,"pid":%s,"tools":"%s","idle_seconds":%s}\n' \
      "$PORT" "$(cat "$PIDFILE")" "$(cat "$KEYFILE" 2>/dev/null || echo '')" \
      "$(( $(date +%s) - $(stat -c %Y "$USEDFILE" 2>/dev/null || date +%s) ))"
    exit 0
  fi
  printf '{"status":"down","port":%s}\n' "$PORT"
  exit 1
  ;;

stop)
  stop_quiet
  echo '{"status":"down"}'
  ;;

ensure)
  TOOLS="${2:-}"
  [ -n "$TOOLS" ] && [ -s "$TOOLS" ] || {
    echo "edge-sidecar: ensure needs an existing tools file" >&2
    exit 2
  }
  KEY="$(key_of "$TOOLS")"
  if usable && [ "$(cat "$KEYFILE" 2>/dev/null || echo '')" = "$KEY" ]; then
    echo "$PORT"
    exit 0
  fi
  # A live server on another surface, or a corpse on this one, both get replaced:
  # the tool set is fixed for the life of the process, so a changed surface is a
  # restart, not a reload.
  stop_quiet
  find_engine || {
    echo "edge-sidecar: needle engine or weights not found" >&2
    exit 1
  }
  mkdir -p "$STATE"
  # A stranger already on the port is not ours to kill.
  if curl -s -m 1 -o /dev/null -X POST "http://127.0.0.1:$PORT/reset" 2>/dev/null; then
    echo "edge-sidecar: port $PORT is already served by another process" >&2
    exit 1
  fi
  # The tool index is keyed by the SURFACE's content hash, so an index written for
  # one tool set can never be reopened against another. That lesson cost a
  # debugging session on 2026-11-02, though the drift it was blamed for turned out
  # to be a different bug: `*-needle-[0-9]*` picked a leftover needle-2 for the
  # one-shot side of `checks:edge` while the unit ran needle-3, and 11/11 same-call
  # read as 1/11. With the build pinned, 11/11 holds with the index on.
  NEEDLE_TELEMETRY=0 DO_NOT_TRACK=1 "$NEEDLE_ENGINE" --model "$NEEDLE_WEIGHTS" \
    --tools "$TOOLS" --tool-index "$STATE/tools-$KEY.idx" --serve --port "$PORT" \
    >>"$LOGFILE" 2>&1 &
  echo "$!" >"$PIDFILE"
  echo "$KEY" >"$KEYFILE"
  date +%s >"$USEDFILE"
  # Readiness, not spawn success: the first /reset is what proves the weights are
  # loaded (kg-sidecar learned the same lesson the same way).
  for _ in $(seq 1 200); do
    if curl -s -m 1 -o /dev/null -X POST "http://127.0.0.1:$PORT/reset" 2>/dev/null; then
      # ONE watchdog for this server, started here rather than per request: a
      # reaper per `ask` is a sleeper per call, and they outlive the shell that
      # spawned them. It polls at most once a minute (or once per idle window on
      # a short test window) and stops the server once the last use is older than
      # EDGE_IDLE_SECONDS. EDGE_IDLE_SECONDS=0 keeps it resident forever.
      if [ "$IDLE" -gt 0 ]; then
        tick=$((IDLE < 60 ? IDLE : 60))
        (
          while kill -0 "$(cat "$PIDFILE" 2>/dev/null || echo 0)" 2>/dev/null; do
            sleep "$tick"
            last="$(stat -c %Y "$USEDFILE" 2>/dev/null || echo 0)"
            [ $(( $(date +%s) - last )) -ge "$IDLE" ] || continue
            "$0" stop >/dev/null 2>&1
            break
          done
        ) >/dev/null 2>&1 &
        echo "$!" >"$STATE/reaper"
      fi
      echo "$PORT"
      exit 0
    fi
    kill -0 "$(cat "$PIDFILE")" 2>/dev/null || break
    sleep 0.1
  done
  echo "edge-sidecar: server did not become ready (see $LOGFILE)" >&2
  stop_quiet
  exit 1
  ;;

ask)
  TOOLS="${2:-}"
  PROMPT="${3:-}"
  [ -n "$PROMPT" ] || {
    echo "edge-sidecar: ask needs a prompt" >&2
    exit 2
  }
  # Inline the already-up case: `ensure` in a fresh process costs ~40 ms, which is
  # a measurable slice of the 800 ms this whole file exists to protect.
  if ! { usable && [ "$(cat "$KEYFILE" 2>/dev/null || echo 'x')" = "$(key_of "$TOOLS")" ]; }; then
    PORT="$(EDGE_PORT="$PORT" "$0" ensure "$TOOLS")" || exit 1
  fi
  date +%s >"$USEDFILE"
  # Reset first: the server is a session, and an unreset context makes call N+1
  # slower than call N.
  curl -s -m 5 -o /dev/null -X POST "http://127.0.0.1:$PORT/reset" || exit 1
  curl -s -m "${EDGE_TIMEOUT:-30}" "http://127.0.0.1:$PORT/complete" \
    -X POST -H 'Content-Type: application/json' \
    --data-binary "$(jq -cn --arg i "$PROMPT" '{input: $i}')"
  echo
  ;;

*)
  sed -n '2,32p' "$0"
  exit 2
  ;;
esac
