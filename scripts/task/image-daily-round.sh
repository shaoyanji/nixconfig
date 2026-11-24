#!/usr/bin/env bash
# image-daily-round.sh [status] — ensure a round is running; `status` is the readout
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


# The no-babysitting entry point: ensure a round is running, then stop. Called
# twice it reports the round already running instead of starting a second one, and
# rows that already have a kept plate are skipped, so a stopped round resumes free.

cmd_round() { # [status]
  need jq
  local roster=${ROSTER:-$repo/lib/image-daily/plates.txt}
  local state=$IMAGES_ROOT/.round.json unit active pending left
  if [ "${1:-}" = "status" ]; then
    pending=$("$(image_daily_cli)" pending --roster "$roster" 2>/dev/null || echo '?')
    left=$(remaining 2>/dev/null || echo '?')
    if [ -s "$state" ]; then
      unit=$(jq -r '.unit // empty' "$state" 2>/dev/null)
      active=$(systemctl --user is-active "$unit" 2>/dev/null || true)
      printf 'unit      %s (%s)\n' "$unit" "${active:-unknown}"
      printf 'roster    %s\n' "$(jq -r '.roster // empty' "$state")"
      printf 'waiting   %s row(s), %s image(s) left\n' "$pending" "$left"
      printf 'journal   (last 6)\n'
      journalctl --user -u "$unit" -n 6 --no-pager -o cat 2>/dev/null | sed 's/^/  /'
    else
      printf 'round     none started from this host\n'
      printf 'waiting   %s row(s), %s image(s) left\n' "$pending" "$left"
    fi
    return 0
  fi
  if [ -s "$state" ]; then
    unit=$(jq -r '.unit // empty' "$state" 2>/dev/null)
    if [ -n "$unit" ] && [ "$(systemctl --user is-active "$unit" 2>/dev/null || true)" = "active" ]; then
      jq -c --arg pending "$("$(image_daily_cli)" pending --roster "$roster" 2>/dev/null || echo 0)" \
        '. + {state: "running", pending: (($pending) | tonumber)}' "$state"
      return 0
    fi
  fi
  pending=$("$(image_daily_cli)" pending --roster "$roster" 2>/dev/null || echo 0)
  left=$(remaining 2>/dev/null || echo 0)
  if [ "${pending:-0}" -le 0 ]; then
    jq -cn --arg r "$roster" '{state: "idle", reason: "every roster row has a kept plate", roster: $r}'
    return 0
  fi
  if [ "${left:-0}" -le 0 ]; then
    jq -cn --argjson p "${pending:-0}" \
      '{state: "idle", reason: "allowance spent; the rows wait for the reset", pending: $p}'
    return 0
  fi
  "$(image_daily_cli)" round --roster "$roster"
}

cmd_round "$@"
