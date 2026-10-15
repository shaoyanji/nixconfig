#!/usr/bin/env bash
# warm-host.sh — make a host's closure substitutable, and prove it before a switch.
#
# Design rule (learned the hard way): this script performs NO ssh. A `nixos-rebuild`
# pre-hook that opens ssh can block on an interactive auth prompt (Tailscale SSH
# added a browser check on fern and hung an unattended run for 5 minutes). Every
# question this script asks is asked of the binary cache, which is a plain HTTP
# request with a timeout. Builds happen only where they are allowed to happen.
#
# Why warming matters
# -------------------
# `nixos-rebuild` on a 15 W dual-core host saturates it for as long as a full
# closure compile takes (measured: load ~9.4 on fern's 2c/4t, killed after
# 30 min). One build on the builder is served to every other host at LAN speed
# by harmonia (inventory metadata.cache_url; first entry in
# nix.settings.substituters), so the client only substitutes.
#
# Modes
# -----
#   warm-host.sh --check [host …]   read-only gate (task checks:build:route).
#                                   Counts the derivations the CALLER would
#                                   compile. Exits 1 on any gap when the caller
#                                   is not the builder.
#   warm-host.sh [host …]           build the closure HERE, then verify it is
#                                   substitutable. Intended for the builder;
#                                   on any other host it reports the gap and
#                                   exits 1 rather than saturating the machine.
#   warm-host.sh --best-effort …    for switch hooks: never fails the switch.
#                                   Prints the gap as a loud warning and exits 0.
#
# Env
# ---
#   CACHE      override the substituter to check against (default: the LAN cache
#              from inventory.toml, then the local store)
#   NO_VERIFY=1  skip the post-build substitution check
#
# Exit codes: 0 = the caller substitutes everything (or is the builder);
#             1 = derivations remain; 2 = usage or config error.
set -euo pipefail

usage() {
  sed -n '2,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
INVENTORY="$REPO/inventory.toml"

mode="warm"
best_effort=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) mode="check"; shift ;;
    --best-effort) best_effort=1; shift ;;
    -h | --help) usage 0 ;;
    --*) echo "unknown option: $1" >&2; usage 2 ;;
    *) break ;;
  esac
done

[ -f "$INVENTORY" ] || {
  echo "inventory.toml not found at $INVENTORY" >&2
  exit 2
}
command -v yq >/dev/null 2>&1 || {
  echo "yq is required (reads the cache URL from inventory.toml)" >&2
  exit 2
}

# The host that is allowed to build: it is the one serving the cache.
builder="$(yq -r '.metadata.builder_host // "frieren"' "$INVENTORY")"
# Falls back to the fleet's harmonia address: `yq -i` rewrites all of inventory.toml
# (a 622-line diff), so the metadata key could not be added without destroying the
# file's formatting. Env CACHE= overrides either way.
cache_url="$(yq -r '.metadata.cache_url // ""' "$INVENTORY" 2>/dev/null || true)"
[ -n "$cache_url" ] || cache_url="http://192.168.3.25:5000"
self="$(hostname)"

# Where the closure is expected to be substitutable from. Probing the LAN cache
# directly (rather than relying on nix.settings.substituters) is deliberate: a
# host whose config has not been switched yet still gets an honest answer.
check_store="${CACHE:-$cache_url}"

if [ "$#" -gt 0 ]; then
  hosts=("$@")
else
  hosts=("$self")
fi

attr_for() { printf '.#nixosConfigurations.%s.config.system.build.toplevel' "$1"; }

# Build routing only applies to hosts that are actually deployed. Probing a
# dormant/preserved host is pointless churn — and the inventory is the source of
# truth for which those are, so ask it rather than poking the host.
host_status() {
  # Quoted key interpolation, not `--arg` (that is jq syntax and mikefarah yq
  # rejects it — the first version of this silently returned "absent" for every
  # host, including the active ones).
  yq -r ".hosts.\"$1\".status // \"absent\"" "$INVENTORY" 2>/dev/null || echo absent
}

# A path is substitutable when the cache can hand it out. Query with nix's own
# store protocol rather than curl: harmonia answers a raw <hash>.narinfo request
# with 404 even for paths it serves (measured 2026-10-15), so a curl-based gate
# reports false failures. No ssh, no daemon, no auth involved either way.
served_by_cache() {
  local path="$1"
  [ -n "$check_store" ] || return 1
  # narinfo-cache-negative-ttl 0: nix caches 404 narinfo answers for 1h, so a
  # path queried before it was built would keep "missing" after the build —
  # the verify step must always ask the cache fresh.
  nix path-info --store "$check_store" --option narinfo-cache-negative-ttl 0 "$path" >/dev/null 2>&1
}

