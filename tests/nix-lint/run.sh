#!/usr/bin/env bash
# Regression fixture for `task checks:nix:lint`
# (scripts/task/nix-fmt.sh --check --all --tools deadnix,statix).
#
# deadnix's hard verdicts — an unused let binding, an unused lambda argument —
# are the rot this gate exists for. The mistake is seeded: a scratch worktree
# gains one untracked .nix file with an unused lambda formal. `nix-fmt.sh --all`
# scans `git ls-files --others`, so the file needs no staging. deadnix must name
# it; HEAD must stay clean.
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

# 1. An unused lambda formal must fail, file named.
printf '{ unusedFormal }:\n{ a = 1; }\n' >"$tmp/wt/flake/fixture-dead-formal.nix"
out=$(cd "$tmp/wt" && bash scripts/task/nix-fmt.sh --check --all --tools deadnix 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'fixture-dead-formal'; then
  echo "ok   dead formal refused, file named"
else
  echo "FAIL seeded tree: rc=$rc — expected a deadnix refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/nix-fmt.sh" --check --all --tools deadnix >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: deadnix refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "nix-lint:test: all cases pass"
exit $fail
