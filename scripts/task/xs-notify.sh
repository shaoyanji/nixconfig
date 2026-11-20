#!/usr/bin/env bash
# xs-notify — poll xs agent-turn store, push changes to ntfy fleet topic.
# SHA1-diff: zero ntfy traffic when nothing changed.
set -euo pipefail

TOKEN_FILE="/run/secrets/agent-turns-token"
NTFY_PASS_FILE="/run/secrets/ntfy/fleet-password"
STATE_DIR="/var/lib/xs-notify"
STATE_FILE="$STATE_DIR/last.sha1"
XS_URL="https://delphi.cloudforest-kardashev.ts.net:8449/v1/events"
NTFY_URL="https://delphi.cloudforest-kardashev.ts.net:8458/fleet"
SCAN=200

TOKEN="$(cat "$TOKEN_FILE")"
NTFY_PASS="$(cat "$NTFY_PASS_FILE")"

# Build query string
QUERY="limit=$SCAN"

# Fetch current turns
if ! RESP=$(curl -sS --max-time 15 \
     -H "Authorization: Bearer $TOKEN" \
     "$XS_URL?$QUERY" 2>/dev/null); then
  echo "xs-notify: no answer from xs API" >&2
  exit 1
fi

# Hash + compare
NEW_SHA=$(printf '%s' "$RESP" | sha1sum | awk '{print $1}')
OLD_SHA=""
[ -f "$STATE_FILE" ] && OLD_SHA=$(cat "$STATE_FILE")

if [ "$NEW_SHA" = "$OLD_SHA" ]; then
  exit 0
fi

# Parse the response for a summary
LIVE_COUNT=$(printf '%s' "$RESP" | jq -r '.live_count // 0' 2>/dev/null || echo 0)
TOTAL=$(printf '%s' "$RESP" | jq -r '.count // 0' 2>/dev/null || echo 0)
SCANNED=$(printf '%s' "$RESP" | jq -r '.scanned // 0' 2>/dev/null || echo 0)

TITLE="xs-notify: turn change detected"
MESSAGE="xs turn log changed: total=$TOTAL scanned=$SCANNED"

curl -s --max-time 10 \
  -u "fleet:$NTFY_PASS" \
  -H "Title: $TITLE" -H "Tags: memo" \
  --data "$MESSAGE" \
  "$NTFY_URL" >/dev/null 2>&1

mkdir -p "$STATE_DIR"
printf '%s' "$NEW_SHA" > "$STATE_FILE"
echo "xs-notify: change detected, ntfy sent (sha1 $NEW_SHA)"
