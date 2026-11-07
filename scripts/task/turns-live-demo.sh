#!/usr/bin/env bash
# turns-live-demo.sh — publish one turn to the xs store and prove it reaches an
# open browser on the public surface, with no tailnet and no funnel.
#
# The public mount is `https://delphi.bountystash.com/turns/`: nginx proxies a
# second turns-dashboard reader that runs `-read-only` and has no Hermes. That is
# why this can be a public page at all — the row carries no prompt form and
# `POST /api/prompt` answers 403 there, so a stranger can read the log and cannot
# spend an agent turn.
#
# What this proves, in one run:
#   posture   the public mount serves rows and carries no prompt form
#   live      the page's stream is connected before the post
#   publish   one turn posted through scripts/task/xs-turn-post.sh, the publisher
#             agents use — one POST, no rebuild, no deploy
#   push      the frame arrives on the public stream AND the row appears in the
#             open page while a window marker set before the post survives (a
#             page that navigated would have cleared it)
#
# Task: agents:xs:demo · host: delphi (the shim and the store live there)
# Exit: 0 push proved on the public mount · 1 the row never arrived ·
#       2 preflight, nothing was posted
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
PUBLIC=${PUBLIC_URL:-https://delphi.bountystash.com/turns/}
SHIM=${SHIM:-http://127.0.0.1:8093}
TOKEN_FILE=${TOKEN_FILE:-/run/secrets/agent-turns-token-dashboard}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/agent-turns/demo
BROWSER=${BROWSER:-1}
AGENT_BROWSER=${AGENT_BROWSER:-$(command -v agent-browser || true)}
# Not on PATH on every host that has it built; the store copy is version-sorted
# so a rebuild picks the newer one without this script learning its path.
if [ -z "$AGENT_BROWSER" ]; then
  AGENT_BROWSER=$(ls -d /nix/store/*-agent-browser-*/bin/agent-browser 2>/dev/null | sort -V | tail -1 || true)
fi

STREAM=
die() { # die <code> <message>
  local code=$1
  shift
  printf 'live-demo: %s\n' "$*" >&2
  case $code in
  2) exit 2 ;;
  *) exit 1 ;;
  esac
}
say() { printf '%-9s %s\n' "$1" "$2"; }
trap '[ -n "$STREAM" ] && kill "$STREAM" 2>/dev/null || true' EXIT

ab() { timeout 120 "$AGENT_BROWSER" "$@" 2>/dev/null; }
evaluate() { ab eval "$1" | tr -d '\n' | jq -r . 2>/dev/null || true; }

wait_for() { # wait_for <file> <needle> <seconds>
  local file=$1 needle=$2 secs=$3 i
  for i in $(seq 1 "$((secs * 2))"); do
    grep -q -- "$needle" "$file" && return 0
    sleep 0.5
  done
  return 1
}

preflight() {
  local tool code
  for tool in curl jq; do
    command -v "$tool" >/dev/null || die 2 "$tool is not on PATH"
  done
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$SHIM/v1/events?limit=1" || true)
  case $code in
  200 | 401) ;;
  *) die 2 "the xs shim does not answer on $SHIM (http ${code:-none}) — run this on delphi" ;;
  esac
  [ -r "$TOKEN_FILE" ] || die 2 "cannot read $TOKEN_FILE, the dashboard's own token"

  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$PUBLIC" || true)
  [ "$code" = 200 ] || die 2 "the public mount $PUBLIC answered ${code:-nothing}"

  mkdir -p "$STATE"
  curl -sN --max-time 15 "${PUBLIC%/}/api/stream" >"$STATE/page.txt" 2>/dev/null || true
  grep -q 'id="turn-' "$STATE/page.txt" || die 2 "the public mount served an empty log — nothing to demonstrate against"
  # The posture check, and it has to be the rendered page: probing /api/prompt
  # would be spent on the tailnet unit, where a valid body starts a real agent
  # turn. A read-only reader never renders the form.
  if grep -q 'class="ask"' "$STATE/page.txt"; then
    die 2 "the public mount renders a prompt form — that reader is not -read-only, and a public page must not be able to prompt"
  fi
  say posture "$PUBLIC: rows, no prompt form (read-only reader)"
}

run() {
  local uuid run_id before arrived marker filled
  preflight

  # Opened BEFORE the post, so a row found in it proves a push and not a page
  # served after the fact.
  timeout 40 curl -sN "${PUBLIC%/}/api/stream" >"$STATE/stream.txt" 2>/dev/null &
  STREAM=$!
  sleep 1

  if [ "$BROWSER" = 1 ] && [ -n "$AGENT_BROWSER" ]; then
    ab open "$PUBLIC" >/dev/null || true
    local i state
    for i in $(seq 1 30); do
      state=$(evaluate 'document.body.dataset.stream')
      [ "$state" = live ] && break
      sleep 1
    done
    [ "$state" = live ] || die 1 "the page at $PUBLIC never reported a live stream"
    say browser "$AGENT_BROWSER, stream live"
    filled=1
  elif [ "$BROWSER" = 1 ]; then
    say browser "skipped: agent-browser is not on PATH (AGENT_BROWSER= sets it)"
  else
    say browser "skipped (BROWSER=0)"
  fi

  run_id=$(date -u +%Y%m%dT%H%M%SZ)
  uuid=$(cat /proc/sys/kernel/random/uuid)
  if [ "${filled:-0}" = 1 ]; then
    before=$(evaluate "window.__demo = \"$uuid\"; document.querySelectorAll('article.turn').length")
    say page "$before turns before the post; marker set"
  fi

  say publish "nixconfig:turns-demo ($run_id) id $uuid"
  SUBJECT=nixconfig:turns-demo \
    ACTION="Public live demo $run_id: one turn posted to the store while $PUBLIC was open, and watched arriving there without a reload" \
    RATIONALE="The cheap publish path: the same shim POST agents:xs:post makes, with no rebuild in it. The mount is the read-only reader, so the public page cannot start an agent turn." \
    OUTCOME=done SOURCE=turns-demo ID="$uuid" XS_TURNS_URL="$SHIM" \
    bash "$ROOT/scripts/task/xs-turn-post.sh" || die 1 "the publisher failed; nothing was demonstrated"

  wait_for "$STATE/stream.txt" "turn-$uuid" 20 ||
    die 1 "the public stream never carried turn-$uuid (see $STATE/stream.txt)"
  say stream "frame turn-$uuid arrived through ${PUBLIC%/}/api/stream"

  if [ "${filled:-0}" = 1 ]; then
    local i
    for i in $(seq 1 30); do
      arrived=$(evaluate "document.querySelector('#turn-$uuid') !== null")
      [ "$arrived" = true ] && break
      sleep 1
    done
    [ "$arrived" = true ] || die 1 "the row never appeared in the open page at $PUBLIC"
    marker=$(evaluate 'window.__demo')
    [ "$marker" = "$uuid" ] ||
      die 1 "the page reloaded (marker $marker, expected $uuid) — the row arrived by navigation, not by push"
    say page "row present, no reload (marker survived); $(evaluate "document.querySelectorAll('article.turn').length") turns"
    ab screenshot "$STATE/shot.png" >/dev/null 2>&1 || true
  fi

  say result "PASS — one POST reached an open browser on the public mount, and nothing was rebuilt"
}

run
