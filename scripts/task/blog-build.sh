#!/usr/bin/env bash
# scripts/task/blog-build.sh — a production build of the blog checkout, into a
# directory the caller owns.
#
# Two gates read a blog build: `cv-blog-check.sh` resolves CV anchors inside it,
# `blog-published-check.sh` fetches every file it carries. Both used to read
# `$BLOG_REPO/_site`, which is whatever the last local build left — a directory
# that outlives the checkout's HEAD and quietly turns a green gate into a claim
# about yesterday. Building here is what makes the verdict about this commit.
#
# JEKYLL_ENV=production is the blog's CI setting (`pages-deploy.yml`) and it is
# not cosmetic: chirpy runs `compress_html` only in production, so a development
# build differs from what Pages serves in every HTML file.
#
# Usage: blog-build.sh OUTDIR
#
# Env: BLOG_REPO (default ~/Documents/shaoyanji.is-a.dev), BUNDLE (default: the
# first of `bundle` on PATH and the store's bundlers that can load the
# checkout's vendored gems). Resolution is a probe, not a preference: a store
# bundler carries its own ruby, and the store holds several — a `vendor/`
# installed by ruby 3.4.12 fails to load under a bundler built on 3.4.9 with a
# `libruby` LoadError that reads like a broken install.
#
# EXIT
#   0  OUTDIR holds the production build
#   2  cannot tell: no checkout, no bundler, no vendored gems, the build failed
set -uo pipefail

BLOG_REPO=${BLOG_REPO:-$HOME/Documents/shaoyanji.is-a.dev}
out=${1:?usage: blog-build.sh OUTDIR}

[ -d "$BLOG_REPO" ] || {
  echo "blog-build: no checkout at $BLOG_REPO" >&2
  exit 2
}

candidates() {
  [ -n "${BUNDLE:-}" ] && { echo "$BUNDLE"; return; }
  command -v bundle 2>/dev/null || true
  ls -d /nix/store/*-bundler-*/bin/bundle 2>/dev/null || true
}

bundle=''
while IFS= read -r cand; do
  [ -n "$cand" ] && [ -x "$cand" ] || continue
  if (cd "$BLOG_REPO" && "$cand" exec jekyll -v >/dev/null 2>&1); then
    bundle=$cand
    break
  fi
done < <(candidates)
[ -n "$bundle" ] || {
  echo "blog-build: no bundler can load $BLOG_REPO — put one on PATH, set BUNDLE=/path/to/bundle, or (bundle install) in the checkout" >&2
  exit 2
}

log=$(mktemp)
trap 'rm -f "$log"' EXIT

rm -rf "$out"
if ! (cd "$BLOG_REPO" && JEKYLL_ENV=production "$bundle" exec jekyll b -d "$out") >"$log" 2>&1; then
  echo "blog-build: jekyll build failed in $BLOG_REPO" >&2
  tail -n 20 "$log" | sed 's/^/  /' >&2
  echo "blog-build: a fresh checkout needs (bundle install) before it can build" >&2
  exit 2
fi
[ -f "$out/index.html" ] || {
  echo "blog-build: $out has no index.html — nothing was built" >&2
  exit 2
}

echo "ok   $BLOG_REPO built to $out ($(find "$out" -type f | wc -l) files)"
