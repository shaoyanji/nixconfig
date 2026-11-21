#!/usr/bin/env bash
# fusion-check.sh — the turns-fusion-plane exit gate: count the source frames,
# the projected rows and the loaded notes, and fail when the projection drifts.
#
# The projection on frieren (scripts/task/turns-fuse.sh -> postgres.fleet) is
# cumulative and append-only: turn/claim/file counts are >= the latest snapshot,
# so equality is wrong — the honest assertions are non-empty tables, notes
# loaded, and db_max(ts) within one timer period of the snapshot's newest turn.
#
#   checks:fusion -> this script, TOON report; exit 0 fresh, 1 stale/empty,
#                    2 unreachable (visibly unchecked, never silently green)
set -euo pipefail

REPO=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
. "$REPO/scripts/task/toon-io.sh"
STALE_PAD="${FUSION_STALE_PAD:-93600}"   # one timer period + margin (26 h)

# --- source side -----------------------------------------------------------
check_out=$(cd "$REPO" && bash scripts/task/turns-fuse.sh --check)
src_turns=$(printf '%s' "$check_out" | awk '$1=="turns"{print $2}')
src_claims=$(printf '%s' "$check_out" | awk '$1=="claims"{print $2}')
src_files=$(printf '%s' "$check_out" | awk '$1=="files"{print $2}')
src_generated=$(printf '%s' "$check_out" | awk '$1=="generated"{print $2}')
snap_max=$(jq -r '[.turns[].ts] | max // ""' "$REPO/lib/agent-turns/turns.json")

# --- projection side --------------------------------------------------------
pg=$(ssh -o ConnectTimeout=8 -o BatchMode=yes frieren \
  'sudo -u postgres psql -d fleet -Atc "select (select count(*) from turn), (select count(*) from turn_claim), (select count(*) from turn_file), (select count(*) from note), coalesce((select max(ts) from turn)::text, chr(39)||chr(39))"' 2>/dev/null) || {
  jq -cn '{status:"unchecked", reason:"frieren postgres unreachable over ssh"}' | toon_emit
  exit 2
}
IFS='|' read -r db_turns db_claims db_files db_notes db_max_ts <<<"$pg"

# --- drift ------------------------------------------------------------------
if [ -n "$snap_max" ] && [ -n "$db_max_ts" ]; then
  lag=$(( $(date -d "$snap_max" +%s) - $(date -d "$db_max_ts" +%s) ))
else
  lag=-1
fi

status="fresh"
[ "$db_turns" -eq 0 ] && status="empty:turn"
[ "$db_notes" -eq 0 ] && status="empty:note"
[ "$lag" -gt "$STALE_PAD" ] && status="stale"
# the projection must contain the snapshot's newest turn once the timer ran;
# a lag within one period is the timer, not drift.
contains_latest=$(ssh -o ConnectTimeout=8 -o BatchMode=yes frieren \
  "sudo -u postgres psql -d fleet -Atc \"select count(*) from turn where ts >= '$snap_max'::timestamptz - interval '1 day'\"" 2>/dev/null || echo 0)

jq -cn \
  --arg status "$status" --argjson lag "$lag" --argjson pad "$STALE_PAD" \
  --argjson st "$src_turns" --argjson sc "$src_claims" --argjson sf "$src_files" \
  --arg gen "$src_generated" --arg smax "$snap_max" \
  --argjson dt "$db_turns" --argjson dc "$db_claims" --argjson df "$db_files" \
  --argjson dn "$db_notes" --arg dmax "$db_max_ts" --argjson cl "$contains_latest" \
  '{status:$status, lag_seconds:$lag, stale_after:$pad,
    source:{turns:$st, claims:$sc, files:$sf, generated:$gen, newest_ts:$smax},
    projection:{turn:$dt, turn_claim:$dc, turn_file:$df, note:$dn, max_ts:$dmax,
                rows_within_1d_of_snapshot:$cl}}' | toon_emit

[ "$status" = fresh ] && exit 0 || exit 1
