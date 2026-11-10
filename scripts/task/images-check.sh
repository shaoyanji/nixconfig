#!/usr/bin/env bash
# The manifest is a projection of urls.tsv: one row in, one asset out. A row that
# stops landing in the manifest is an upload nothing can find, and it reads as a
# missing image on the frontend rather than as a broken build.
set -euo pipefail
root=${IMAGES_ROOT:-/Volumes/data/pics/generated}
tsv=$root/published/urls.tsv
man=$root/published/manifest.json
if [ ! -s "$tsv" ] || [ ! -s "$man" ]; then
  echo "images-check: no asset root at $root — nothing to compare"
  exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
grep -v '^$' "$tsv" | cut -f1 | sort >"$tmp/rows"
jq -r '.assets[].path' "$man" | sort >"$tmp/assets"
rows=$(wc -l <"$tmp/rows")
count=$(jq -r '.count' "$man")
assets=$(wc -l <"$tmp/assets")
rc=0
if [ "$rows" != "$count" ]; then
  echo "images-check: urls.tsv has $rows row(s), the manifest counts $count" >&2
  rc=1
fi
if [ "$assets" != "$count" ]; then
  echo "images-check: the manifest counts $count but lists $assets asset(s)" >&2
  rc=1
fi
missing=$(comm -23 "$tmp/rows" "$tmp/assets" || true)
extra=$(comm -13 "$tmp/rows" "$tmp/assets" || true)
if [ -n "$missing" ]; then
  echo "images-check: rows with no asset in the manifest:" >&2
  printf '%s\n' "$missing" | sed 's/^/  /' >&2
  rc=1
fi
if [ -n "$extra" ]; then
  echo "images-check: assets with no row in urls.tsv:" >&2
  printf '%s\n' "$extra" | sed 's/^/  /' >&2
  rc=1
fi
if [ "$rc" = 0 ]; then
  echo "images-check: ok — $rows row(s), $count asset(s), the same paths"
fi
exit "$rc"
