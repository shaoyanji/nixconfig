#!/usr/bin/env bash
# Regression fixture for `task checks:registry:compiled`
# (the serial-leg `nix build` of .#checks.*.knobs / registry-schema /
# site-assets in `checks:quick`, taskfiles/checks.yml).
#
# The drift classes these drvs exist to refuse, from flake/checks.nix: a
# modules.toml knob whose `path` names no file, an inventory `managed` that is
# not a boolean, and site JavaScript that no longer parses. No break is on
# record — the checks landed with the compiled registries — so the mistakes
# are seeded in a scratch worktree: knobs.ai's `path` points at a file that
# does not exist, frieren's `managed` becomes a string, and a syntax error is
# appended to lib/site/aki.js. No `?submodules=1`: a worktree does not check
# out the secrets gitlink, and these drvs force nothing in it.
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

# 1. A knob path naming no file must refuse knobs, the id named. The path
#    stays under modules/ so registry-schema's path-prefix rule is not the
#    thing that fires.
awk '/^\[knobs\.ai\]/{b=1} /^\[knobs\./ && !/knobs\.ai/{b=0} b && /^path = /{sub(/noDE\.nix/, "noDE-fixture-missing.nix")} {print}' \
  "$tmp/wt/modules.toml" >"$tmp/mt" && mv "$tmp/mt" "$tmp/wt/modules.toml"
out=$(build knobs); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'paths that do not exist' && echo "$out" | grep -q 'ai'; then
  echo "ok   missing knob path refused, id named"
else
  echo "FAIL seeded knob path: rc=$rc — expected a missing-path refusal"; echo "$out" | tail -6; fail=1
fi

# 2. A non-boolean `managed` must refuse registry-schema, the host named.
awk '/^\[hosts\.frieren\]/{b=1} /^\[hosts\./ && !/frieren/{b=0} b && /^managed = true/{$0="managed = \"yes\""} {print}' \
  "$tmp/wt/inventory.toml" >"$tmp/inv" && mv "$tmp/inv" "$tmp/wt/inventory.toml"
out=$(build registry-schema); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'frieren: managed must be a boolean'; then
  echo "ok   non-boolean managed refused, host named"
else
  echo "FAIL seeded managed: rc=$rc — expected a schema refusal naming frieren"; echo "$out" | tail -6; fail=1
fi

# 3. Site JS that does not parse must refuse site-assets, the file named.
printf '\nthis is not (javascript\n' >>"$tmp/wt/lib/site/aki.js"
out=$(build site-assets); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'aki.js'; then
  echo "ok   broken site asset refused, file named"
else
  echo "FAIL seeded syntax: rc=$rc — expected a node --check refusal"; echo "$out" | tail -6; fail=1
fi

# 4. The current tree builds all three drvs.
if (cd "$repo" && nix build --no-link --builders "" ".#checks.${sys}.knobs" ".#checks.${sys}.registry-schema" ".#checks.${sys}.site-assets" >/dev/null 2>&1); then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "registry-compiled:test: all cases pass"
exit $fail
