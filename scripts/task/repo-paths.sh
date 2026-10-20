#!/usr/bin/env bash
# Fail when a tracked file hardcodes a machine-specific checkout path.
#
# A task or module that names the author's checkout only works on the one host
# that has it; this tree deploys to the whole fleet and runs in CI, where that
# path does not exist. Use one of these instead:
#
#   taskfile   a path relative to the task dir      modules/services/x.nix
#   shell      "$(git rev-parse --show-toplevel)"
#   nix        ../..  (resolves to the flake source)
#   python     Path(__file__).resolve().parents[n]
#
# This file is the one place the absolute prefixes are allowed to appear: it is
# the gate, and it excludes itself by path.
#
# Exception: put `repo-path-ok:` and a reason on the offending line, for text
# that quotes a path it does not use (verbatim log output, a note body).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

SELF="scripts/task/repo-paths.sh"

PATTERNS=(
  '/Volumes/data/projects/nixconfig'
  '/srv/data/projects/nixconfig'
  '/home/[^/]+/Documents/nixconfig'
  '/Users/[^/]+/Documents/nixconfig'
)

fail=0
for pat in "${PATTERNS[@]}"; do
  hits="$(git grep -nE "$pat" -- '*.sh' '*.py' '*.yml' '*.nix' ":!${SELF}" | grep -v 'repo-path-ok:' || true)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  printf '\n%s\n' "FAIL: a checkout path is hardcoded above. Use a repo-relative path,"
  printf '%s\n\n' "git rev-parse --show-toplevel, Nix ../.., or Path(__file__) instead."
  exit 1
fi

echo "PASS: no tracked file hardcodes a checkout path."
