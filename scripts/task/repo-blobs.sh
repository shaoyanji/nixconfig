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
# Three modes, because the moments differ:
#   --index    staged blobs. Runs in .githooks/pre-commit, before the blob exists.
#   --push     only the blobs the push would add: reachable from the pushed
#              commits and not already on the remote. Runs in .githooks/pre-push,
#              which pipes git's pre-push lines (local ref, local sha, remote
#              ref, remote sha) in on stdin.
#   --history  every blob reachable from any ref. The audit gate. It stays red
#              on the two legacy blobs above until a rewrite removes them, which
#              is the point: no push can fix them, and failing every push for
#              them only teaches --no-verify.
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
  --push) mode=push ;;
  -h | --help)
    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
    exit 0
    ;;
  *)
    echo "usage: repo-blobs.sh [--index|--push|--history]   MAX=<bytes> ALLOW=<globs>" >&2
    exit 2
    ;;
esac

allowed() {
  local path="$1" pat
  [ -n "$ALLOW" ] || return 1
  IFS=',' read -ra pats <<<"$ALLOW"
  for pat in "${pats[@]}"; do
    # shellcheck disable=SC2254 # glob match is the point
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

list_blobs() {
  # stdin: `git rev-list --objects` lines. stdout: "<path>\t<size>".
  awk 'NF>1{print substr($0, index($0, " ")+1)"\t"$1}' | sizeof_blobs
}

if [ "$mode" = index ]; then
  # Index objects, not working-tree files: what would be committed.
  rows=$(git ls-files -s -- | awk '$1=="120000" || $1=="160000"{next} {print $4"\t"$2}' | sizeof_blobs)
  label="index"
elif [ "$mode" = push ]; then
  # One line per ref, as git sends them. A deleted ref (local sha all zeros)
  # adds nothing; a new branch (no remote sha) starts from nothing.
  locals=()
  excludes=()
  while read -r _lref lsha _rref rsha; do
    [ -n "${lsha//0/}" ] || continue
    locals+=("$lsha")
    [ -n "${rsha:-}" ] && [ -n "${rsha//0/}" ] && excludes+=("$rsha")
  done
  if [ "${#locals[@]}" -eq 0 ]; then
    echo "push: no ref to send, no blob checked"
    exit 0
  fi
  # A ref the server moved to after our last fetch is not in this object
  # database, and `rev-list --not <missing>` dies with "bad object" — which
  # refused a legitimate push twice in a row while another turn was pushing.
  # Keep the bases this clone can resolve, say so about the rest, and let the
  # range against the refs we do have speak for itself.
  resolvable=()
  if [ "${#excludes[@]}" -gt 0 ]; then
    for base in "${excludes[@]}"; do
      if git cat-file -e "$base^{commit}" 2>/dev/null; then
        resolvable+=("$base")
      else
        echo "push: base $base is not in this clone (behind the server); checking against the refs we have" >&2
      fi
    done
  fi
  excludes=("${resolvable[@]+"${resolvable[@]}"}")
  # --remotes as well as the sent shas: a branch built here out of commits the
  # remote already holds carries no new objects either.
  if ! rows=$(git rev-list --objects "${locals[@]}" \
    --not ${excludes[@]+"${excludes[@]}"} --remotes | list_blobs); then
    echo "blobs: could not list the objects this push would add" >&2
    exit 2
  fi
  label="push"
else
  rows=$(git rev-list --objects --all | list_blobs)
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
