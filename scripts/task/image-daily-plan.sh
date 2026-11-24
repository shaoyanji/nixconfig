#!/usr/bin/env bash
# image-daily-plan.sh — what is due today, and what it would cost
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"



# --- subcommands ------------------------------------------------------------

cmd_plan() {
  need jq cpg
  cli=$(image_daily_cli)
  "$cli" guard || die "briefs: a brief is not bank-ready (see above)"
  local rem lane rows n total=0
  rem=$("$cli" remaining)
  [ -n "$rem" ] || die "cpg usage answered nothing — is the session alive? (cpg status --json)"
  say "allowance remaining: $rem"
  mapfile -t lane_list < <("$cli" lanes)
  for lane in "${lane_list[@]}"; do
    rows=$("$cli" due --lane "$lane") || rows=""
    n=$(printf '%s' "$rows" | grep -c . || true)
    total=$((total + n))
    printf '  %-6s due %2s  budget %2s  max_age %s d\n' "$lane" "$n" \
      "$("$cli" budget --lane "$lane")" "$("$cli" setting --lane "$lane" --key max_age_days)"
    [ "$n" -gt 0 ] && printf '%s\n' "$rows" | awk -F'\t' '{printf "         - %-22s %s\n", $1, $3}'
  done
  if [ "$rem" -ge 1000 ]; then
    printf '  leftover after the queue: unlimited on this plan (the hourly burst is the ceiling)\n'
  else
    printf '  leftover after the queue: %s (unspent unless STORYBOOK=1)\n' "$((rem - total))"
  fi
}

cmd_plan "$@"
