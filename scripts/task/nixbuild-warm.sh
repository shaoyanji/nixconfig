#!/usr/bin/env bash
# nixbuild-warm.sh — identify uncached derivations and warm the fleet
# Cachix cache using a remote builder (e.g. nixbuild.net).
#
# Budget strategy: `warm` realises host closures with --max-jobs 0, so
# NOTHING builds locally — every missing derivation is dispatched to
# the configured distributed builders (eu.nixbuild.net, see
# modules/profiles/nixbuild-client.nix). The local machine only
# substitutes and signs. That keeps the nixbuild.net free-tier budget
# (25 build-hours/month) as the single build resource.
#
# Prerequisites:
#   - CACHIX_TOKEN set (cache push rights) and cachix on PATH
#   - distributed builds configured + `nix ssh-store://eu.nixbuild.net`
#     reachable (modules/profiles/nixbuild-client.nix does this)
#   - host flakes reachable from the building host (nixbuild.net pulls
#     the flake itself when given a flake ref; for private flakes pass
#     a local --flake override or push the source first)
#
# Usage:
#   nixbuild-warm.sh plan  [host…]   # read-only: report build/fetch gaps per host
#   nixbuild-warm.sh warm  [host…]   # build gaps on the remote builder + cachix push
#   nixbuild-warm.sh warm --flake <ref> [host…]
#
# Env:
#   CACHIX_CACHE      cache name (default: shaoyanji)
#   CACHIX_TOKEN      auth token for pushing
#   WARM_HOSTS        default host list when none given
set -euo pipefail

MODE="${1:-plan}"
shift || true

CACHE="${CACHIX_CACHE:-shaoyanji}"
FLAKE=""
# Optional --flake <ref> override; remaining args are hosts
while [ "$#" -gt 0 ]; do
  case "$1" in
  --flake)
    FLAKE="$2"
    shift 2
    ;;
  -*)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
  *)
    break
    ;;
  esac
done
HOSTS=("$@")
[ "${#HOSTS[@]}" -eq 0 ] && HOSTS=(${WARM_HOSTS:-frieren stark fern})
# Flake ref: "." (local tree) or e.g. "/path/to/flake" / "github:shaoyanji/nixconfig"
FLAKE_REF="${FLAKE:-.}"

# Root derivation for a host (from the local eval, no build needed)
root_drv() {
  local host="$1"
  nix eval --raw "${FLAKE_REF}#nixosConfigurations.${host}.config.system.build.toplevel.drvPath" 2>/dev/null
}

# Set of .drv paths that would be BUILT (not fetched) for a closure.
# Parsed from `nix build --dry-run` stderr — stable across nix 2.x.
build_set() {
  local drv="$1"
  nix build "$drv^*" --dry-run 2>&1 | awk '
    /will be built/ {f=1; next}
    /will be (copied|fetched)|this path will be/ {f=0}
    f' | grep -oE "/nix/store/[a-z0-9]+-[^\'\` ]+\.drv" || true
}

plan_host() {
  local host="$1" drv builds
  drv="$(root_drv "$host")"
  if [ -z "$drv" ]; then
    echo "## ${host}: EVAL FAILED"
    return 1
  fi
  builds="$(build_set "$drv")"
  local count
  count="$(grep -c . <<<"$builds" || true)"
  echo "## ${host}: ${count} derivations missing from substituters"
  if [ "$count" -gt 0 ]; then
    # Rough build-hour estimate: unknown, so show the heavy hitters
    # by name (python/llvm/rust/chromium... dominate wall time).
    grep -oE '\-(python3|llvm|rustc|chromium|mesa|linux|webkit|gcc|stdenv|nixos-system)[^\ ]*' <<<"$builds" | sort -u | head -5 | sed 's/^/   heavyweight? /'
    echo "$builds" >"/tmp/warm-${host}.builds"
    echo "   full list: /tmp/warm-${host}.builds"
  fi
}

warm_host() {
  local host="$1" drv
  drv="$(root_drv "$host")"
  if [ -z "$drv" ]; then
    echo "## ${host}: EVAL FAILED"
    return 1
  fi
  echo "## ${host}: realising closure on remote builder (max-jobs 0 locally)"
  # --max-jobs 0: local builds forbidden → every missing drv is sent to
  # the distributed builders. Missing substitutes are downloaded, then
  # the whole closure is in the local store ready to sign+push.
  nix build "$drv^*" --max-jobs 0 --no-link --print-out-paths
  echo "## ${host}: pushing to cachix ${CACHE}"
  nix build "$drv^*" --dry-run 2>/dev/null >/dev/null || true
  # Push the runtime closure of the toplevel output (signs + uploads).
  out="$(nix build "$drv^*" --no-link --print-out-paths | tail -1)"
  cachix push "$CACHE" "$out"
}

case "$MODE" in
plan)
  rc=0
  for h in "${HOSTS[@]}"; do
    plan_host "$h" || rc=1
  done
  exit "$rc"
  ;;
warm)
  if ! command -v cachix >/dev/null 2>&1; then
    echo "cachix not on PATH (nix-shell -p cachix)" >&2
    exit 2
  fi
  if [ -z "${CACHIX_TOKEN:-}" ]; then
    echo "CACHIX_TOKEN not set — cannot push to ${CACHE}" >&2
    exit 2
  fi
  for h in "${HOSTS[@]}"; do
    warm_host "$h"
  done
  echo "Done. Verify: task dev:nixbuild:plan (should drop to ~0 missing)"
  ;;
*)
  echo "Unknown mode: $MODE (use plan|warm)" >&2
  exit 2
  ;;
esac
