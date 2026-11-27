#!/usr/bin/env bash
# activate-host.sh — deploy ONE active host by pulling its closure from the LAN
# binary cache on the target itself, then switching to it.
#
# Why not `nixos-rebuild --target-host` (the previous implementation)
# ------------------------------------------------------------------
# That PUSHES the whole closure over ssh, one path at a time. Measured on
# 2026-10-15: 128 paths in ~7 minutes. The same closure pulled from harmonia over
# HTTP ran at ~130-150 paths/min — roughly 8x — because the transfer is parallel,
# request-bounded and resumable. A switch that should be minutes was taking 30+.
#
# The three faults this path works around, all hit for real
# --------------------------------------------------------
# 1. **root cannot evaluate a flake on NFS.** `nixos-rebuild --flake` run as root
#    against a checkout on the NAS mount dies with libgit2 "repository path
#    is not owned by current user", and root's `safe.directory` does NOT suppress
#    it. So: resolve the store path in THIS process (where the flake evaluates)
#    and send the *path*, never the flake, to the target.
# 2. **A systemd unit's PATH has no `nix`.** Root under systemd-run is a
#    non-login shell; use absolute paths on the target.
# 3. **harmonia serves unsigned narinfo.** `nix copy --from` needs
#    `--no-check-sigs`. Its narinfo is trusted because it is the fleet's own LAN
#    cache over a trusted network — assert that here rather than assume it.
#
# 4. **systemd-run nulls the service's stdin.** Without --pipe, `bash -s` reads
#    an empty script, exits 0 instantly, and the unit reports success while
#    nothing happened — the deploy silently did not deploy. --pipe forwards the
#    piped script from ssh through sudo into the unit.
# 5. **Negative narinfo caching poisons a freshly warmed cache.** Nix caches
#    404 narinfo answers for 1h (narinfo-cache-negative-ttl). A target that
#    pulled before the closure was warmed keeps "not finding" the path even
#    after it is served, and the caller-side gate does the same. All cache
#    queries here disable that cache so they always ask harmonia fresh.
#
# ssh is used, but ONLY bounded and non-interactive: BatchMode + ConnectTimeout,
# piping a script to `sudo bash -s`. It cannot prompt, so it cannot hang the way
# Tailscale SSH's browser check hung an unattended run for 5 minutes.
#
# Usage
# -----
#   activate-host.sh <host> [target]        deploy (default target: <host>)
#   activate-host.sh --check <host>         report only: is the closure servable?
#
# Env: CACHE=<url> (default: inventory metadata.cache_url)
#      TOP=<store path> reuse an already-resolved toplevel instead of evaluating
#      `.?submodules=1#nixosConfigurations.<host>.config.system.build.toplevel`
#      again — the flag matches what the warm path builds, or the two disagree.
#      infra:deploy:host:* passes the path its gate just resolved
#      (`warm-host.sh --check --emit-path`), so a deploy evaluates the toplevel
#      ONCE. The path is still gated against the cache here, so a stale or
#      foreign TOP fails exactly like a cold closure.
#      WAIT=<seconds> poll the target for the activation result after starting
#      the unit (default 600; 0 disables and returns right after the start).
# Exit: 0 = activated; 1 = gate failed, activation failed, or WAIT timeout
#       (activation itself keeps running detached on that timeout);
#       2 = usage/config error.
set -euo pipefail

usage() {
  sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
INVENTORY="$REPO/inventory.toml"

mode="deploy"
case "${1:-}" in
  --check) mode="check"; shift ;;
  -h | --help) usage 0 ;;
  --*) echo "unknown option: $1" >&2; usage 2 ;;
esac

host="${1:-}"
target="${2:-$1}"
[ -n "$host" ] || usage 2

[ -f "$INVENTORY" ] || { echo "inventory.toml not found" >&2; exit 2; }
command -v yq >/dev/null 2>&1 || { echo "yq required" >&2; exit 2; }

