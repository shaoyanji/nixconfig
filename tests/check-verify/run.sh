#!/usr/bin/env bash
# Regression fixture for `task check:verify` (scripts/task/check.sh verify).
#
# The gate holds flake/check-inventory.nix honest in both directions — a
# checks:* task with no row and a row naming no task are both exit 1. The
# mistake is seeded: a scratch worktree's inventory loses one row
# (`checks:repo:paths`), leaving a gate nobody classified — the drift a rename
# or a careless delete produces. `check.sh verify` must refuse it; HEAD must
# stay clean.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null || { echo "fixture: no git" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

fail=0

# 1. A missing inventory row must fail, the orphaned task named.
grep -v '"checks:repo:paths" = ' "$tmp/wt/flake/check-inventory.nix" >"$tmp/wt/inv.tmp" &&
  mv "$tmp/wt/inv.tmp" "$tmp/wt/flake/check-inventory.nix"
grep -q '"checks:repo:paths" = ' "$tmp/wt/flake/check-inventory.nix" &&
  { echo "fixture: row removal did not take" >&2; exit 2; }
out=$(cd "$tmp/wt" && bash scripts/task/check.sh verify 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'repo:paths'; then
  echo "ok   missing row refused, orphaned task named"
else
  echo "FAIL seeded tree: rc=$rc — expected a verify refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/check.sh" verify >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: verify refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "check-verify:test: all cases pass"
exit $fail
