#!/usr/bin/env bash
# image-daily-adopt.sh — a manifest row for every Cloudinary upload that has none
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


cmd_adopt() {
  need jq
  adopt_cloudinary
  [ "${DRY:-0}" = "1" ] && { say "dry run: nothing added, nothing built"; return 0; }
  build_index
  deploy_frontend
}

cmd_adopt "$@"
