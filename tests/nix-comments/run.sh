#!/usr/bin/env bash
# Regression fixture for `task checks:nix:comments`
# (scripts/task/nix-comments.sh).
#
# Two breaks, one seeded and one replayed. The gate resolves every `task <name>`
# a Nix comment cites against the recipe table, so a cite to a recipe that does
# not exist is a pointer to nothing; no such break is on record, so that one is
# seeded. The other is history: 2ca9a316 spent 18 prose lines past the recorded
# ceiling while the gate printed `6513/6495` and exited 0, and only a git hook —
# skippable with `--no-verify`, absent in a clone that never installed it —
# refused it. The gate must refuse both, and HEAD must stay clean.
#
# Both seeds edit a tracked file in a scratch worktree so the flake source
# carries them; the worktree is reset between cases.
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
# The worktree is HEAD's tree plus the gate the author is editing: judging a
# ceiling with the script HEAD records would pass a change to the script itself.
# Committed, the two are the same file.
cp "$repo/scripts/task/nix-comments.sh" "$tmp/wt/scripts/task/nix-comments.sh"

fail=0

# 1. A seeded dangling task pointer must fail, named.
echo '# see task nope:zzz' >>"$tmp/wt/flake/check-inventory.nix"
out=$(cd "$tmp/wt" && bash scripts/task/nix-comments.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'nope:zzz'; then
  echo "ok   seeded cite refused, pointer named"
else
  echo "FAIL seeded tree: rc=$rc — expected unresolved pointer"; echo "$out" | tail -6; fail=1
fi

# 2. The replayed drift: 18 prose lines past the ceiling, the shape 2ca9a316
#    landed. The gate must refuse it and say so on the ceiling line.
# Reset only the seeded file: a whole-tree checkout would also restore HEAD's
# copy of the gate script over the working tree's.
git -C "$tmp/wt" checkout -- flake/check-inventory.nix >/dev/null 2>&1
for i in $(seq 1 18); do
  printf '# a prose line that restates the code, %s\n' "$i" >>"$tmp/wt/flake/check-inventory.nix"
done
out=$(cd "$tmp/wt" && bash scripts/task/nix-comments.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'prose over the ceiling'; then
  echo "ok   past drift refused on the ceiling"
else
  echo "FAIL drift tree: rc=$rc — expected a ceiling breach"; echo "$out" | tail -8; fail=1
fi

# 3. The current tree passes.
if bash "$repo/scripts/task/nix-comments.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "nix-comments:test: all cases pass"
exit $fail
