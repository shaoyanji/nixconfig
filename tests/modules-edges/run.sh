#!/usr/bin/env bash
# Regression fixture for `task checks:modules:edges`
# (scripts/task/modules-edges.sh).
#
# The 2026-11 module conversion found path edges by hand across 24 files —
# `import ../x.nix` and bare `./x.nix` imports elements that work at eval time
# and only break when the target is renamed. No break is on record (the gate
# was written before one could ship), so the mistake is seeded: a tracked
# module file in a scratch worktree gains one relative path import. Text-only
# check, ~0.6 s; the seeded line must be named and HEAD must stay clean.
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

# 1. A seeded `import ../x.nix;` must fail, file:line named.
echo 'import ../lib/seeded-edge.nix;' >>"$tmp/wt/modules/global/user.nix"
out=$(cd "$tmp/wt" && bash scripts/task/modules-edges.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'user.nix'; then
  echo "ok   seeded edge refused, module named"
else
  echo "FAIL seeded tree: rc=$rc — expected an edge refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/modules-edges.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "modules-edges:test: all cases pass"
exit $fail
