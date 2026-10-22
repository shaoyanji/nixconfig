#!/usr/bin/env bash
# netbook is the one host whose closure is PUSHED, not pulled.
#
# Why: the netbook has no builder (2-core Celeron, 1.8 GiB), no flake checkout,
# and harmonia never held its paths — it fetched them from cache.nixos.org long
# before the LAN cache existed for this host. A pull-based deploy therefore
# either compiles on the weakest machine in the fleet or fails on a path nothing
# serves.
#
# So: stage the tree on frieren, build it there (`--builders ""`: the closure is
# substitutable — measured 4m22s wall / 8s CPU), `nix copy` it over the LAN, then
# activate the BUILT system with nix-env + switch-to-configuration. No flake
# evaluation and no compiler runs on the netbook at all.
#
# TWO GUARDS run on the target after the build and before the copy:
#
#   1. Boot chain (exit 3). The pinned nixpkgs (`nixpkgs_25_11`) makes the new
#      system's kernel and initrd the store paths the host already boots; if they
#      differ, nothing is copied or activated. This is the check that keeps a
#      deploy from bricking a machine whose newer initrds did not mount root.
#      ALLOW_KERNEL_CHANGE=1 overrides it for a deliberate, attended boot test.
#   2. `/etc/nixos` drift (exit 4). That directory remains as a fallback, so an
#      edit there means a local `nixos-rebuild` would deploy something the flake
#      cannot see. The last deploy records its hash; a different one is refused.
#      ALLOW_CONFIG_DRIFT=1 overrides it after reading the printed diff.
#
# Vars: TARGET=root@192.168.3.36 (LAN — Tailscale SSH is check-gated, so an
#         unattended connection hangs on a browser prompt)
#       ACTION=apply|boot|preflight|rollback|verify   STAGE=switch|boot
#       ATTR=netbook   BUILDER=devji@100.97.61.65 (frieren's tailnet address)
#       REMOTE=/tmp/netbook-deploy   REMOTE_ONLY=1 (everything to nixbuild.net)
# Exit: 0 ok · 1 usage/build/copy failure · 3 boot chain changed · 4 config drift
set -euo pipefail

TARGET=${TARGET:-root@192.168.3.36}
ACTION=${ACTION:-apply}
STAGE=${STAGE:-switch}
ATTR=${ATTR:-netbook}
REMOTE=${REMOTE:-/tmp/netbook-deploy}
# frieren's TAILNET address: `/etc/hosts` maps the bare name to 192.168.3.25,
# which only exists on the home LAN, so a cloud host cannot reach it.
BUILDER=${BUILDER:-devji@100.97.61.65}

say() { printf 'deploy-netbook: %s\n' "$*"; }
die() {
  printf 'deploy-netbook: %s\n' "$*" >&2
  exit 1
}

# --- orchestrator: stage the tree on the builder, then run this script there ----
if [ "${ON_BUILDER:-0}" != "1" ]; then
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  say "staging the tree on ${BUILDER}:${REMOTE}"
  rsync -az --delete \
    --exclude .git --exclude result --exclude 'result-*' \
    "${root}/" "${BUILDER}:${REMOTE}/"
  ssh -o BatchMode=yes -o ConnectTimeout=10 "${BUILDER}" \
    "ON_BUILDER=1 TARGET=$(printf '%q' "$TARGET") ACTION=$(printf '%q' "$ACTION") STAGE=$(printf '%q' "$STAGE") ATTR=$(printf '%q' "$ATTR") REMOTE=$(printf '%q' "$REMOTE") ALLOW_KERNEL_CHANGE=$(printf '%q' "${ALLOW_KERNEL_CHANGE:-0}") ALLOW_CONFIG_DRIFT=$(printf '%q' "${ALLOW_CONFIG_DRIFT:-0}") REMOTE_ONLY=$(printf '%q' "${REMOTE_ONLY:-0}") bash $(printf '%q' "${REMOTE}")/scripts/task/deploy-netbook.sh"
  exit $?
fi

cd "$REMOTE"

target_ssh() { ssh -o BatchMode=yes -o ConnectTimeout=10 "${TARGET}" "$@"; }

report_target() {
  target_ssh bash -s <<'REPORT'
set -e
cur=$(readlink -f /run/current-system)
echo "current:    ${cur}"
echo "booted:     $(readlink -f /run/booted-system)"
echo "generation: $(readlink -f /nix/var/nix/profiles/system | sed 's|.*/||')"
if [ -r /etc/nixos/.flake-managed ]; then
  rec_system=$(sed -n 's/^system=//p' /etc/nixos/.flake-managed)
  rec_hash=$(sed -n 's/^config-sha256=//p' /etc/nixos/.flake-managed)
  echo "deployed:   ${rec_system:-unknown}"
  if [ -n "$rec_system" ] && [ "$rec_system" != "$cur" ]; then
    echo "DRIFT: deployed ${rec_system} but running ${cur} — a local nixos-rebuild bypassed the flake" >&2
  fi
  if [ -n "$rec_hash" ] && [ -r /etc/nixos/configuration.nix ]; then
    now=$(sha256sum /etc/nixos/configuration.nix | cut -d' ' -f1)
    [ "$now" = "$rec_hash" ] || echo "DRIFT: /etc/nixos/configuration.nix changed since the last deploy" >&2
  fi
else
  echo "deployed:   never (no /etc/nixos/.flake-managed)"
fi
failed=$(systemctl --failed --no-legend | wc -l)
echo "failed units: ${failed}"
[ "${failed}" -eq 0 ] || systemctl --failed --no-legend | sed -n '1,5p'
df -h / | tail -1
REPORT
}

