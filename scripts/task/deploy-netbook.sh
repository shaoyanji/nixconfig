#!/usr/bin/env bash
# netbook is the one host whose closure is PUSHED, not pulled.
#
# Why: the netbook has no builder (2-core Celeron, 1.8 GiB), no flake checkout,
# and harmonia never held its paths — it fetched them from cache.nixos.org long
# before the LAN cache existed for this host. A pull-based deploy therefore
# either compiles on the weakest machine in the fleet or fails on a path nothing
# serves.
#
# So: stage the tree on frieren, obtain the closure there — substitute first,
# nixbuild.net for the gaps (`BUILD=auto`, measured 4m22s wall / 8s CPU when
# nothing had to be built) — `nix copy` it over the LAN, then activate the BUILT
# system with nix-env + switch-to-configuration. No flake evaluation and no
# compiler runs on the netbook at all.
#
# TWO GUARDS run on the target after the build and before the copy, and one
# check runs after activation:
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
#   3. Activation completeness (exit 5/6, after the switch). The switcher links
#      /etc and /run/current-system before it talks to systemd, so a dead system
#      bus leaves a half-activated host that still looks current. The check asks
#      the bus for the unit list; a failure means changed units never restarted.
#
# Nothing on the netbook pulls. It cannot use harmonia (the LAN cache never held
# its paths, and its own closure is 6.6 GB of paths fetched years ago from
# cache.nixos.org), so "pull from the cache" is not a fallback that might work:
# the push IS the delivery. Frieren is the only machine in the loop that can
# both evaluate the flake and hold the result.
#
# Vars: TARGET=root@192.168.3.36 (LAN — Tailscale SSH is check-gated, so an
#         unattended connection hangs on a browser prompt)
#       ACTION=apply|boot|preflight|rollback|verify   STAGE=switch|boot
#       ATTR=netbook   BUILDER=devji@100.97.61.65 (frieren's tailnet address)
#       REMOTE=/tmp/netbook-deploy
#       BUILD=auto|local|remote (default auto: substitute, then nixbuild.net for
#         the gaps; local = compile on frieren; remote = nixbuild.net only)
#       REMOTE_ONLY=1 (alias of BUILD=remote)
# Exit: 0 ok · 1 usage/build/copy failure · 3 boot chain changed · 4 config drift
#       5 system bus dead after activation (units not restarted) · 6 switch non-zero
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
# Delivery: report which link in the chain works instead of assuming the LAN
# cache. On this host the honest answer is usually "reachable, but it has none
# of these paths", because every path predates the cache.
cache=${HARMONIA_CACHE:-http://192.168.3.25:5000}
if timeout 8 nix path-info --store "$cache" "$cur" >/dev/null 2>&1; then
  echo "harmonia:   has this system — a pull would work"
else
  err=$(timeout 8 nix path-info --store "$cache" "$cur" 2>&1 | tr '\n' ' ')
  case "$err" in
    *onnect* | *efused* | *imeout* | *imed*) echo "harmonia:   UNREACHABLE — the push is the only path" ;;
    *) echo "harmonia:   reachable but does NOT have this system — the push is the only path" ;;
  esac
fi
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
# "nothing to roll back" is a question about the PROFILE, not about what is
# running. Comparing the rollback target with /run/current-system made the
# staged case — profile ahead of the running system, which is exactly what
# `STAGE=boot` leaves behind — perform the rollback and then exit 1 as if there
# had been no previous generation. Ask whether the profile moved instead.
before=$(readlink -f /nix/var/nix/profiles/system)
nix-env -p /nix/var/nix/profiles/system --rollback
after=$(readlink -f /nix/var/nix/profiles/system)
if [ "$after" = "$before" ]; then
  echo "deploy-netbook: no previous generation to roll back to" >&2
  exit 1
