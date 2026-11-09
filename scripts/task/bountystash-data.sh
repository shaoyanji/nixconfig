#!/usr/bin/env bash
# scripts/task/bountystash-data.sh — one corpus, one published copy.
#
#   bountystash-data.sh sync  DIR     write DIR/data/portfolio*.json from the corpus
#   bountystash-data.sh check DIR     fail when they are not the same document
#
# The corpus is lib/bountystash/portfolio*.json: it is what the Gemini capsule
# compiles and what a content edit touches. The console builds from its own
# data/ copy, so that copy is written here and never hand-edited — the deploy asks
# `check` first, and a stale copy fails instead of publishing yesterday's prose.
set -euo pipefail

usage() {
  echo "usage: bountystash-data.sh sync|check DIR" >&2
  exit 2
}

[ $# -eq 2 ] || usage
mode=$1
dir=${2%/}
files=(portfolio portfolio.de)

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

case "$mode" in
  sync)
    [ -d "$dir/data" ] || { echo "bountystash-data: no $dir/data" >&2; exit 2; }
    for f in "${files[@]}"; do
      jq . "$repo/lib/bountystash/$f.json" >"$dir/data/$f.json"
    done
    echo "bountystash-data: wrote ${#files[@]} files into $dir/data"
    ;;
  check)
    drift=0
    for f in "${files[@]}"; do
      if [ ! -s "$dir/data/$f.json" ]; then
        echo "bountystash-data: $dir/data/$f.json is missing" >&2
        drift=1
      elif ! diff -q <(jq -S . "$repo/lib/bountystash/$f.json") <(jq -S . "$dir/data/$f.json") >/dev/null; then
        echo "bountystash-data: data/$f.json differs from lib/bountystash/$f.json — run task bountystash:data" >&2
        drift=1
      fi
    done
    if [ "$drift" -ne 0 ]; then
      exit 1
    fi
    echo "bountystash-data: the console's data is the corpus"
    ;;
  *) usage ;;
esac
