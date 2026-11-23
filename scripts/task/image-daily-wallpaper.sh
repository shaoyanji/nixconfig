#!/usr/bin/env bash
# image-daily-wallpaper.sh — set the first in-rotation wallpaper with swaybg
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


cmd_wallpaper() {
  local rotation=$repo/lib/image-daily/rotation.json
  local taste_root=${IMAGES_ROOT%/generated}/taste-test
  local id reason pick=""
  local -a approved ids
  mapfile -t approved < <(jq -r '.wall.in[]?' "$rotation" 2>/dev/null || true)
  command -v ffprobe >/dev/null || die "ffprobe is required to check a plate's shape (pkgs.ffmpeg)"

  if [ "${#approved[@]}" -gt 0 ]; then
    # List order is priority: the first id that resolves is the wallpaper, so
    # "first in the rotation" is a line a person can move.
    for id in "${approved[@]}"; do
      reason=$(jq -r --arg id "$id" '.wall.out[$id] // ""' "$rotation" 2>/dev/null || true)
      if [ -n "$reason" ]; then say "skipping $id: $reason"; continue; fi
      pick=$(resolve_plate "$taste_root" "$id") || { say "skipping $id: no such plate"; continue; }
      if ! landscape "$pick"; then
        say "skipping $id: $(dimensions "$pick" || echo unknown) is not landscape"
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
      pick=$(resolve_plate "$taste_root" "$id") || continue
      if ! landscape "$pick"; then
        say "skipping $id: $(dimensions "$pick" || echo unknown) is not landscape"
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
