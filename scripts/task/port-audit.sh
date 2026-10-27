#!/usr/bin/env bash
# port-audit.sh — diff a host's *declared* firewall surface against its *actual* listeners.
#
# Why this exists: on a scoped host (frieren/firewall-scope.nix) the firewall is the ONLY
# control in front of a pile of services that bind 0.0.0.0 — rpcbind, NFS mountd/statd,
# LLMNR, the Pi-hole web UI. Auditing that by hand produced a wrong conclusion once
# already, and self-scanning with nmap cannot see it: traffic to the host's own address
# is accepted by the `-i lo -j nixos-fw-accept` rule before the interface-scoped rules are
# reached, so a loopback-path scan over-reports every local listener as "open from the
# LAN". This script never scans; it compares two authoritative sources instead:
#
#   declared  → `nix eval` of the merged firewall option for the interface
#               (catches every module's contribution, not just the ones you remembered)
#   actual    → `ss -tuln` (bind address preserved, so loopback-only is distinguishable)
#
# Buckets reported:
#   SERVED            declared AND listening somewhere      — the intended surface
#   DEAD-HOLE         declared, NOTHING listening           — stale firewall entry (drift)
#   REDUNDANT         declared, loopback-bound only         — hole the LAN cannot use
#   FIREWALL-ONLY     public listener, NOT declared, a port below the dynamic range
#   ACCEPTED          public listener, NOT declared, listed in ACCEPTED_PUBLIC below
#   DYNAMIC           public listener on a port at/above the first dynamic port
#   LOOPBACK-ONLY     listening on 127.0.0.1/::1            — not exposed to the network
#
# Why DYNAMIC is its own bucket and not a failure: above
# `net.ipv4.ip_local_port_range`'s first port the number was drawn at start-up (or taken
# from the dynamic pool) rather than chosen, so there is no stable number to declare — it
# is re-drawn every boot (NFS lockd/statd before their ports were pinned, tailscaled's
# peerapi, an upstream-internal listener with no bind knob). Failing STRICT on those would
# produce a gate that can never be satisfied and a set that changes on every run, which is
# how the real finding got lost last time. They stay visible here; the fix for them is
# per-service isolation (routing namespace / uid split), not a firewall list. Pinning a
# port (services.nfs.server.statdPort, …) moves it OUT of this bucket into
# FIREWALL-ONLY/ACCEPTED, where it can be decided once. Caveat, on purpose: a *configured*
# fixed port above the first dynamic port that is never declared lands here too, so read
# this bucket when a service starts listening on a high port — every declared port in this
# fleet is below it (max 32400), and the NFS convention block sits at 32765-32767.
#
# ACCEPTED_PUBLIC is deliberately tiny and each entry needs a reason: a listener that no
# intended client reaches from the audited interface AND that cannot be bound to a narrower
# address by its owning module. Declaring it would widen the firewall for something nothing
# uses; deleting the entry is not an option either (the listener exists), so the honest
# state is "known, unreachable, firewall-scoped — revisit when the owner changes".
#
# Exit codes: 0 = report produced (STRICT=0 or no drift), 1 = DEAD-HOLE or FIREWALL-ONLY
#             found with STRICT=1, 2 = could not evaluate (nix eval failure).
set -uo pipefail

HOST="${HOST:-frieren}"
IFACE="${IFACE:-enp1s0}"
STRICT="${STRICT:-0}"

# Documented exceptions. Format: "<port>" with the reason on the same line. Reviewed
# 2026-10-12 (HC-7); re-review whenever the bucket below changes.
ACCEPTED_PUBLIC="111 20048 32765 32766 10809"
# `in_set` below compares newline-separated sets (that is what the `nix eval` lists are),
# so normalise here — a space-separated string would only ever match as one long line and
# every accepted port would silently fall through to FIREWALL-ONLY.
accepted_set="$(printf '%s\n' $ACCEPTED_PUBLIC)"
declare -A ACCEPTED_REASON=(
  [111]="rpcbind — NFSv3 client-reachability service; no bind-address option in the NixOS module. Fleet clients mount NFSv4 (which needs no rpcbind), so nothing on the LAN uses it."
  [20048]="rpc.mountd — as 111: only NFSv3 mounts consult it, and the module cannot narrow its bind address."
  [32765]="rpc.statd — pinned from a per-boot port (services.nfs.server.statdPort). v3-only NLM callback surface, unreachable from the LAN."
  [32766]="kernel lockd — pinned (services.nfs.server.lockdPort). Same v3-only story as statd."
  [10809]="iVentoy internal listener on the configured LAN address; upstream port, not configurable. The documented UI is TCP 26000 (declared, SERVED) and PXE streams over 16000."
)

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 2

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

# --- declared surface (authoritative: the merged Nix option, not a grep) -----------------
declared_json="$(
  nix eval --json --extra-experimental-features 'nix-command flakes' \
    ".?submodules=1#nixosConfigurations.${HOST}.config.networking.firewall.interfaces.${IFACE}" 2>/dev/null
)" || {
  echo "ERROR: nix eval failed for ${HOST} interface ${IFACE}" >&2
  echo "       (check the host name and interface, and that this is a scoped host)" >&2
  exit 2
}

declared_tcp="$(jq -r '.allowedTCPPorts[]? // empty' <<<"$declared_json" | sort -n -u)"
declared_udp="$(jq -r '.allowedUDPPorts[]? // empty' <<<"$declared_json" | sort -n -u)"

# --- actual listeners (bind address preserved) -------------------------------------------
# ss -tulnH columns: Netid State Recv-Q Send-Q Local:Port Peer:Port
listeners="$(ss -tulnH 2>/dev/null | awk '{print $1"\t"$5}')"

