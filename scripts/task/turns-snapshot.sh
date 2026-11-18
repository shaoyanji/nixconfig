#!/usr/bin/env bash
# turns-snapshot.sh — refresh the committed view of the agent-turn ledger.
#
# Why a file and not a fetch in Nix: the shim authenticates with a bearer header,
# which `builtins.fetchurl` cannot send, and a build sandbox has no network at
# all. The public mount answers 404 for the JSON. So the one thing Nix can read is
# a file in the tree, and the pin is what keeps it honest: `pin` is the sha256 of
# the sorted frame ids, recomputed at eval by `lib/agent-turns.nix`, so editing an
# id by hand fails `.#agentTurns` instead of quietly changing the graph.
#
# Appending is the only allowed edit: a refresh that would drop a frame the
# committed snapshot already holds is refused, because the ledger is append-only
# and a shrinking view of it is a different claim.
#
# Env
#   OUT=      destination (default lib/agent-turns/turns.json)
#   LIMIT=    newest frames to read, 1-200 (default 200)
#   XS_TURNS_URL=  endpoint override
#
# Task: agents:turns:snapshot
# Exit: 0 written · 1 the shim would lose a frame · 2 no token or a bad response
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${OUT:-$ROOT/lib/agent-turns/turns.json}
LIMIT=${LIMIT:-200}
URL=${XS_TURNS_URL:-https://delphi.cloudforest-kardashev.ts.net:8449}

case $LIMIT in
'' | *[!0-9]*) printf 'turns-snapshot: LIMIT must be a number 1-200: %s\n' "$LIMIT" >&2; exit 2 ;;
esac
[ "$LIMIT" -ge 1 ] && [ "$LIMIT" -le 200 ] || { printf 'turns-snapshot: LIMIT must be 1-200\n' >&2; exit 2; }

. "$ROOT/scripts/task/lib/paths.sh"
token=${AGENT_TURNS_TOKEN:-}
if [ -z "$token" ]; then
  token=$(secret_get '["agent-turns-token"]') || {
    printf 'turns-snapshot: no AGENT_TURNS_TOKEN and no agent-turns-token in sops\n' >&2
    exit 2
  }
fi
[ "${#token}" -ge 32 ] || { printf 'turns-snapshot: the token is missing or too short\n' >&2; exit 2; }

resp=$(curl -sS --max-time 20 -H "Authorization: Bearer $token" "$URL/v1/events?limit=$LIMIT") || {
  printf 'turns-snapshot: no answer from %s\n' "$URL" >&2
  exit 2
}
case $resp in
'{'*) ;;
*) printf 'turns-snapshot: not a JSON object: %s\n' "$(printf '%s' "$resp" | head -c 120)" >&2; exit 2 ;;
esac

turns=$(printf '%s\n' "$resp" | jq -c '
  [.events[] | {id, ts, source, subject, action, outcome,
                claims: (.claims // []), files: (.files_changed // []),
                base_commit, branch, frame: ._frame}]') || {
  printf 'turns-snapshot: could not normalise the response\n' >&2
  exit 2
}

export LC_ALL=C
new_ids=$(printf '%s' "$turns" | jq -r '.[].id' | sort)
if [ -f "$OUT" ]; then
  gone=$(comm -23 <(jq -r '.turns[].id' "$OUT" | sort) <(printf '%s\n' "$new_ids") | head -3 | tr '\n' ' ')
  if [ -n "${gone// /}" ]; then
    printf 'turns-snapshot: refusing to drop frames the snapshot already holds: %s\n' "$gone" >&2
    exit 1
  fi
fi

count=$(printf '%s' "$turns" | jq 'length')
pin=$(printf '%s\n' "$new_ids" | sha256sum | cut -d' ' -f1)

mkdir -p "$(dirname "$OUT")"
jq -n --argjson turns "$turns" --argjson count "$count" --arg pin "$pin" \
  --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{generated: $generated, count: $count, pin: $pin, turns: $turns}' >"$OUT.tmp"
mv "$OUT.tmp" "$OUT"
printf 'turns-snapshot: %s turns, pin %s → %s\n' "$count" "${pin:0:12}" "${OUT#"$ROOT"/}"
