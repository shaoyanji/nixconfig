#!/usr/bin/env bash
# Regression fixture for the media library: the manifest the page reads, and the
# rows the page renders.
#
# The index jq is not copied here — it is extracted from the module by its own
# delimiters, so a test cannot pass against a filter the host no longer runs.
# The page functions are extracted the same way and run under node: the row is
# asserted to carry a thumbnail only when the manifest names a poster, to keep
# the copy button outside the anchor, and to order folders newest first.
#
# The fixture is six files over three folders, so every rule is exercised at
# least once: a video with a poster, a video without one, an image whose
# extension is upper case, audio, a subtitle-adjacent `.txt` that must be
# dropped, and the poster itself that must never be listed.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
module="$repo/modules/services/media-relay.nix"
page="$repo/lib/media-relay/index.html"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for cmd in jq node find; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "fixture: $cmd is required" >&2
    exit 2
  }
done
[ -f "$module" ] || {
  echo "fixture: $module is missing" >&2
  exit 2
}
[ -f "$page" ] || {
  echo "fixture: $page is missing" >&2
  exit 2
}

fail=0
is() {
  local name=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name" >&2
    echo "       want: $want" >&2
    echo "       got:  $got" >&2
    fail=1
  fi
}

# The filter lives between the `jq -R -n --arg now` line and the line that
# redirects it to the manifest, indented as Nix string content.
sed -n "/jq -R -n --arg now/,/^ *' >\"\\\$tmp\"\$/p" "$module" |
  sed '1d;$d;s/^ *//' >"$work/filter.jq"
if [ ! -s "$work/filter.jq" ]; then
  echo "fixture: could not extract the index filter from $module" >&2
  exit 2
fi

lib="$work/lib"
mkdir -p "$lib/vidA" "$lib/vidB" "$lib/pics"
head -c 5000 /dev/zero >"$lib/vidA/Big Buck Bunny.mp4"
head -c 1200 /dev/zero >"$lib/vidA/poster.jpg"
head -c 3000 /dev/zero >"$lib/vidB/clip.webm"
head -c 900 /dev/zero >"$lib/loose.mp3"
head -c 400 /dev/zero >"$lib/pics/photo.JPG"
printf 'notes\n' >"$lib/notes.txt"

find "$lib" -type f ! -name '.index.json' -printf '%P\t%s\t%T@\n' |
  jq -R -n --arg now "2026-01-01T00:00:00Z" -f "$work/filter.jq" >"$work/index.json" || {
  echo "fixture: the index filter failed to run" >&2
  exit 2
}

j() { jq -r "$1" "$work/index.json"; }

is "count excludes the poster and the .txt" "4" "$(j '.count')"
is "bytes are the library's media only" "9300" "$(j '.bytes')"
is "paths are relative and sorted" \
  "loose.mp3,pics/photo.JPG,vidA/Big Buck Bunny.mp4,vidB/clip.webm" \
  "$(j '[.files[].path] | join(",")')"
is "kinds follow the extension set" "audio,image,video,video" "$(j '[.files[].kind] | join(",")')"
is "an upper-case extension is lowercased" "jpg" "$(j '.files[] | select(.path | startswith("pics/")) | .ext')"
is "a folder with a poster names it" "vidA/poster.jpg" \
  "$(j '.files[] | select(.path | startswith("vidA/")) | .poster')"
is "a folder without one has no poster field" "null" \
  "$(j '.files[] | select(.path | startswith("vidB/")) | .poster // "null"')"
is "the poster is not a file of its own" "0" \
  "$(j '[.files[] | select(.name == "poster.jpg")] | length')"
is "the poster is not counted as bytes" "0" \
  "$(j '[.files[] | select(.path | endswith("poster.jpg")) | .size] | add // 0')"
is "a .txt is left out of the manifest" "0" \
  "$(j '[.files[] | select(.name == "notes.txt")] | length')"
is "the manifest is stamped" "2026-01-01T00:00:00Z" "$(j '.generated')"

# The page's own functions, not a reimplementation of them.
node "$here/page.js" "$page" || fail=1

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "FAIL: the media library regressed against the fixture above." >&2
  exit 1
fi
echo "PASS: the index and the page rows hold over the fixture."
