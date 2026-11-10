#!/usr/bin/env bash
# Read side of the xs turn log: find turns (Q= is the grep the ledger used to
# give), see the live claims among them, and get a verdict for the subject or the
# areas you are about to touch.
#
# One renderer, three shapes: `toon` (the agent default, compact rows), `text`
# (a person: two lines per turn), `json` (the whole model, for a program).
# Editing lives in scripts/task/xs-turn-query.jq, which also states the "live"
# rule once: the NEWEST entry per subject that is in_progress, blocked or failed.
#
# Task: agents:xs:list · protocol: docs/agent-turns.md · skill: xs-turns
# Exit: 0 nothing live for what was asked · 1 a live claim on SUBJECT, or a live
#       claim overlapping CLAIM · 2 no usable token, bad input, or no answer
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEMPLATE=${XS_TURN_QUERY_TEMPLATE:-$ROOT/scripts/task/xs-turn-query.jq}
URL=${XS_TURNS_URL:-https://delphi.cloudforest-kardashev.ts.net:8449}

limit=${LIMIT:-20}
repo=${REPO:-}
subject=${SUBJECT:-}
source_name=${SOURCE:-}
claim=${CLAIM:-}
q=${Q:-}
id=${ID:-}
stale_days=${STALE_DAYS:-7}
live_only=${LIVE:-}
# TOON is the default because the reader is an agent; a person asks for text.
format=${FORMAT:-toon}
# The scan is the endpoint's cap, not the display limit: a turn from last month
# is exactly the one that is missed. LIMIT= is how many rows to show.
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
text | json | toon) ;;
*) unreadable "FORMAT must be toon, text or json: $format" ;;
esac

# A filtered read is how an old turn is found at all; the shim scans 2000 frames
# for a query carrying a filter, so pass one even when Q= is the only restriction.
query=$(jq -rn \
  --arg limit "$scan" --arg repo "$repo" --arg subject "$subject" --arg source "$source_name" '
  "limit=\($limit)"
  + (if $repo != "" then "&repo=\($repo | @uri)" else "" end)
  + (if $subject != "" then "&subject=\($subject | @uri)" else "" end)
  + (if $source != "" then "&source=\($source | @uri)" else "" end)')

. "${BASH_SOURCE[0]%/*}/lib/paths.sh"

token=${AGENT_TURNS_TOKEN:-}
if [ -z "$token" ]; then
  command -v sops >/dev/null || unreadable 'no AGENT_TURNS_TOKEN and sops is not on PATH'
  token=$(secret_get '["agent-turns-token"]') ||
    unreadable 'could not read agent-turns-token from sops (submodule checked out? age key?)'
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
model=$(jq -c -f "$TEMPLATE" \
  --arg repo "$repo" --arg subject "$subject" --arg source "$source_name" \
  --arg q "$q" --arg id "$id" --arg claim "$claim" \
  --argjson display "$limit" --arg cutoff "$cutoff" \
  --arg staleDays "$stale_days" --arg liveonly "$live_only" <<<"$resp") ||
  unreadable 'could not render the response; is xs-turn-query.jq intact?'

case $format in
json) printf '%s\n' "$model" ;;
toon) printf '%s\n' "$model" | toon -e ;;
text)
  # A person reads the header, one two-line block per turn, then the claims and
  # the verdict — the same model, laid out instead of encoded.
  printf '%s\n' "$model" | jq -r '
    "\(.turns | length) shown · \(.matched) matched · \(.stored) stored"
      + (if .q.text != "" then "  q=\"\(.q.text)\"" else "" end)
      + (if .q.subject != "" then "  subject=\(.q.subject)" else "" end)
      + (if .q.claim != "" then "  claim=\(.q.claim)" else "" end)
      + "  scanned \(.scanned)"
      + (if .truncated then "  SCAN CAPPED — older turns were not examined" else "" end),
    "",
    (if (.turns | length) == 0
     then "  (nothing matches — widen REPO, drop SUBJECT, or use fewer words in Q)"
     else (.turns[] |
       "\(.ts)  \(.src)  \(.out)  \(.subj)",
       ("  " + .act),
       (if .snip != "" and (.hit | test("rationale|claims|files|outcome"))
        then ("  [" + .hit + "] " + .snip) else empty end),
       (if .claims != "" then ("  claims: " + .claims) else empty end),
       (if .files > 0 then ("  files: \(.files)") else empty end))
     end),
    "",
    "== live claims (newest entry per subject unresolved, inside \(.stale_days) days)",
    (if (.live | length) == 0 then "  none"
     else (.live[] | "  \(.ts)  \(.subj)  \(.src)  \(.kind)  \(.text)") end),
    (if (.stale | length) == 0 then empty else
      "== stale (unresolved with no newer entry; abandoned until someone posts an update)",
      (.stale[] | "  \(.ts)  \(.subj)  \(.src)  \(.kind)  \(.text)") end),
    "",
    "== verdict",
    "\(.verdict.state)  \(.verdict.text)"
  '
  ;;
esac

case $(printf '%s\n' "$model" | jq -r '.verdict.state') in
live) exit 1 ;;
*) exit 0 ;;
esac
