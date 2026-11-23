#!/usr/bin/env bash
# image-daily-gc.sh — destroy Cloudinary public ids nothing references
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"



# Cloudinary keeps every public id forever, so a renamed asset or a superseded
# convention leaves an id that nothing serves and every listing shows. The
# references are the manifest and the blog checkout; everything else under
# GC_PREFIX is garbage. `DRY=1` prints the list instead of destroying it.

cmd_gc() {
  need jq curl git
  local prefix=${GC_PREFIX:-shaoyanji/} blog=${BLOG_DIR:-$HOME/Documents/shaoyanji.is-a.dev}
  local keep=$IMAGES_ROOT/.gc-keep ids id n=0 gone=0
  [ -s "$IMAGES_ROOT/published/urls.tsv" ] || die "no urls.tsv yet — run images:publish first"
  {
    cut -f1 "$IMAGES_ROOT/published/urls.tsv" | sed 's/\.\(png\|jpg\|jpeg\|webp\)$//; s#^#assets/#'
    if [ -d "$blog" ]; then
      grep -rhoE 'image/upload/[^)[:space:]"]+' "$blog/_config.yml" "$blog/_posts" 2>/dev/null |
        sed -e 's#.*image/upload/##' -e 's#^v[0-9]*/##' -e 's#^[a-z0-9]*_[^/]*/##' \
          -e 's/\.\(png\|jpg\|jpeg\|webp\)$//'
    fi
  } | sort -u >"$keep"
  say "references: $(wc -l <"$keep") public id(s)"
  ids=$(bash "$repo/scripts/task/cloudinary.sh" list --prefix "$prefix") || die "could not list $prefix"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    # `grep ... && continue` returns 1 when the id is absent, and errexit would
    # take that as the function failing; the absent case is the point.
    if grep -qxF "$id" "$keep"; then continue; fi
    if [ "${DRY:-0}" = "1" ]; then
      say "would destroy $id"
      gone=$((gone + 1))
      continue
    fi
    bash "$repo/scripts/task/cloudinary.sh" destroy "$id" >/dev/null &&
      { say "destroyed $id"; gone=$((gone + 1)); }
  done <<<"$ids"
  say "$n under $prefix, $gone orphan(s)"
}

cmd_gc "$@"
