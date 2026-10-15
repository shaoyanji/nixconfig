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
#    against /Volumes/data/projects/nixconfig dies with libgit2 "repository path
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

# Read the cache from inventory when it is declared there, else fall back to the
# fleet's harmonia address. The fallback is a constant on purpose: `yq -i` rewrites
# ALL of inventory.toml (a 622-line diff) so the metadata key could not be added
# without destroying the file's formatting. Env CACHE= always wins.
cache="${CACHE:-$(yq -r '.metadata.cache_url // ""' "$INVENTORY" 2>/dev/null || true)}"
[ -n "$cache" ] || cache="http://192.168.3.25:5000"

# Active hosts only: routing a dormant/preserved host is pointless churn.
status="$(yq -r ".hosts.\"$host\".status // \"absent\"" "$INVENTORY" 2>/dev/null || echo absent)"
if [ "$status" != "active" ]; then
  echo "activate [$host] SKIP — not an active host (inventory status: $status)"
  exit 0
fi

# Resolve the target store path HERE (NixOS toplevel output path, no build).
attr=".#nixosConfigurations.$host.config.system.build.toplevel"
top="$(nix eval --raw "$attr.outPath" 2>/dev/null || true)"
[ -n "$top" ] || { echo "activate [$host] cannot evaluate $attr" >&2; exit 1; }

# The closure must already be servable; otherwise this is not a deploy, it is a
# build waiting to happen on the target.
#
# Test via nix's own store protocol, NOT a raw curl of <hash>.narinfo: harmonia
# answers that request with 404 while serving the path perfectly well over the
# store API (measured 2026-10-15 on both a warm and a cold path — the curl test
# gave false failures). `nix path-info --store` is the authoritative answer.
if ! nix path-info --store "$cache" --option narinfo-cache-negative-ttl 0 "$top" >/dev/null 2>&1; then
  echo "activate [$host] GATE FAILED — $cache does not serve $top" >&2
  echo "  warm it on the builder first: task infra:warm:cache HOSTS=$host" >&2
  exit 1
fi
echo "activate [$host] closure is served by $cache"

if [ "$mode" = "check" ]; then
  echo "activate [$host] READY — target $target, path $top"
  exit 0
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
CACHE='$cache'
TOP='$top'
ACTION='$action'
if [ "\$(readlink -f /run/current-system)" = "\$TOP" ]; then
  echo "already on \$TOP — nothing to do"
  exit 0
fi
echo "== pulling closure from \$CACHE (HTTP, parallel, resumable) =="
"\$NIX" copy --from "\$CACHE" --no-check-sigs --option narinfo-cache-negative-ttl 0 --option trusted-substituters "\$CACHE" "\$TOP"
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
