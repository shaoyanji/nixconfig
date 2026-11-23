#!/usr/bin/env bash
# Regression fixture for `checks:hosts:args` (scripts/task/hosts-args-check.sh).
#
# Both rules are judged against the real clanker migration, not a retyped sketch.
# `git show HEAD:hosts/clanker.nix` is a standalone home host importing
# `self.modules."roles.lean"` — the migration's real past mistake — so it fails.
# The same file with that import removed fails on the dead `self`; marked `nixos`
# instead of `home`, it passes, which is the scope: NixOS hosts still import
# `self.modules` by name. The working-tree `_:` file passes. An empty `{ ... }`
# pattern fails statix W10, an unused `pkgs` fails, a used one passes.
#
# Coverage is asserted both ways: every case must run, and every case that runs
# must be listed.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/hosts-args-check.sh"

for tool in deadnix statix yq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "fixture: $tool is required" >&2
    exit 2
  }
done
[ -f "$gate" ] || {
  echo "fixture: $gate missing" >&2
  exit 2
}
git -C "$repo" rev-parse --verify HEAD >/dev/null 2>&1 || {
  echo "fixture: needs a git checkout with HEAD" >&2
  exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
cases=0
ran=""
inventory() { # kind of clanker
  printf '[hosts.clanker]\nkind = "%s"\n\n[hosts.frieren]\nkind = "nixos"\n' "$1" >"$tmp/inventory.toml"
}
reset() {
  rm -rf "$tmp/hosts"
  mkdir -p "$tmp/hosts"
  inventory home
}

run() { # name want_rc needle
  local name="$1" want="$2" needle="${3:-}" out rc
  cases=$((cases + 1))
  ran="${ran}${name}"$'\n'
  out="$(bash "$gate" "$tmp" 2>&1)"
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL ${name}: exit ${rc}, want ${want}"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; then
    echo "FAIL ${name}: output lacks '${needle}'"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  echo "ok   ${name} (exit ${rc})"
}

reset
git -C "$repo" show HEAD:hosts/clanker.nix >"$tmp/hosts/clanker.nix"
run "HEAD home host importing self.modules fails" 1 "standalone home host"

reset
inventory nixos
git -C "$repo" show HEAD:hosts/clanker.nix >"$tmp/hosts/clanker.nix"
run "the same file marked nixos passes" 0 "clean"

reset
git -C "$repo" show HEAD:hosts/clanker.nix |
  sed '/imports = \[self\.modules\."roles\.lean"\];/d' >"$tmp/hosts/clanker.nix"
run "dead self after the import removal fails" 1 "Unused lambda pattern: self"

reset
cp "$repo/hosts/clanker.nix" "$tmp/hosts/clanker.nix"
run "working-tree wildcard pattern passes" 0 "clean"

reset
printf '{ ... }: {\n  a = 1;\n}\n' >"$tmp/hosts/empty.nix"
run "empty pattern fails W10" 1 "empty argument pattern"

reset
printf '{ pkgs, ... }: {\n  a = 1;\n}\n' >"$tmp/hosts/unused.nix"
run "unused pkgs fails" 1 "Unused lambda pattern: pkgs"

reset
printf '{ pkgs, ... }: {\n  a = pkgs.hello;\n}\n' >"$tmp/hosts/used.nix"
run "used pkgs passes" 0 "clean"

expected="HEAD home host importing self.modules fails
the same file marked nixos passes
dead self after the import removal fails
working-tree wildcard pattern passes
empty pattern fails W10
unused pkgs fails
used pkgs passes
"
if [ "$ran" != "$expected" ]; then
  echo "FAIL coverage: cases run do not match the listed set"
  printf 'ran:\n%s' "$ran" | sed 's/^/     /'
  fail=1
fi

echo "host-args fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
