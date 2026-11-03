#!/usr/bin/env bash
# The unposted side of the xs turn log: what could not reach the endpoint, and why
# something was refused. Read-only — the post path is what drains the queue, and
# `agents:xs:post` replays it oldest-first before posting its own body.
#
# Task: agents:xs:queue · protocol: docs/agent-turns.md · skill: xs-turns
# Exit: 0 always when the state directory is readable (an empty queue is an
#       answer), 2 when a file exists but does not parse.
set -euo pipefail

dir=${AGENT_TURNS_STATE:-$HOME/.local/state/agent-turns}
queue=$dir/queue.jsonl
rejected=$dir/queue.rejected.jsonl

unreadable() {
  printf 'xs-queue: %s\n' "$*" >&2
  exit 2
}

depth=0
if [ -f "$queue" ]; then
  depth=$(grep -c . "$queue" || true)
fi

bad=0
if [ -f "$rejected" ]; then
  bad=$(grep -c . "$rejected" || true)
fi

printf 'state    %s\n' "$dir"
printf 'queued   %s\n' "$depth"
printf 'rejected %s\n' "$bad"

if [ "$depth" -gt 0 ]; then
  # An unposted turn is evidence that a subject has no entry yet: sorting by ts
  # says how far behind the log is, which is the number worth acting on.
  oldest=$(jq -rs 'map(.ts) | sort | first' <"$queue" 2>/dev/null) ||
    unreadable 'queue.jsonl does not parse as one JSON object per line'
  subject=$(jq -rs 'sort_by(.ts) | first | .subject' <"$queue" 2>/dev/null || true)
  printf 'oldest   %s\n' "$oldest"
  printf 'subject  %s\n' "$subject"
  printf 'drain    task agents:xs:post SUBJECT=<next subject> (replays the queue first)\n'
fi

if [ "$bad" -gt 0 ]; then
  last=$(jq -rsc 'last | {subject, outcome, ts}' <"$rejected" 2>/dev/null) ||
    unreadable 'queue.rejected.jsonl does not parse'
  printf 'last-rejected %s\n' "$last"
  printf 'note     a 400 is usually the credential word scan; the body is kept here, unposted\n'
fi

exit 0
