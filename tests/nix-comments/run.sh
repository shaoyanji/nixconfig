#!/usr/bin/env bash
# Regression fixture for `task checks:nix:comments`
# (scripts/task/nix-comments.sh).
#
# The gate resolves every `task <name>` a Nix comment cites against the recipe
# table — a cite to a recipe that does not exist is a pointer to nothing. No
# such break is on record, so the mistake is seeded, not replayed: a tracked
# .nix file in a scratch worktree gets one comment citing `task nope:zzz`,
# a recipe the task plane has never had. The gate must name it; HEAD must
# stay clean. The seed edits a tracked file so the worktree's flake source
# carries it.
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

# 1. A seeded dangling task pointer must fail, named.
echo '# see task nope:zzz' >>"$tmp/wt/flake/check-inventory.nix"
out=$(cd "$tmp/wt" && bash scripts/task/nix-comments.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'nope:zzz'; then
  echo "ok   seeded cite refused, pointer named"
else
  echo "FAIL seeded tree: rc=$rc — expected unresolved pointer"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/nix-comments.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "nix-comments:test: all cases pass"
exit $fail
