#!/usr/bin/env bash
# xs-notify — poll xs agent-turn store on delphi, SHA1-diff, and push changes
# directly to Telegram bot @Frierenixbot (chat_id: 8679391100).
# Zero Telegram traffic when nothing changed.
set -euo pipefail

TOKEN_FILE="${AGENT_TURNS_TOKEN_FILE:-/run/secrets/agent-turns-token}"
BOT_TOKEN_FILE="${BOT_TOKEN_FILE:-/var/lib/xs-notify/bot.token}"
STATE_DIR="${STATE_DIR:-/var/lib/xs-notify}"
STATE_FILE="$STATE_DIR/last.sha1"
JSON_FILE="$STATE_DIR/last.json"
XS_URL="${XS_TURNS_URL:-https://delphi.cloudforest-kardashev.ts.net:8449/v1/events}"
CHAT_ID="${TELEGRAM_CHAT_ID:-8679391100}"
SCAN=200

if [ ! -r "$BOT_TOKEN_FILE" ]; then
  echo "xs-notify: bot token file not readable: $BOT_TOKEN_FILE" >&2
  exit 1
fi
BOT_TOKEN="$(tr -d '\r\n ' < "$BOT_TOKEN_FILE")"

if [ ! -r "$TOKEN_FILE" ]; then
  echo "xs-notify: xs token file not readable: $TOKEN_FILE" >&2
  exit 1
fi
XS_TOKEN="$(tr -d '\r\n ' < "$TOKEN_FILE")"

# Fetch current turns
if ! RESP=$(curl -sS --max-time 15 \
     -H "Authorization: Bearer $XS_TOKEN" \
     "$XS_URL?limit=$SCAN" 2>/dev/null); then
  echo "xs-notify: no answer from xs API at $XS_URL" >&2
  exit 2
fi

# Hash + compare
NEW_SHA=$(printf '%s' "$RESP" | sha1sum | awk '{print $1}')
OLD_SHA=""
[ -f "$STATE_FILE" ] && OLD_SHA=$(cat "$STATE_FILE")

if [ "$NEW_SHA" = "$OLD_SHA" ]; then
  exit 0
fi

# Detect changed / new turns
CHANGED=""
if [ -f "$JSON_FILE" ]; then
  CHANGED=$(jq -c --argfile old "$JSON_FILE" '
    ($old.events | map({(.id): .outcome}) | add // {}) as $old_outcomes |
    [.events[] | select($old_outcomes[.id] == null or $old_outcomes[.id] != .outcome)]
  ' <<< "$RESP" 2>/dev/null || echo "[]")
fi

if [ -z "$CHANGED" ] || [ "$CHANGED" = "[]" ] || [ "$CHANGED" = "null" ]; then
  CHANGED=$(jq -c '[.events[0]]' <<< "$RESP" 2>/dev/null || echo "[]")
fi

COUNT=$(jq 'length' <<< "$CHANGED" 2>/dev/null || echo 0)
echo "xs-notify: change detected ($COUNT changed turn(s), new sha1 $NEW_SHA)"

# Send Telegram alert for each changed turn (up to 5)
echo "$CHANGED" | jq -c '.[:5][]' | while read -r event; do
  TEXT=$(jq -r '"xs turn changed: \(.subject) → \(.outcome) — \(.action)"' <<< "$event" | head -c 4000)
  PAYLOAD=$(jq -cn --arg chat_id "$CHAT_ID" --arg text "$TEXT" '{chat_id: ($chat_id | tonumber), text: $text}')
  
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null || echo "000")
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "xs-notify: sent Telegram alert for $(jq -r '.subject' <<< "$event")"
  else
    echo "xs-notify: failed to send Telegram alert (HTTP $HTTP_CODE)" >&2
  fi
done

# Persist state
mkdir -p "$STATE_DIR"
printf '%s' "$NEW_SHA" > "$STATE_FILE"
printf '%s' "$RESP" > "$JSON_FILE"
echo "xs-notify: state updated to sha1 $NEW_SHA"
