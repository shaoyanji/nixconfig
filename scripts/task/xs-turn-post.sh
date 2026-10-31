#!/usr/bin/env bash
# Post one xs turn. The body comes from scripts/task/xs-turn.jq, never from a
# caller: the template owns the field set, id/ts/source/git context are filled in,
# and the prose arrives as environment variables (task-level `env:`), so a quote,
# a backtick or a $( ) in a rationale never reaches a shell.
#
# Task: agents:xs:post · protocol: docs/agent-turns.md · skill: xs-turns
# Exit: 0 stored (201) or already stored (200) · 2 bad input, nothing sent ·
#       3 no usable token · 4 transport · 5 the shim rejected the entry
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEMPLATE=${XS_TURN_TEMPLATE:-$ROOT/scripts/task/xs-turn.jq}
URL=${XS_TURNS_URL:-https://delphi.cloudforest-kardashev.ts.net:8449}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/agent-turns
BODY=$STATE_DIR/last-turn.json

# The codes are spelled out literally (`exit N`, not `exit "$code"`) because
# `checks:tasks` compares the codes a summary promises against the codes a script
# literally emits, and a variable reads as no contract at all.
fail() {
  local code=$1
  shift
  printf 'xs-turn: %s\n' "$*" >&2
  case $code in
  2) exit 2 ;;
  3) exit 3 ;;
  *) exit 4 ;;
  esac
}

cap() { # cap <field> <value> <limit>
  [ "${#2}" -le "$3" ] || fail 2 "$1 is ${#2} characters; the shim allows $3"
}

# --- input -------------------------------------------------------------------
subject=${SUBJECT:-}
action=${ACTION:-}
rationale=${RATIONALE:-}
outcome=${OUTCOME:-done}
source_name=${SOURCE:-$(whoami)}
files=${FILES:-}
commits=${COMMITS:-}
claims=${CLAIMS:-}
id=${ID:-$(cat /proc/sys/kernel/random/uuid)}
ts=${TS:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}

[ -n "$subject" ] || fail 2 'SUBJECT is required: <repo>:<task-id>'
case $subject in
:* | *:) fail 2 "SUBJECT needs both halves of <repo>:<task-id>, got: $subject" ;;
*:*) ;;
*) fail 2 "SUBJECT must be <repo>:<task-id>, got: $subject" ;;
esac
[ -n "${action// /}" ] || fail 2 'ACTION is required: one line of what landed'

cap source "$source_name" 64
cap subject "$subject" 200
cap action "$action" 500
cap rationale "$rationale" 1000
cap outcome "$outcome" 300

[[ $source_name =~ ^[A-Za-z0-9._-]+$ ]] ||
  fail 2 "SOURCE must be letters, digits, dot, dash or underscore: $source_name"
[[ $outcome =~ ^(done|in_progress|blocked|failed)(: .+)?$ ]] ||
  fail 2 "OUTCOME must be done, in_progress, blocked: <why> or failed: <why>: $outcome"
[[ $id =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] ||
  fail 2 "ID must be a client-generated UUID: $id"
[[ $ts =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  fail 2 "TS must look like 2026-10-31T09:00:00Z: $ts"

# Filled in, not remembered: the commit the turn started from and the branch it
# is on. Override them when the work landed on another branch or base.
base_commit=${BASE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)}
branch=${BRANCH:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)}
if [ -n "$base_commit" ] && [[ ! $base_commit =~ ^[0-9a-f]{7,40}$ ]]; then
  fail 2 "BASE_COMMIT must be a git hash: $base_commit"
fi
if [ -n "$branch" ] && [[ ! $branch =~ ^[A-Za-z0-9._/-]+$ ]]; then
  fail 2 "BRANCH must be a branch name: $branch"
fi

# --- body --------------------------------------------------------------------
mkdir -p "$STATE_DIR"
body=$(jq -n -f "$TEMPLATE" \
  --arg id "$id" \
  --arg ts "$ts" \
  --arg source "$source_name" \
  --arg subject "$subject" \
  --arg action "$action" \
  --arg rationale "$rationale" \
  --arg base_commit "$base_commit" \
  --arg branch "$branch" \
  --arg files "$files" \
  --arg commits "$commits" \
  --arg claims "$claims" \
  --arg outcome "$outcome") || fail 2 "the template could not render: $TEMPLATE"

# Kept on disk: it is what the documented queue fallback appends, and a retry
# with the same id is a safe no-op.
printf '%s\n' "$body" >"$BODY"
bytes=$(printf '%s' "$body" | wc -c | tr -d ' ')
[ "$bytes" -le 16384 ] || fail 2 "body is $bytes bytes, the shim's limit is 16384 (kept at $BODY)"

# --- token -------------------------------------------------------------------
token=${AGENT_TURNS_TOKEN:-}
if [ -z "$token" ]; then
  command -v sops >/dev/null || fail 3 'no AGENT_TURNS_TOKEN and sops is not on PATH'
  token=$(sops -d "$ROOT/modules/secrets.yaml" | yq -r '.["agent-turns-token"]') ||
    fail 3 'could not read agent-turns-token from modules/secrets.yaml'
fi
[ "${#token}" -ge 32 ] || fail 3 'the agent-turns token is missing or too short'

# --- post --------------------------------------------------------------------
resp=$(mktemp "${TMPDIR:-/tmp}/xs-turn-resp.XXXXXX")
trap 'rm -f "$resp"' EXIT

code=$(curl -sS --max-time 15 \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -X POST --data-binary "@$BODY" \
  -o "$resp" -w '%{http_code}' "$URL/v1/events") || {
  printf 'xs-turn: no answer from %s\n' "$URL" >&2
  printf '  the body is at %s\n' "$BODY" >&2
  printf '  fallback: cat %s >> %s/queue.jsonl   (replay when it answers; a repeated UUID returns 200)\n' \
    "$BODY" "$STATE_DIR" >&2
  exit 4
}

case $code in
201 | 200) ;;
400 | 401 | 405)
  { jq -r '.error // .message // .' "$resp" 2>/dev/null || cat "$resp"; } >&2
  printf 'xs-turn: rejected (http %s); the body is kept at %s\n' "$code" "$BODY" >&2
  exit 5
  ;;
*)
  printf 'xs-turn: unexpected http %s\n' "$code" >&2
  cat "$resp" >&2
  exit 4
  ;;
esac

printf 'http      %s%s\n' "$code" "$([ "$code" = 200 ] && printf ' (already stored)' || true)"
jq -r '"frame     \(.id)", "client    \(.client_uuid)"' "$resp" 2>/dev/null || true
printf 'subject   %s\noutcome   %s\n' "$subject" "$outcome"
