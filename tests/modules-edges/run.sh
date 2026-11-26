#!/usr/bin/env bash
# Regression fixture for `task checks:modules:edges`
# (scripts/task/modules-edges.sh).
#
# The 2026-11 module conversion found path edges by hand across 24 files —
# `import ../x.nix` and bare `./x.nix` imports elements that work at eval time
# and only break when the target is renamed. No break is on record (the gate
# was written before one could ship), so the mistake is seeded: a tracked
# module file in a scratch worktree gains one relative path import. Text-only
# check, ~0.6 s; the seeded line must be named and HEAD must stay clean.
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

# 1. A seeded `import ../x.nix;` must fail, file:line named.
echo 'import ../lib/seeded-edge.nix;' >>"$tmp/wt/modules/global/user.nix"
out=$(cd "$tmp/wt" && bash scripts/task/modules-edges.sh 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'user.nix'; then
  echo "ok   seeded edge refused, module named"
else
  echo "FAIL seeded tree: rc=$rc — expected an edge refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The allowed shapes stay allowed — the lock that keeps the gate from
# over-reaching: a path edge is only a violation WITHOUT an argument or a
# derivation context. Each documented allowed line is seeded; the gate must
# stay green on all of them.
git -C "$tmp/wt" checkout -- modules/global/user.nix
cat >>"$tmp/wt/modules/global/user.nix" <<'SEED'
# allowed: a load with arguments is a dependency, not an edge
allowedWithArgs = import ../scripts/x.nix {inherit pkgs;};
# allowed: an asset read, not a Nix module
allowedAsset = builtins.readFile ../config/nu/x.nu;
# allowed: a derivation path, inside src
allowedSrc = ../scripts/x.sh;
# allowed: an overlay import is not a module
allowedOverlay = nixpkgs.overlays = [(import ../../overlays/x.nix)];
SEED
out=$(cd "$tmp/wt" && bash scripts/task/modules-edges.sh 2>&1); rc=$?
if [ $rc -eq 0 ]; then
  echo "ok   allowed-case lock: all four shapes pass, none flagged"
else
  echo "FAIL allowed case: rc=$rc — gate refused a documented allowed shape"; echo "$out" | tail -8; fail=1
fi

# 3. The current tree passes.
if bash "$repo/scripts/task/modules-edges.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "modules-edges:test: all cases pass"
exit $fail
