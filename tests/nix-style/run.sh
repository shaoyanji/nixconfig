#!/usr/bin/env bash
# Regression fixture for the per-file alias gate
# (scripts/task/nix-style-check.sh), wired as `checks:nix:style` in
# checks:quick.
#
# A gate that cannot fail is no gate, so the failing input is checked out of
# history, not retyped: `2fe0c687^` is the tree right before the unification —
# flake/policies.nix carried lib.filter/lib.elem/lib.hasAttr minorities against
# a builtins-majority file, and flake/epistemics.nix one lib.filter. The gate
# must refuse that tree, name the files, and accept the current one.
# (lib/nix-files.nix rides along as the honest control: its pre-fix version
# mixes no aliases — the map|>concatStringsSep it carried is a different class
# this gate does not lint, and the fixture asserts the gate leaves it alone.)
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

gate="$repo/scripts/task/nix-style-check.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The past tree: same file set, checked out of the commit before the gate and
# the unification landed.
mkdir -p "$tmp/flake" "$tmp/lib"
for p in flake/policies.nix flake/epistemics.nix lib/nix-files.nix; do
  git show "2fe0c687^:$p" >"$tmp/$p" 2>/dev/null || { echo "fixture: cannot read 2fe0c687^:$p" >&2; exit 2; }
done

fail=0

# 1. The current tree passes.
if bash "$gate" >/dev/null 2>&1; then
  echo "ok   current tree passes the gate"
else
  echo "FAIL current tree: gate refused the shipped files"
  fail=1
fi

# 2. The past mistake fails — and names the mixing files.
out="$(bash "$gate" "$tmp/flake" "$tmp/lib" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL past tree (2fe0c687^): gate accepted the mixed files"
  fail=1
else
  echo "ok   past tree (2fe0c687^) fails the gate"
  grep -q 'flake/policies.nix mixes' <<<"$out" \
    && echo "ok   the failure names flake/policies.nix" \
    || { echo "FAIL the failure does not name flake/policies.nix"; fail=1; }
  grep -q 'flake/epistemics.nix mixes' <<<"$out" \
    && echo "ok   the failure names flake/epistemics.nix" \
    || { echo "FAIL the failure does not name flake/epistemics.nix"; fail=1; }
  grep -q 'nix-files.nix mixes' <<<"$out" \
    && { echo "FAIL the gate blames nix-files.nix — it mixes no aliases"; fail=1; } \
    || echo "ok   the honest control file is not blamed"
fi

# 3. A fresh mix introduced into a clean file fails: one minority spelling is
# enough — the gate does not need both to be frequent.
cp "$repo"/lib/docs.nix "$tmp/lib/mixed.nix"
echo 'x = builtins.filter (a: a) [];' >>"$tmp/lib/mixed.nix"
mkdir -p "$tmp/just-mixed" && cp "$tmp/lib/mixed.nix" "$tmp/just-mixed/"
if bash "$gate" "$tmp/just-mixed" >/dev/null 2>&1; then
  echo "FAIL single minority spelling: gate accepted builtins.filter next to lib.filter"
  fail=1
else
  echo "ok   one minority spelling fails the gate"
fi

exit "$fail"
