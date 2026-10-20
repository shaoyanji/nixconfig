#!/usr/bin/env bash
# tailnet-dns.sh — what the tailnet actually hands clients, and whether it works.
#
# The tailnet DNS page is invisible state like route approval, with one extra
# trap: a nameserver that is a SUBNET ROUTE (10.99.0.53) is only reachable from
# clients that accept routes. `hosts/{eisen,fern,aristotle}` deliberately set
# `--accept-routes=false` (accepting frieren's 192.168.3.0/24 hijacks their LAN
# traffic through table 52), so for those hosts that entry is dead weight — and
# with "Override DNS servers" on, dead weight is the whole failover plan.
#
# It also probes each nameserver, because route failover is NODE-level, not
# service-level: measured 2026-10-20, crab-hole stopped on delphi for 32 s and
# the /32 stayed where it was; only the second nameserver entry kept queries
# alive. A resolver that dies while its host stays up does not fail over.
#
# Usage: tailnet-dns.sh            # report; exit 1 when a listed resolver fails
# Env:   ZONE (default frieren.lan), PROBE (default doubleclick.net)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
# shellcheck source=lib/tailnet-api.sh
source "$here/lib/tailnet-api.sh"

zone="${ZONE:-frieren.lan}"
probe="${PROBE:-doubleclick.net}"

token="$(tailnet_token)" || exit 2
auth="Authorization: Bearer $token"
api="https://api.tailscale.com/api/v2/tailnet/-/dns"

nameservers="$(curl -sS -m 20 -H "$auth" "$api/nameservers" | jq -r '.dns // [] | .[]')"
magic="$(curl -sS -m 20 -H "$auth" "$api/preferences" | jq -r '.magicDNS // false')"
split="$(curl -sS -m 20 -H "$auth" "$api/split-dns" | jq -c '.')"

# Split DNS pins a zone to specific resolvers and bypasses the global list, so a
# zone that is pinned here is NOT faulted for what the global members answer.
# Pinning is the chosen shape for frieren.lan: crab-hole on delphi is a forwarding
# ad-blocker with no static-record support, so it cannot answer the fleet's
# wildcard while it holds the shared /32.
split_zone="$(printf '%s' "$split" | jq -r --arg z "$zone" '(.[$z] // []) | first // empty')"
if [ -n "$split_zone" ]; then
  za="$(dig +short +time=2 +tries=1 @"$split_zone" "photos.$zone" 2>/dev/null | head -1)"
  printf 'split DNS: %s -> %s  (photos.%s=%s)\n' "$zone" "$split_zone" "$zone" "${za:-—}"
  if [ -z "$za" ]; then
    echo "PINNED RESOLVER DOES NOT SERVE $zone"
    fail_pre=1
  fi
  echo
fi

if [ -z "$nameservers" ]; then
  echo "global nameservers: (none) — tailnet clients use their own resolvers"
  echo "magicDNS: $magic   split DNS: $split"
  echo
  echo "Nothing points at the resolver pair, so 10.99.0.53 serves nobody but the"
  echo "LAN clients that are configured for it by hand."
  exit 0
fi

echo "magicDNS: $magic   split DNS: $split"
echo "global nameservers (proxied; Tailscale queries them, not the OS):"
echo

fail=${fail_pre:-0}
routed=0
total=0
node_ips=0
while read -r ns; do
  [ -n "$ns" ] || continue
  total=$((total + 1))

  # 100.64.0.0/10 is the tailnet itself: a node address needs no routing help.
  # Anything else is a subnet route and needs `--accept-routes` on the client.
  kind="subnet-route"
  if [[ "$ns" =~ ^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\. ]]; then
    kind="tailnet-node"
    node_ips=$((node_ips + 1))
  else
    routed=$((routed + 1))
  fi

  a="$(dig +short +time=2 +tries=1 @"$ns" "photos.$zone" 2>/dev/null | head -1)"
  b="$(dig +short +time=2 +tries=1 @"$ns" "$probe" 2>/dev/null | head -1)"
  filtered="no"
  case "$b" in 0.0.0.0|"") filtered="yes" ;; esac

  status="ok"
  if [ -z "$a" ]; then status="NO ANSWER"; fail=1; fi
  if [ "$filtered" = "no" ]; then status="$status  not-filtering"; fail=1; fi
  # A probe from a node that BINDS this address is answered by its own lo bind,
  # not by whatever the route currently points at — an outage on the other node
  # looks healthy here. Say so instead of reporting a green that proves nothing.
  local_bind=""
  if ip -4 addr show 2>/dev/null | grep -q "inet ${ns}/32"; then
    local_bind="local-bind"
  fi
  printf '  %-16s %-13s %-22s filter=%-3s %s %s\n' "$ns" "$kind" "photos.$zone=${a:-—}" "$filtered" "$status" "$local_bind"
