#!/usr/bin/env bash
# image-daily-add.sh FILE [URL] — give one file a manifest row, rebuild, deploy
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"



# One file, one row — the ad-hoc half of the bank. `adopt` sweeps the account
# for uploads nobody wrote a row for; `add` is the same row written directly,
# so a render that was just uploaded does not wait for a listing of everything
# Cloudinary holds. The row, the rebuilt manifest and the deploy are one step:
# "uploaded" and "in the gallery" used to be two commands a person had to
# remember (`images:gen`, then `images:adopt`), and a forgotten second step was
# a plate that existed but served nothing.

cmd_add() { # FILE [URL]
  need jq
  local file=${1:?add needs a file} url=${2:-}
  [ -f "$file" ] || die "add: no such file: $file"
  local rel id rows=$IMAGES_ROOT/published/urls.tsv
  case $file in
  "$IMAGES_ROOT"/published/*) rel=${file#"$IMAGES_ROOT/published/"} ;;
  "$IMAGES_ROOT"/src/*) rel=${file#"$IMAGES_ROOT/src/"} ;;
  *) rel="wall/$(today)/$(basename "$file")" ;;
  esac
  id="assets/${rel%.*}"
  case $rel in badge/*) id="assets/fleet/$(basename "${rel%.*}")" ;; esac
  # The published tree is the bank's local replica: a file the gallery serves
  # belongs there, or a later publish holds a row whose file only exists
  # under src/ and the shrink arithmetic reads it as served-but-absent.
  if [ ! -f "$IMAGES_ROOT/published/$rel" ]; then
    mkdir -p "$IMAGES_ROOT/published/$(dirname "$rel")"
    cp -f "$file" "$IMAGES_ROOT/published/$rel"
  fi
  mkdir -p "$IMAGES_ROOT/published"
  touch "$rows"
  if awk -F'\t' -v r="$rel" '$1 == r { found = 1 } END { exit !found }' "$rows"; then
    say "add: $rel already has a row; rebuilding and deploying"
  else
    # A URL handed over is the upload that already happened (image-gen uploads
    # before it reports one); without it the file crosses here, under the same
    # `assets/<rel>` id publish and adopt derive, so all three stay one path.
    if [ -z "$url" ]; then
      url=$("$(image_daily_cli)" cloudinary upload "$file" --public-id "$id" --repo "$repo") ||
        die "add: upload failed for $rel"
    fi
    printf '%s\t%s\t%s\n' "$rel" "$url" "$(stat -c%s "$file")" >>"$rows"
    sort -t"$(printf '\t')" -k1,1 -o "$rows" "$rows"
    say "add: $rel -> $url"
  fi
  "$(image_daily_cli)" index
  "$(image_daily_cli)" deploy
}

cmd_add "$@"
