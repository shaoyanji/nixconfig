#!/usr/bin/env bash
# Regression fixture for `task checks:infron` (scripts/task/infron-check.sh).
#
# The real mistake is on record: the hermes persona gained the tokenrouter
# lane `deepseek/deepseek-v4.1-flash-1017-free` — a `-free` suffix, not the
# `:free` contract the guard greps — before any declared exception existed,
# and the gate refused it (a262147a added the declaration). The mistake never
# lived on a committed tree, so it is seeded, not replayed: a worktree's
# config.yaml gets the same shape — a `-free` id with no declaration, i.e. a
# model bump that drops the contract — and the gate must refuse, id named.
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

persona="$tmp/wt/modules/user/ai/hermes-persona/config.yaml"
fail=0

# 1. An undeclared `-free` id (the tokenrouter mistake's exact shape) refuses.
sed -i 's/deepseek\/deepseek-v4.1-flash-1017-free/deepseek\/deepseek-v4.2-flash-1017-free/g' "$persona"
out=$(cd "$tmp/wt" && bash scripts/task/infron-check.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'deepseek/deepseek-v4.2-flash-1017-free'; then
  echo "ok   undeclared -free id refused, id named"
else
  echo "FAIL undeclared id: rc=$rc — expected refusal naming the id"; echo "$out" | tail -6; fail=1
fi

# 2. An id with no billing marker at all (a typo'd upgrade) refuses too.
git -C "$tmp/wt" checkout -- modules/user/ai/hermes-persona/config.yaml
sed -i 's/deepseek\/deepseek-v4.1-flash-1017-free/deepseek\/deepseek-v4.1-flash/g' "$persona"
out=$(cd "$tmp/wt" && bash scripts/task/infron-check.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'deepseek/deepseek-v4.1-flash'; then
  echo "ok   marker-less id refused, id named"
else
  echo "FAIL marker-less id: rc=$rc — expected refusal naming the id"; echo "$out" | tail -6; fail=1
fi

# 3. The current tree passes.
if bash "$repo/scripts/task/infron-check.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "infron:test: all cases pass"
exit $fail
