#!/usr/bin/env bash
# image-daily-post.sh — SLUG= TITLE= one motion: banner, judge, upload, manifest, front matter
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


# One motion from a title to a post that has a banner. The banner is generated,
# judged and uploaded before the file exists, so a post cannot ship with a hero
# that 404s, and no JPEG enters the tree.
# One front-matter field from a draft, unquoted. A draft is the source of the body
# and of the metadata the generator never asks for (description, author, the toc
# flags); the banner, the date and the title are the generator's.

fm_field() {
  awk -v k="$1" '/^---$/{n++; next} n==1 && index($0, k":")==1 {
      v=substr($0, length(k)+2); sub(/^ +/, "", v); gsub(/^"|"$/, "", v); print v; exit
    }' "$2"
}


cmd_post() {
  need jq cpg agy ffmpeg git
  local slug=${SLUG:-} title=${TITLE:-} prompt=${PROMPT:-} alt=${ALT:-}
  local blog=${BLOG_DIR:-$HOME/Documents/shaoyanji.is-a.dev}
  [ -n "$slug" ] || die "SLUG=<url-slug> is required"
  [ -n "$title" ] || die 'TITLE="the post title" is required'
  [ -d "$blog/.git" ] || die "no blog checkout at $blog (BLOG_DIR=...)"
  [ -n "$alt" ] || alt=$title
  [ -n "$prompt" ] || prompt="A blog banner for an engineering post titled \"$title\". One clear subject, realistic photographic style, natural light, shallow depth of field, no text, no lettering, no logos, nothing to read."
  local day post file verdict defect jpg url card body='' tsv=$IMAGES_ROOT/published/urls.tsv cli
  cli=$(image_daily_cli)
  day=$(today)
  post=$blog/_posts/$day-$slug.md
  if [ -f "$post" ] && [ "${FORCE:-0}" != "1" ]; then
    die "$post exists — FORCE=1 to rewrite its front matter (the body is kept)"
  fi
  # A promotion starts from a draft: same slug, an older date, a body already
  # written. `DRAFT=1` finds it beside the target, `DRAFT=<path>` names it.
  local draft=''
  case ${DRAFT:-} in
  '' | 0) ;;
  1)
    draft=$(ls -1 "$blog"/_posts/*-"$slug".md 2>/dev/null | grep -v "/$day-" | head -1 || true)
    [ -n "$draft" ] || die "DRAFT=1: no _posts/*-$slug.md beside $post to promote"
    ;;
  *)
    draft=${DRAFT#./}
    case $draft in /*) ;; *) draft=$blog/$draft ;; esac
    ;;
  esac
  [ -z "$draft" ] || [ -f "$draft" ] || die "no draft at $draft"
  [ "$(remaining || echo 0)" -gt 0 ] || die "no images left today"

  say "$slug: generating a banner"
  file=$("$cli" attempt --id "blog-$slug" --lane blog --size 1536x1024 --name "$slug.png" --prompt "$prompt" --day "$day") || die "generation failed"
  verdict=$("$cli" judge --png "$file" --lane blog --intent "$(lane_setting blog intent)")
  if [ "$(printf '%s' "$verdict" | jq -r '.verdict')" = "reroll" ]; then
    defect=$(printf '%s' "$verdict" | jq -r '.defect // "the composition"')
    say "$slug: reroll — $defect"
    rm -f "$file"
    file=$("$cli" attempt --id "blog-$slug" --lane blog --size 1536x1024 --name "$slug.png" \
      --prompt "$prompt (Change only this: $defect.)" --day "$day") || die "reroll failed"
    verdict=$("$cli" judge --png "$file" --lane blog --intent "$(lane_setting blog intent)")
  fi
  say "judge: $(printf '%s' "$verdict" | jq -r '.verdict + " — " + .reason')"
  [ "$(printf '%s' "$verdict" | jq -r '.verdict')" = "keep" ] ||
    die "the judge did not keep $file; nothing was uploaded"

  record "$day" blog "blog-$slug" "$file" keep "$(printf '%s' "$verdict" | jq -r '.reason')"
  jpg=$IMAGES_ROOT/published/blog/$slug.jpg
  "$cli" crop --png "$file" --jpg "$jpg" || die "could not crop the banner"
  url=$(bash "$repo/scripts/task/cloudinary.sh" upload "$jpg" --public-id "assets/blog/$slug") ||
    die "upload failed"
  say "cloudinary: $url"

  # The manifest is the reference list: a new upload of the same slug replaces the
  # old row instead of joining it, so a regenerated banner does not appear twice.
  mkdir -p "$(dirname "$tsv")"
  [ -f "$tsv" ] && grep -v "^blog/$slug\.jpg	" "$tsv" >"$tsv.new" || true
  printf 'blog/%s.jpg\t%s\t%s\n' "$slug" "$url" "$(stat -c%s "$jpg")" >>"$tsv.new"
  mv -f "$tsv.new" "$tsv"
  build_index
  "$cli" deploy

  card=$(bash "$repo/scripts/task/cloudinary.sh" url "assets/blog/$slug" \
    --transform 'f_jpg,q_auto,w_1200,h_630,c_fill')
  # The public id carries no extension; the delivery URL names the format anyway,
  # and the other fifteen posts are `.jpg`, so a scraper never has to guess.
  card=$card.jpg
  # Two sources for the metadata: a draft (a promotion) or an existing post
  # (`FORCE=1`). The body is everything after the second fence either way.
  local fm_src=''
  if [ -n "$draft" ]; then
    fm_src=$draft
  elif [ -f "$post" ]; then
    fm_src=$post
  fi
  [ -z "$fm_src" ] || body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$fm_src" | sed '/./,$!d')
  [ -z "$fm_src" ] || [ -n "$body" ] || die "$fm_src has no body after its front matter"
  local cats=${CATEGORIES:-} tgs=${TAGS:-} desc=${DESCRIPTION:-} author=${AUTHOR:-}
  local pin=false toc=true comments=false math=false mermaid=false
  if [ -n "$fm_src" ]; then
    [ -n "$cats" ] || cats=$(fm_field categories "$fm_src")
    [ -n "$tgs" ] || tgs=$(fm_field tags "$fm_src")
    [ -n "$desc" ] || desc=$(fm_field description "$fm_src")
    [ -n "$author" ] || author=$(fm_field author "$fm_src")
    pin=$(fm_field pin "$fm_src")
    toc=$(fm_field toc "$fm_src")
    comments=$(fm_field comments "$fm_src")
    math=$(fm_field math "$fm_src")
    mermaid=$(fm_field mermaid "$fm_src")
    pin=${pin:-false}
    toc=${toc:-true}
    comments=${comments:-false}
    math=${math:-false}
    mermaid=${mermaid:-false}
  fi
  cats=${cats:-Blog}
  tgs=${tgs:-technology}
  cats=${cats#[}
  cats=${cats%]}
  tgs=${tgs#[}
  tgs=${tgs%]}
  {
    printf -- '---\n'
    printf 'layout: post\n'
    printf 'title: "%s"\n' "${title//\"/\\\"}"
    printf 'date: %s 00:00:00 +0000\n' "$day"
    printf 'categories: [%s]\n' "$cats"
    printf 'tags: [%s]\n' "$tgs"
    [ -z "$desc" ] || printf 'description: "%s"\n' "${desc//\"/\\\"}"
    [ -z "$author" ] || printf 'author: %s\n' "$author"
    printf 'image:\n  path: %s\n  alt: "%s"\n' "$card" "${alt//\"/\\\"}"
    if [ -n "$fm_src" ]; then
      printf 'pin: %s\ntoc: %s\ncomments: %s\nmath: %s\nmermaid: %s\n' \
        "$pin" "$toc" "$comments" "$math" "$mermaid"
    fi
    printf -- '---\n\n'
    [ -z "$body" ] || printf '%s\n' "$body"
  } >"$post"
  say "post: $post"
  local paths=("${post#"$blog"/}")
  if [ -n "$draft" ] && [ "$draft" != "$post" ]; then
    rm -f "$draft"
    # A draft that was never tracked leaves nothing for git to stage, and
    # `git add --` on a path that does not exist is fatal, which aborted the
    # commit and the push after the banner had already been paid for
    # (2026-11-16). Only a tracked draft is worth naming.
    if git -C "$blog" ls-files --error-unmatch "${draft#"$blog"/}" >/dev/null 2>&1; then
      paths+=("${draft#"$blog"/}")
    fi
  fi
  git -C "$blog" add -A -- "${paths[@]}"
  if ! git -C "$blog" diff --cached --quiet -- "${paths[@]}" 2>/dev/null; then
    git -C "$blog" commit -q -m "post: $title" \
      -m "Banner from the image queue, on Cloudinary where the crop lives in the URL."
  fi
  say "commit: $(git -C "$blog" log --oneline -1)"
  if [ "${PUSH:-0}" = "1" ]; then
    git -C "$blog" push -q origin HEAD && say "pushed: the site deploys from this"
  else
    say "not pushed — PUSH=1 lands it"
  fi
}

cmd_post "$@"
