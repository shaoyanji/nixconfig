#!/usr/bin/env bash
# image-daily-today.sh — the day's allowance, the next slot's share, roster rows waiting
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


# What the day still holds, in one readout: the allowance, the share the next slot
# takes, and how many roster rows are waiting for it. Read-only — it asks the pool
# and the user timer table, and spends nothing.

cmd_today() {
  need jq
  local day left limit roster pending units total n next_at wrapper reserve cap
  roster=${ROSTER:-$repo/lib/image-daily/plates.txt}
  day=$(today)
  left=$(remaining)
  [ -n "$left" ] || die "usage unreadable (401 from cpg) — run cpg refresh, or chatplayground-go login when the session itself is gone"

  printf '%s\n' "$day"
  if [ "$left" -ge 1000 ]; then
    printf '  allowance   unlimited on this plan; the hourly burst (25) is the ceiling\n'
  else
    limit=$(cpg usage --json 2>/dev/null | jq -r '.entitlement.limits.imagesPerDay // empty' 2>/dev/null)
    case $limit in
    "" | *[!0-9]*) printf '  allowance   %s left\n' "$left" ;;
    *) printf '  allowance   %s of %s used, %s left\n' "$((limit - left))" "$limit" "$left" ;;
    esac
  fi

  # The slots are read from the units that exist, not from a number in this file:
  # the schedule lives in Nix, and a second copy would drift from it.
  units=$(systemctl --user list-unit-files --no-legend 'image-daily-slot-*.service' 2>/dev/null |
    sed -n 's/^image-daily-slot-\([0-9][0-9]*\)\.service.*/\1/p' | sort -n || true)
  total=$(printf '%s\n' "$units" | grep -c . 2>/dev/null || true)
  if [ "${total:-0}" -eq 0 ]; then
    printf '  next slot   no image-daily-slot timer on this host\n'
  else
    # `list-timers` is sorted by next elapse, so its first row is the next slot,
    # and the last column is the unit that row activates. Its JSON form is not on
    # every systemd this fleet runs (`--json` is unrecognized here), and the table
    # is the one shape both answer.
    n=$(systemctl --user list-timers --no-pager --no-legend 'image-daily-slot-*.timer' 2>/dev/null |
      awk 'NR == 1 {print $NF}' | sed -n 's/^image-daily-slot-\([0-9][0-9]*\)\.service$/\1/p' || true)
    if [ -z "$n" ]; then
      printf '  next slot   %s slot(s) registered, none scheduled\n' "$total"
    else
      next_at=$(systemctl --user show -p NextElapseUSecRealtime --value "image-daily-slot-$n.timer" 2>/dev/null || true)
      # The reserve is baked into the wrapper, not the unit: ExecStart names the
      # store path, and the `export RESERVE=` line lives inside that file.
      wrapper=$(systemctl --user show -p ExecStart --value "image-daily-slot-$n.service" 2>/dev/null |
        grep -o '/nix/store/[^ "]*image-daily-slot-[0-9][0-9]*' | head -1 || true)
      reserve=$(grep -o 'export RESERVE=[0-9][0-9]*' "$wrapper" 2>/dev/null | head -1 | cut -d= -f2 || true)
      cap=$(slot_share "$left" "$((total - n + 1))")
      printf '  next slot   %s of %s at %s -> cap %s' "$n" "$total" "${next_at:-unknown}" "$cap"
      if [ -n "$reserve" ] && [ "$reserve" -gt 0 ]; then printf ', %s held back' "$reserve"; fi
      printf '\n'
    fi
  fi

  pending=$(roster_pending "$roster" 2>/dev/null || printf '?')
  printf '  roster      %s row(s) waiting in %s\n' "${pending:-?}" "${roster#"$repo"/}"
}

cmd_today "$@"
