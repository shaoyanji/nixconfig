#!/usr/bin/env bash
# Regression fixture for checks:drv-equality MODE=projection.
#
# The missing check was a current-state verdict: compare mode can preserve an
# error that was already in its baseline, while projection mode must fail whenever
# any inventory-projected configuration does not evaluate. The seeded tree adds
# one false assertion to alarm, the cheapest standalone home host; the live tree
# must pass the same narrowed sweep, and snapshot/compare must stay identical.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

command -v git >/dev/null && command -v python3 >/dev/null ||
  { echo "fixture: need git and python3" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

seed_submodule() {
  path="$1"
  sha=$(git -C "$repo" ls-tree HEAD "$path" | awk '$2 == "commit" {print $3}')
  [ -n "$sha" ] || { echo "fixture: $path is not a submodule at HEAD" >&2; return 1; }
  git -C "$repo/$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    { echo "fixture: $path is not initialized" >&2; return 1; }
  rm -rf "$tmp/wt/$path"
  git clone -q "$repo/$path" "$tmp/wt/$path" &&
    git -C "$tmp/wt/$path" checkout -q "$sha"
}
seed_submodule modules/secrets || exit 2
seed_submodule projects/neocities-dragoncourt || exit 2

if ! git -C "$repo" diff --quiet HEAD --; then
  git -C "$repo" diff --binary HEAD | git -C "$tmp/wt" apply --index ||
    { echo "fixture: cannot apply the checkout diff" >&2; exit 2; }
fi

fail=0

# 1. A HOSTS typo is empty input, not a green zero-host sweep.
out=$(cd "$repo" && HOSTS=ghost FORCE=1 python3 scripts/task/drv-equality.py projection 2>&1); rc=$?
if [ $rc -eq 2 ] && echo "$out" | grep -q 'no configuration matches HOSTS'; then
  echo "ok   empty HOSTS match refused"
else
  echo "FAIL empty HOSTS: rc=$rc — expected refusal"; echo "$out" | tail -8
  fail=1
fi

# 2. The seeded false assertion must break projection mode and name the host.
python3 - "$tmp/wt/hosts/alarm.nix" <<'PY' ||
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
needle = "  programs.home-manager.enable = true;\n}\n"
replacement = "  programs.home-manager.enable = true;\n\n  assertions = [{ assertion = false; message = \"drv-equality projection fixture failure\"; }];\n}\n"
if needle not in text:
    raise SystemExit("alarm fixture insertion point missing")
path.write_text(text.replace(needle, replacement))
PY
  { echo "fixture: cannot seed the false assertion" >&2; exit 2; }
out=$(cd "$tmp/wt" && HOSTS=alarm FORCE=1 python3 scripts/task/drv-equality.py projection 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'BROKEN alarm' &&
   echo "$out" | grep -q 'drv-equality projection fixture failure'; then
  echo "ok   seeded false assertion refused, host named"
else
  echo "FAIL seeded tree: rc=$rc — expected a projection refusal"; echo "$out" | tail -12
  fail=1
fi

# 3. The live tree passes the same narrowed projection sweep.
if (cd "$repo" && HOSTS=alarm FORCE=1 python3 scripts/task/drv-equality.py projection >/dev/null 2>&1); then
  echo "ok   HEAD alarm projection passes"
else
  echo "FAIL HEAD: projection mode refused the live tree"; fail=1
fi

# 4. The pre-existing equality contract still compares a clean host identically.
base="$tmp/baseline.json"
if (cd "$repo" && HOSTS=alarm FORCE=1 python3 scripts/task/drv-equality.py snapshot --out "$base" >/dev/null 2>&1) &&
   (cd "$repo" && HOSTS=alarm FORCE=1 python3 scripts/task/drv-equality.py compare --out "$base" 2>/dev/null | grep -q '1 host(s) identical'); then
  echo "ok   snapshot/compare stays identical"
else
  echo "FAIL snapshot/compare: clean host did not compare identical"; fail=1
fi

[ $fail -eq 0 ] && echo "drv-equality:test: all cases pass"
exit $fail
