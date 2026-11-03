#!/usr/bin/env bash
# Read side of the xs turn log: recent turns, the live claims among them, and a
# verdict for the subject or the areas you are about to touch.
#
# Rendering lives in scripts/task/xs-turn-list.jq, which also states the rule for
# "live" once: the NEWEST entry per subject that is in_progress, blocked or
# failed. A blocked subject is a decision waiting on a human, so it is open work.
#
# Task: agents:xs:list · protocol: docs/agent-turns.md · skill: xs-turns
# Exit: 0 nothing live for what was asked · 1 a live claim on SUBJECT, or a live
#       claim overlapping CLAIM · 2 no usable token, bad LIMIT, or no answer
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEMPLATE=${XS_TURN_LIST_TEMPLATE:-$ROOT/scripts/task/xs-turn-list.jq}
URL=${XS_TURNS_URL:-https://delphi.cloudforest-kardashev.ts.net:8449}

limit=${LIMIT:-20}
repo=${REPO:-}
subject=${SUBJECT:-}
source_name=${SOURCE:-}
claim=${CLAIM:-}
stale_days=${STALE_DAYS:-7}
live_only=${LIVE:-}
# TOON is the default because the reader is an agent; a person asks for table.
format=${FORMAT:-toon}
# The scan is always the endpoint's cap, not the display limit: a live claim older
# than the last 20 turns is exactly the one that hurts, and the shim scans the log
# for a filtered query. LIMIT= is how many rows to show.
scan=200

unreadable() {
  printf 'xs-list: %s\n' "$*" >&2
  exit 2
}

case $limit in
'' | *[!0-9]*) unreadable "LIMIT must be a number 1-200: $limit" ;;
esac
[ "$limit" -ge 1 ] && [ "$limit" -le 200 ] || unreadable "LIMIT must be between 1 and 200: $limit"
case $stale_days in
'' | *[!0-9]*) unreadable "STALE_DAYS must be a number: $stale_days" ;;
esac
[ "$stale_days" -ge 1 ] || unreadable "STALE_DAYS must be at least 1: $stale_days"
case $live_only in
'' | 0 | 1) ;;
*) unreadable "LIVE must be 1 or empty: $live_only" ;;
esac
case $format in
table | json | toon) ;;
*) unreadable "FORMAT must be toon, table or json: $format" ;;
esac

query=$(jq -rn \
  --arg limit "$scan" --arg repo "$repo" --arg subject "$subject" --arg source "$source_name" '
  "limit=\($limit)"
  + (if $repo != "" then "&repo=\($repo | @uri)" else "" end)
  + (if $subject != "" then "&subject=\($subject | @uri)" else "" end)
  + (if $source != "" then "&source=\($source | @uri)" else "" end)')

token=${AGENT_TURNS_TOKEN:-}
if [ -z "$token" ]; then
  command -v sops >/dev/null || unreadable 'no AGENT_TURNS_TOKEN and sops is not on PATH'
  token=$(sops -d "$ROOT/modules/secrets.yaml" | yq -r '.["agent-turns-token"]') ||
    unreadable 'could not read agent-turns-token from modules/secrets.yaml'
fi
[ "${#token}" -ge 32 ] || unreadable 'the agent-turns token is missing or too short'

if ! resp=$(curl -sS --max-time 15 -H "Authorization: Bearer $token" "$URL/v1/events?$query"); then
  unreadable "no answer from $URL — check the MagicDNS name and that the shim is up"
fi
case $resp in
'{'*) ;;
*) unreadable "the endpoint did not return a JSON object: $(printf '%s' "$resp" | head -c 120)" ;;
esac

cutoff=$(date -u -d "-${stale_days} days" +%Y-%m-%dT%H:%M:%SZ)
rendered=$(jq -r -f "$TEMPLATE" \
  --arg subject "$subject" --arg claim "$claim" \
  --argjson display "$limit" --arg cutoff "$cutoff" \
  --arg staleDays "$stale_days" --arg liveonly "$live_only" <<<"$resp") ||
  unreadable 'could not render the response; is xs-turn-list.jq intact?'

status=$(printf '%s\n' "$rendered" | sed -n 's/^status\t//p')

case $format in
json) jq -c '{count, scanned, truncated, events}' <<<"$resp" ;;
toon) jq -c '{count, scanned, truncated, events}' <<<"$resp" | toon -e ;;
*) printf '%s\n' "$rendered" | sed '/^status\t/d' ;;
esac

case $status in
live) exit 1 ;;
*) exit 0 ;;
esac
