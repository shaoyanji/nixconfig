#!/usr/bin/env bash
# image-daily-plates.sh — a requested round of photoreal character plates from the roster
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


# The round itself is `image-daily plates` in tools/os (the unjudged_streak
# breaker, the archetype expansion and the hold write-back live there): a row
# whose plate the judge kept is skipped, a held row is parked with its reason
# on the prompt field, and a requested round may wait one burst window out.
# This file is the dispatch shim — DETACH=1 hands the same loop to systemd-run
# through `round`, which is the verb a timer calls so the unit outlives the
# shell that starts it.

cmd_plates() {
  need git
  local cli roster=${ROSTER:-$repo/lib/image-daily/plates.txt}
  cli=$(image_daily_cli)
  if [ "${DETACH:-0}" = "1" ]; then
    "$cli" round --roster "$roster" --root "$IMAGES_ROOT" --repo "$repo"
    return 0
  fi
  "$cli" plates --roster "$roster" --root "$IMAGES_ROOT" --repo "$repo" "$@"
}

cmd_plates "$@"
