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
## declared  → `nix eval` of the merged firewall option (the interface's lists AND the
#               global ones) — catches every module's contribution, not the remembered ones
#   actual    → `ss -tuln` on THIS machine (bind address preserved, so loopback-only is
#               distinguishable). Local by design: no ssh in an unattended path, so a
#               HOST that is not this host is refused rather than half-answered.
#   served    → `tailscale serve status --json` for ports tailscaled itself terminates.
#
# Buckets reported:
#   SERVED            declared AND listening somewhere      — the intended surface
#   SERVED-GLOBAL     permitted by the GLOBAL firewall list  — declared, but open on every interface
#   SERVED-SERVE      a `tailscale serve` port               — tailscaled forwards internally, no row needed
#   DEAD-HOLE         declared, NOTHING listening           — stale firewall entry (drift)
#   REDUNDANT         declared, loopback-bound only         — hole with no possible client (FAILS)
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
# A port gets into REDUNDANT by being declared on the audited interface while its only
# listener binds loopback — the firewall hole cannot be reached, and the client path is the
# vhost or `tailscale serve` mount in front of it (the delphi media relay had no way in
# until it got a mount; a firewall row for its loopback 8094 would have been a hole with
# no client). That is never a state to keep, so it fails unconditionally. DEAD-HOLE and
# FIREWALL-ONLY stay behind STRICT=1: they need a decision, and STRICT is how a run asks.
#
# Exit codes: 0 = report produced (STRICT=0 or no drift), 1 = REDUNDANT, or DEAD-HOLE /
#             FIREWALL-ONLY with STRICT=1, 2 = not auditable: HOST is not this machine, the
#             interface declares no ports, or the nix eval failed.
set -uo pipefail

self="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
HOST="${HOST:-$self}"
IFACE="${IFACE:-enp1s0}"
STRICT="${STRICT:-0}"

# The listener half is THIS machine's `ss` — no ssh in the path, because an
# unattended audit must never wait on an auth prompt. So a foreign HOST would
# compare its declaration against your listeners: run on delphi, frieren's list
# reported 21 DEAD-HOLE ports that every one had a listener for. Refuse it.
if [ -n "$self" ] && [ "${HOST%%.*}" != "$self" ]; then
  echo "ERROR: HOST=$HOST, but this machine is '$self'." >&2
  echo "       The audit compares a declaration against the LOCAL listeners, so a" >&2
  echo "       remote HOST would report this host's ports as another host's drift." >&2
  echo "       Run it on that host instead:" >&2
  echo "         ssh $HOST 'cd ~/Documents/nixconfig && HOST=$HOST IFACE=$IFACE bash scripts/task/port-audit.sh'" >&2
  exit 2
fi

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
firewall_json="$(
  nix eval --json --extra-experimental-features 'nix-command flakes' \
    ".?submodules=1#nixosConfigurations.${HOST}.config.networking.firewall" 2>/dev/null
)" || {
  echo "ERROR: nix eval failed for ${HOST}" >&2
  echo "       (check the host name, and that this machine can evaluate the tree)" >&2
  exit 2
}

declared_tcp="$(jq -r --arg i "$IFACE" '.interfaces[$i].allowedTCPPorts[]? // empty' <<<"$firewall_json" | sort -n -u)"
declared_udp="$(jq -r --arg i "$IFACE" '.interfaces[$i].allowedUDPPorts[]? // empty' <<<"$firewall_json" | sort -n -u)"
# The global lists are a second declaration, not an absence of one: delphi permits
# ssh, nginx and the gemini capsule on every interface, so those listeners are
# declared-and-open rather than FIREWALL-ONLY on tailscale0.
global_tcp="$(jq -r '.allowedTCPPorts[]? // empty' <<<"$firewall_json" | sort -n -u)"