# Active hosts only. A preserved/dormant host is not part of the deploy surface:
# no gate keeps its config green, so evaluating one can surface bit-rot that
# reads as a regression, and deploying it is not a normal operation.
#
# This is a WARNING-level gate, not a failure: naming a preserved host sets off
# no build, no cache query, no ssh, and exits 0 with the reason. Reviving one is
# deliberate, so it takes an explicit ALLOW_PRESERVED=1.
status="$(yq -r ".hosts.\"$host\".status // \"absent\"" "$INVENTORY" 2>/dev/null || echo absent)"
if [ "$status" != "active" ]; then
  echo "activate [$host] WARNING — inventory status is '$status', not 'active'." >&2
  echo "         Preserved/dormant hosts are not deployed; nothing was evaluated," >&2
  echo "         copied or switched. To revive $host deliberately:" >&2
  echo "         ALLOW_PRESERVED=1 task infra:apply:host:$host" >&2
  [ "${ALLOW_PRESERVED:-0}" = "1" ] || exit 0
  echo "activate [$host] WARNING — proceeding anyway (ALLOW_PRESERVED=1, status '$status')" >&2
fi

# Resolve the target store path HERE (NixOS toplevel output path, no build).
# TOP= skips the evaluation: the caller already forced it and this would be a
# second whole-toplevel eval of the same attrset for the same answer.
attr=".?submodules=1#nixosConfigurations.$host.config.system.build.toplevel"
if [ -n "${TOP:-}" ]; then
  top="$TOP"
  case "$top" in
    /nix/store/*) ;;
    *) echo "activate [$host] TOP must be a /nix/store path, got '$top'" >&2; exit 2 ;;
  esac
  echo "activate [$host] using caller-resolved toplevel $top"
else
  top="$(nix eval --raw "$attr.outPath" 2>/dev/null || true)"
fi
[ -n "$top" ] || { echo "activate [$host] cannot evaluate $attr" >&2; exit 1; }

# Which substituters may serve this host's closure, IN THE HOST'S OWN ORDER —
# read from `.?submodules=1#inventory.cache.<host>`, the same projection modules/global/global.nix
# consumes for nix.settings.substituters. Deciding it in both places is what broke
# delphi's deploys: the module excluded the LAN cache for a cloud host while this
# script gated on it, so the deploy either aborted or left the switch with nothing
# to fetch — and the whole system compiled there.
#
# Env CACHE=<url> pins it to exactly one cache (unchanged escape hatch).
#
# AFTER the toplevel, not before: the loop below tests `$top` against each cache, so
# resolving it later made every caller that did not pass TOP= die on `set -u` at
# this line — `infra:apply:host:*` and the fleet loop, i.e. the paths that exist
# precisely because they have no gate of their own to resolve it.
caches="$(nix eval --json "$REPO#inventory.cache.$host.deployStores" 2>/dev/null | jq -r '.[]' | tr '\n' ' ' || true)"
if [ -z "$caches" ]; then
  echo "activate [$host] cannot read $REPO#inventory.cache.$host.deployStores" >&2
  exit 2
fi
[ -n "${CACHE:-}" ] && caches="$CACHE"
# shellcheck disable=SC2086
set -- $caches
cache="$1"
serving=""
for c in "$@"; do
  if nix path-info --store "$c" --option narinfo-cache-negative-ttl 0 "$top" >/dev/null 2>&1; then
    serving="$c"
    break
  fi
done

# The closure must already be servable; otherwise this is not a deploy, it is a
# build waiting to happen on the target.
#
# Test via nix's own store protocol, NOT a raw curl of <hash>.narinfo: harmonia
# answers that request with 404 while serving the path perfectly well over the
# store API (measured 2026-10-15 on both a warm and a cold path — the curl test
# gave false failures). `nix path-info --store` is the authoritative answer.
# The toplevel is the ONE path no cache holds durably. It is a generated script
# tree whose store path changes with every commit, and a cache prunes what nothing
# references: measured 2026-11-18, delphi's RUNNING toplevel was absent from all
# seven of its stores, so `warm-host.sh --check` (which excludes exactly this
# path) called the host READY while this gate refused it — two instruments,
# opposite answers, one host. The closure is the deployable object; the toplevel
# is what the switch produces, and it produces it in milliseconds once every
# input substitutes.
#
# So: when the toplevel alone is missing, carry its derivation to the target and
# let it realise it there. Proven, not assumed — a dry run with builders off must
# leave exactly one pending derivation and it must be this toplevel's, so nothing
# but the generated script tree can be built on the target.
toplevel_drv=""
if [ -z "$serving" ]; then
  drv="$(nix eval --raw "$attr.drvPath" 2>/dev/null || true)"
  # The no-dispatch dry run is the envelope's `none` render, not an inline
  # `--builders ""` — one spelling of the builders decision fleet-wide.
  # shellcheck disable=SC2086 # the renderer prints flags; word splitting is the point
  pending="$(nix build "$attr" --dry-run --json $(bash "$REPO/scripts/task/rebuild-flags.sh" --builders none) 2>/dev/null | jq -r '.[].drvPath' 2>/dev/null || true)"
  if [ -n "$drv" ] && [ "$pending" = "$drv" ]; then
    toplevel_drv="$drv"
    echo "activate [$host] toplevel is in no store (normal); the closure substitutes, so the target builds just that tree from $drv"
  fi
fi

if [ -z "$serving" ] && [ -z "$toplevel_drv" ]; then
  echo "activate [$host] GATE FAILED — none of this host's substituters serve $top:" >&2
  echo "  $caches" >&2
  echo "  and it is not the toplevel alone: a dry run still has other derivations pending." >&2
  echo "  warm it on the builder first: task infra:warm:host:$host" >&2
  exit 1
fi
if [ -n "$serving" ]; then
  cache="$serving"
  echo "activate [$host] closure is served by $cache"
fi

if [ "$mode" = "check" ]; then
  echo "activate [$host] READY — target $target, path $top"
  exit 0
fi

# The derivation has to be IN the target's store for it to realise anything. Its
# inputs are all substitutable (that is what the dry run proved), so this is the
# generated tree only — a few seconds, no compiler.
if [ -n "$toplevel_drv" ]; then
  # `nix copy`, not a bare `nix-store --export`: a drv names its input drvs, and
  # `nix-store --import` refuses the set unless every one of them is present —
  # measured 2026-11-18 on frieren, "store path …-activate.drv does not exist",
  # after the same hand-off happened to work on delphi where CI had left them.
  # copy walks the drv closure itself, so the target gets what the realise needs.
  echo "activate [$host] carrying the toplevel derivation to $target"
  NIX_SSHOPTS="-o BatchMode=yes -o ConnectTimeout=10" nix copy --to "ssh://$target" "$toplevel_drv" || {
    echo "activate [$host] GATE FAILED — could not hand the toplevel derivation to $target" >&2
    exit 1
  }
fi

action="${ACTION:-switch}"

# The activation program, executed ON the target under sudo. Values are baked in
# so nothing depends on the target's environment.
unit="activate-$(printf '%s' "$host" | tr -c 'a-zA-Z0-9' '-')-$(date +%s)"
remote="$(cat <<REMOTE
set -euo pipefail
export PATH="/run/current-system/sw/bin:/run/current-system/sw/sbin:\$PATH"
NIX=/run/current-system/sw/bin/nix
NIXENV=/run/current-system/sw/bin/nix-env
CACHES='$caches'
TOP='$top'
TOP_DRV='$toplevel_drv'
ACTION='$action'
if [ "\$(readlink -f /run/current-system)" = "\$TOP" ]; then
  echo "already on \$TOP — nothing to do"
  exit 0
fi
# Substitute from EVERY cache the host is configured for, in its order, and
# never let this path compile: a copy that silently falls through to a build is
# how a deploy turns into a 100%-CPU NAS/cloud host. A cache that cannot serve
# the toplevel is skipped; the validity check below is the verdict.
set -- \$CACHES
for c in "\$@"; do
  echo "== pulling closure from \$c (HTTP, parallel, resumable) =="
  "\$NIX" copy --from "\$c" --no-check-sigs --option narinfo-cache-negative-ttl 0 --option trusted-substituters "\$c" "\$TOP" && break || echo "   \$c did not serve it; trying the next substituter"
done
if ! "\$NIX" path-info "\$TOP" >/dev/null 2>&1; then
  # Only the toplevel can be missing here: the caller proved every other
  # derivation substitutes, so realising this drv builds the generated script
  # tree and nothing else. Then the check below is the same verdict as always.
  if [ -n "\$TOP_DRV" ]; then
    echo "== building the toplevel tree from \$TOP_DRV (its inputs all substitute) =="
    # nix-store, not `nix store`: there is no `nix store realise` subcommand, and
    # the first version of this line printed its usage error into a `|| true`
    # and left the deploy looking like a cache miss (measured 2026-11-18).
    /run/current-system/sw/bin/nix-store --realise "\$TOP_DRV" ||
      echo "   realise of the toplevel tree FAILED — the verdict below still decides"
  fi
  if ! "\$NIX" path-info "\$TOP" >/dev/null 2>&1; then
    echo "activate FAILED — \$TOP is not in the local store and no substituter served it." >&2
    echo "  refusing to fall through to compiling the closure on this host. Warm it: task infra:warm:host:<host>" >&2
    exit 1
  fi
fi
echo "== registering generation =="
"\$NIXENV" -p /nix/var/nix/profiles/system --set "\$TOP"
echo "== activating (\$ACTION) =="
"\$TOP/bin/switch-to-configuration" "\$ACTION"
if [ "\$ACTION" = "boot" ]; then
  echo "== COMPLETED (boot stage): default boot profile is \$(readlink -f /nix/var/nix/profiles/system) (reboot required to activate) =="
else
  echo "== COMPLETED (switch): current system is \$(readlink -f /run/current-system) =="
fi
REMOTE
)"

echo "activate [$host] running on $target (unit $unit, action $action); progress: ssh $target journalctl -u $unit"
# Detached so a 20-minute transfer cannot be killed by the caller's session, and
# so the copy survives a dropped connection. No --collect so journal/exit state is retained for diagnosis.
printf '%s\n' "$remote" |
  ssh -o BatchMode=yes -o ConnectTimeout=10 -o ControlMaster=no "$target" \
    "sudo systemd-run --pipe --unit='$unit' --description='activate $host from $cache' --property=Type=oneshot bash -s"

# Report a real outcome. The unit runs detached, but the caller should not be
# left with only "started" — the 2026-10-15 incident was exactly that: the unit
# exited 0 without executing anything and the deploy silently did not deploy.
# Poll until the target reports the expected toplevel (success), the unit
# reports failure, or WAIT seconds pass (activation continues detached).
wait="${WAIT:-600}"
if [ "$wait" = "0" ]; then
  echo "activate [$host] started (WAIT=0, not polling). Completion signal:"
  echo "  ssh $target 'readlink -f /run/current-system'   # expect $top"
  exit 0
fi

ssh_opts="-o BatchMode=yes -o ConnectTimeout=10 -o ControlMaster=no"
deadline=$((SECONDS + wait))
while [ "$SECONDS" -lt "$deadline" ]; do
  sleep 5
  out="$(ssh $ssh_opts "$target" "readlink -f /run/current-system; systemctl show -p ActiveState --value '$unit' 2>/dev/null || true")" || out=""
  cur="$(printf '%s\n' "$out" | sed -n '1p')"
  state="$(printf '%s\n' "$out" | sed -n '2p')"

  if [ "$action" = "boot" ]; then
    boot_link="$(ssh $ssh_opts "$target" "readlink -f /nix/var/nix/profiles/system 2>/dev/null || true")"
    if [ "$boot_link" = "$top" ] && [ "$state" = "inactive" ]; then
      echo "activate [$host] SUCCESS (boot stage) — $target default boot profile is $top"
      exit 0
    fi
  elif [ "$cur" = "$top" ]; then
    echo "activate [$host] SUCCESS — $target is on $top"
    exit 0
  fi

  if [ "$state" = "failed" ]; then
    echo "activate [$host] FAILED on $target — unit journal:" >&2
    ssh $ssh_opts "$target" "journalctl -u '$unit' --no-pager | tail -30" >&2 || true
    exit 1
  fi

  if [ "$state" = "inactive" ] || [ "$state" = "not-found" ]; then
    sleep 3
    cur="$(ssh $ssh_opts "$target" "readlink -f /run/current-system 2>/dev/null || true")"
    if [ "$cur" = "$top" ]; then
      echo "activate [$host] SUCCESS — $target is on $top"
      exit 0
    fi
    boot_link="$(ssh $ssh_opts "$target" "readlink -f /nix/var/nix/profiles/system 2>/dev/null || true")"
    if [ "$action" = "boot" ] && [ "$boot_link" = "$top" ]; then
      echo "activate [$host] SUCCESS (boot stage) — $target default boot profile is $top"
      exit 0
    fi
    echo "activate [$host] FAILED on $target — unit finished but the target is still on $cur. Unit journal:" >&2
    ssh $ssh_opts "$target" "journalctl -u '$unit' --no-pager | tail -30" >&2 || true
    exit 1
  fi
done

echo "activate [$host] TIMEOUT after ${wait}s — activation continues detached on $target. Check:"
echo "  ssh $target 'readlink -f /run/current-system'   # expect $top"
exit 1
