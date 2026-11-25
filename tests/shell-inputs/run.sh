#!/usr/bin/env bash
# Regression fixture for `task checks:shell-inputs`
# (scripts/task/shell-inputs.py).
#
# The failing input is a real past tree, not a retype: 0e46552e is the xs-notify
# module as shipped — `writeShellApplication` with
# `runtimeInputs = [coreutils curl jq]` whose readFile script pipes sha1sum
# through awk. The systemd unit's PATH has no awk, so the timer exited 127 every
# minute from 2026-11-21 until c3d1447a supplied gawk. The checker resolves ROOT
# from its own path, so a copy of the current script is placed inside the old
# worktree; it must refuse the tree HEAD's module came from.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null && command -v python3 >/dev/null ||
  { echo "fixture: need git and python3" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" 0e46552e >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree at 0e46552e" >&2; exit 2; }
mkdir -p "$tmp/wt/scripts/task"
cp "$repo/scripts/task/shell-inputs.py" "$tmp/wt/scripts/task/"

fail=0

# 1. The past tree must fail — awk judged missing from xs-notify's inputs.
out=$(python3 "$tmp/wt/scripts/task/shell-inputs.py" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'xs-notify'; then
  echo "ok   0e46552e refused, xs-notify named"
else
  echo "FAIL 0e46552e: rc=$rc — expected an awk violation"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if python3 "$repo/scripts/task/shell-inputs.py" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: checker refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "shell-inputs:test: all cases pass"
exit $fail
