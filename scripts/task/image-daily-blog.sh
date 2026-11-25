#!/usr/bin/env bash
# image-daily-blog.sh [--dir PATH] — Chirpy front matter per banner, and the JPEGs copied
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


# The consumer of the blog lane is a Chirpy checkout, not this gallery: hand over
# the front matter the theme reads for the in-page hero and for og:image, and the
# JPEG next to it when a checkout path is given.

cmd_blog() { # [--dir PATH]
  need jq
  local dir="" src=$IMAGES_ROOT/published/blog f slug alt
  if [ "${1:-}" = "--dir" ]; then dir=${2:?--dir needs a path}; fi
  [ -d "$src" ] || die "no banners under $src yet — run images:publish first"
  for f in "$src"/*.jpg; do
    [ -f "$f" ] || continue
    slug=$(basename "${f%.jpg}")
    alt=$(jq -r --arg id "blog-$slug" '.briefs[] | select(.id == $id) | .prompt' "$BRIEFS")
    if [ -n "$dir" ]; then
      mkdir -p "$dir/assets/img/banners"
      cp -f "$f" "$dir/assets/img/banners/"
    fi
    url=$(awk -F'\t' -v k="blog/$slug.jpg" '$1 == k { print $2 }' \
      "$IMAGES_ROOT/published/urls.tsv" 2>/dev/null)
    [ -n "$url" ] || url=$("$(image_daily_cli)" cloudinary upload "$f" \
      --public-id "shaoyanji/banners/$slug" --repo "$repo")
    printf 'image:\n  path: %s\n  alt: %s\n\n' "$url" "${alt:-$slug}"
  done
}

cmd_blog "$@"
