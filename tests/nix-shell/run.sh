#!/usr/bin/env bash
# Regression fixture for `task checks:nix:shell`
# (scripts/task/nix-shell-lint.sh -> nix-shell-lint.py).
#
# The trap class: `${var:-default}` inside a writeShell* indented string is Nix
# interpolation, and Nix parses `var:-default` as a URI literal — the script
# ships a literal where an expansion was meant, with no eval error. The mistake
# is seeded: a scratch worktree gains one staged .nix file carrying exactly
# that. The checker scans the index, so the file is `git add`ed inside the
# worktree (its HEAD is untouched). It must be named; HEAD must stay clean.
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

# 1. A `${x:-y}` in a writeShellScript string must fail, file named.
cat >"$tmp/wt/modules/fixture-shell-interp.nix" <<'NIX'
{ pkgs }:
{
  fixture = pkgs.writeShellScript "fixture-interp" ''
    echo "${greeting:-hello}"
  '';
}
NIX
git -C "$tmp/wt" add modules/fixture-shell-interp.nix
out=$(cd "$tmp/wt" && bash scripts/task/nix-shell-lint.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'fixture-shell-interp'; then
  echo "ok   expansion-in-interpolation refused, file named"
else
  echo "FAIL seeded tree: rc=$rc — expected an interpolation refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/nix-shell-lint.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "nix-shell:test: all cases pass"
exit $fail
