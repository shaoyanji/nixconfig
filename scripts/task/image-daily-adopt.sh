#!/usr/bin/env bash
# image-daily-adopt.sh — a manifest row for every Cloudinary upload that has none
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


cmd_adopt() {
  need jq
  "$(image_daily_cli)" adopt
  [ "${DRY:-0}" = "1" ] && { say "dry run: nothing added, nothing built"; return 0; }
  "$(image_daily_cli)" index
  "$(image_daily_cli)" deploy
}

cmd_adopt "$@"