# Ports tailscaled terminates and forwards itself (`task ops:*` style mounts: TLS ends
# in tailscaled, the upstream is loopback). Traffic arrives over the WireGuard socket,
# so the kernel firewall never sees a connection to the port and no row can exist.
serve_json="$(tailscale serve status --json 2>/dev/null || true)"
serve_ports="$(jq -r '((.TCP // {}) | keys[]), ((.Web // {}) | keys[] | sub(".*:"; ""))' <<<"${serve_json:-{\}}" 2>/dev/null | grep -E '^[0-9]+$' | sort -n -u)"
if [ -z "$serve_json" ]; then
  serve_status="unavailable (tailscale serve status failed)"
elif [ -z "$serve_ports" ]; then
  serve_status="none"
else
  serve_status="$(printf '%s ' $serve_ports)"
fi

# An interface that declares nothing is not a scoped interface: every listener
# then lands in FIREWALL-ONLY, which reads as a finding and is only a typo. The
# default interface (`enp1s0`) makes this the common case on a cloud host.
if [ -z "$declared_tcp" ] && [ -z "$declared_udp" ]; then
  echo "ERROR: ${IFACE} declares no ports on ${HOST} — not one of its scoped interfaces." >&2
  echo "       Run inside the clone when \$HOME's Taskfile is stale, or name the interface:" >&2
  echo "         task -t ~/Documents/nixconfig/Taskfile.yml checks:ports HOST=${HOST} IFACE=tailscale0" >&2
  exit 2
fi

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
# One line per set in the header. `printf '%s '` with an EMPTY set prints a single
# space, which reads as a value — so an empty set is spelled out instead.
fmt() {
  if [ -n "${1:-}" ]; then printf '%s ' $1; else printf 'none'; fi
}

echo "=== port audit: ${HOST} / ${IFACE} ==="
echo "declared: $(printf '%s ' $declared_tcp)(tcp) / $(printf '%s ' $declared_udp)(udp)"
echo "global:   $(fmt "$global_tcp")(tcp, open on every interface)"
echo "serve:    ${serve_status}"
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

firewall_only=""; accepted=""; dynamic=""; served_global=""; served_serve=""
for p in $public_tcp; do
  in_set "$p" "$declared_tcp" && continue
  if in_set "$p" "$global_tcp"; then
    served_global="${served_global}${p} "
  elif in_set "$p" "$accepted_set"; then
    accepted="${accepted}${p} "
  elif in_set "$p" "$serve_ports"; then
    served_serve="${served_serve}${p} "
  elif is_dynamic "$p"; then
    dynamic="${dynamic}${p} "
  else
    firewall_only="${firewall_only}${p} "
  fi
done

echo "SERVED (declared + listening):        ${served:-none}"
echo "SERVED-GLOBAL (global list):         ${served_global:-none}"
echo "SERVED-SERVE (tailscaled mount):     ${served_serve:-none}"
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
  echo "ERROR: REDUNDANT ports are declared on ${IFACE} but bind loopback only: ${redundant}" >&2
  echo "       The hole has no possible client, and it widens ${IFACE} for nothing. Reach the" >&2
  echo "       service through its vhost or serve mount and set \`lan = false; tailnet = false;\`" >&2
  echo "       on its row, or make the listener bind the interface." >&2
fi
if [ -n "$served_serve" ]; then
  echo "Note: SERVED-SERVE ports are tailscaled mounts — TLS terminates in tailscaled and it"
  echo "      forwards to the upstream itself, so no inbound filtered connection reaches the"
  echo "      port and a firewall row for one would be a hole with no client."
fi
if [ -n "$served_global" ]; then
  echo "Note: SERVED-GLOBAL ports are in networking.firewall.allowed*Ports, i.e. open on"
  echo "      every interface. Declared, not drift — but on a host that scopes everything"
  echo "      else, this is the row to narrow into profiles.serviceExposure."
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

if [ -n "$redundant" ]; then
  exit 1
fi

if [ "$STRICT" = "1" ] && { [ -n "$dead" ] || [ -n "$firewall_only" ]; }; then
  echo
  echo "ERROR: STRICT=1 with drift — DEAD-HOLE: ${dead:-none} / FIREWALL-ONLY: ${firewall_only:-none}" >&2
  exit 1
fi
exit 0
