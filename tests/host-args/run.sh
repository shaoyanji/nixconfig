#!/usr/bin/env bash
# Regression fixture for `checks:hosts:args` (scripts/task/hosts-args-check.sh).
#
# Both rules are judged against the real clanker migration, not a retyped sketch.
# The mistake is resolved by pickaxe — the commit that introduced
# `imports = [self.modules."roles.lean"]` in `hosts/clanker.nix` — because HEAD
# stopped carrying it when the migration landed; a history rewrite fails this
# fixture loudly rather than turning the proof into a no-op. That blob is a
# standalone home host importing `self.modules`, so it fails; with the import
# removed it fails naming the dead `self`; marked `nixos` instead of `home` it
# passes, which is the scope NixOS hosts still rely on. The working-tree `_:`
# file passes. A file reached through `flake/host-inventory.nix`
# (`hosts/clanker/configuration.nix`) is still judged, and a home host that
# resolves to no file is exit 2, never a silent pass. An empty `{ ... }` pattern
# fails statix W10, an unused `pkgs` fails, a used one passes.
#
# Coverage is asserted both ways: every case must run, and every case that runs
# must be listed.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/hosts-args-check.sh"

for tool in deadnix statix yq nix; do
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

mistake="$(git -C "$repo" log -S'self.modules."roles.lean"' --format=%H -- hosts/clanker.nix | tail -n 1)"
git -C "$repo" show "$mistake:hosts/clanker.nix" 2>/dev/null |
  grep -qF 'imports = [self.modules."roles.lean"]' || {
  echo "fixture: no commit introduces the clanker self.modules import — cannot prove the rule fails on it" >&2
  exit 2
}
blob() { git -C "$repo" show "$mistake:hosts/clanker.nix"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
cases=0
ran=""
inventory() { # kind of clanker
  printf '[hosts.clanker]\nkind = "%s"\n\n[hosts.frieren]\nkind = "nixos"\n' "$1" >"$tmp/inventory.toml"
}
reset() {
  rm -rf "$tmp/hosts" "$tmp/flake"
  mkdir -p "$tmp/hosts"
  inventory home
}
registry() { # module file a home host imports, relative to tmp
  mkdir -p "$tmp/flake"
  printf '{ inputs, self, moduleFiles }:\n{\n  clanker = {\n    kind = "home";\n    modules = [../%s];\n  };\n}\n' "$1" >"$tmp/flake/host-inventory.nix"
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
blob >"$tmp/hosts/clanker.nix"
run "the past home host importing self.modules fails" 1 "standalone home host"

reset
inventory nixos
blob >"$tmp/hosts/clanker.nix"
run "the same blob marked nixos passes" 0 "clean"

reset
blob | sed '/imports = \[self\.modules\."roles\.lean"\];/d' >"$tmp/hosts/clanker.nix"
run "dead self after the import removal fails" 1 "Unused lambda pattern: self"

reset
cp "$repo/hosts/clanker.nix" "$tmp/hosts/clanker.nix"
run "working-tree wildcard pattern passes" 0 "clean"

reset
mkdir -p "$tmp/hosts/clanker"
registry hosts/clanker/configuration.nix
blob >"$tmp/hosts/clanker/configuration.nix"
run "a host-inventory module path is judged" 1 "standalone home host"

reset
mkdir -p "$tmp/hosts/clanker"
cp "$repo/hosts/clanker.nix" "$tmp/hosts/clanker/configuration.nix"
run "a home host resolving to no file is a hard stop" 2 "maps to no file"

reset
inventory nixos # the linter cases judge no home host, so none may be unresolved
printf '{ ... }: {\n  a = 1;\n}\n' >"$tmp/hosts/empty.nix"
run "empty pattern fails W10" 1 "empty argument pattern"

reset
inventory nixos
printf '{ pkgs, ... }: {\n  a = 1;\n}\n' >"$tmp/hosts/unused.nix"
run "unused pkgs fails" 1 "Unused lambda pattern: pkgs"

reset
inventory nixos
printf '{ pkgs, ... }: {\n  a = pkgs.hello;\n}\n' >"$tmp/hosts/used.nix"
run "used pkgs passes" 0 "clean"

expected="the past home host importing self.modules fails
the same blob marked nixos passes
dead self after the import removal fails
working-tree wildcard pattern passes
a host-inventory module path is judged
a home host resolving to no file is a hard stop
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
