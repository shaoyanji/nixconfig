#!/usr/bin/env bash
# kernel-collision-check.sh — [gate] every nixosConfiguration's
# boot.kernelPackages resolves to exactly one winning definition.
#
# THE CLASS: NixOS merges option definitions by priority; two definitions
# tied at the winning tier with different values are a hard "defined
# multiple times" error that fails the whole configuration's eval. It bit
# twice behind one line in modules/profiles/base-node.nix: mkOverride 1500
# tied with the option default in nixos/modules/system/boot/kernel.nix and
# broke every host importing the baseline without its own override — eisen
# until 2026-10-19 — after raspberry-pi/3's mkDefault had already collided
# with an earlier baseline for minyx. The fix is mkOverride 1200, strictly
# between mkDefault (1000) and the option default (1500)
# [[AGENTS.nix#dormant-host-gates]].
#
# Forcing kernelPackages.kernel.version forces the merge: ~1.3 s per host,
# one host per nix process under oom-guard.sh — the fleet rule even when the
# eval is cheap. A preserved host that fails to evaluate for another reason
# is a warning (pre-existing break); an active one makes the verdict
# cannot-tell.
#
#   kernel-collision-check.sh      every nixosConfiguration, live tree
#   HOSTS="a b" …                  that subset only
#   REV=<sha> …                    the flake at that commit (fixtures)
#
# Exit: 0 clean, 1 a kernel collision, 2 cannot tell.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
root=$(pwd -P)
flake="git+file://$root?submodules=1"
[ -n "${REV:-}" ] && flake="$flake&rev=$REV"

enum='let f = builtins.getFlake "'"$flake"'"; inv = f.inventory.hosts; in
  map (n: { name = n; status = inv.${n}.status or "active"; })
    (builtins.attrNames f.nixosConfigurations)'
hosts=$(nix eval --impure --json --expr "$enum" 2>/dev/null | jq -r '.[] | .name + " " + .status') ||
  { echo "kernel-collision: cannot enumerate nixosConfigurations" >&2; exit 2; }
[ -n "${HOSTS:-}" ] &&
  hosts=$(echo "$hosts" | awk -v want="$HOSTS" 'BEGIN { split(want, w, " "); for (i in w) k[w[i]] = 1 } k[$1]')

collide=0; unsure=0; n=0
while read -r name status; do
  [ -z "$name" ] && continue
  n=$((n + 1))
  expr='let f = builtins.getFlake "'"$flake"'"; in f.nixosConfigurations.'"$name"'.config.boot.kernelPackages.kernel.version'
  errf=$(mktemp)
  out=$(bash scripts/task/oom-guard.sh --timeout 120 --label "kernel-collision $name" -- \
    nix eval --raw --impure --expr "$expr" 2>"$errf")
  rc=$?
  err=$(cat "$errf")
  rm -f "$errf"
  if [ $rc -eq 0 ]; then
    printf 'ok      %-14s %s\n' "$name" "${out%%kernel-collision*}"
  elif echo "$err" | grep -q 'defined multiple times\|conflicting definition values'; then
    printf 'COLLIDE %-14s\n' "$name"
    echo "$err" | grep 'In `' | sed 's/^/          /'
    collide=$((collide + 1))
  elif [ "$status" = "preserved" ]; then
    printf 'skip    %-14s preserved, pre-existing eval break\n' "$name"
  else
    printf 'ERROR   %-14s %s\n' "$name" "$(echo "$err" | tail -1)"
    unsure=$((unsure + 1))
  fi
done <<<"$hosts"

echo "kernel-collision: $n host(s) — $collide collision(s), $unsure unverifiable"
[ $collide -gt 0 ] && exit 1
[ $unsure -gt 0 ] && exit 2
exit 0
