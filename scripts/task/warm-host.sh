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
#   warm-host.sh --check --emit-path <host>
#                                   the same gate, but stdout is EXACTLY the
#                                   resolved toplevel path (the report moves to
#                                   stderr). infra:deploy:host:* uses this so the
#                                   path is resolved once and handed to
#                                   activate-host.sh via TOP= — no second
#                                   whole-toplevel evaluation.
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
emit_path=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) mode="check"; shift ;;
    --emit-path) emit_path=1; shift ;;
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

# `--emit-path` has an unambiguous stdout only for one host: a list would emit
# several paths and the caller could not tell which one to activate.
if [ "$emit_path" = 1 ]; then
  [ "$mode" = "check" ] || { echo "--emit-path requires --check" >&2; usage 2; }
  [ "${#hosts[@]}" -eq 1 ] || { echo "--emit-path takes exactly one host" >&2; usage 2; }
fi

# Human report. With --emit-path stdout is reserved for the path, so the report
# goes to stderr instead of being swallowed by the caller's command substitution.
report() {
  if [ "$emit_path" = 1 ]; then
    printf '%s\n' "$*" >&2
  else
    printf '%s\n' "$*"
  fi
}

attr_for() { printf '.#nixosConfigurations.%s.config.system.build.toplevel' "$1"; }

# Pin a store path as a fleet GC root. /nix/var/nix/gcroots/fleet is root-owned
# 0755, so `nix build --out-link` there fails for the operator account: measured
# 2026-10-23, the build succeeded and the run still exited 1 on "creating symlink
# ... Permission denied". Try the direct link, then passwordless sudo, and say
# plainly when neither can pin -- a warm that warmed must not report failure
# because of where its root lives.
pin_fleet_root() {
  local host="$1" path="$2" dir=/nix/var/nix/gcroots/fleet dest
  dest="$dir/$host"
  mkdir -p "$dir" 2>/dev/null || true
  if [ -w "$dir" ] && ln -sfn "$path" "$dest" 2>/dev/null; then
    return 0
  fi
  if sudo -n ln -sfn "$path" "$dest" 2>/dev/null; then
    report "warm [$host] GC root pinned as root: $dest"
    return 0
  fi
  report "warm [$host] WARNING -- $dest is not writable by $(id -un) and sudo is not passwordless." >&2
  report "         The closure is built and served; it is only unpinned until the next GC." >&2
  return 0
}

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
  # A preserved host is NOT a check target: its config may be known-broken and
  # evaluating it would report someone else's dormant failure as this run's
  # regression. Warning only (fail stays 0), and we return before `drvPath`,
  # `outPath` or the dry-run, so nothing is evaluated at all.
  if [ "$status" != "active" ]; then
    report "warm [$h] WARNING — inventory status is '$status', not 'active'; not checking a preserved host"
    continue
  fi

  # Not a NixOS flake host (home/darwin configurations, unregistered hosts):
  # nothing to warm, and not an error.
  if ! nix eval --raw "$attr.drvPath" >/dev/null 2>&1; then
    report "warm [$h] SKIP — not a NixOS flake host (home/darwin or unregistered)"
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
      report "warm [$h] READY — this host substitutes everything${cache_url:+ (LAN cache $cache_url)}"
    else
      report "warm [$h] GAP — this host would COMPILE $n derivations"
      if [ "$is_builder" = 1 ]; then
        report "         (allowed here: $self is the builder — the closures are supposed to be built here)"
      else
        report "         → fix: run 'task infra:warm:cache HOSTS=$h' on $builder, then switch"
        report "           (the closure is then served by $cache_url; nothing compiles on $self)"
        fail=1
      fi
    fi
    # The single toplevel resolution the caller may reuse (TOP= in
    # activate-host.sh). Emitted even on a GAP so a failing deploy still names
    # the path it was about to switch to.
    if [ "$emit_path" = 1 ]; then
      printf '%s\n' "$top"
    fi
    continue
  fi

  # ---- warm ----------------------------------------------------------------
  if [ "$is_builder" != 1 ]; then
    # Building here is exactly what the policy forbids. Report instead of
    # saturating the machine; --best-effort keeps a switch unblocked.
    n="$(pending_count "$attr")"
    report "warm [$h] REFUSED — $self is not the builder ($builder); this host would compile $n derivations"
    report "         → run on $builder: task infra:warm:cache HOSTS=$h"
    fail=1
    continue
  fi

  report "warm [$h] building on $builder (the builder; allowed) and pinning fleet GC root"
  built_top="$(nix build "$attr" -L --max-jobs "${MAX_JOBS:-2}" --no-link --print-out-paths | tail -n1)"
  pin_fleet_root "$h" "$built_top"

  if [ "${NO_VERIFY:-0}" = "1" ]; then
    continue
  fi

  # ---- verify the closure is actually substitutable -------------------------
  if [ -n "$top" ] && served_by_cache "$top"; then
    report "warm [$h] OK — $cache_url serves $top; a switch will substitute, not compile"
  else
    # Harmonia answers narinfo only for paths in its store; a miss here while
    # the build succeeded means the path is present but not being advertised,
    # which is a real cache-side fault worth failing on.
    report "warm [$h] WARNING — built, but $cache_url did not serve its narinfo." >&2
    report "         check: curl $cache_url/nix-cache-info ; nix path-info --store $cache_url $top" >&2
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
