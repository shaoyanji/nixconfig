#!/usr/bin/env bash
# image-daily-variants.sh — list superseded renders under variants/, put one back
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"



# The other half of `archive_prior`: with no argument it lists the superseded
# renders, and with `VARIANT=<path>` it puts one back. A restore also drops the
# path from the manifest, because publish copies a row it already carries rather
# than uploading again — the row is what says "this URL is already served", and
# after a restore that sentence is wrong.

cmd_variants() {
  local root=$IMAGES_ROOT/variants want=${VARIANT:-} rel file rows=$IMAGES_ROOT/published/urls.tsv
  if [ -z "$want" ]; then
    [ -d "$root" ] || { say "no superseded renders yet ($root)"; return 0; }
    find "$root" -type f \( -name '*.png' -o -name '*.jpg' \) | sort |
      while IFS= read -r f; do say "${f#"$root"/}"; done
    return 0
  fi
  case $want in
  /*) file=$want ;;
  *)
    want=${want#"$IMAGES_ROOT/"}
    want=${want#variants/}
    file=$root/$want
    ;;
  esac
  [ -f "$file" ] || die "no archived render at $file"
  # variants/wall/2026-11-16/dota-phantom-assassin.<stamp>[-n].png -> wall/<day>/<slug>.png
  rel=${file#"$root"/}
  rel=$(printf '%s' "$rel" | sed -E 's/\.[0-9]{8}T[0-9]{6}Z(-[0-9]+)?(\.[a-z]+)$/\2/')
  # The plate being replaced is archived too, so flipping the choice back is the
  # same command run against the other file instead of a one-way door. Copy the
  # chosen render aside first: archiving writes into the same folder it came from.
  local hold=$file.hold.$$
  cp -f "$file" "$hold" || die "could not read $file"
  "$(image_daily_cli)" archive --file "$IMAGES_ROOT/published/$rel"
  mkdir -p "$(dirname "$IMAGES_ROOT/published/$rel")" "$(dirname "$IMAGES_ROOT/src/$rel")"
  mv -f "$hold" "$IMAGES_ROOT/published/$rel"
  cp -f "$IMAGES_ROOT/published/$rel" "$IMAGES_ROOT/src/$rel"
  if [ -s "$rows" ]; then
    awk -F'\t' -v r="$rel" '$1 != r' "$rows" >"$rows.restore.$$" && mv -f "$rows.restore.$$" "$rows"
  fi
  say "restored $rel from $(basename "$file")"
  [ "${PUBLISH:-1}" = "1" ] || { say "PUBLISH=0: the gallery still serves the replaced plate"; return 0; }
  [ -s "$rows" ] || { say "manifest is empty — nothing to publish until a plate lands again"; return 0; }
  cmd_publish
}

cmd_variants "$@"
