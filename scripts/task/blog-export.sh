#!/usr/bin/env bash
# blog-export.sh — move a finished `ideas/<slug>.md` into the Jekyll blog repo.
#
#   blog-export.sh SLUG [--force]
#
# The draft is authored here, where the graph and the source documents are; the
# blog repo is where it gets published. This is the one-way door between them,
# and it is deliberately dumb: it converts the idea's frontmatter into the blog's
# own post front matter (the shape in that repo's BLOG_AUTHORING.md, which its
# `task post` also emits), copies the body verbatim, and stops. It never commits
# and never pushes — the blog's CI deploys on push, so publication stays an
# operator decision (and an unattended run must not be able to make it).
#
# Front matter written, matching the blog's template:
#   layout: post · title · date · author · categories: [Blog] · tags: [] · flags
# Categories and tags are the blog's vocabulary, not this repo's; the operator
# sets them in the blog repo (`task post` there shows the existing lists). A
# `#tags:` line in the idea's frontmatter is carried through if present, because
# that is the one place the author already knows them.
#
# Usage: blog-export.sh SLUG [--force]
#   BLOG_REPO   checkout to write into (default ~/Documents/shaoyanji.is-a.dev)
#   BLOG_AUTHOR post author (default: the blog's own default, `matt`)
#
# Exit: 0 = written; 1 = source draft missing or malformed; 2 = usage, no blog
# checkout, or the target post already exists.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
BLOG_REPO="${BLOG_REPO:-$HOME/Documents/shaoyanji.is-a.dev}"
BLOG_AUTHOR="${BLOG_AUTHOR:-matt}"

usage() { sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

SLUG=""
FORCE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "blog-export: unknown option $1" >&2; exit 2 ;;
    *)
      [ -z "$SLUG" ] || { echo "blog-export: one slug per run" >&2; exit 2; }
      SLUG="${1%.md}"
      shift
      ;;
  esac
done
[ -n "$SLUG" ] || { usage >&2; exit 2; }

src="$REPO/ideas/${SLUG}.md"
[ -f "$src" ] || {
  echo "blog-export: no draft at ideas/${SLUG}.md" >&2
  ls "$REPO/ideas" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  /' >&2 || true
  exit 1
}

if [ ! -d "$BLOG_REPO/_posts" ]; then
  echo "blog-export: no blog checkout at $BLOG_REPO (needs a _posts/ directory)" >&2
  echo "  gh repo clone shaoyanji/shaoyanji.is-a.dev \"$BLOG_REPO\"" >&2
  echo "  or: BLOG_REPO=/path/to/checkout task dev:blog:export SLUG=$SLUG" >&2
  exit 2
fi

# Frontmatter is the first block between two `---` lines; everything after the
# closing one is the body. A file without it is not a draft this can publish.
if ! head -1 "$src" | grep -qx -- '---'; then
  echo "blog-export: ideas/${SLUG}.md has no frontmatter block" >&2
  exit 1
fi
close="$(awk 'NR > 1 && /^---$/ { print NR; exit }' "$src")"
[ -n "$close" ] || { echo "blog-export: ideas/${SLUG}.md frontmatter is unclosed" >&2; exit 1; }

fm="$(sed -n "2,$((close - 1))p" "$src")"
body="$(sed -n "$((close + 1)),\$p" "$src")"

title="$(printf '%s\n' "$fm" | awk 'sub(/^title: */, "") { print; exit }')"
[ -n "$title" ] || title="$SLUG"

# `about:` is this repo's graph vocabulary and does not belong in the post; a
# `tags:` line is the only frontmatter key carried across.
tags="$(printf '%s\n' "$fm" | awk 'sub(/^tags: */, "") { print; exit }')"
date="$(date +%Y-%m-%d)"
target="$BLOG_REPO/_posts/${date}-${SLUG}.md"

if [ -e "$target" ] && [ "$FORCE" = 0 ]; then
  echo "blog-export: ${target#"$BLOG_REPO"/} already exists (--force to replace it)" >&2
  exit 2
fi

{
  printf -- '---\n'
  printf 'layout: post\n'
  printf 'title: %s\n' "$title"
  printf 'date: %s\n' "$date"
  printf 'author: %s\n' "$BLOG_AUTHOR"
  printf 'categories: [Blog]\n'
  printf 'tags: %s\n' "${tags:-[]}"
  printf 'pin: false\n'
  printf 'toc: true\n'
  printf 'comments: false\n'
  printf 'math: false\n'
  printf 'mermaid: false\n'
  printf -- '---\n'
  printf '%s\n' "$body"
} >"$target"

echo "blog-export: wrote ${target#"$BLOG_REPO"/}"
echo
echo "categories and tags are the blog's vocabulary, set in the post or with"
echo "'task post' in that repo; nothing here is committed or pushed."
echo
git -C "$BLOG_REPO" status --short -- "$target" 2>/dev/null || true
