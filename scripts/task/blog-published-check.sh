#!/usr/bin/env bash
# scripts/task/blog-published-check.sh — the live is-a.dev site is the build of
# blog main.
#
# Pages sets no header naming the tree it serves, so a deploy that kept
# yesterday's build answers 200 exactly like a fresh one. Three references make
# the answer exact, and none of them is the checkout's `_site`:
#   * the checkout is clean and its HEAD is what origin/main points at right now
#     (`git ls-remote`, not a stale fetch), so an unpublished commit or an edit
#     in the working tree fails before a request;
#   * the site is rebuilt here in production mode (`blog-build.sh`), because
#     `_site` is the last local build and not necessarily this commit's;
#   * every file the build carries is fetched and compared byte for byte.
#
# Three fields are the build environment rather than the build, and none of
# them reproduces across machines:
#   * the clock — the feed's `<updated>`, an undated page's article time, and the
#     service worker's `chirpy-<epoch>` cache name;
#   * the sitemap's `<lastmod>`, which jekyll-sitemap takes from each file's
#     mtime, so a fresh checkout writes a different value for the same source;
#   * the CSS sourcemap's `sources`, which names the ruby the gems were vendored
#     under (`vendor/bundle/ruby/3.2.0` on CI, another here).
# Each is compared as a placeholder while every other byte stays strict, so a
# moved post date, a changed template or a stale PDF still fails.
#
# Usage: blog-published-check.sh
#
# Env: BLOG_REPO (default ~/Documents/shaoyanji.is-a.dev), HOST
# (shaoyanji.is-a.dev), TIMEOUT (25), BUNDLE (see blog-build.sh).
#
# EXIT
#   0  every file the build carries is served at HOST, byte for byte
#   1  divergence: a served file differs, or the checkout is dirty / not main
#   2  cannot tell: no checkout, no bundler, no A record, no answer in time
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

BLOG_REPO=${BLOG_REPO:-$HOME/Documents/shaoyanji.is-a.dev}
HOST=${HOST:-shaoyanji.is-a.dev}
TIMEOUT=${TIMEOUT:-25}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "blog-published: $*" >&2
  exit 2
}

# The stamp a build writes into its feed is its clock. The feed is one line and
# carries one `<updated>` per entry, so take the first match — the feed-level
# one — and never the last, which is just the oldest post's date.
stamp_of() {
  grep -o '<updated>[^<]*</updated>' "$1" 2>/dev/null | head -n 1 | sed 's|</\?updated>||g'
}

# Normalise one file: the caller's own clock, and the epoch in the SW cache
# name, both become one placeholder. Nothing else is touched.
norm() { # STAMP FILE
  local -a stamps=()
  [ -n "$1" ] && stamps=(-e "s|$1|@BUILD_TIME@|g")
  sed "${stamps[@]}" \
    -e 's|chirpy-[0-9][0-9]*|chirpy-@BUILD_TIME@|g' \
    -e 's|<lastmod>[^<]*</lastmod>|<lastmod>@LASTMOD@</lastmod>|g' \
    -e 's|vendor/bundle/ruby/[0-9][0-9.]*/|vendor/bundle/ruby/@RUBY@/|g' \
    "$2"
}

# `rev-parse` rather than a `.git` test: a linked worktree's `.git` is a file.
git -C "$BLOG_REPO" rev-parse --git-dir >/dev/null 2>&1 || fail "no git checkout at $BLOG_REPO"

dirty=$(git -C "$BLOG_REPO" status --porcelain 2>/dev/null) ||
  fail "git status failed in $BLOG_REPO"
if [ -n "$dirty" ]; then
  echo "FAIL $BLOG_REPO has uncommitted changes — the published site is not this tree" >&2
  printf '     %s\n' $dirty >&2
  echo "     fix: land or discard them; a local build is not a published commit" >&2
  exit 1
fi

head=$(git -C "$BLOG_REPO" rev-parse HEAD 2>/dev/null) || fail "no HEAD in $BLOG_REPO"
remote=$(timeout "$TIMEOUT" git -C "$BLOG_REPO" ls-remote origin refs/heads/main 2>/dev/null | cut -f1)
[ -n "$remote" ] || fail "origin/main did not answer from $BLOG_REPO"

if [ "$head" != "$remote" ]; then
  echo "FAIL the blog checkout is not origin/main" >&2
  echo "     checkout HEAD: $head" >&2
  echo "     origin/main:   $remote" >&2
  echo "     fix: land or pull the blog branch — a Pages build of any other commit is drift" >&2
  exit 1
fi
short=$(git -C "$BLOG_REPO" rev-parse --short HEAD)
echo "ok   $BLOG_REPO is clean at origin/main $short"

build="$tmp/site"
bash "$(dirname "${BASH_SOURCE[0]}")/blog-build.sh" "$build" || fail "could not build the blog"

ip=$(dig +short @1.1.1.1 "$HOST" | grep -E '^[0-9]' | sed -n 1p)
[ -n "$ip" ] || fail "1.1.1.1 returns no A record for $HOST"

fetch() { # PATH -> body on stdout
  curl -sSL --max-time "$TIMEOUT" --resolve "$HOST:443:$ip" "https://$HOST$1"
}

fetch / >"$tmp/root" || fail "$HOST / did not answer"
build_stamp=$(stamp_of "$build/feed.xml")
live_stamp=$(fetch /feed.xml 2>/dev/null | grep -o '<updated>[^<]*</updated>' | head -n 1 | sed 's|</\?updated>||g')

ok=0
bad=0
total=0
while IFS= read -r rel; do
  # Pages reads `_headers` at deploy time and never serves it.
  [ "$rel" = "_headers" ] && continue
  total=$((total + 1))
  case $rel in
    index.html) url=/ ;;
    */index.html) url="/${rel%/index.html}/" ;;
    *) url="/$rel" ;;
  esac
  code=$(curl -sSL --max-time "$TIMEOUT" --resolve "$HOST:443:$ip" \
    -o "$tmp/body" -w '%{http_code}' "https://$HOST$url")
  if [ "$code" != 200 ]; then
    printf 'FAIL %s%s answers %s, the build of %s carries it\n' "$HOST" "$url" "$code" "$short"
    bad=$((bad + 1))
    continue
  fi
  norm "$live_stamp" "$tmp/body" >"$tmp/live.norm"
  norm "$build_stamp" "$build/$rel" >"$tmp/build.norm"
  if cmp -s "$tmp/live.norm" "$tmp/build.norm"; then
    ok=$((ok + 1))
  else
    printf 'FAIL %s%s differs  live %s %sB  build %s %sB\n' "$HOST" "$url" \
      "$(sha256sum <"$tmp/live.norm" | cut -c1-12)" "$(wc -c <"$tmp/live.norm")" \
      "$(sha256sum <"$tmp/build.norm" | cut -c1-12)" "$(wc -c <"$tmp/build.norm")"
    bad=$((bad + 1))
  fi
done < <(cd "$build" && find . -type f | sed 's|^\./||' | sort)

if [ "$bad" -ne 0 ]; then
  echo "blog-published: $bad of $total file(s) at $HOST differ from the build of $short" >&2
  echo "blog-published: live is not main's build — let Pages finish (gh run list), or push main" >&2
  exit 1
fi

echo "blog-published: $ok/$total file(s) at $HOST match the build of $short"
exit 0
