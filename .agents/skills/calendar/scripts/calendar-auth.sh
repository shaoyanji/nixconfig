#!/usr/bin/env bash
# Google Calendar: token, sync and consent — one shot where the fleet can help.
#
#   calendar-auth.sh                     fetch a live token from a fleet peer, else consent
#   calendar-auth.sh fetch               just the peer pull: ssh a fleet host for its token
#   calendar-auth.sh verify              sync now and show what khal can see
#   calendar-auth.sh auth [--force]      peer fetch first; consent only when no peer answers
#   calendar-auth.sh auth --force --browser   drive the consent in Chromium: no paste,
#                                        and no phone prompt when CAL_PASSKEY_FILE
#                                        holds a vault passkey (scripts/task/gcal-consent.sh)
#
# The OAuth *token* is runtime state, not config: `modules/calendar.nix` only
# gates `vdirsyncer.service` on the token file, so nothing here needs a rebuild.
# A refresh token is bound to the OAuth client, not the host — the client pair
# is the same sops plane on every host, so a token minted anywhere in the fleet
# refreshes everywhere. Consent is the last resort, never the first move.
set -euo pipefail

ACCOUNT=${CAL_ACCOUNT:-calendar_google}
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
TOKEN=${CAL_TOKEN:-$CFG/vdirsyncer/google_token}
WAIT=${CAL_WAIT:-300}
PAIR_PORT=${CAL_CALLBACK_PORT:-8080}
# Hosts that can hand over a live token, ssh-target form. delphi's door is the
# public name (tailnet names demand a browser check per client — deploy doc).
PEERS=${CAL_TOKEN_PEERS:-"devji@delphi.bountystash.com"}

die() {
  echo "calendar-auth: $*" >&2
  exit 1
}

need() { command -v "$1" >/dev/null || die "$1 is not installed on this host"; }

# A refresh token outlives the host it was minted on: the grant binds to the
# OAuth client pair, which is the same sops plane everywhere, so a peer's token
# file works here verbatim. This is the difference between "re-consent" (a
# browser, a human, maybe a Google CAPTCHA) and "scp" (one second, unattended).
# frieren 2026-11-22: consent died on a logged-out profile; delphi's token
# passed checks:gcal on first copy.
fetch() {
  need ssh
  local remote="${CAL_TOKEN_REMOTE:-.config/vdirsyncer/google_token}"
  local tmp; tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN
  local peer self; self=$(hostname)
  for peer in $PEERS; do
    case "$peer" in "$self"|*@"$self"|"$self".*) continue ;; esac
    echo "calendar-auth: asking $peer for a token …" >&2
    if timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=8 "$peer" \
        "test -s $remote && cat $remote" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("refresh_token")' "$tmp" ||
        die "$peer handed over a token file with no refresh_token — refusing to install it"
      install -m600 "$tmp" "$TOKEN"
      echo "calendar-auth: token installed from $peer" >&2
      discover_collections
      verify
      return 0
    fi
    echo "calendar-auth: $peer has no usable token (or is unreachable)" >&2
  done
  rm -f "$tmp"
  return 1
}

# `discover` creates each local collection only by asking, and metasync pulls
# display names for khal's `default_calendar`. Both advisory: a server that
# cannot do either still syncs events. Shared by fetch and auth.
discover_collections() {
  echo "calendar-auth: creating the local collections for $ACCOUNT …" >&2
  timeout 120 vdirsyncer discover "$ACCOUNT" < <(yes y) >/dev/null 2>&1 ||
    echo "calendar-auth: collection discovery reported an error — continuing, sync will say what is missing" >&2
  timeout 120 vdirsyncer metasync >/dev/null 2>&1 ||
    echo "calendar-auth: metasync skipped (the server may not support it); khal will show collection ids instead of names" >&2
}

