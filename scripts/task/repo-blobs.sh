#!/usr/bin/env bash
# Fail when a large blob enters the index, or is already reachable in history.
#
# A blob is forever. The 26.5 MiB skyline STL and an 829 KiB wallpaper lived in
# this history for a year, 4 MiB of a 12 MiB pack, long after both files were
# deleted from the tree; removing them cost a rewrite of every commit id on
# every branch. Deleting a file does not delete its blob, so the only cheap
# moment to refuse one is before it is committed.
#
# What belongs here is text. A binary stays out of this repository: on the NAS
# under /srv/data, or registered in modules/config/fetches.json and downloaded
# by URL at build time, so the store owns the bytes and git only owns the hash.
#
# Two modes, because the two moments differ:
#   --index    staged blobs. Runs in .githooks/pre-commit, before the blob exists.
#   --history  every blob reachable from any ref. Runs in pre-push and as a check.
#
# Threshold is 512 KiB, MAX= to change it. Headroom over the largest legitimate
# file here (AGENTS.nix, ~342 KiB); the wallpaper that started this would have
# been refused. Exceptions are per-path and deliberate: ALLOW="a/b.png,c/*.pdf"
# takes comma-separated globs, and the run prints each one it skipped.
#
# Exit 0 = clean, 1 = at least one blob over the threshold, 2 = could not run.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

MAX="${MAX:-524288}"
ALLOW="${ALLOW:-}"
self="scripts/task/repo-blobs.sh"

mode=""
case "${1:---history}" in
  --index) mode=index ;;
  --history) mode=history ;;
  -h | --help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "usage: repo-blobs.sh [--index|--history]   MAX=<bytes> ALLOW=<globs>" >&2
    exit 2
    ;;
esac

allowed() {
  local path="$1" pat
  [ -n "$ALLOW" ] || return 1
  IFS=',' read -ra pats <<<"$ALLOW"
  for pat in "${pats[@]}"; do
    # shellcheck disable=SC2053 # glob match is the point
    case "$path" in $pat) return 0 ;; esac
  done
  return 1
}

sizeof_blobs() {
  # stdin: "<path>\t<blob>". stdout: "<path>\t<size>", same order, space-safe.
  local rows
  rows=$(mktemp)
  cat >"$rows"
  paste -d'\t' <(cut -f1 "$rows") <(cut -f2 "$rows" | git cat-file --batch-check='%(objectsize)') |
    awk -F'\t' '$2 ~ /^[0-9]+$/'
  rm -f "$rows"
}

if [ "$mode" = index ]; then
  # Index objects, not working-tree files: what would be committed.
  rows=$(git ls-files -s -- | awk '$1=="120000" || $1=="160000"{next} {print $4"\t"$2}' | sizeof_blobs)
  label="index"
else
  rows=$(git rev-list --objects --all |
    awk 'NF>1{print substr($0, index($0, " ")+1)"\t"$1}' |
    sizeof_blobs)
  label="history"
fi

bad=0
total=0
biggest=0
biggest_path=""
human() { numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1"; }

while IFS=$'\t' read -r path size; do
  [ -n "${path:-}" ] || continue
  [ "$path" = "$self" ] && continue
  total=$((total + 1))
  if [ "$size" -gt "$biggest" ]; then
    biggest=$size
    biggest_path=$path
  fi
  [ "$size" -gt "$MAX" ] || continue
  if allowed "$path"; then
    printf '  allowed  %9s  %s\n' "$(human "$size")" "$path"
    continue
  fi
  bad=$((bad + 1))
  printf '  OVER     %9s  %s\n' "$(human "$size")" "$path"
done <<<"$rows"

printf '%s: %d blob(s) over %s across %d, largest %s%s\n' \
  "$label" "$bad" "$(human "$MAX")" "$total" "$(human "$biggest")" \
  "${biggest_path:+ ($biggest_path)}"

if [ "$bad" -ne 0 ]; then
  echo
  echo "A blob this size is permanent: deleting the file later keeps the object and"
  echo "costs a rewrite of every commit to remove it. Put the bytes on /srv/data, or"
  echo "register the URL in modules/config/fetches.json and let the store fetch it."
  echo "For a deliberate exception: ALLOW='<glob>' bash scripts/task/repo-blobs.sh"
  exit 1
fi
