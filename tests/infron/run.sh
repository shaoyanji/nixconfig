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
sed -i 's/qwen\/qwen3.8-27b:free/deepseek\/deepseek-v4.2-flash-1017-free/g' "$persona"
out=$(cd "$tmp/wt" && bash scripts/task/infron-check.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'deepseek/deepseek-v4.2-flash-1017-free'; then
  echo "ok   undeclared -free id refused, id named"
else
  echo "FAIL undeclared id: rc=$rc — expected refusal naming the id"; echo "$out" | tail -6; fail=1
fi

# 2. An id with no billing marker at all (a typo'd upgrade) refuses too.
git -C "$tmp/wt" checkout -- modules/user/ai/hermes-persona/config.yaml
sed -i 's/qwen\/qwen3.8-27b:free/deepseek\/deepseek-v4.1-flash/g' "$persona"
out=$(cd "$tmp/wt" && bash scripts/task/infron-check.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'deepseek/deepseek-v4.1-flash'; then
  echo "ok   marker-less id refused, id named"
else
  echo "FAIL marker-less id: rc=$rc — expected refusal naming the id"; echo "$out" | tail -6; fail=1
fi

# 3. A re-added xpl lane refuses: the lane measured a payment wall
# (insufficient_credits, $5 top-up, 2026-11-26) after passing the catalog
# probe, so the gate must never wave it through again. Its provider is
# `custom` and the id carries no :free — the refusal needs no special case.
git -C "$tmp/wt" checkout -- modules/user/ai/hermes-persona/config.yaml
python3 - "$persona" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
lane = """  - provider: custom
    model: deepseek-v4.1-flash-uncensored-fast
    base_url: https://api.experientiallabs.ai/v1
    key_env: EXPLABS_API_KEY
"""
s = s.replace("fallback_providers:\n", "fallback_providers:\n" + lane, 1)
open(p, "w").write(s)
EOF
out=$(cd "$tmp/wt" && bash scripts/task/infron-check.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'deepseek-v4.1-flash-uncensored-fast'; then
  echo "ok   re-added xpl lane refused, id named"
else
  echo "FAIL xpl lane: rc=$rc — expected refusal naming the lane"; echo "$out" | tail -6; fail=1
fi

# 4. An ollama-cloud lane refuses too: measured a payment wall (402 on every
# one of 71 attempts, 2026-11-22), so its provider carries no free contract.
git -C "$tmp/wt" checkout -- modules/user/ai/hermes-persona/config.yaml
python3 - "$persona" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
lane = """  - provider: ollama-cloud
    model: nemotron-3-ultra
"""
s = s.replace("fallback_providers:\n", "fallback_providers:\n" + lane, 1)
open(p, "w").write(s)
EOF
out=$(cd "$tmp/wt" && bash scripts/task/infron-check.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'ollama-cloud'; then
  echo "ok   re-added ollama-cloud lane refused, provider named"
else
  echo "FAIL ollama-cloud lane: rc=$rc — expected refusal naming the provider"; echo "$out" | tail -6; fail=1
fi

# 5. The current tree passes.
if bash "$repo/scripts/task/infron-check.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "infron:test: all cases pass"
exit $fail