fi
echo "rolling back: ${before} -> ${after}"
"${after}/bin/switch-to-configuration" switch
echo "current:  $(readlink -f /run/current-system)"
echo "profile:  ${after}"
# The switcher links /run/current-system but does not install boot entries, so
# the loader still defaults to the newer generation. Say it rather than letting
# a reboot quietly undo the rollback.
echo "note: /boot/loader/loader.conf still defaults to the newer entry — run"
echo "      ${after}/bin/switch-to-configuration boot to make the rollback stick"
ROLLBACK
    ;;

  verify)
    report_target
    ;;

  apply | boot)
    toplevel=".#nixosConfigurations.${ATTR}.config.system.build.toplevel"
    # Three ways to get the closure onto frieren, cheapest first: substitute
    # (free), then nixbuild.net (25 h/month budget), then compile locally. `auto`
    # is the useful default because it spends nothing when the pinned 25.11
    # release is already in the caches, and still completes when it is not.
    mode=${BUILD:-auto}
    [ "${REMOTE_ONLY:-0}" = "1" ] && mode=remote
    case "$mode" in
      auto)
        say "substituting .#nixosConfigurations.${ATTR} on the builder (no compile)"
        if ! system=$(nix build --no-link --print-out-paths --max-jobs 0 --builders "" "$toplevel" 2>/dev/null); then
          say "not fully substitutable — filling the gaps on nixbuild.net"
          system=$(nix build --no-link --print-out-paths --max-jobs 0 "$toplevel")
        fi
        ;;
      local)
        say "building .#nixosConfigurations.${ATTR} on the builder (local compile allowed)"
        system=$(nix build --no-link --print-out-paths --builders "" "$toplevel")
        ;;
      remote)
        say "building .#nixosConfigurations.${ATTR} on nixbuild.net only"
        system=$(nix build --no-link --print-out-paths --max-jobs 0 "$toplevel")
        ;;
      *) die "unknown BUILD=${mode} (auto|local|remote)" ;;
    esac
    [ -n "${system}" ] || die "build produced no system path"
    # Both sides must speak the same shape or the guard refuses every deploy. The
    # built system exposes `kernel`/`initrd` as symlinks to FILES
    # (`…-linux-7.1.2/bzImage`); the target reduces its running ones to the store
    # directory. Normalizing both to `/nix/store/<name>` is what makes this an
    # exact comparison instead of a permanent false positive (measured 2026-10-22:
    # refused an identical boot chain twice, once from each mismatch direction).
    store_path() { printf '%s\n' "$1" | cut -d/ -f1-4; }
    new_k=$(store_path "$(readlink -f "${system}/kernel")")
    new_i=$(store_path "$(readlink -f "${system}/initrd")")
    say "system: ${system}"

    # Both guards, on the target, before a single path is copied.
    target_ssh bash -s \
      "${new_k}" "${new_i}" "${ALLOW_KERNEL_CHANGE:-0}" "${ALLOW_CONFIG_DRIFT:-0}" <<'GUARD'
set -e
new_k=$1
new_i=$2
allow_k=$3
allow_d=$4
# Compare the STORE PATHS, not the files: `readlink -f /run/current-system/kernel`
# resolves to `<store>/bzImage`, while the evaluated value is the store directory
# itself. Cutting to /nix/store/<name> keeps the comparison exact and stops it
# from reporting a false change (which it did, on this host, before this line).
store_path() { printf '%s\n' "$1" | cut -d/ -f1-4; }
run_k=$(store_path "$(readlink -f /run/current-system/kernel)")
run_i=$(store_path "$(readlink -f /run/current-system/initrd)")
echo "boot chain  new:     ${new_k} + ${new_i}"
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
# The switcher links /etc and /run/current-system BEFORE it asks systemd to
# restart units, so a broken system bus produces a half-activation that still
# looks like success: the new system is current, and every unit whose config
# changed kept running the old one. Measured on this host 2026-10-22.
set +e
"${system}/bin/switch-to-configuration" "$stage"
switch_rc=$?
set -e
if ! busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager ListUnits >/dev/null 2>&1; then
  echo "deploy-netbook: the system bus cannot reach pid1 — activation is PARTIAL." >&2
  echo "  /etc and /run/current-system point at ${system}, but changed units were not" >&2
  echo "  restarted. Restart the bus, re-run the switch, and reboot if a desktop" >&2
  echo "  session died with it:  systemctl restart dbus.service" >&2
  exit 5
fi
if [ "$switch_rc" -ne 0 ]; then
  echo "deploy-netbook: switch-to-configuration exited ${switch_rc} with a live bus." >&2
  echo "  Read its output above; the common cause is logind refusing to list users." >&2
  exit 6
fi
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
