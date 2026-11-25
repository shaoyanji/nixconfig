#!/usr/bin/env bash
# pane-poll — one xs read for every pane's status, replacing N tmux scrapes.
#
# The watcher used to `capture-pane` each lane to learn what it was doing; the
# ledger already holds that — the newest unresolved turn per subject IS the
# pane's state. One `agents:xs:list LIVE=1` call returns them all.
#
# stdout: one row per live subject — `subject | source | outcome | age | text`
# Exit: 0 live turns exist · 1 nothing live · 2 no ledger answer.
set -euo pipefail

die() { printf 'pane-poll: %s\n' "$*" >&2; exit 2; }
ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"

out=$(task agents:xs:list LIVE=1 FORMAT=json 2>/dev/null) ||
  die "no ledger answer (endpoint down or no token)"

n=$(jq '.live | length' <<<"$out")
[ "${n:-0}" -gt 0 ] || { echo "pane-poll: nothing live"; exit 1; }

now=$(date +%s)
printf 'SUBJECT | SRC | OUTCOME | AGE | TEXT\n'
jq -r '.live[] | [.subj, .src, .kind, .ts, .text] | @tsv' <<<"$out" |
  while IFS=$'\t' read -r subj src kind ts text; do
    # .ts arrives as YYYY-MM-DDTHH:MM (UTC) — age in minutes, ledger-side.
    epoch=$(date -u -d "${ts}:00" +%s 2>/dev/null || echo "$now")
    age=$(( (now - epoch) / 60 ))
    printf '%s | %s | %s | %sm | %.60s\n' "$subj" "$src" "$kind" "$age" "$text"
  done
