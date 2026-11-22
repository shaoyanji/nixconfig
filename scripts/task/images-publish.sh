#!/usr/bin/env bash
# images-publish.sh — publish the bank, but never let the served gallery shrink.
#
# WHY THIS EXISTS: `image-daily.sh publish` rebuilds urls.tsv from the files on
# THIS machine plus the ledger, then deploys that manifest. Run it from a host
# that holds a partial tree and the gallery silently collapses to that batch —
# measured 2026-11-21 on delphi, 536 assets became 126, with every Cloudinary
# asset untouched. Four lines of arithmetic turn that into a failed command.
#
#   IMAGES_ROOT=/Volumes/data/pics/generated bash images-publish.sh
#   ... DRY=1        stage and build the manifest, upload and deploy nothing
#   ... FORCE=1      accept a smaller manifest on purpose (a real purge)
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
IMAGES_ROOT=${IMAGES_ROOT:?IMAGES_ROOT is required (the tree that holds published/)}
FORCE=${FORCE:-0}
DRY=${DRY:-0}
PROJECT=${PROJECT:-bountystash-assets}
manifest=$IMAGES_ROOT/published/manifest.json

count() { [ -f "$1" ] && jq -r '.count // 0' "$1" 2>/dev/null || echo 0; }

prev=$(count "$manifest")
REUPLOAD=${REUPLOAD:-0}
IMAGES_ROOT="$IMAGES_ROOT" REUPLOAD="$REUPLOAD" PAGES=0 DRY="$DRY" \
  bash "$repo/scripts/task/image-daily.sh" publish
now=$(count "$manifest")
printf 'images-publish: %s -> %s asset(s)\n' "$prev" "$now"

if [ "$now" -lt "$prev" ] && [ "$FORCE" != "1" ]; then
  cat >&2 <<EOF
images-publish: REFUSED — the rebuilt manifest holds $now assets, the one being
images-publish: replaced holds $prev. This host does not hold the full bank.
images-publish: publish where IMAGES_ROOT is the whole tree (frieren:
images-publish: /Volumes/data/pics/generated), or pass FORCE=1 to shrink on purpose.
EOF
  exit 1
fi

if [ "$DRY" = "1" ]; then
  echo "images-publish: dry run — nothing uploaded, nothing deployed"
  exit 0
fi

bash "$repo/scripts/task/pages-deploy.sh" "$IMAGES_ROOT/site-dist" \
  --project-name="$PROJECT" --branch=main
jq -cn --argjson prev "$prev" --argjson now "$now" \
  '{previous: $prev, published: $now, delta: ($now - $prev)}'
