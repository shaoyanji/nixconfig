#!/usr/bin/env bash
# scripts/task/bountystash-dir.sh — where the bountystash-console checkout is.
#
# The console lives in its own repo, so every task that builds or deploys it
# needs a path, and no path is right on more than one host: frieren keeps it on
# the data volume, a workstation beside this repo, a fresh host not at all. The
# taskfile therefore asks here instead of naming one, and `BOUNTY_DIR` is the
# answer to "where is it" for this invocation, not a constant.
#
# Prints the checkout and exits 0, or names every place it looked and exits 2.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

candidates=()
add() {
  local dir=${1%/}
  local seen
  for seen in ${candidates[@]+"${candidates[@]}"}; do
    [ "$seen" = "$dir" ] && return 0
  done
  candidates+=("$dir")
}

if [ -n "${BOUNTY_DIR:-}" ]; then
  add "$BOUNTY_DIR"
fi
add "$(dirname "$repo")/bountystash-console"
add "/Volumes/data/projects/bountystash-console"
add "/srv/data/projects/bountystash-console"
add "$HOME/Documents/bountystash-console"
add "$HOME/projects/bountystash-console"
add "$HOME/bountystash-console"

# A checkout, not just a directory with the right name: the build script is what
# the tasks run, and .git is what the git tasks operate on.
for dir in "${candidates[@]}"; do
  if [ -f "$dir/scripts/build.js" ] && [ -d "$dir/.git" ]; then
    printf '%s\n' "$dir"
    exit 0
  fi
done

{
  echo "bountystash-dir: no bountystash-console checkout found. Looked in:"
  printf '  %s\n' "${candidates[@]}"
  echo ""
  echo "Point one: BOUNTY_DIR=/path/to/bountystash-console task bountystash:build"
} >&2
exit 2
