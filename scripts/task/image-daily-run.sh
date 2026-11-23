#!/usr/bin/env bash
# image-daily-run.sh — generate, judge, keep; every verdict to the ledger
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


cmd_run() {
  need jq cpg agy git
  briefs_guard || die "briefs: a brief is not bank-ready (see above)"
  mkdir -p "$IMAGES_ROOT" "$STAGE"
  exec 9>"$IMAGES_ROOT/.run.lock"
  flock -n 9 || { say "another run holds the lock"; exit 0; }

  local day marker
  day=$(today)
  # A day can be spent in more than one pass: the generator's burst limit is 25 an
  # hour, so four slots 6h20 apart each spend a slice. The marker is per slot, or
  # the second slot of the day would read as a repeat of the first.
  marker=$IMAGES_ROOT/.done/$day
  [ -n "${SLOT:-}" ] && marker=$marker.${SLOT}
  if [ -f "$marker" ] && [ "${FORCE:-0}" != "1" ]; then
    say "$day already ran; FORCE=1 to spend again"
    exit 0
  fi

  local rem lane budget
  rem=$(remaining)
  [ -n "$rem" ] || die "cpg usage answered nothing — run cpg status --json"
  # Every slot holds a slice back. A plate someone asked for during the day is worth
  # more than the queue's next due entry, and a slot that spends the day at 13:20
  # leaves nothing for that. The last slot reserves too, because a hand-run batch in
  # the evening would otherwise find the day already swept.
  local reserve=${RESERVE:-0}
  if [ "$reserve" -le 0 ]; then
    say "$day: $rem images available"
  elif [ "$rem" -gt "$reserve" ]; then
    say "$day: $rem images available, $reserve held for ad-hoc requests"
    rem=$((rem - reserve))
  else
    say "$day: $rem images available, all $reserve reserved for ad-hoc requests"
    rem=0
  fi

  local cap=${CAP:-0} spent_total=0 room
  select_lanes
  for lane in "${lane_list[@]}"; do
    budget=$(lane_budget "$lane")
    [ "$budget" -gt "$rem" ] && budget=$rem
    if [ "$cap" -gt 0 ]; then
      room=$((cap - spent_total))
      [ "$room" -gt 0 ] || { say "cap $cap reached; the next slot takes the rest"; break; }
      [ "$budget" -gt "$room" ] && budget=$room
    fi
    run_lane "$lane" "$budget"
    spent_total=$((spent_total + LANE_SPENT))
    rem=$(remaining || echo 0)
  done

  # Whatever is left is discretionary: the storybook project takes it, and the
  # printer is idempotent, so a nearly-finished book simply stops.
  # Opt-in, not default. Two books of uniform spreads filled the allowance with
  # the same style on every page, which is the one thing a 100-image day should
  # not buy; a varied bank is worth more than 32 plates of the same look.
  local left
  left=$(remaining || echo 0)
  if [ "$reserve" -gt 0 ]; then
    left=$((left - reserve))
    [ "$left" -lt 0 ] && left=0
  fi
  if [ "${STORYBOOK:-0}" = "1" ] && [ "$left" -gt 0 ] && [ -n "${STORYBOOK_DIR:-}" ] &&
    [ -f "$repo/.agents/skills/cpg/scripts/storybook.py" ]; then
    say "storybook: $left images left, printing $((left / 3)) spread(s)"
    [ "${DRY:-0}" = "1" ] || python3 "$repo/.agents/skills/cpg/scripts/storybook.py" \
      run --limit "$((left / 3))" || say "storybook stopped early (see its ledger)"
  elif [ "$left" -gt 0 ]; then
    say "leftover: $left images unused (STORYBOOK=1 with STORYBOOK_DIR to spend them)"
  fi

  if [ "${PUBLISH:-1}" = "1" ] && [ "${DRY:-0}" != "1" ]; then
    cmd_publish || say "publish failed; assets are on disk and the lane reads stale until it succeeds"
  fi

  # The wall lane's keeps are wallpaper candidates too, so the approval a roster
  # round does runs here as well; APPROVE=0 leaves the rotation to a person.
  if [ "${APPROVE:-1}" = "1" ] && [ "${DRY:-0}" != "1" ]; then
    cmd_approve || say "approve failed; the kept plates are on disk and `images:approve` retries it"
  fi

  # A dry run has spent nothing, so it must not claim the day: the marker is what
  # makes the 06:10 run a no-op, and marking a DRY pass would silence the night.
  if [ "${DRY:-0}" != "1" ]; then
    mkdir -p "$IMAGES_ROOT/.done"
    date -u +%FT%TZ >"$marker"
  fi
  say "$day done"
}

cmd_run "$@"
