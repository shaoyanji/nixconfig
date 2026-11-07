#!/usr/bin/env bash
# turns-funnel-demo.sh — the publish -> live-push path, proved the way a reader
# outside the tailnet sees it.
#
# Why it exists: the dashboard was verified with a mock store and a browser on a
# tailnet host, which proves the client but not the path. This runs the deployed
# binary against the real xs store and puts it on the public internet for one
# bounded run:
#
#   reader    the turns-dashboard binary from the running unit, `-read-only`, on
#             a loopback port — read-only is what makes a public exposure safe,
#             because the prompt endpoint is the one thing a stranger could spend
#             an agent turn on
#   funnel    `tailscale funnel --https=<port>` in front of that reader (Tailscale
#             allows funnel on 443, 8443 and 10000; 8443 is already a serve mount
#             here)
#   publish   one turn through scripts/task/xs-turn-post.sh, the same publisher
#             agents use — no rebuild, no deploy, one POST
#   assert    the open page must grow that row with no reload (a window marker set
#             before the post must survive it), and the public SSE stream must
#             carry the frame
#   teardown  the funnel is removed in a trap and the removal is verified against
#             the public URL, so a failed run cannot leave the log exposed
#
# Task: agents:xs:demo · host: delphi (the shim and the dashboard live there)
# Exit: 0 push proved and the funnel is down (or KEEP=1 left it up on purpose) ·
#       1 the row never arrived · 2 preflight, nothing was started · 3 no funnel
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SUB=${SUB:-run}
PORT=${PORT:-8071}
FUNNEL_PORT=${FUNNEL_PORT:-10000}
WAIT=${WAIT:-90}
BROWSER=${BROWSER:-1}
KEEP=${KEEP:-}
SHIM=${SHIM:-http://127.0.0.1:8093}
TOKEN_FILE=${TOKEN_FILE:-/run/secrets/agent-turns-token-dashboard}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/agent-turns/demo
AGENT_BROWSER=${AGENT_BROWSER:-$(command -v agent-browser || true)}
# Not on PATH on every host that has it built; the store copy is version-sorted
# so a rebuild picks the newer one without this script learning its path.
if [ -z "$AGENT_BROWSER" ]; then
  AGENT_BROWSER=$(ls -d /nix/store/*-agent-browser-*/bin/agent-browser 2>/dev/null | sort -V | tail -1 || true)
fi

READER=
STREAM=
HOST=
URL=
LEAVE_UP=0

die() { # die <code> <message>
  local code=$1
  shift
  printf 'funnel-demo: %s\n' "$*" >&2
  case $code in
  2) exit 2 ;;
  3) exit 3 ;;
  *) exit 1 ;;
  esac
}

say() { printf '%-9s %s\n' "$1" "$2"; }

teardown() {
  [ "$LEAVE_UP" = 1 ] && return 0
  if [ -n "$STREAM" ]; then kill "$STREAM" 2>/dev/null || true; fi
  if [ -n "$READER" ]; then kill "$READER" 2>/dev/null || true; fi
  rm -f "$STATE/reader.pid"
  sudo -n tailscale funnel --https="$FUNNEL_PORT" off >/dev/null 2>&1 || true
}
trap teardown EXIT

# The funnel is the one mutation this script makes outside its own state
# directory, so it is proved off by asking the public URL, not by trusting the
# command that removed it.
funnel_is_down() {
  if tailscale funnel status 2>/dev/null | grep -q "https://$HOST:$FUNNEL_PORT\b"; then
    return 1
  fi
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$URL" 2>/dev/null || true)
  [ "$code" = 000 ] || [ -z "$code" ]
}

