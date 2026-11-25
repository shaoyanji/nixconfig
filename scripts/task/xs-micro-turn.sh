#!/usr/bin/env bash
# xs-micro-turn — a turn small enough to be a route, not a brief.
#
# The watcher used to paste full task prose into every pane. A micro-turn is
# the same ledger row with the fat trimmed: SUBJECT carries repo + task id,
# CLAIM the paths, ACTION one line a pane can read as the route. The pane
# pulls the full frame from xs itself; nothing else rides along.
#
# Env:  SUBJECT=<repo>:<id>   ACTION=<one line, <=72 chars>
#       CLAIM=<paths,csv>     OUTCOME=in_progress|done|blocked:|failed:
#       SOURCE=<agent> (default: micro-turn)  RATIONALE= (only when needed)
# Exit: the xs-post exit (2 bad input, 3 no token, 4 queued, 5 rejected).
#
# Transport stays `task agents:xs:post` — this renders through the same
# scripts/task/xs-turn.jq schema, no second turn format exists.
set -euo pipefail

die() { printf 'xs-micro-turn: %s\n' "$*" >&2; exit 2; }

subject=${SUBJECT:-}
action=${ACTION:-}
claim=${CLAIM:-}
outcome=${OUTCOME:-in_progress}
source_name=${SOURCE:-micro-turn}
rationale=${RATIONALE:-}

[ -n "$subject" ] || die "SUBJECT=<repo>:<id> is required"
case "$subject" in *:*) ;; *) die "SUBJECT needs the <repo>:<id> form" ;; esac
[ -n "$action" ] || die "ACTION is required — one line the pane can route on"

# One line, hard cap: past ~60 chars the action stops being a route token and
# starts being a brief, which is the burn this scheme exists to end.
action=$(printf '%s' "$action" | tr '\n' ' ')
if [ "${#action}" -gt 72 ]; then
  action=${action:0:69}…
  printf 'xs-micro-turn: ACTION truncated to 72 chars\n' >&2
fi

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"

SUBJECT="$subject" ACTION="$action" OUTCOME="$outcome" SOURCE="$source_name" \
  CLAIMS="$claim" RATIONALE="$rationale" \
  exec task agents:xs:post
