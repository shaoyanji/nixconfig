#!/usr/bin/env bash
# Regression fixture for `task checks:inventory:compiled`
# (the serial-leg `nix build` of .#checks.*.inventory-schema / -hosts /
# -modules in `checks:quick`, taskfiles/checks.yml).
#
# The drift classes these drvs exist to refuse, from lib/inventory.nix:
# a declared `is_nix` contradicting `kind`, and a flake-built host the
# inventory row has but the flake does not (coverage.missing). No break is on
# record — the checks landed with the compiled inventory — so the mistakes are
# seeded in a scratch worktree: burgernas's `is_nix` flips to true (its kind is
# external), and a phantom `[hosts.fixture-phantom]` nixos row is appended —
# the flake does not build it, so coverage must name it. No `?submodules=1`:
# a worktree does not check out the secrets gitlink, and these drvs force
# nothing in it. ~4 s per drv.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null && command -v nix >/dev/null ||
  { echo "fixture: need git and nix" >&2; exit 2; }
sys=$(nix eval --impure --raw --expr builtins.currentSystem) ||
  { echo "fixture: no currentSystem" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

build() { (cd "$tmp/wt" && nix build --no-link --builders "" ".#checks.${sys}.$1" 2>&1); }

fail=0

# 1. `is_nix = true` on an external host must refuse inventory-schema, host
#    named. The flip is scoped to burgernas's block — five other externals
#    carry the same `is_nix = false` line.
awk '/^\[hosts\.burgernas\]/{b=1} /^\[hosts\./ && !/burgernas/{b=0} b && /^is_nix = false/{$0="is_nix = true"} {print}' \
  "$tmp/wt/inventory.toml" >"$tmp/inv" && mv "$tmp/inv" "$tmp/wt/inventory.toml"
out=$(build inventory-schema); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'burgernas' && ! echo "$out" | grep -q 'serv00'; then
  echo "ok   is_nix contradiction refused, host named"
else
  echo "FAIL seeded is_nix: rc=$rc — expected a schema refusal naming only burgernas"; echo "$out" | tail -6; fail=1
fi

# 2. A phantom nixos host the flake does not build must refuse inventory-hosts.
cat >>"$tmp/wt/inventory.toml" <<'EOF'

[hosts.fixture-phantom]
hostname = "fixture-phantom"
status = "active"
kind = "nixos"
arch = "x86_64-linux"
EOF
out=$(build inventory-hosts); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'fixture-phantom'; then
  echo "ok   phantom host refused, row named"
else
  echo "FAIL seeded phantom: rc=$rc — expected a coverage refusal"; echo "$out" | tail -6; fail=1
fi

# 3. The current tree builds all three drvs.
if (cd "$repo" && nix build --no-link --builders "" ".#checks.${sys}.inventory-schema" ".#checks.${sys}.inventory-hosts" ".#checks.${sys}.inventory-modules" >/dev/null 2>&1); then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "inventory-compiled:test: all cases pass"
exit $fail