done <<<"$nameservers"

echo
# A nameserver that is a shared /32 is served by whichever node holds the route,
# so the entries above say nothing about whether THAT node can answer the fleet's
# own zone. Ask each advertiser directly on its node address — this is the check
# that catches "delphi is the /32 primary but has no frieren.lan records".
# Match a nameserver against an advertised route either exactly (node address)
# or as a prefix (a /32 or subnet route serving it).
members="$(curl -sS -m 20 -H "$auth" "https://api.tailscale.com/api/v2/tailnet/-/devices?fields=all" \
  | jq -r --argjson ns "$(printf '%s\n' "$nameservers" | jq -R . | jq -s .)" '
      .devices[]
      | . as $d
      | select(
          ($d.advertisedRoutes // []) as $routes
          | $ns
          | map(. as $n | $routes | map(. as $r | ($r == $n) or ($r | startswith($n + "/"))) | any)
          | any
        )
      | "\(.name)\t\([.addresses[] | select(startswith("100."))] | first)"')"

if [ -n "$members" ]; then
  echo "resolver members advertising those addresses (probed on their node IP):"
  while IFS=$'\t' read -r name ip; do
    [ -n "$ip" ] || continue
    a="$(dig +short +time=2 +tries=1 @"$ip" "photos.$zone" 2>/dev/null | head -1)"
    b="$(dig +short +time=2 +tries=1 @"$ip" "$probe" 2>/dev/null | head -1)"
    note=""
    if [ -z "$a" ]; then
      if [ -n "$split_zone" ]; then
        note="n/a — $zone is pinned to $split_zone"
      else
        note="DOES NOT SERVE $zone"
        fail=1
      fi
    fi
    # 0.0.0.0 or no answer = the blocked answer (crab-hole says NXDOMAIN, pihole
    # says 0.0.0.0); anything else means the blocklist is not in effect.
    case "$b" in
      0.0.0.0 | "") ;;
      *)
        [ -z "$note" ] && note="not-filtering"
        fail=1
        ;;
    esac
    printf '  %-14s %-16s photos.%s=%-14s %s\n' "$name" "$ip" "$zone" "${a:-—}" "${note:-ok}"
  done <<<"$members"
  echo
fi

echo "override (console-only, not exposed by the API) decides whether clients"
echo "actually use this list or keep their local resolvers."
if [ "$routed" -gt 0 ]; then
  echo
  echo "NOTE: $routed of $total entries are subnet routes. Clients with"
  echo "--accept-routes=false cannot reach them at all. Node addresses ($node_ips listed)"
  echo "always work."
fi

# A list made ONLY of subnet routes is unusable for every host that refuses
# routes — and those hosts refuse them on purpose, so this is not a preference,
# it is a broken configuration. Read the set from the repo rather than hardcoding
# names: the declaration is what makes it true.
if [ "$node_ips" -eq 0 ] && [ "$routed" -gt 0 ]; then
  # Option order matters: `--` ends option parsing, so `--include` must come
  # first. A grep miss must not abort the report under `set -e`/pipefail.
  routes_off="$( (grep -rl --include='*.nix' -- '--accept-routes=false' "$repo/hosts" 2>/dev/null || true) \
    | sed -E 's|.*/hosts/([^/]+)/.*|\1|' | sort -u | tr '\n' ' ')"
  echo
  echo "FAIL: every global nameserver is a subnet route, and these hosts refuse"
  echo "routes (${routes_off:-none found in the repo}): they have no usable resolver."
  echo "Add a node address — 100.97.61.65 (frieren) or 100.123.145.53 (delphi)."
  fail=1
fi
if [ "$total" -lt 2 ]; then
  echo
  echo "NOTE: one nameserver is not a failover plan. Route failover is node-level:"
  echo "a resolver that dies on a live host keeps its route."
fi
echo
 echo "Probe caveat: a 'local-bind' entry is answered by this host's own lo bind,"
 echo "so it proves the service runs, not that the routed path to it works. Run"
 echo "this from a plain client to test the path."

exit "$fail"
