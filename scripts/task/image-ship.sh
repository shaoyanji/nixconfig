#!/usr/bin/env bash
# image-ship.sh — the whole ad-hoc path as one command:
# prompt -> PNG -> Cloudinary -> manifest row -> Pages deploy -> served check.
#
#   PROMPT='...' bash image-ship.sh            # {"path","url","rel","served"}
#   PROMPT='...' DETACH=1 bash image-ship.sh   # the same, under a user unit
#
# WHY THIS EXISTS: the path used to be three commands a person had to remember —
# `images:gen` to render and upload (the CLI's URL is session-gated, so the bank
# upload is part of generation, not a step after), then `images:adopt` to notice
# the upload and rebuild the manifest, with the deploy folded inside that. The
# first two steps are one decision — "put this prompt in the gallery" — so they
# are one command. `images:gen` still answers the render alone, `images:add`
# registers a file already on disk, `images:adopt` still sweeps the account for
# rows nothing wrote; this is the front door for one image.
#
# The last step reads the gallery back: a deploy that reports live but a
# manifest without the asset is the failure `pages-deploy.sh`'s readiness wait
# cannot see, so `served` in the JSON is true only when the public manifest
# carries the row.
set -euo pipefail

repo=${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
if [ -z "${IMAGES_ROOT:-}" ]; then
  if [ -d /Volumes/data/pics ]; then
    IMAGES_ROOT=/Volumes/data/pics/generated
  else
    IMAGES_ROOT=$HOME/Pictures/generated
  fi
fi
PROJECT=${PROJECT:-bountystash-assets}
SIZE=${SIZE:-1536x1024}
PAGES=${PAGES:-1}

say() { printf '%s\n' "$*" >&2; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' |
    sed -e 's/^-*//' -e 's/-*$//' | cut -c1-48
}

# A detached ship runs the whole pipeline in the unit — gen, row, deploy and
# the served check — because a gen-only detach would still leave the manifest
# step to whoever reads the log.
launch_detached() { # slug log
  local slug=$1 log=$2 unit
  unit="image-ship-$slug"
  systemctl --user stop "$unit" 2>/dev/null || true
  systemd-run --user --unit "$unit" --collect \
    --working-directory="$repo" \
    --setenv=PATH="$PATH" \
    --setenv=PROMPT="$PROMPT" --setenv=OUT="${OUT:-}" --setenv=SIZE="$SIZE" \
    --setenv=IMAGES_ROOT="$IMAGES_ROOT" --setenv=PROJECT="$PROJECT" \
    --setenv=PAGES="$PAGES" --setenv=DETACH=0 --setenv=REPO="$repo" \
    -- bash "$0" >"$log" 2>&1
  jq -cn --arg unit "$unit" --arg log "$log" '{unit: $unit, log: $log}'
}

: "${PROMPT:?PROMPT is required}"
if [ "${DETACH:-0}" = "1" ]; then
  launch_detached "$(slugify "$PROMPT")" "${LOG:-$IMAGES_ROOT/$(slugify "$PROMPT").ship.log}"
  exit 0
fi

# gen prints one JSON object: {id,url,path,bank,...}. `.url` is the Cloudinary
# delivery URL only when `bank` is true; on an upload failure it stays the
# session-gated render URL, which must never reach the manifest.
gen=$(IMAGES_ROOT="$IMAGES_ROOT" SIZE="$SIZE" PROMPT="$PROMPT" \
  OUT="${OUT:-}" UPLOAD=1 DETACH=0 bash "$repo/scripts/task/image-gen.sh") || {
  say "image-ship: generation failed"
  exit 1
}
printf '%s\n' "$gen" >&2
path=$(printf '%s' "$gen" | jq -r '.path // empty')
bank=$(printf '%s' "$gen" | jq -r '.bank // false')
url=$(printf '%s' "$gen" | jq -r '.url // empty')
[ -n "$path" ] && [ -f "$path" ] || { say "image-ship: no render path in the gen output"; exit 1; }
# bank=false means the upload failed and the render is only on disk: `add`
# uploads it there under the same public id, so either way the row lands.
[ "$bank" = "true" ] || url=""

PAGES="$PAGES" IMAGES_ROOT="$IMAGES_ROOT" \
  bash "$repo/scripts/task/image-daily.sh" add "$path" "$url"

case $path in
"$IMAGES_ROOT"/published/*) rel=${path#"$IMAGES_ROOT/published/"} ;;
"$IMAGES_ROOT"/src/*) rel=${path#"$IMAGES_ROOT/src/"} ;;
*) rel="wall/$(date +%F)/$(basename "$path")" ;;
esac

# The deploy's own readiness wait already ran inside `add`; this polls the
# served manifest for the row itself, because `/` answering 200 says the
# frontend attached, not that this asset is on it.
served=false
if [ "$PAGES" = "1" ]; then
  tries=0
  while [ "$tries" -lt 24 ]; do
    if curl -fsS --max-time 10 "https://$PROJECT.pages.dev/manifest.json" 2>/dev/null |
      jq -e --arg p "$rel" '.assets[]? | select(.path == $p)' >/dev/null 2>&1; then
      served=true
      break
    fi
    tries=$((tries + 1))
    sleep 5
  done
  [ "$served" = "true" ] ||
    say "image-ship: deploy finished but $rel is not on the served manifest yet — check https://$PROJECT.pages.dev/manifest.json"
fi

jq -cn --arg path "$path" --arg url "$url" --arg rel "$rel" \
  --arg project "$PROJECT" --argjson served "$served" \
  '{path: $path, url: $url, rel: $rel, served: $served,
    gallery: ("https://" + $project + ".pages.dev/")}'
[ "$served" = "true" ] || [ "$PAGES" != "1" ]
