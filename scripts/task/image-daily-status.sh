#!/usr/bin/env bash
# image-daily-status.sh — [gate] per-lane freshness, exit 1 when a lane is stale
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


cmd_status() {
  need jq
  local stale=0 lane newest age max
  [ -f "$LEDGER" ] || { say "no ledger yet at $LEDGER"; exit 1; }
  select_lanes
  for lane in "${lane_list[@]}"; do
    newest=$(jq -r --arg l "$lane" 'select(.verdict == "keep" and .lane == $l) | .day' "$LEDGER" | sort | tail -1)
    max=$(lane_setting "$lane" max_age_days)
    if [ -z "$newest" ]; then
      printf '  %-6s never  stale\n' "$lane"
      stale=1
      continue
    fi
    age=$((($(epoch "$(today)") - $(epoch "$newest")) / 86400))
    if [ -n "$max" ] && [ "$age" -gt "$max" ]; then
      printf '  %-6s %s  %sd old (max %s)  STALE\n' "$lane" "$newest" "$age" "$max"
      stale=1
    else
      printf '  %-6s %s  %sd old (max %s)\n' "$lane" "$newest" "$age" "${max:-—}"
    fi
  done
  local parked=0 id rev
  while IFS=$'\t' read -r id rev; do
    if is_parked "$id" "$rev"; then parked=$((parked + 1)); fi
  done < <(jq -r '.briefs[] | [.id, (.rev // 1)] | @tsv' "$BRIEFS")
  [ "$parked" -eq 0 ] ||
    printf '  %-6s %s brief(s) parked: %s rejections without a keep\n' "" "$parked" "$PARK_AFTER"
  printf '  remaining today: %s\n' "$(remaining 2>/dev/null || echo '?')"
  exit "$stale"
}

cmd_status "$@"