# Derivations no substituter can serve, i.e. what would be COMPILED.
#
# `--builders ""` is not decoration: frieren has eu.nixbuild.net configured as a
# distributed builder (/etc/nix/machines) and nixbuild.net bills PER BUILD-SECOND
# against a 25 h/month free tier. A gate that could dispatch a build is a gate
# that can spend that budget — which is exactly what happened on 2026-10-15, when
# a `--check` that called `nix build --print-out-paths` (instead of --dry-run)
# dispatched full closures to the remote builder. With builders disabled here, a
# check CANNOT build even if a future edit drops the --dry-run.
pending_count() {
  nix build "$1" --dry-run --builders "" 2>&1 | grep -c 'will be built' || true
}

is_builder=0
[ "$self" = "$builder" ] && is_builder=1

fail=0

for h in "${hosts[@]}"; do
  attr="$(attr_for "$h")"

  # Only active hosts. A preserved/dormant/WIP host is not deployed, so there is
  # nothing to route for it and nothing to check.
  status="$(host_status "$h")"
  if [ "$status" != "active" ]; then
    echo "warm [$h] SKIP — not an active host (inventory status: $status)"
    continue
  fi

  # Not a NixOS flake host (home/darwin configurations, unregistered hosts):
  # nothing to warm, and not an error.
  if ! nix eval --raw "$attr.drvPath" >/dev/null 2>&1; then
    echo "warm [$h] SKIP — not a NixOS flake host (home/darwin or unregistered)"
    continue
  fi

  # `nix eval ... .outPath` forces the derivation's OUTPUT PATH without building
  # it. `nix build --print-out-paths` would silently START a build — which is how
  # a read-only "--check" once launched a full closure compile (caught when it
  # hung for 400 s on stark's NVIDIA closure). Never build in a check.
  top="$(nix eval --raw "$attr.outPath" 2>/dev/null || true)"

  if [ "$mode" = "check" ]; then
    n="$(pending_count "$attr")"
    if [ "${n:-0}" -eq 0 ]; then
      echo "warm [$h] READY — this host substitutes everything${cache_url:+ (LAN cache $cache_url)}"
    else
      echo "warm [$h] GAP — this host would COMPILE $n derivations"
      if [ "$is_builder" = 1 ]; then
        echo "         (allowed here: $self is the builder — the closures are supposed to be built here)"
      else
        echo "         → fix: run 'task infra:warm:cache HOSTS=$h' on $builder, then switch"
        echo "           (the closure is then served by $cache_url; nothing compiles on $self)"
        fail=1
      fi
    fi
    continue
  fi

  # ---- warm ----------------------------------------------------------------
  if [ "$is_builder" != 1 ]; then
    # Building here is exactly what the policy forbids. Report instead of
    # saturating the machine; --best-effort keeps a switch unblocked.
    n="$(pending_count "$attr")"
    echo "warm [$h] REFUSED — $self is not the builder ($builder); this host would compile $n derivations"
    echo "         → run on $builder: task infra:warm:cache HOSTS=$h"
    fail=1
    continue
  fi

  echo "warm [$h] building on $builder (the builder; allowed)"
  nix build "$attr" -L --max-jobs "${MAX_JOBS:-2}"

  if [ "${NO_VERIFY:-0}" = "1" ]; then
    continue
  fi

  # ---- verify the closure is actually substitutable -------------------------
  if [ -n "$top" ] && served_by_cache "$top"; then
    echo "warm [$h] OK — $cache_url serves $top; a switch will substitute, not compile"
  else
    # Harmonia answers narinfo only for paths in its store; a miss here while
    # the build succeeded means the path is present but not being advertised,
    # which is a real cache-side fault worth failing on.
    echo "warm [$h] WARNING — built, but $cache_url did not serve its narinfo." >&2
    echo "         check: curl $cache_url/nix-cache-info ; nix path-info --store $cache_url $top" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ] && [ "$best_effort" = 1 ]; then
  cat >&2 <<-EOF
	WARNING: $self could not be prepared from $cache_url — a switch would compile the
	         closure HERE. Prepare it on $builder first: task infra:warm:cache HOSTS=${hosts[*]}
	EOF
  exit 0
fi

exit "$fail"
