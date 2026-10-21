#!/usr/bin/env bash
# dns-pool-check.sh — fail when a declared resolver address sits inside the LAN
# DHCP pool, where the router may lease it to another device.
#
# Why: the resolver address is the one LAN address clients are handed (and the
# one `*.frieren.lan` points at), so a device that obtains it by DHCP answers
# DNS for the LAN. A router reservation normally prevents that, but a
# reservation is a binding, not a range: if it is lost (reset, firmware, MAC
# edit) the dynamic pool hands the address out. Keeping resolver addresses
# outside the pool makes the separation structural instead of procedural.
#
# The pool is router state and has no readable API here, so it is passed in
# explicitly — this check refuses to guess:
#   POOL=192.168.3.100-192.168.3.200      or POOL_START=… POOL_END=…
# Resolver addresses come from the same declaration `checks:dns:failover` reads
# (`profiles.dnsFailover` on HOST), unless RESOLVERS= is given.
#
# Exit codes: 0 = every resolver address is outside the pool; 1 = at least one
#   is inside (or the pool is unusable/misordered); 2 = cannot evaluate (no pool
#   declared, bad address, nix eval failed, or the declaration has no addresses).
set -uo pipefail

HOST="${HOST:-frieren}"
RESOLVERS_OVERRIDE="${RESOLVERS:-}"
POOL="${POOL:-}"
POOL_START="${POOL_START:-}"
POOL_END="${POOL_END:-}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 2

ip2int() {
  local IFS=.
  local -a o
  read -r -a o <<<"$1"
  [[ ${#o[@]} -eq 4 ]] || return 1
  local i
  for i in "${o[@]}"; do
    [[ $i =~ ^[0-9]{1,3}$ ]] || return 1
    ((i <= 255)) || return 1
  done
  echo $(( (o[0] << 24) + (o[1] << 16) + (o[2] << 8) + o[3] ))
}

# --- the pool bounds (explicit input, never inferred) -------------------------
if [ -z "$POOL" ] && { [ -z "$POOL_START" ] || [ -z "$POOL_END" ]; }; then
  echo "ERROR: no DHCP pool given." >&2
  echo "       Pass the router's dynamic range: POOL=192.168.3.100-192.168.3.200" >&2
  echo "       (or POOL_START=… POOL_END=…). This check cannot read the router." >&2
  exit 2
fi

if [ -n "$POOL" ]; then
  if [[ "$POOL" =~ ^([0-9.]+)[[:space:]]*-[[:space:]]*([0-9.]+)$ ]]; then
    POOL_START="${BASH_REMATCH[1]}"
    POOL_END="${BASH_REMATCH[2]}"
  else
    echo "ERROR: POOL='${POOL}' is not START-END (e.g. 192.168.3.100-192.168.3.200)" >&2
    exit 2
  fi
fi

pool_start_int="$(ip2int "$POOL_START")" || {
  echo "ERROR: POOL_START='${POOL_START}' is not an IPv4 address" >&2
  exit 2
}
pool_end_int="$(ip2int "$POOL_END")" || {
  echo "ERROR: POOL_END='${POOL_END}' is not an IPv4 address" >&2
  exit 2
}

if [ "$pool_start_int" -gt "$pool_end_int" ]; then
  echo "ERROR: pool start ${POOL_START} is above end ${POOL_END} — check the range" >&2
  exit 1
fi

# --- the declared resolver addresses ----------------------------------------
if [ -n "$RESOLVERS_OVERRIDE" ]; then
  addrs="$(tr ' ,' '\n\n' <<<"$RESOLVERS_OVERRIDE")"
else
  command -v nix >/dev/null 2>&1 || {
    echo "ERROR: nix is required to read profiles.dnsFailover (or pass RESOLVERS=)" >&2
    exit 2
  }
  command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required" >&2
    exit 2
  }
  cfg_json="$(
    nix eval --json --extra-experimental-features 'nix-command flakes' \
      ".#nixosConfigurations.${HOST}.config.profiles.dnsFailover" 2>/dev/null
  )" || {
    echo "ERROR: nix eval failed for ${HOST}.config.profiles.dnsFailover" >&2
    echo "       (is HOST a host that enables profiles.dnsFailover?)" >&2
    exit 2
  }
  addrs="$(
    jq -r '(.resolvers[]?), .zoneAddress, (.virtualIp // empty)' <<<"$cfg_json" |
      grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' || true
  )"
fi

mapfile -t addresses < <(printf '%s\n' "$addrs" | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' | sort -u || true)

if [ "${#addresses[@]}" -eq 0 ]; then
  echo "ERROR: no resolver addresses to check (declaration empty or RESOLVERS= unset)" >&2
  exit 2
fi

echo "=== dns pool check: ${HOST} (pool ${POOL_START}-${POOL_END}) ==="
printf 'addresses: %s\n\n' "${addresses[*]}"

inside=""
for a in "${addresses[@]}"; do
  a_int="$(ip2int "$a")" || {
    echo "ERROR: '${a}' is not a valid IPv4 address" >&2
    exit 2
  }
  if [ "$a_int" -ge "$pool_start_int" ] && [ "$a_int" -le "$pool_end_int" ]; then
    echo "FAIL  ${a} is INSIDE the pool ${POOL_START}-${POOL_END} — the router may lease it to another device"
    inside="${inside}${a} "
  else
    echo "OK    ${a} is outside the pool ${POOL_START}-${POOL_END}"
  fi
done

echo
if [ -n "$inside" ]; then
  echo "ERROR: resolver address(es) inside the DHCP pool: ${inside}" >&2
  echo "       Move them out of the pool (or narrow the pool), then re-run." >&2
  exit 1
fi

echo "OK: every declared resolver address is outside the DHCP pool"
exit 0
