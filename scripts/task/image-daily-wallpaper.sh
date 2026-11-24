#!/usr/bin/env bash
# image-daily-wallpaper.sh — set the first in-rotation wallpaper with swaybg
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"

# Rotation is a judgement, not a timer: `in` is approval and priority, `out` is a
# rejection with its reason (lib/image-daily/rotation.json). The first approved id
# that resolves is the wallpaper, so the order is the operator's to move, not a
# sort of filenames. A rejected plate never rotates however new it is, and a plate
# in neither list is unjudged rather than bad, so nothing lands on a screen on the
# strength of its date alone. With no approval list yet, the newest unrejected
# plate is used, which is what a lane nobody has looked at gets.
# A wallpaper is landscape. A square plate under `swaybg -m fill` is cropped to a
# stripe of itself, which reads on a screen as a broken wallpaper rather than as a
# wrong request — so the shape is measured where the plate is chosen. The size a
# generator returns is not the size it was asked for until someone reads it.


cmd_wallpaper() {
  local rotation=$repo/lib/image-daily/rotation.json
  local taste_root=${IMAGES_ROOT%/generated}/taste-test
  local id reason pick="" cli
  local -a approved ids
  cli=$(image_daily_cli)
  mapfile -t approved < <(jq -r '.wall.in[]?' "$rotation" 2>/dev/null || true)
  command -v ffprobe >/dev/null || die "ffprobe is required to check a plate's shape (pkgs.ffmpeg)"

  if [ "${#approved[@]}" -gt 0 ]; then
    # List order is priority: the first id that resolves is the wallpaper, so
    # "first in the rotation" is a line a person can move.
    for id in "${approved[@]}"; do
      reason=$(jq -r --arg id "$id" '.wall.out[$id] // ""' "$rotation" 2>/dev/null || true)
      if [ -n "$reason" ]; then say "skipping $id: $reason"; continue; fi
      pick=$("$cli" resolve --id "$id" --taste-root "$taste_root") || { say "skipping $id: no such plate"; continue; }
      if ! "$cli" landscape --file "$pick"; then
        say "skipping $id: $("$cli" dimensions --file "$pick" || echo unknown) is not landscape"
        pick=""
        continue
      fi
      break
    done
  else
    # Nothing approved: newest unjudged plate, which is what a fresh generation
    # has to be before anyone has looked at it.
    mapfile -t ids < <(
      { find "$IMAGES_ROOT/published/wall" -name '*.png' 2>/dev/null | sed -E 's#.*/wall/##'
        find "$IMAGES_ROOT/src/wall" -name '*.png' 2>/dev/null | sed -E 's#.*/wall/##'
      } | awk '!seen[$0]++' | sort -r
    )
    for id in "${ids[@]}"; do
      reason=$(jq -r --arg id "$id" '.wall.out[$id] // ""' "$rotation" 2>/dev/null || true)
      [ -n "$reason" ] && continue
      pick=$("$cli" resolve --id "$id" --taste-root "$taste_root") || continue
      if ! "$cli" landscape --file "$pick"; then
        say "skipping $id: $("$cli" dimensions --file "$pick" || echo unknown) is not landscape"
        pick=""
        continue
      fi
      break
    done
  fi
  [ -n "$pick" ] || die "nothing in rotation resolves; approve a plate in lib/image-daily/rotation.json"

  [ "${DRY:-0}" = "1" ] && { printf '%s\n' "$pick"; return 0; }
  command -v swaybg >/dev/null || die "swaybg is not installed on this host"
  pkill -x swaybg 2>/dev/null || true
  setsid swaybg -m fill -i "$pick" >/dev/null 2>&1 &
  say "$(basename "$pick")"
}

cmd_wallpaper "$@"
