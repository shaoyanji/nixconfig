#!/usr/bin/env bash
# Regression fixture for `task checks:repo:paths` (scripts/task/repo-paths.sh).
#
# The failing input is a real past tree, not a retype: 7059c0a2^ is the commit
# before `fix(atuin): resolve the repo from git, not a hardcoded path list` —
# atuin-bootstrap.sh, Taskfile.yml, hosts/delphi/configuration.nix and
# modules/nixoshmsymlinks.nix all carried literal checkout paths that only the
# author's machine could resolve. The gate must refuse that tree and accept
# the current one.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/repo-paths.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }
command -v git >/dev/null || { echo "fixture: no git" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

fail=0

# 1. The past tree must fail — the current script greps it with git rev-parse.
git -C "$repo" worktree add --detach "$tmp/wt" "7059c0a2^" >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree at 7059c0a2^" >&2; exit 2; }
out=$(cd "$tmp/wt" && bash "$gate" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'atuin-bootstrap.sh'; then
  echo "ok   7059c0a2^ refused, hardcoded files named"
else
  echo "FAIL 7059c0a2^: rc=$rc — expected hardcode hits"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if (cd "$repo" && bash "$gate") >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "repo-paths:test: all cases pass"
exit $fail
