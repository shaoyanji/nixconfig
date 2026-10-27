#!/usr/bin/env bash
# dns-failover-check.sh — verify a declared DNS resolver group actually answers,
# and whether it can fail over at all.
#
# Why: frieren is the fleet's only resolver (HC-3). `profiles.dnsFailover`
# *declares* the group, but a declaration is not a working failover path. This
# reads the group from that same declaration (so it cannot drift from the
# config) and proves the two things the exit criteria name:
#   * every resolver in the group answers the wildcard zone with the declared
#     address — "dig against the secondary returns the wildcard record";
#   * the group has more than one member, i.e. there is somewhere to fail over
#     TO. A one-member "group" is a single point of failure, not HA, so this is
#     reported as *not evaluable* rather than as a pass.
# When a `virtualIp` is declared it also looks for two owners of the VIP on the
# wire (two distinct ARP reply MACs = split brain).
#
# Two deliberate choices, both learned from the live host:
#   * Probe a SUBDOMAIN (`NAME`, default `hc3-check.<zone>`), not the apex.
#     The apex can carry a local override — on frieren `frieren.lan` answers
#     127.0.0.1 (TTL 0) while `photos.frieren.lan` answers 192.168.3.25 — and a
#     wildcard's job is subdomains. Set NAME=<zone> to test the apex anyway.
#   * Query a resolver that IS this host through 127.0.0.1, and say so. A packet
#     to the host's own LAN address arrives on `lo`, where dnsmasq's
#     `interface=<lan>` scoping drops it (@192.168.3.25 times out while
#     @127.0.0.1 answers), so the LAN path cannot be exercised from the host
#     itself. The pass is annotated so it is not read as "the LAN path works".
#
# Redundancy has two shapes, and counting entries in `resolvers` only sees one:
#   * client-side — clients are handed the member addresses, so >= 2 entries is
#     the proof that there is somewhere to fall back to;
#   * VRRP — clients are handed ONE address that floats between nodes, so a
#     single entry is correct by design and the group is proven by that address
#     answering the zone while exactly one MAC owns it (two owners = two
#     MASTERs, i.e. split brain).
#
# Exit codes: 0 = group healthy AND redundant; 1 = a listed resolver failed to
#   answer the zone, or the VIP answered from two MACs (split brain); 2 = the
#   failover path cannot be evaluated (no dig/jq/nix, nix eval failed, one
#   member and no probed VIP).
set -uo pipefail

HOST="${HOST:-frieren}"
NAME_OVERRIDE="${NAME:-}"
EXPECT_OVERRIDE="${EXPECT:-}"
RESOLVERS_OVERRIDE="${RESOLVERS:-}"
VIP_OVERRIDE="${VIP-}"
IFACE="${IFACE:-}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 2

for bin in nix jq dig; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: $bin is required" >&2
    exit 2
  }
done

# --- the declaration (authoritative: the merged option, not a grep) -----------
cfg_json="$(
  nix eval --json --extra-experimental-features 'nix-command flakes' \
    ".?submodules=1#nixosConfigurations.${HOST}.config.profiles.dnsFailover" 2>/dev/null
)" || {
  echo "ERROR: nix eval failed for ${HOST}.config.profiles.dnsFailover" >&2
  echo "       (is HOST a host that enables profiles.dnsFailover?)" >&2
  exit 2
}

zone="$(jq -r '.zone' <<<"$cfg_json")"
probe="${NAME_OVERRIDE:-hc3-check.${zone}}"
expect="${EXPECT_OVERRIDE:-$(jq -r '.zoneAddress' <<<"$cfg_json")}"
vip="${VIP_OVERRIDE:-$(jq -r '.virtualIp // empty' <<<"$cfg_json")}"

if [ -n "$RESOLVERS_OVERRIDE" ]; then
  group="$(tr ' ,' '\n\n' <<<"$RESOLVERS_OVERRIDE")"
else
  group="$(jq -r '.resolvers[]?' <<<"$cfg_json")"
fi

mapfile -t resolvers < <(printf '%s\n' "$group" | grep -E '^[0-9A-Fa-f:.]+$' || true)

