#!/usr/bin/env bash
# Regression fixture for `task checks:skills:mirror`
# (scripts/task/skills-task-mirror.py).
#
# The gate refuses a SKILL.md whose table restates task `desc` cells at scale —
# three mirroring rows in one skill is the hard verdict, a mirror that will
# drift the next time the desc changes. The mistake is seeded, not replayed: a
# scratch worktree's `checks` SKILL.md gains three rows whose rest-cells are
# task descs verbatim. The descs are pulled from `task --list-all --json` at
# run time so the seed tracks the live surface. HEAD must stay clean.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null && command -v python3 >/dev/null ||
  { echo "fixture: need git and python3" >&2; exit 2; }

# Three task descs long enough to clear the token filter — the hard verdict
# needs three mirroring rows in one skill.
mapfile -t seeds < <(cd "$repo" && task --list-all --json 2>/dev/null |
  python3 -c '
import json, sys
want = {"checks:prose", "checks:nix:lint", "checks:tasks"}
for t in json.load(sys.stdin)["tasks"]:
    d = t.get("desc") or ""
    if t["name"] in want and len(d.split()) >= 6:
        print(t["name"] + "\t" + d)
')
[ "${#seeds[@]}" -eq 3 ] || { echo "fixture: need 3 task descs, got ${#seeds[@]}" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

fail=0

# 1. Three restating rows must fail, skill + a task named.
for row in "${seeds[@]}"; do
  printf '| task %s | %s |\n' "${row%%$'\t'*}" "${row#*$'\t'}" >>"$tmp/wt/.agents/skills/checks/SKILL.md"
done
out=$(cd "$tmp/wt" && python3 scripts/task/skills-task-mirror.py 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'checks:'; then
  echo "ok   restating rows refused, task named"
else
  echo "FAIL seeded tree: rc=$rc — expected a mirror refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The current tree passes.
if python3 "$repo/scripts/task/skills-task-mirror.py" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "skills-mirror:test: all cases pass"
exit $fail
