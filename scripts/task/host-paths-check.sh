#!/usr/bin/env bash
# Fail when a tracked file names the layout of one machine.
#
# This repo is public, and three classes leak a workstation into it:
#
#   1. a mount that exists on one host only — `/Volumes/<name>` other than the
#      documented storage root `/Volumes/data`;
#   2. somebody's checkout under a home directory (`/home/<u>/Documents/...`,
#      `/Users/<u>/projects/...`) — dead on every other machine and in CI;
#   3. key material in the clear, which must only ever reach the tree encrypted.
#
# Deliberately NOT judged: `file://` (most uses here are `nix copy --to file://`
# caches and `git+file://` flake refs, and markdown links are `checks:docs:links`'
# job), `/home/<user>` as a fact (the fleet's own user home is configuration, not
# a leak), and IP addresses (the inventory publishes the fleet's network on
# purpose). `checks:repo:paths` covers a checkout path in code; this covers the
# layout around it.
#
# An exception is `host-path-ok:` with a reason on the same line. The turn ledger
# and test fixtures are skipped by path: one is generated, the other asserts on
# strings.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

SELF="scripts/task/host-paths-check.sh"
EXCLUDE=(":!${SELF}" ":!lib/agent-turns/turns.json" ":!*_test.go" ":!tests/*")

fail=0

# label, extended regex, optional regex of lines to ignore
judge() {
  local label=$1 pattern=$2 ignore=${3:-}
  local hits
  # Every stage carries `|| true`: `git grep` and the final `grep -v` both exit 1
  # on a clean tree, and under `set -e` that would abort the gate instead of
  # letting it report PASS.
  hits="$(
    { git grep -nIE -- "$pattern" -- . "${EXCLUDE[@]}" || true; } |
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
  '/(home|Users)/[^/]+/(Documents|projects|Desktop|Downloads)/' \
  '/Documents/nixconfig'

judge \
  'key material in the clear' \
  'BEGIN (OPENSSH|RSA|EC|AGE|PGP) PRIVATE KEY|AGE-SECRET-KEY-1'

if [ "$fail" -ne 0 ]; then
  printf '\nFAIL: a machine path or plaintext key is tracked above.\n'
  printf 'Use a portable form ($HOME, git rev-parse --show-toplevel, ../..), or mark\n'
  printf 'the line `host-path-ok: <reason>` when the path is the point.\n'
  exit 1
fi

printf 'PASS: %s tracked files, no machine paths or plaintext keys.\n' "$(git ls-files | wc -l | tr -d ' ')"
