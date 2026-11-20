#!/usr/bin/env bash
# Fail when a tracked file names the layout of one machine.
#
# This repo is public, and three classes leak a workstation into it:
#
#   1. a mount that exists on one host only — `/Volumes/<name>` other than the
#      documented storage root `/Volumes/data`;
#   2. somebody's checkout under a home directory — the `Documents/`, `projects/`,
#      `code/`, `src/`, `dev/`, `work/`, `repos/`, `git/`, `source/`,
#      `Developer/` or `Workspace/` folder a checkout sits in below a home, dead
#      on every other machine and in CI;
#   3. a Windows profile path (`C:\Users\<name>\…`, or its forward-slash form),
#      the same leak on the one host in the fleet that runs Windows;
#   4. key material in the clear, which must only ever reach the tree encrypted.
#
# The home vocabulary is a list of the words a checkout actually sits in, not a
# proof: a checkout under a word nobody listed reads as portable. Widening it is
# the repair, and `tests/host-paths/run.sh` keeps one failing case per word class
# so the list cannot quietly lose one.
#
# Deliberately NOT judged: `file://` (most uses are `nix copy --to file://`
# caches and `git+file://` flake refs, and markdown links are
# `checks:docs:links`), `/home/<user>` as a fact (the fleet's own user home is
# configuration), and IP addresses (the inventory publishes the network on
# purpose). `checks:repo:paths` covers a checkout path in code; this covers the
# layout around it.
#
# An exception is `host-path-ok:` with a reason on the same line. The turn ledger
# and test fixtures are skipped by path.
#
# Usage: host-paths-check.sh [FILE...]   no arguments = every tracked file.
set -euo pipefail

EXCLUDE=(
  ":!scripts/task/host-paths-check.sh"
  ":!lib/agent-turns/turns.json"
  ":!*_test.go"
  ":!tests/*"
)

# Two doors: the gate itself walks tracked files, and the fixture hands it a temp
# file per rule. The fixture needs the same rules, not a copy of them.
if [ "$#" -gt 0 ]; then
  files=("$@")
  count=$#
  scan() { grep -nIE -- "$1" "${files[@]}" 2>/dev/null || true; }
else
  cd "$(git rev-parse --show-toplevel)"
  count=$(git ls-files | wc -l | tr -d ' ')
  scan() { git grep -nIE -- "$1" -- . "${EXCLUDE[@]}" || true; }
fi

fail=0

# label, extended regex, optional regex of lines to ignore
judge() {
  local label=$1 pattern=$2 ignore=${3:-}
  local hits
  # Every stage carries `|| true`: `git grep` and the final `grep -v` both exit 1
  # on a clean tree, and under `set -e` that would abort the gate instead of
  # letting it report PASS.
  hits="$(
    scan "$pattern" |
      { if [ -n "$ignore" ]; then grep -vE -- "$ignore" || true; else cat; fi; } |
      { grep -v 'host-path-ok:' || true; }
  )"
  if [ -n "$hits" ]; then
    printf 'FAIL %s\n' "$label"
    printf '%s\n' "$hits" | sed 's/^/  /'
    fail=1
  fi
}

judge \
  'a mount that is not the documented storage root' \
  '/Volumes/[A-Za-z][^/]*' \
  '/Volumes/data'

judge \
  'a checkout under a home directory' \
  '/(home|Users)/[^/]+/(Documents|projects|Desktop|Downloads|code|src|dev|work|repos|git|source|Developer|Workspace)/' \
  '/Documents/nixconfig'

# The leading guard is what keeps `file:///Users/…` from reading as a drive
# letter: a URL is not a profile path, and the docs gate itself greps for one.
judge \
  'a Windows user profile path' \
  '(^|[^A-Za-z])[A-Za-z]:[\\/]+(Users|Documents and Settings)[\\/]+'

judge \
  'key material in the clear' \
  'BEGIN (OPENSSH|RSA|EC|AGE|PGP) PRIVATE KEY|AGE-SECRET-KEY-1'

if [ "$fail" -ne 0 ]; then
  printf '\nFAIL: a machine path or plaintext key is tracked above.\n'
  printf 'Use a portable form ($HOME, git rev-parse --show-toplevel, ../..), or mark\n'
  printf 'the line `host-path-ok: <reason>` when the path is the point.\n'
  exit 1
fi

printf 'PASS: %s file(s) checked, no machine paths or plaintext keys.\n' "$count"
