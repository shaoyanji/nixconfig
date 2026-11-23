#!/usr/bin/env bash
# image-daily-share.sh SLOTS_LEFT — the cap one slot takes, from the same arithmetic today prints
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"

slot_share "$(remaining)" "${1:-1}"
