#!/usr/bin/env bash
# cpg-session-touch.sh — touch the stored Clerk session, and fail before it expires.
#
# The 60-second API token is minted from the long-lived `__client` cookie, so a
# token refresh says nothing about the session behind it. Measured 2026-11-14: a
# session whose `last_active_at` had not moved for seven days reported `expired`,
# every mint answered 401, and nothing failed until an image round needed it.
# Minting is not activity; this is the call that is.
#
# Exit codes are the contract with the unit:
#   0  touched, and the session has more than EXPIRE_WARN_HOURS left
#   1  no auth file, no session fields, touch refused, or status not `active`
#   2  alive but expiring inside the warning window — re-auth is due, not failed
set -euo pipefail

auth=${CPG_AUTH:-$HOME/.chatplayground/auth.json}
warn_hours=${EXPIRE_WARN_HOURS:-48}

die() {
  echo "cpg-session-touch: $*" >&2
  exit 1
}
say() { echo "cpg-session-touch: $*" >&2; }

command -v jq >/dev/null 2>&1 || die "jq is not on PATH"
command -v curl >/dev/null 2>&1 || die "curl is not on PATH"
[ -f "$auth" ] || die "no auth file at $auth — a host that never logged in is not a failure, but this condition should have skipped the unit"

sid=$(jq -r '.sessionId // empty' "$auth")
cookie=$(jq -r '.clientCookie // empty' "$auth")
token=$(jq -r '.token // empty' "$auth")
{ [ -n "$sid" ] && [ -n "$cookie" ]; } ||
  die "auth.json carries no sessionId/clientCookie — the session is gone; re-auth with 'chatplayground-go login'"

# The issuer is the `iss` claim of whatever token is stored, so a moved instance
# needs no edit here. The literal is only a fallback for a token that will not
# decode (an expired one still decodes; a clobbered one does not).
iss=$(printf '%s' "$token" | cut -d. -f2 | tr '_-' '/+' |
  { read -r body || true; printf '%s' "$body" | base64 -d 2>/dev/null || true; } |
  jq -r '.iss // empty' 2>/dev/null || true)
[ -n "$iss" ] || iss=https://clerk.chatplayground.ai

# One call, no cookie jar: this must not rotate `__client`. If Clerk answers with
# a new cookie the stored one is still the one `cpg` mints from, and writing it
# back here would race the CLI.
resp=$(curl -sS --max-time 20 -X POST \
  "$iss/v1/client/sessions/$sid/touch?_clerk_js_version=5.42.0" \
  -H "Cookie: __client=$cookie" \
  -H "Origin: ${CPG_ORIGIN:-https://app.chatplayground.ai}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d '' -w '\n%{http_code}' 2>/dev/null) || die "touch request could not be made"
http=${resp##*$'\n'}
body=${resp%$'\n'*}
[ "$http" = "200" ] || die "touch answered HTTP $http — the session is no longer valid"

client=$(curl -sS --max-time 20 "$iss/v1/client?_clerk_js_version=5.42.0" \
  -H "Cookie: __client=$cookie" 2>/dev/null) || die "could not read the client object back"
read -r status active expire < <(
  printf '%s' "$client" | jq -r --arg sid "$sid" '
    .response.sessions[]? | select(.id == $sid)
    | "\(.status) \(.last_active_at) \(.expire_at)"'
)
[ -n "${status:-}" ] || die "the client object no longer lists session $sid — re-auth needed"
[ "$status" = "active" ] || die "session status is '$status', not 'active' — re-auth needed"

# Both timestamps are epoch milliseconds. A touch moves `last_active_at`; whether
# it also moves `expire_at` is the provider's policy, which is why this reports
# both instead of assuming the touch bought a full week.
now_ms=$(($(date +%s) * 1000))
left_h=$(((expire - now_ms) / 3600000))
say "status=$status last_active=$(date -u -d "@$((active / 1000))" +%FT%TZ) expires=$(date -u -d "@$((expire / 1000))" +%FT%TZ) (${left_h}h)"

if [ "$left_h" -lt "$warn_hours" ]; then
  say "session expires in ${left_h}h — under the ${warn_hours}h warning window; a touch is not extending the session's fixed expiry"
  exit 2
fi
exit 0
