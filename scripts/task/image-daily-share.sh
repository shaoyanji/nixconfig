#!/usr/bin/env bash
# image-daily-share.sh SLOTS_LEFT — the cap one slot takes, from the same arithmetic today prints
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"

"$(image_daily_cli)" share --slots "${1:-1}"
