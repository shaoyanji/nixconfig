#!/usr/bin/env bash
# Regression fixture for `task checks:toon:tasks`
# (scripts/task/toon-tasks.sh).
#
# The gate holds the agent boundary on the taskfile plane: a cmds line may not
# hand JSON to a reader with a bare `| toon -e` (that is toon_emit's job in
# scripts/task/toon-io.sh) nor hand-case `{{.FORMAT}}`. The mistake is seeded:
# a scratch worktree's checks.yml gains one cmds line piping to `toon -e`
# directly — the spell the gate was written to refuse. Only cmds blocks are
# scanned, so the seed is a real cmd entry, not prose. HEAD must stay clean.
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

# 1. A bare `| toon -e` cmd must fail, file:line named.
cat >>"$tmp/wt/taskfiles/checks.yml" <<'YML'

  fixture:toon-bare:
    cmds:
      - nix eval --json .#inventory.hosts | toon -e
YML
out=$(cd "$tmp/wt" && bash scripts/task/toon-tasks.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'checks.yml'; then
  echo "ok   bare toon -e cmd refused, file named"
else
  echo "FAIL seeded tree: rc=$rc — expected a refusal"; echo "$out" | tail -6; fail=1
fi

# 2. A hand-cased FORMAT must fail too — the second refusal shape.
git -C "$tmp/wt" checkout taskfiles/checks.yml >/dev/null 2>&1
cat >>"$tmp/wt/taskfiles/checks.yml" <<'YML'

  fixture:toon-case:
    cmds:
      - |
        case "{{.FORMAT}}" in
          json) jq '.' ;;
        esac
YML
out=$(cd "$tmp/wt" && bash scripts/task/toon-tasks.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'hand-cases\|FORMAT'; then
  echo "ok   hand-cased FORMAT refused"
else
  echo "FAIL case tree: rc=$rc — expected a refusal"; echo "$out" | tail -6; fail=1
fi

# 3. The current tree passes.
if bash "$repo/scripts/task/toon-tasks.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "toon-tasks:test: all cases pass"
exit $fail
