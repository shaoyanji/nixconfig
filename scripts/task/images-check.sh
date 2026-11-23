#!/usr/bin/env bash
# The manifest is a projection of urls.tsv: one row in, one asset out. A row that
# stops landing in the manifest is an upload nothing can find, and it reads as a
# missing image on the frontend rather than as a broken build. The URL half of a
# row is checked too: every row must name the Cloudinary delivery URL of the
# public id its path derives — a session-gated render URL would serve a 401,
# and a URL naming another upload serves the wrong plate.
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
# A row is not shipped just because it exists: its URL must be the bank's
# delivery URL for the id the path derives — `badge/<x>` addresses
# `assets/fleet/<x>`, every other lane is `assets/<path>` — and never the
# session-gated render URL, which answers 401 to anyone but its maker. This is
# the contract `images:ship`/`images:add` and publish all write to, so the gate
# that proves row-into-manifest is the right place to prove it.
while IFS=$'\t' read -r rel url _bytes; do
  [ -n "$rel" ] || continue
  case $rel in
    badge/*) want="assets/fleet/$(basename "${rel%.*}")" ;;
    *) want="assets/${rel%.*}" ;;
  esac
  case $url in
    *chatplayground* | */api/files/*)
      echo "images-check: $rel carries a session-gated URL, not the bank: $url" >&2
      rc=1 ;;
    https://res.cloudinary.com/*/image/upload/*"$want".*) ;;
    *)
      echo "images-check: $rel url does not name $want: $url" >&2
      rc=1 ;;
  esac
done <"$tsv"

# The manifest's URL is the row's URL carried through the build: a consumer
# reads the manifest, so a URL that drifted between the two is a shipped plate
# whose link is wrong in exactly the place the gallery serves it from.
grep -v '^$' "$tsv" | cut -f1,2 | sort >"$tmp/rowurls"
jq -r '.assets[] | [.path, .url] | @tsv' "$man" | sort >"$tmp/asseturls"
if ! cmp -s "$tmp/rowurls" "$tmp/asseturls"; then
  echo "images-check: manifest URLs differ from urls.tsv rows:" >&2
  diff "$tmp/rowurls" "$tmp/asseturls" | head -10 | sed 's/^/  /' >&2
  rc=1
fi

if [ "$rc" = 0 ]; then
  echo "images-check: ok — $rows row(s), $count asset(s), same paths and bank URLs"
fi
exit "$rc"
