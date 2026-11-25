#!/usr/bin/env bash
# Regression fixture for `task checks:prose` (scripts/task/prose-tells.sh).
#
# The gate vocabulary is modules/config/prose-tells.tsv — `delve` is a `gate`
# row, the tell every unslop sweep exists to catch. No surviving break is on
# record (each sweep deletes the word before it can ship), so the mistake is
# seeded: a tracked markdown file in a scratch worktree gains one sentence
# carrying the tell, outside any fence and outside the exempt paths. The gate
# must name file:line; HEAD must stay clean.
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

# 1. A seeded gate-row tell must fail, file:line named.
echo 'We delve into the details.' >>"$tmp/wt/MANUAL.md"
out=$(cd "$tmp/wt" && bash scripts/task/prose-tells.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'MANUAL.md'; then
  echo "ok   seeded tell refused, file named"
else
  echo "FAIL seeded tree: rc=$rc — expected a tell refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if bash "$repo/scripts/task/prose-tells.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "prose:test: all cases pass"
exit $fail
