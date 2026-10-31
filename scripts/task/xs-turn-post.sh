#!/usr/bin/env bash
# Post one xs turn. The body comes from scripts/task/xs-turn.jq, never from a
# caller: the template owns the field set, id/ts/source/git context are filled in,
# and the prose arrives as environment variables (task-level `env:`), so a quote,
# a backtick or a $( ) in a rationale never reaches a shell.
#
# Transport is not the caller's problem: an unreachable endpoint appends the body
# to ~/.local/state/agent-turns/queue.jsonl and the next run that reaches the shim
# replays it, oldest first (the UUID is the dedup key, so replay is idempotent).
#
# Task: agents:xs:post · protocol: docs/agent-turns.md · skill: xs-turns
# Exit: 0 stored (201), already stored (200), or an earlier queued entry replayed
#       on this run · 2 bad input, nothing sent · 3 no usable token · 4 transport
#       (the body is queued, not lost) · 5 the shim rejected the entry
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
# A shape check is not enough: a hand-typed override with the right number of hex
# digits records a base that does not exist, which is worse than none. Resolve it
# against the object database when the hash is an override.
if [ -n "$base_commit" ] && [[ ! $base_commit =~ ^[0-9a-f]{7,40}$ ]]; then
  fail 2 "BASE_COMMIT must be a git hash: $base_commit"
fi
if [ -n "${BASE_COMMIT:-}" ] && ! git -C "$ROOT" cat-file -e "$base_commit^{commit}" 2>/dev/null; then
  fail 2 "BASE_COMMIT is not a commit in this clone: $base_commit"
fi
if [ -n "$branch" ] && [[ ! $branch =~ ^[A-Za-z0-9._/-]+$ ]]; then
  fail 2 "BRANCH must be a branch name: $branch"
fi

# --- body --------------------------------------------------------------------
mkdir -p "$STATE_DIR"
# Compact on purpose: the file this writes is one JSONL line, so it is both the
# wire body and a queue entry. `jq .` reindents it for a human.
body=$(jq -n -c -f "$TEMPLATE" \
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

# --- post, with the queue in the same path -----------------------------------
# A transport failure is not the caller's problem to solve: the body is already on
# disk, so it is appended to the queue and replayed, oldest first, on the next run
# that reaches the endpoint. Blind replay is safe because the UUID is the dedup
# key — a repeated id returns 200 and stores nothing twice.
QUEUE=$STATE_DIR/queue.jsonl
REJECTED=$STATE_DIR/queue.rejected.jsonl
resp=$(mktemp "${TMPDIR:-/tmp}/xs-turn-resp.XXXXXX")
pending=$(mktemp "${TMPDIR:-/tmp}/xs-turn-pending.XXXXXX")
trap 'rm -f "$resp" "$pending"' EXIT

# One poster at a time per machine: two agents replaying the same queue would
# interleave the rewrite and hand each other a body mid-flight.
if command -v flock >/dev/null; then
  exec 9>"$STATE_DIR/.post.lock"
  flock -w 30 9 || fail 4 "another post holds $STATE_DIR/.post.lock"
fi

post() { # post <body-file>: prints the http code; non-zero means no answer
  curl -sS --max-time 15 \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -X POST --data-binary "@$1" \
    -o "$resp" -w '%{http_code}' "$URL/v1/events"
}

queue_depth() { # lines pending, 0 when the file is absent or empty
  [ -s "$QUEUE" ] || { printf '0'; return 0; }
  grep -c . "$QUEUE" || true
}

# Replay what an earlier run could not deliver, in order. 400 is poison: the shim
# will never accept that line, so it moves aside instead of blocking the queue.
replay_queue() {
  replayed=0
  [ -s "$QUEUE" ] || return 0
  mapfile -t lines <"$QUEUE"
  leftover=$STATE_DIR/.queue.$$
  : >"$leftover"
  i=0
  while [ "$i" -lt "${#lines[@]}" ]; do
    line=${lines[$i]}
    i=$((i + 1))
    [ -n "$line" ] || continue
    printf '%s\n' "$line" >"$pending"
    if ! code=$(post "$pending"); then
      # Still no endpoint: keep this line and everything after it, untouched.
      printf '%s\n' "$line" >>"$leftover"
      if [ "$i" -lt "${#lines[@]}" ]; then
        printf '%s\n' "${lines[@]:$i}" >>"$leftover"
      fi
      mv "$leftover" "$QUEUE"
      return 1
    fi
    case $code in
    201 | 200) replayed=$((replayed + 1)) ;;
    400) printf '%s\n' "$line" >>"$REJECTED" ;;
    *) printf '%s\n' "$line" >>"$leftover" ;;
    esac
  done
  mv "$leftover" "$QUEUE"
  return 0
}

if ! replay_queue; then
  printf 'xs-turn: the endpoint still does not answer; %s queued turn(s) kept\n' "$(queue_depth)" >&2
fi

if ! code=$(post "$BODY"); then
  printf '%s\n' "$body" >>"$QUEUE"
  printf 'xs-turn: no answer from %s — queued (%s pending)\n' "$URL" "$(queue_depth)" >&2
  printf '  this run did not reach the log; the next successful run replays it\n' >&2
  exit 4
fi

case $code in
201 | 200) ;;
400 | 401 | 405)
  { jq -r '.error // .message // .' "$resp" 2>/dev/null || cat "$resp"; } >&2
  printf 'xs-turn: rejected (http %s); the body is kept at %s\n' "$code" "$BODY" >&2
  exit 5
  ;;
*)
  printf '%s\n' "$body" >>"$QUEUE"
  printf 'xs-turn: unexpected http %s — queued (%s pending)\n' "$code" "$(queue_depth)" >&2
  exit 4
  ;;
esac

printf 'http      %s%s\n' "$code" "$([ "$code" = 200 ] && printf ' (already stored)' || true)"
jq -r '"frame     \(.id)", "client    \(.client_uuid)"' "$resp" 2>/dev/null || true
printf 'subject   %s\noutcome   %s\n' "$subject" "$outcome"
if [ "$replayed" -gt 0 ]; then printf 'replayed  %s queued turn(s)\n' "$replayed"; fi
if [ -s "$REJECTED" ]; then
  printf 'rejected  %s poisoned line(s) in %s\n' "$(grep -c . "$REJECTED")" "$REJECTED"
fi
