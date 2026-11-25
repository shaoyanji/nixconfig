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
# Forcing kernelPackages.kernel.version forces the merge: ~1.3 s per host.
# The sweep fans out PAR (default 4) ways — each host still its own nix
# process under oom-guard.sh, so peak is ~4 × ~200 MiB of evaluator — and
# reports in inventory order once all workers have landed. The flake source
# is warmed once first: on a dirty worktree every git+file fetch exports the
# tree, so 25 cold fetches would serialize on the store and cost more than
# the merges they precede. A preserved host that fails to evaluate for
# another reason is a warning (pre-existing break); an active one makes the
# verdict cannot-tell.
#
#   kernel-collision-check.sh      every nixosConfiguration, live tree
#   HOSTS="a b" …                  that subset only
#   REV=<sha> …                    the flake at that commit (fixtures)
#   PAR=<n> …                      sweep width, default 4
#
# Exit: 0 clean, 1 a kernel collision, 2 cannot tell.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
root=$(pwd -P)
flake="git+file://$root?submodules=1"
[ -n "${REV:-}" ] && flake="$flake&rev=$REV"

# Warm the flake source once (see header): without it the parallel workers
# contend on git+file export instead of evaluating.
nix eval --impure --expr '(builtins.getFlake "'"$flake"'").outPath' >/dev/null 2>&1 ||
  { echo "kernel-collision: cannot resolve $flake" >&2; exit 2; }

enum='let f = builtins.getFlake "'"$flake"'"; inv = f.inventory.hosts; in
  map (n: { name = n; status = inv.${n}.status or "active"; })
    (builtins.attrNames f.nixosConfigurations)'
hosts=$(nix eval --impure --json --expr "$enum" 2>/dev/null | jq -r '.[] | .name + " " + .status') ||
  { echo "kernel-collision: cannot enumerate nixosConfigurations" >&2; exit 2; }
[ -n "${HOSTS:-}" ] &&
  hosts=$(echo "$hosts" | awk -v want="$HOSTS" 'BEGIN { split(want, w, " "); for (i in w) k[w[i]] = 1 } k[$1]')

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export flake tmp

check_one() {
  read -r name status <<<"$1"
  expr='let f = builtins.getFlake "'"$flake"'"; in f.nixosConfigurations.'"$name"'.config.boot.kernelPackages.kernel.version'
  out=$(bash scripts/task/oom-guard.sh --timeout 120 --label "kernel-collision $name" -- \
    nix eval --raw --impure --expr "$expr" 2>"$tmp/$name.err")
  rc=$?
  err=$(cat "$tmp/$name.err"); rm -f "$tmp/$name.err"
  if [ $rc -eq 0 ]; then
    printf '%s\n' "${out%%kernel-collision*}" >"$tmp/ok.$name"
  elif echo "$err" | grep -q 'defined multiple times\|conflicting definition values'; then
    echo "$err" | grep 'In `' >"$tmp/collide.$name"
  elif [ "$status" = "preserved" ]; then
    : >"$tmp/skip.$name"
  else
    echo "$err" | tail -1 >"$tmp/error.$name"
  fi
  return 0
}
export -f check_one

printf '%s\n' "$hosts" | xargs -d '\n' -P"${PAR:-4}" -I{} bash -c 'check_one "$1"' _ {}

collide=0; unsure=0; n=0
while read -r name status; do
  [ -z "$name" ] && continue
  n=$((n + 1))
  if [ -f "$tmp/ok.$name" ]; then
    printf 'ok      %-14s %s\n' "$name" "$(cat "$tmp/ok.$name")"
  elif [ -f "$tmp/collide.$name" ]; then
    printf 'COLLIDE %-14s\n' "$name"
    sed 's/^/          /' "$tmp/collide.$name"
    collide=$((collide + 1))
  elif [ -f "$tmp/skip.$name" ]; then
    printf 'skip    %-14s preserved, pre-existing eval break\n' "$name"
  else
    printf 'ERROR   %-14s %s\n' "$name" "$(cat "$tmp/error.$name" 2>/dev/null || echo 'worker produced no result')"
    unsure=$((unsure + 1))
  fi
done <<<"$hosts"

echo "kernel-collision: $n host(s) — $collide collision(s), $unsure unverifiable"
[ $collide -gt 0 ] && exit 1
[ $unsure -gt 0 ] && exit 2
exit 0