# The kernel's dynamic port range. A listener BELOW `ephemeral_low` has a stable number
# and can be declared or accepted; at/above it the number was drawn at start-up and cannot
# be named in advance (see the header).
ephemeral_range="$(sysctl -n net.ipv4.ip_local_port_range 2>/dev/null || true)"
ephemeral_low="${ephemeral_range%%[ 	]*}"
ephemeral_high="${ephemeral_range##*[ 	]}"
# Fallback keeps the audit usable where sysctl is absent; Linux's default is 32768 60999.
case "$ephemeral_low" in '' | *[!0-9]*) ephemeral_low=32768 ;; esac
case "$ephemeral_high" in '' | *[!0-9]*) ephemeral_high=60999 ;; esac

# NOTE: printf with an explicit \n — without it the whole set collapses onto one line and
# every set lookup below silently returns false (SERVED comes out empty, DEAD-HOLE gets
# everything). That failure mode looks like a finding, so it is worth the comment.
port_of() { printf '%s\n' "${1##*:}"; }
# Loopback in all three forms ss uses: 127.0.0.1:80, [::1]:80, and the IPv4-mapped
# [::ffff:127.0.0.1]:80 form — missing the third reports a loopback-only service
# (e.g. a JVM on 9998) as a public listener, i.e. invents a finding out of nothing.
is_loopback() {
  case "$1" in
    127.* | "[::1]:"* | "[::ffff:127."*) return 0 ;;
    *) return 1 ;;
  esac
}
is_dynamic() { [ "$1" -ge "$ephemeral_low" ]; }

public_tcp="$(printf '%s\n' "$listeners" | grep -E '^tcp' | while read -r _proto addr; do
  is_loopback "$addr" && continue
  port_of "$addr"
done | sort -n -u)"

loopback_tcp="$(printf '%s\n' "$listeners" | grep -E '^tcp' | while read -r _proto addr; do
  is_loopback "$addr" || continue
  port_of "$addr"
done | sort -n -u)"

listening_any_tcp="$(printf '%s\n' "$public_tcp" "$loopback_tcp" | grep -E '^[0-9]+$' | sort -n -u)"

in_set() { printf '%s\n' "$2" | grep -qxF "$1"; }

echo "=== port audit: ${HOST} / ${IFACE} ==="
echo "declared: $(printf '%s ' $declared_tcp)(tcp) / $(printf '%s ' $declared_udp)(udp)"
echo "dynamic range: ${ephemeral_low}-${ephemeral_high} (ports from ${ephemeral_low} up cannot be declared)"
echo

served=""; dead=""; redundant=""
for p in $declared_tcp; do
  if ! in_set "$p" "$listening_any_tcp"; then
    dead="${dead}${p} "
  elif in_set "$p" "$loopback_tcp" && ! in_set "$p" "$public_tcp"; then
    redundant="${redundant}${p} "
  else
    served="${served}${p} "
  fi
done

firewall_only=""; accepted=""; dynamic=""
for p in $public_tcp; do
  in_set "$p" "$declared_tcp" && continue
  if in_set "$p" "$accepted_set"; then
    accepted="${accepted}${p} "
  elif is_dynamic "$p"; then
    dynamic="${dynamic}${p} "
  else
    firewall_only="${firewall_only}${p} "
  fi
done

echo "SERVED (declared + listening):        ${served:-none}"
echo "DEAD-HOLE (declared, no listener):    ${dead:-none}"
echo "REDUNDANT (declared, loopback only):  ${redundant:-none}"
echo "FIREWALL-ONLY (public, undeclared):   ${firewall_only:-none}"
echo "ACCEPTED (public, documented):        ${accepted:-none}"
echo "DYNAMIC (drawn port, undeclarable):   ${dynamic:-none}"
echo "LOOPBACK-ONLY (not exposed):          $(printf '%s ' $loopback_tcp)"
echo

if [ -n "$dead" ]; then
  echo "Note: DEAD-HOLE ports are firewall holes with nothing behind them — prune them from"
  echo "      the scoped allow-list, or re-enable the service they were declared for."
fi
if [ -n "$redundant" ]; then
  echo "Note: REDUNDANT ports have a declared LAN hole but their listener is loopback-bound,"
  echo "      so the hole is unusable and unnecessary — usually a proxied service."
fi
if [ -n "$firewall_only" ]; then
  echo "Note: FIREWALL-ONLY ports bind a public address but are permitted nowhere. They are"
  echo "      reachable only if the interface scope is loosened, misapplied, or absent on a"
  echo "      host that lacks this scoping — treat them as firewall-dependent, not safe."
fi
if [ -n "$accepted" ]; then
  echo "Note: ACCEPTED ports are the documented exceptions above. Each is unreachable from"
  echo "      ${IFACE} by any intended client and cannot be bound more narrowly by its module,"
  echo "      so the interface scope is its correct control — not an oversight."
  if [ "${VERBOSE:-0}" = "1" ]; then
    for p in $accepted; do
      echo "        ${p}: ${ACCEPTED_REASON[$p]:-<no reason recorded>}"
    done
  fi
fi
if [ -n "$dynamic" ]; then
  echo "Note: DYNAMIC ports sit in ${ephemeral_low}-${ephemeral_high}, so they were drawn at"
  echo "      start-up and there is no stable number to declare. Pin the port where the owner"
  echo "      allows it (services.nfs.server.statdPort/lockdPort) or isolate the service; the"
  echo "      firewall scope is their only control until then."
fi

if [ "$STRICT" = "1" ] && { [ -n "$dead" ] || [ -n "$firewall_only" ]; }; then
  echo
  echo "ERROR: STRICT=1 with drift — DEAD-HOLE: ${dead:-none} / FIREWALL-ONLY: ${firewall_only:-none}" >&2
  exit 1
fi
exit 0
