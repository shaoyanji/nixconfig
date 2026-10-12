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
#   FIREWALL-ONLY     public listener, NOT declared         — firewall is the sole control
#   LOOPBACK-ONLY     listening on 127.0.0.1/::1            — not exposed to the network
#
# Exit codes: 0 = report produced (STRICT=0), 1 = dead holes found and STRICT=1,
#             2 = could not evaluate (nix eval failure).
set -uo pipefail

HOST="${HOST:-frieren}"
IFACE="${IFACE:-enp1s0}"
STRICT="${STRICT:-0}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 2

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

# --- declared surface (authoritative: the merged Nix option, not a grep) -----------------
declared_json="$(
  nix eval --json --extra-experimental-features 'nix-command flakes' \
    ".#nixosConfigurations.${HOST}.config.networking.firewall.interfaces.${IFACE}" 2>/dev/null
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

firewall_only=""
for p in $public_tcp; do
  in_set "$p" "$declared_tcp" || firewall_only="${firewall_only}${p} "
done

echo "SERVED (declared + listening):        ${served:-none}"
echo "DEAD-HOLE (declared, no listener):    ${dead:-none}"
echo "REDUNDANT (declared, loopback only):  ${redundant:-none}"
echo "FIREWALL-ONLY (public, undeclared):   ${firewall_only:-none}"
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

if [ "$STRICT" = "1" ] && [ -n "$dead" ]; then
  echo
  echo "ERROR: STRICT=1 and dead firewall holes exist: ${dead}" >&2
  exit 1
fi
exit 0