verify() {
  need vdirsyncer
  [ -s "$TOKEN" ] || die "no token at $TOKEN — run: calendar-auth.sh fetch (or auth for the full flow)"
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
    die "authorisation rejected — 403 accessNotConfigured means the Cloud project lacks caldav.googleapis.com; invalid_grant means the token is dead: run calendar-auth.sh auth (it pulls a live token from the fleet before asking for consent)"
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
  local force=0 browser=${CAL_BROWSER:-0}
  while [ $# -gt 0 ]; do
    case "$1" in
    --force) force=1 && shift ;;
    --browser) browser=1 && shift ;;
    *) die "unknown flag $1" ;;
    esac
  done
  if [ -s "$TOKEN" ] && [ "$force" = 0 ]; then
    die "already authorised ($TOKEN) — use 'calendar-auth.sh verify', or auth --force to redo it"
  fi
  [ "$force" -eq 1 ] && rm -f "$TOKEN"

  # One-shot path: a peer's refresh token is the same grant — install it and
  # sync, no browser, no human. Consent only happens when no peer can help.
  if [ "${CAL_NO_PEER:-0}" != 1 ] && fetch; then
    return 0
  fi
  echo "calendar-auth: no fleet token — falling back to interactive consent" >&2

  log=$(mktemp)
  # vdirsyncer keeps its OAuth callback server alive only while this runs, so
  # the browser step has to happen inside this window. It writes the token
  # itself when consent lands — that file is the success signal, not the exit
  # code, because the process can also end by being interrupted.
  # stdin is /dev/null on purpose: this process also prints "Should vdirsyncer
  # attempt to create it?" and would otherwise eat the redirect URL the operator
  # pastes below. It exits at that prompt once the token is written, which is
  # exactly when its job is done; collections are created afterwards.
  vdirsyncer discover "$ACCOUNT" >"$log" 2>&1 </dev/null &
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

  PORT=$(printf '%s\n' "$url" | sed -n 's/.*redirect_uri=http%3A%2F%2F127\.0\.0\.1%3A\([0-9]*\).*/\1/p')
  [ -n "$PORT" ] || PORT="$PAIR_PORT"

  if [ "$browser" = 0 ]; then
  cat >&2 <<EOF
Open this URL in a browser and approve calendar access:

  $url

Google will redirect to:
  http://127.0.0.1:$PORT/?state=...&code=...

Option A (Recommended — No SSH tunnel needed):
  Open the URL on your client browser, approve consent. When the browser fails
  to connect to the 127.0.0.1:$PORT redirect page, copy the full URL from your
  browser's address bar and paste it below:

Option B (SSH tunnel):
  Open a tunnel for port $PORT (NOTE: NOT 8080, which is Pi-hole):
    ssh -N -L $PORT:127.0.0.1:$PORT $(hostname)

Waiting up to ${WAIT}s for $TOKEN...
Paste redirect URL here (or press Enter if using Option B):
EOF
  else
    echo "calendar-auth: driving the consent in Chromium — no paste, no display" >&2
    repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
    bash "$repo/scripts/task/gcal-consent.sh" "$url" "$PORT" "${CAL_PASSKEY_FILE:-}" ||
      die "the browser consent driver failed — the token file is untouched only if it never answered; rerun without --browser to finish by hand"
  fi

  waited=0
  while [ "$waited" -lt "$WAIT" ]; do
    if [ -s "$TOKEN" ]; then
      echo "calendar-auth: token written after ${waited}s" >&2
      break
    fi
    if [ -t 0 ]; then
      if read -t 1 -r line; then
        if [ -n "$line" ]; then
          clean_url=$(printf '%s\n' "$line" | sed 's|https://127.0.0.1|http://127.0.0.1|; s|localhost|127.0.0.1|')
          echo "Sending authorization response to local listener on port $PORT..." >&2
          curl -s "$clean_url" >/dev/null 2>&1 || true
        fi
      fi
    else
      sleep 1
    fi
    kill -0 "$pid" 2>/dev/null || die "vdirsyncer discover exited without a token: $(tail -3 "$log")"
    waited=$((waited + 1))
  done
  [ -s "$TOKEN" ] || die "no token after ${WAIT}s — the redirect never reached localhost:$PORT"

  # Google sets `refresh_token_expires_in` only when the consent granted
  # *time-based* access, and the token then dies at that timestamp: sync starts
  # answering invalid_grant on the next run. Approving with a checkbox that said
  # "this session" is a one-click mistake, so name it here instead of leaving it
  # to the journal. (delphi, 2026-11-15: refresh_token_expires_in=52.)
  time_based=$(python3 - "$TOKEN" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("refresh_token_expires_in") or "")
except Exception:
    print("")
PY
)
  [ -z "$time_based" ] || die "the consent granted time-based access (${time_based}s), so this token is already spent — approve again and choose permanent access; if the OAuth app is still in Testing, publish it, because Testing caps every refresh token at 7 days"

  # A token is not a working pair. `discover` creates each local collection only
  # by asking, and its prompt had no TTY (or was answered no), so the local side
  # stayed empty and `sync` paired nothing — the failure read "no collection
  # synced", which looks like a dead token but is an empty directory (delphi,
  # 2026-11-06). Answer yes deterministically, then pull display names so khal's
  # `default_calendar` resolves; both are advisory, because a server that cannot
  # do either still syncs events.
  discover_collections
  verify
}

cmd=${1:-auth}
case "$cmd" in
auth) shift && auth "$@" ;;
fetch) shift && fetch || die "no peer could hand over a token — run: calendar-auth.sh auth" ;;
verify) shift && verify ;;
-h | --help) sed -n '2,16p' "$0" ;;
*) die "unknown command '$cmd' — (no argument) | fetch | verify" ;;
esac