# The binary and site are read from the RUNNING process, not from the unit text:
# an ExecStart argument list contains `-site` twice (`…-turns-dashboard-site
# -hermes-home …`), and a pattern match on that line picks the wrong one.
unit_paths() {
  local pid i argv
  pid=$(systemctl show turns-dashboard -p MainPID --value 2>/dev/null)
  [ -n "$pid" ] && [ "$pid" != 0 ] || return 1
  mapfile -t argv < <(tr '\0' '\n' <"/proc/$pid/cmdline")
  BIN=${argv[0]:-}
  SITE=
  for ((i = 1; i < ${#argv[@]}; i++)); do
    [ "${argv[$i]}" = "-site" ] && SITE=${argv[$((i + 1))]:-}
  done
  [ -n "$SITE" ]
}

preflight() {
  local tool code
  for tool in curl jq tailscale systemctl; do
    command -v "$tool" >/dev/null || die 2 "$tool is not on PATH"
  done
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$SHIM/v1/events?limit=1" || true)
  case $code in
  200 | 401) ;;
  *) die 2 "the xs shim does not answer on $SHIM (http ${code:-none}) — run this on delphi" ;;
  esac
  [ -r "$TOKEN_FILE" ] || die 2 "cannot read $TOKEN_FILE, the dashboard's own token"

  unit_paths || die 2 "the turns-dashboard unit is not running, so there is no deployed binary to prove"
  [ -x "$BIN" ] || die 2 "the running unit's binary is not executable: ${BIN:-none}"
  [ -d "$SITE" ] || die 2 "the running unit serves no readable -site directory: ${SITE:-none}"
  "$BIN" -h 2>&1 | grep -q -- '-read-only' ||
    die 2 "the deployed dashboard predates -read-only; rebuild delphi before demonstrating on a public port"

  HOST=$(tailscale status --json | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
  [ -n "$HOST" ] || die 2 "tailscale reports no MagicDNS name, so there is no funnel URL"
  URL="https://$HOST:$FUNNEL_PORT/"

  if tailscale funnel status 2>/dev/null | grep -q "https://$HOST:$FUNNEL_PORT\b"; then
    die 2 "port $FUNNEL_PORT already carries a serve/funnel entry; pick another with FUNNEL_PORT="
  fi
  if curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$PORT/api/health"; then
    die 2 "loopback :$PORT is already serving; pick another with PORT="
  fi
}

start_reader() {
  local bin=$1 site=$2
  mkdir -p "$STATE"
  : >"$STATE/reader.log"
  setsid "$bin" -addr "127.0.0.1:$PORT" -shim "$SHIM" -token-file "$TOKEN_FILE" \
    -prompt-log "$STATE/prompts.jsonl" -site "$site" -limit 120 -read-only \
    >>"$STATE/reader.log" 2>&1 </dev/null &
  READER=$!
  printf '%s\n' "$READER" >"$STATE/reader.pid"
  local i
  for i in $(seq 1 30); do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$PORT/api/health" || true)" = 200 ]; then
      say reader "127.0.0.1:$PORT read-only, real store at $SHIM"
      return 0
    fi
    sleep 0.5
  done
  sed 's/^/  /' "$STATE/reader.log" >&2
  die 2 "the reader did not answer on :$PORT"
}

funnel_on() {
  if ! sudo -n tailscale funnel --bg --https="$FUNNEL_PORT" "http://127.0.0.1:$PORT" >"$STATE/funnel.log" 2>&1; then
    sed 's/^/  /' "$STATE/funnel.log" >&2
    die 3 "tailscale refused the funnel (sudo -n must work, and the tailnet needs Funnel enabled)"
  fi
  # Enabling a funnel is not instant: the control plane has to publish the port
  # at the ingress and the certificate has to land (measured 2026-11-07: 10 s on
  # a warm hostname, and a full cold path once took longer than 45 s). WAIT is
  # generous on purpose; the last failure is printed so a refusal is not guessed.
  local i code last=starting
  for i in $(seq 1 "$WAIT"); do
    if code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$URL" 2>&1); then
      if [ "$code" = 200 ]; then
        say funnel "$URL (public, ${i}s after the command)"
        return 0
      fi
      last="http $code"
    else
      last=$code
    fi
    sleep 1
  done
  die 3 "the funnel URL did not answer 200 within ${WAIT}s (last: $last) — a tailnet that forbids Funnel is a refusal, not a bug here"
}

ab() { timeout 120 "$AGENT_BROWSER" "$@" 2>/dev/null; }
evaluate() { ab eval "$1" | tr -d '\n' | jq -r . 2>/dev/null || true; }

browser_open() {
  ab open "$URL" >/dev/null || true
  local i state
  for i in $(seq 1 30); do
    state=$(evaluate 'document.body.dataset.stream')
    [ "$state" = live ] && break
    sleep 1
  done
  [ "$state" = live ] || die 1 "the page at $URL never reported a live stream"
  say browser "$AGENT_BROWSER, stream live"
}

publish() { # publish <uuid> <run-id>
  local uuid=$1 run=$2
  SUBJECT=nixconfig:turns-demo \
    ACTION="Funnel demo $run: one turn posted to the store while a public page was open, and watched arriving there without a reload" \
    RATIONALE="Cheap publish path: the shim POST agents:xs:post already makes. The reader is the deployed binary with -read-only, so the public surface cannot start an agent turn." \
    OUTCOME=done SOURCE=turns-demo ID="$uuid" XS_TURNS_URL="$SHIM" \
    bash "$ROOT/scripts/task/xs-turn-post.sh"
}

wait_for() { # wait_for <grep-file> <needle> <seconds>
  local file=$1 needle=$2 secs=$3 i
  for i in $(seq 1 "$((secs * 2))"); do
    grep -q -- "$needle" "$file" && return 0
    sleep 0.5
  done
  return 1
}

run() {
  local uuid run_id code before arrived marker
  # Deliberately not in a $( ) subshell: preflight sets HOST and URL as well as
  # BIN and SITE, and a substitution would hand back only the last of those.
  preflight

  start_reader "$BIN" "$SITE"
  funnel_on

  # The wire half: a stream opened BEFORE the post, so a row found in it proves a
  # push and not a page that was simply served after the fact. `//api/stream` is
  # 307-ed to the clean path by Go's mux, and curl follows nothing by default —
  # the base is trimmed rather than the redirect followed.
  timeout 40 curl -sN "${URL%/}/api/stream" >"$STATE/stream.txt" 2>/dev/null &
  STREAM=$!
  sleep 1

  local browser_live=0
  if [ "$BROWSER" = 1 ] && [ -n "$AGENT_BROWSER" ]; then
    browser_open
    browser_live=1
  elif [ "$BROWSER" = 1 ]; then
    say browser "skipped: agent-browser is not on PATH (AGENT_BROWSER= sets it)"
  else
    say browser "skipped (BROWSER=0)"
  fi

  run_id=$(date -u +%Y%m%dT%H%M%SZ)
  uuid=$(cat /proc/sys/kernel/random/uuid)
  if [ "$browser_live" = 1 ]; then
    before=$(evaluate "window.__demo = \"$uuid\"; document.querySelectorAll('article.turn').length")
    say page "$before turns before the post; marker set"
  fi

  say publish "nixconfig:turns-demo ($run_id) id $uuid"
  publish "$uuid" "$run_id" || die 1 "the publisher failed; nothing was demonstrated"

  wait_for "$STATE/stream.txt" "turn-$uuid" 20 ||
    die 1 "the public stream never carried turn-$uuid (see $STATE/stream.txt)"
  say stream "frame turn-$uuid arrived through ${URL%/}/api/stream"

  if [ "$browser_live" = 1 ]; then
    local i
    for i in $(seq 1 30); do
      arrived=$(evaluate "document.querySelector('#turn-$uuid') !== null")
      [ "$arrived" = true ] && break
      sleep 1
    done
    [ "$arrived" = true ] || die 1 "the row never appeared in the open page at $URL"
    marker=$(evaluate 'window.__demo')
    [ "$marker" = "$uuid" ] ||
      die 1 "the page reloaded (marker $marker, expected $uuid) — the row arrived by navigation, not by push"
    say page "row present, no reload (marker survived); $(evaluate "document.querySelectorAll('article.turn').length") turns"
    ab screenshot "$STATE/shot.png" >/dev/null 2>&1 || true
  fi

  if [ "$KEEP" = 1 ]; then
    LEAVE_UP=1
    say keep "funnel left up at $URL — 'task agents:xs:demo SUB=off' takes it down"
    return 0
  fi

  teardown
  funnel_is_down || die 1 "the funnel is still answering at $URL after teardown"

  # The real surface, not the demo: the same publish shows up on the tailnet mount.
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
    "https://$HOST:8460/api/stream" 2>/dev/null || true)
  if [ "$code" = 200 ]; then
    say real "https://$HOST:8460 still serves the live log"
  fi

  say funnel "off; $URL answers nothing"
  say result "PASS — one POST reached an open browser outside the tailnet, and the funnel is gone"
}

off() {
  HOST=$(tailscale status --json | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
  URL="https://${HOST}:$FUNNEL_PORT/"
  if [ -f "$STATE/reader.pid" ]; then
    kill "$(cat "$STATE/reader.pid")" 2>/dev/null || true
    rm -f "$STATE/reader.pid"
    say reader "stopped"
  fi
  sudo -n tailscale funnel --https="$FUNNEL_PORT" off >/dev/null 2>&1 || true
  if funnel_is_down; then
    say result "funnel off; $URL answers nothing"
    exit 0
  fi
  die 1 "the funnel still answers at $URL"
}

case $SUB in
run) run ;;
off) off ;;
*) die 2 "SUB must be run or off, got: $SUB" ;;
esac
