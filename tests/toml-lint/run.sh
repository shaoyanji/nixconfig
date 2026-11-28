#!/usr/bin/env bash
# Regression fixture for `task checks:toml:lint` — the inline `git ls-files`
# + `yq` loop in taskfiles/checks.yml, replicated here so the fixture needs no
# task shim.
#
# A TOML file that stops parsing only fails when a consumer reads it. Seed an
# unclosed array in inventory.toml, the fleet's highest-impact TOML input; the
# loop must refuse and name it. HEAD must stay clean.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null && command -v yq >/dev/null ||
  { echo "fixture: need git and yq" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

fail=0

toml_scan() {
  local dir="$1" bad=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    yq '.' "$dir/$f" >/dev/null 2>&1 || { echo "INVALID TOML: $f"; bad=1; }
  done < <(git -C "$dir" ls-files '*.toml')
  return $bad
}

echo 'broken = [unclosed' >>"$tmp/wt/inventory.toml"
out=$(cd "$tmp/wt" && toml_scan "$tmp/wt" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'inventory.toml'; then
  echo "ok   malformed toml refused, file named"
else
  echo "FAIL seeded tree: rc=$rc — expected a parse refusal"; echo "$out" | tail -6; fail=1
fi

if toml_scan "$repo" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: a tracked toml does not parse"; fail=1
fi

[ $fail -eq 0 ] && echo "toml-lint:test: all cases pass"
exit $fail