case "$ACTION" in
  preflight)
    # Read-only: is the target there, what is it running, and has the fallback
    # copy been edited since the last deploy? No build, no copy, no activation.
    report_target
    ;;

  rollback)
    say "rolling ${TARGET} back one generation"
    target_ssh bash -s <<'ROLLBACK'
set -e
cur=$(readlink -f /run/current-system)
nix-env -p /nix/var/nix/profiles/system --rollback
prev=$(readlink -f /nix/var/nix/profiles/system)
if [ "$prev" = "$cur" ]; then
  echo "deploy-netbook: no previous generation to roll back to" >&2
  exit 1
fi
echo "rolling back: ${cur} -> ${prev}"
"${prev}/bin/switch-to-configuration" switch
echo "current: $(readlink -f /run/current-system)"
ROLLBACK
    ;;

  verify)
    report_target
    ;;

  apply | boot)
    if [ "${REMOTE_ONLY:-0}" = "1" ]; then
      build_flags=(--max-jobs 0)
      say "building .#nixosConfigurations.${ATTR} on the remote builder only"
    else
      build_flags=(--builders "")
      say "building .#nixosConfigurations.${ATTR} on ${BUILDER} (substitution)"
    fi
    system=$(nix build --no-link --print-out-paths "${build_flags[@]}" \
      ".#nixosConfigurations.${ATTR}.config.system.build.toplevel")
    [ -n "${system}" ] || die "build produced no system path"
    new_k=$(nix eval --raw ".#nixosConfigurations.${ATTR}.config.system.build.kernel.outPath")
    new_i=$(nix eval --raw ".#nixosConfigurations.${ATTR}.config.system.build.initialRamdisk.outPath")
    say "system: ${system}"

    # Both guards, on the target, before a single path is copied.
    target_ssh bash -s \
      "${new_k}" "${new_i}" "${ALLOW_KERNEL_CHANGE:-0}" "${ALLOW_CONFIG_DRIFT:-0}" <<'GUARD'
set -e
new_k=$1
new_i=$2
allow_k=$3
allow_d=$4
run_k=$(readlink -f /run/current-system/kernel)
run_i=$(readlink -f /run/current-system/initrd)
echo "boot chain  new: ${new_k} + ${new_i}"
echo "boot chain  running: ${run_k} + ${run_i}"
if [ "$new_k" != "$run_k" ] || [ "$new_i" != "$run_i" ]; then
  if [ "$allow_k" != "1" ]; then
    echo "deploy-netbook: REFUSING — this system changes the boot chain." >&2
    echo "  The kernel and initrd must stay the store paths this host boots." >&2
    echo "  A deliberate change needs ALLOW_KERNEL_CHANGE=1 and an attended boot test." >&2
    exit 3
  fi
  echo "deploy-netbook: WARNING — boot chain changes (ALLOW_KERNEL_CHANGE=1)" >&2
fi
if [ -r /etc/nixos/.flake-managed ] && [ -r /etc/nixos/configuration.nix ]; then
  rec_hash=$(sed -n 's/^config-sha256=//p' /etc/nixos/.flake-managed)
  now=$(sha256sum /etc/nixos/configuration.nix | cut -d' ' -f1)
  if [ -n "$rec_hash" ] && [ "$now" != "$rec_hash" ]; then
    if [ "$allow_d" != "1" ]; then
      echo "deploy-netbook: REFUSING — /etc/nixos/configuration.nix changed since the last deploy." >&2
      echo "  A local nixos-rebuild from that file would deploy a divergence the flake cannot see." >&2
      echo "  Re-read the diff; ALLOW_CONFIG_DRIFT=1 accepts it and records the new hash." >&2
      exit 4
    fi
    echo "deploy-netbook: WARNING — accepting /etc/nixos drift (ALLOW_CONFIG_DRIFT=1)" >&2
  fi
fi
GUARD

    say "pushing the closure to ${TARGET} over the LAN"
    nix copy --to "ssh://${TARGET}" "${system}"
    target_ssh bash -s "${system}" <<'VALID'
set -e
nix-store --check-validity "$1"
VALID

    say "activating (${STAGE}) on ${TARGET}"
    target_ssh bash -s "${system}" "${STAGE}" <<'ACTIVATE'
set -e
system=$1
stage=$2
nix-env -p /nix/var/nix/profiles/system --set "$system"
"${system}/bin/switch-to-configuration" "$stage"
# Record what this host is actually running, so `verify` can tell a flake deploy
# from a local `nixos-rebuild` nobody can see from the repo.
mkdir -p /etc/nixos
{
  echo "system=$system"
  echo "config-sha256=$(sha256sum /etc/nixos/configuration.nix 2>/dev/null | cut -d' ' -f1)"
} > /etc/nixos/.flake-managed
printf '%s\n' \
  "This host is deployed from the nixconfig flake: task infra:apply:host:netbook" \
  "The files here are a FALLBACK, not the source. Editing them and running" \
  "nixos-rebuild deploys a divergence the flake cannot see." \
  > /etc/nixos/FLAKE-IS-TRUTH
ACTIVATE

    report_target
    ;;

  *)
    die "unknown ACTION=${ACTION} (apply|boot|preflight|rollback|verify)"
    ;;
esac
