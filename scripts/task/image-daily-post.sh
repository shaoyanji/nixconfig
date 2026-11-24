#!/usr/bin/env bash
# image-daily-post.sh — SLUG= TITLE= one motion: banner, judge, upload, manifest, front matter
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


# The motion is `image-daily post` in tools/os — banner generation, the judge
# reroll, the crop, the Cloudinary upload and the front-matter write live
# there now. SLUG, TITLE, PROMPT, ALT, BLOG_DIR, DRAFT, CATEGORIES, TAGS,
# DESCRIPTION, AUTHOR, FORCE and PUSH reach it through the environment,
# unchanged.

cmd_post() {
  "$(image_daily_cli)" post --root "$IMAGES_ROOT" --repo "$repo" "$@"
}

cmd_post "$@"