# Addresses this host owns — used to route self-queries through loopback.
local_addrs="$(ip -o -4 addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
is_local() { printf '%s\n' "$local_addrs" | grep -qxF "$1"; }

echo "=== dns failover check: ${HOST} (zone ${zone}, probe ${probe} -> ${expect}) ==="
printf 'resolvers: %s\n' "${resolvers[*]:-<none declared>}"
echo

if [ "${#resolvers[@]}" -eq 0 ]; then
  echo "ERROR: no resolvers declared in profiles.dnsFailover.resolvers" >&2
  exit 2
fi

# --- every member must answer the wildcard zone ------------------------------
failed=""
for r in "${resolvers[@]}"; do
  if is_local "$r"; then
    query=127.0.0.1
    note=" (local resolver; queried via loopback, LAN path not exercised)"
  else
    query="$r"
    note=""
  fi
  answer="$(dig +short +time=2 +tries=1 "@${query}" "${probe}" A 2>/dev/null | head -n1)"
  if [ "$answer" = "$expect" ]; then
    echo "OK    ${r} answers ${probe} -> ${answer}${note}"
  else
    echo "FAIL  ${r} answered '${answer:-<no answer>}' for ${probe} (expected ${expect})${note}"
    failed="${failed}${r} "
  fi
done
echo

# --- split brain on the VRRP VIP (only when one is declared) -----------------
vip_split=""
vip_checked="no"
# `yes` only when the address answered and one MAC owned it — the positive
# evidence the redundancy rule below needs. Reachability alone is not it: an
# address nobody answers is a group that is down, not a group that can fail over.
vip_owned="no"
if [ -n "$vip" ]; then
  if command -v arping >/dev/null 2>&1; then
    iface_args=()
    [ -n "$IFACE" ] && iface_args=(-I "$IFACE")
    macs="$(
      arping -c 4 -w 3 "${iface_args[@]}" "$vip" 2>/dev/null |
        grep -oE '\[[0-9A-Fa-f:]{17}\]' | tr -d '[]' | sort -u || true
    )"
    mac_count="$(printf '%s\n' "$macs" | grep -c . || true)"
    vip_checked="yes"
    if [ "$mac_count" -gt 1 ]; then
      vip_split="yes"
      echo "FAIL  VIP ${vip} answered from ${mac_count} MACs — split brain:"
      printf '        %s\n' $macs
    elif [ "$mac_count" -eq 1 ]; then
      vip_owned="yes"
      echo "OK    VIP ${vip} owned by exactly one MAC (${macs})"
    else
      echo "WARN  VIP ${vip} answered from no MAC — is the group up?"
    fi
  else
    echo "WARN  arping not available; skipped the VIP split-brain probe"
  fi
fi

# --- redundancy: a group of one is not failover ------------------------------
echo
if [ "${#resolvers[@]}" -lt 2 ] && [ "$vip_owned" != "yes" ]; then
  echo "NOT EVALUABLE: ${#resolvers[@]} resolver(s) declared and no probed VIP — a"
  echo "               one-member group proves the primary answers, not that failover"
  echo "               works. Provision a second always-on resolver and either list both"
  echo "               addresses in profiles.dnsFailover.resolvers or declare a"
  echo "               virtualIp both nodes hold."
  echo "               A VIP that exists but was not probed (no arping?) leaves this"
  echo "               undecided on purpose: RESOLVERS=\"<primary> <secondary>\" checks"
  echo "               the members directly."
  exit 2
fi

if [ "${#resolvers[@]}" -lt 2 ]; then
  echo "Redundancy: VRRP VIP ${vip} (one client address, floating between the group's"
  echo "            nodes). Priority decides MASTER; the peer itself is not enumerable"
  echo "            from one host's config — probe it after a switch with"
  echo "            RESOLVERS=\"<primary> <secondary>\"."
fi

if [ -n "$failed" ]; then
  echo "ERROR: resolvers did not answer the zone: ${failed}" >&2
  exit 1
fi
if [ "$vip_split" = "yes" ]; then
  echo "ERROR: split brain detected on VIP ${vip}" >&2
  exit 1
fi

echo "OK: group answers the zone and is redundant (\
${#resolvers[@]} resolver(s) declared, VIP checked: ${vip_checked}, VIP owned: ${vip_owned})"
exit 0
