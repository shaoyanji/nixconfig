#!/usr/bin/env bash
# Read side of the xs turn log: recent turns, the live claims among them, and a
# verdict for the subject or the areas you are about to touch.
#
# Rendering lives in scripts/task/xs-turn-list.jq, which also states the rule for
# "live" once: the NEWEST entry per subject that says in_progress.
#
# Task: agents:xs:list · protocol: docs/agent-turns.md · skill: xs-turns
# Exit: 0 nothing live for what was asked · 1 a live claim on SUBJECT, or a live
#       claim overlapping CLAIM · 2 no usable token, bad LIMIT, or no answer
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEMPLATE=${XS_TURN_LIST_TEMPLATE:-$ROOT/scripts/task/xs-turn-list.jq}
URL=${XS_TURNS_URL:-https://delphi.cloudforest-kardashev.ts.net:8449}

limit=${LIMIT:-20}
repo=${REPO:-}
subject=${SUBJECT:-}
source_name=${SOURCE:-}
claim=${CLAIM:-}
format=${FORMAT:-table}

unreadable() {
  printf 'xs-list: %s\n' "$*" >&2
  exit 2
}

case $limit in
'' | *[!0-9]*) unreadable "LIMIT must be a number 1-200: $limit" ;;
esac
[ "$limit" -ge 1 ] && [ "$limit" -le 200 ] || unreadable "LIMIT must be between 1 and 200: $limit"
case $format in
table | json) ;;
*) unreadable "FORMAT must be table or json: $format" ;;
esac

query=$(jq -rn \
  --arg limit "$limit" --arg repo "$repo" --arg subject "$subject" --arg source "$source_name" '
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

rendered=$(jq -r -f "$TEMPLATE" --arg subject "$subject" --arg claim "$claim" <<<"$resp") ||
  unreadable 'could not render the response; is xs-turn-list.jq intact?'

status=$(printf '%s\n' "$rendered" | sed -n 's/^status\t//p')

if [ "$format" = "json" ]; then
  jq '.count, .events' <<<"$resp"
else
  printf '%s\n' "$rendered" | sed '/^status\t/d'
fi

case $status in
live) exit 1 ;;
*) exit 0 ;;
esac
