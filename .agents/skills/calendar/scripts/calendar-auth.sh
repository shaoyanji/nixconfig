#!/usr/bin/env bash
# Google Calendar: the one-time consent flow, or proof that sync still works.
#
#   calendar-auth.sh                     first sync: discover, wait for consent, sync, read back
#   calendar-auth.sh verify              sync now and show what khal can see
#   calendar-auth.sh auth [--force]      the same as the default, spelled out
#
# The OAuth *token* is runtime state, not config: `modules/calendar.nix` only
# gates `vdirsyncer.service` on the token file, so nothing here needs a rebuild.
set -euo pipefail

ACCOUNT=${CAL_ACCOUNT:-calendar_google}
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
TOKEN=${CAL_TOKEN:-$CFG/vdirsyncer/google_token}
WAIT=${CAL_WAIT:-300}
PAIR_PORT=${CAL_CALLBACK_PORT:-8080}

die() {
  echo "calendar-auth: $*" >&2
  exit 1
}

need() { command -v "$1" >/dev/null || die "$1 is not installed on this host"; }

verify() {
  need vdirsyncer
  [ -s "$TOKEN" ] || die "no token at $TOKEN — run: calendar-auth.sh auth"
  echo "calendar-auth: syncing $ACCOUNT …" >&2
  out=$(timeout 180 vdirsyncer sync 2>&1) || true
  printf '%s\n' "$out" | grep -E '^Syncing ' >/dev/null || {
    printf '%s\n' "$out" | tail -5 >&2
    die "no collection synced — the account is not reachable at all (token? network?)"
  }

  # Two very different failures share the exit code. Auth errors are fatal and
  # named here; a per-item error is one bad event, and vdirsyncer syncs the rest
  # anyway, so it is a warning the caller can see rather than a red verdict.
  if printf '%s\n' "$out" | grep -qiE 'invalid_grant|accessNotConfigured|401 Unauthorized'; then
    printf '%s\n' "$out" | grep -iE '^error' | head -3 >&2
    die "authorisation rejected — 403 accessNotConfigured means the Cloud project lacks caldav.googleapis.com; invalid_grant means the token is dead: delete $TOKEN and run auth --force"
  fi
  item_errors=$(printf '%s\n' "$out" | grep -cE '^error: .*(Unknown error|properties are missing)' || true)
  [ "$item_errors" -eq 0 ] || printf '%s\n' "$out" | grep -E '^error: Unknown error' | head -5 >&2

  events=$(khal list today 7d --format '{start-time}|{title}' 2>/dev/null | grep -c '|' || true)
  echo "token       $TOKEN"
  echo "account     $ACCOUNT"
  echo "upcoming    ${events} event(s) in the next 7 days"
  echo "skipped     ${item_errors} item(s) the remote would not hand over"
  khal list today 7d --format '{start-time}  {title}' 2>/dev/null | head -8
}

auth() {
  need vdirsyncer
  local force=0
  while [ $# -gt 0 ]; do
    case "$1" in
    --force) force=1 && shift ;;
    *) die "unknown flag $1" ;;
    esac
  done
  if [ -s "$TOKEN" ] && [ "$force" = 0 ]; then
    die "already authorised ($TOKEN) — use 'calendar-auth.sh verify', or auth --force to redo it"
  fi
  [ "$force" -eq 1 ] && rm -f "$TOKEN"

  log=$(mktemp)
  # vdirsyncer keeps its OAuth callback server alive only while this runs, so
  # the browser step has to happen inside this window. It writes the token
  # itself when consent lands — that file is the success signal, not the exit
  # code, because the process can also end by being interrupted.
  vdirsyncer discover "$ACCOUNT" >"$log" 2>&1 &
  pid=$!
  cleanup() {
    kill "$pid" 2>/dev/null || true
    rm -f "$log"
  }
  trap cleanup EXIT

  url=""
  for _ in $(seq 1 40); do
    url=$(grep -oE 'https://accounts\.google\.com/[A-Za-z0-9._~:/?#@!$&*+,;=%-]+' "$log" | head -1 || true)
    [ -n "$url" ] && break
    kill -0 "$pid" 2>/dev/null || die "vdirsyncer discover exited before printing a URL: $(tail -3 "$log")"
    sleep 0.5
  done
  [ -n "$url" ] || die "no consent URL after 20s: $(tail -3 "$log")"

  cat >&2 <<EOF
Open this URL in a browser and approve calendar access:

  $url

Google then redirects to http://localhost:$PAIR_PORT on the machine running the
browser. On a headless host, hold that port open from your laptop first:

  ssh -N -L $PAIR_PORT:127.0.0.1:$PAIR_PORT $(hostname)

Do not close this terminal: vdirsyncer's callback server lives only as long as
this run. Waiting up to ${WAIT}s for $TOKEN.
EOF

  waited=0
  while [ "$waited" -lt "$WAIT" ]; do
    if [ -s "$TOKEN" ]; then
      echo "calendar-auth: token written after ${waited}s" >&2
      break
    fi
    kill -0 "$pid" 2>/dev/null || die "vdirsyncer discover exited without a token: $(tail -3 "$log")"
    sleep 1
    waited=$((waited + 1))
  done
  [ -s "$TOKEN" ] || die "no token after ${WAIT}s — the redirect never reached localhost:$PAIR_PORT (tunnel not open?)"
  verify
}

cmd=${1:-auth}
case "$cmd" in
auth) shift && auth "$@" ;;
verify) shift && verify ;;
-h | --help) sed -n '2,9p' "$0" ;;
*) die "unknown command '$cmd' — (no argument) | verify" ;;
esac
