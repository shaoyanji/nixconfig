#!/usr/bin/env bash
# image-daily-publish.sh — upload kept assets to Cloudinary, write the manifest, deploy the frontend
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


# The publish is `image-daily publish` in tools/os — the union merge of the
# served manifest, the publish_shrink_guard, the upload loop and the deploy
# all live there now (a manifest is a union, never a snapshot: 2026-11-21 on
# delphi, 556 assets became 144). GATE=0, FORCE=1, MERGE=0, REUPLOAD=1, DRY=1
# and PROJECT reach it through the environment, unchanged.

cmd_publish() {
  "$(image_daily_cli)" publish --root "$IMAGES_ROOT" --repo "$repo" "$@"
}

cmd_publish "$@"
