#!/usr/bin/env bash
# atuin-audit.sh — is atuin logged in on every active Nix-managed host?
#
# atuin-bootstrap.sh finishes ONE host; this asks the same question of the fleet
# in one pass, so "which host still has not joined" is a table instead of a
# memory. Membership comes from inventory.toml: active, kind nixos or home.
# External hosts are out of scope by construction — their ssh lives in a per-host
# shard task with its own user, port and transport, not in an ssh alias.
#
# The probe asks atuin, not systemd. `atuin status` is the only thing that knows a
# session exists, and sync_address is what separates a fleet client from a host
# that logged into api.atuin.sh and then reported "invalid credentials" — the
# failure mode in SKILL.md that reads exactly like a wrong sops password.
#
# An unreachable host is SKIP, not a failure: a sleeping laptop is not a broken
# login, and a gate that reddens on absence is a gate people learn to ignore.
# STRICT=1 turns absence into a failure for the run that wants to prove the fleet
# is actually up.
#
# A bare hostname resolves only where MagicDNS is the resolver, and a tailnet host
# with Tailscale SSH answers `ssh` with "requires an additional check" instead of a
# key handshake. So each host is tried three times — ssh alias, tailnet FQDN, LAN
# address from inventory.toml — and one resolver or auth gap is not thirteen
# unreachable machines.
#
# Usage: atuin-audit.sh [--strict]
# Env:   HOSTS="a b"  audit only these · ATUIN_TIMEOUT=20 per host · STRICT=1
# Exit:  0 every reachable host is logged in · 1 a reachable host is not
#        · 2 inventory.toml or yq is missing
set -uo pipefail

strict=0
for arg in "$@"; do
  case "$arg" in
  --strict) strict=1 ;;
  -h | --help) sed -n '2,24p' "$0"; exit 0 ;;
  *)
    echo "atuin-audit: unknown argument $arg" >&2
    exit 2
    ;;
  esac
done
[ "${STRICT:-0}" = 1 ] && strict=1

here=$(dirname -- "${BASH_SOURCE[0]}")
ROOT=${NIXCONFIG:-$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || true)}
INVENTORY=${INVENTORY:-${ROOT:-.}/inventory.toml}
TIMEOUT=${ATUIN_TIMEOUT:-20}

[ -f "$INVENTORY" ] || { printf 'atuin-audit: no inventory at %s\n' "$INVENTORY" >&2; exit 2; }
command -v yq >/dev/null || { echo "atuin-audit: yq is not on PATH" >&2; exit 2; }

hosts=$(yq -r '.hosts | to_entries | .[]
  | select(.value.status == "active" and (.value.kind == "nixos" or .value.kind == "home"))
  | [.key, (.value.network.ssh_alias // .key), (.value.network.lan_ip // "")] | @tsv' "$INVENTORY") || {
  echo "atuin-audit: could not read hosts from $INVENTORY" >&2
  exit 2
}

# host -> tailnet FQDN, from the local tailscale daemon. Empty when tailscale is
# absent or logged out, which leaves the single-alias behaviour below unchanged.
declare -A fqdn=()
if command -v tailscale >/dev/null 2>&1 && ts=$(timeout 10 tailscale status --json 2>/dev/null); then
  while IFS=$'\t' read -r name dns; do
    [ -n "$name" ] && [ -n "$dns" ] || continue
    fqdn[$name]=${dns%.}
  done < <(jq -r '((.Peer // {}) | to_entries[] | [.value.HostName, .value.DNSName]),
    (if .Self then [.Self.HostName, .Self.DNSName] else empty end) | @tsv' <<<"$ts" 2>/dev/null)
fi

if [ -n "${HOSTS:-}" ]; then
  keep=$(printf '%s\n' $HOSTS)
  hosts=$(while IFS=$'\t' read -r key target lan; do
    grep -qxF -- "$key" <<<"$keep" && printf '%s\t%s\t%s\n' "$key" "$target" "$lan"
  done <<<"$hosts")
fi

# GNU timeout is missing on darwin hosts; ConnectTimeout still bounds the connect,
# and a hang after that is what ATUIN_TIMEOUT exists for.
wrapper=$(command -v timeout || command -v gtimeout || true)

probe() { # target
  if [ -n "$wrapper" ]; then
    "$wrapper" "$TIMEOUT" ssh -o BatchMode=yes -o ConnectTimeout=3 \
      -o StrictHostKeyChecking=accept-new "$1" bash -s 2>/dev/null
  else
    ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$1" bash -s 2>/dev/null
  fi <<'REMOTE'
set +e
d=$(command -v atuin 2>/dev/null)
if [ -z "$d" ]; then
  for p in "/etc/profiles/per-user/$(id -un)/bin/atuin" "$HOME/.nix-profile/bin/atuin" /run/current-system/sw/bin/atuin; do
    [ -x "$p" ] && d=$p && break
  done
fi
[ -n "$d" ] || { printf 'absent\t-\t-\t-\t-\t-\n'; exit 0; }
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
addr=$("$d" config get sync_address 2>/dev/null | tail -1)
export ATUIN_SESSION="${ATUIN_SESSION:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "audit-$$-$RANDOM")}"
if "$d" status >/dev/null 2>&1; then logged=yes; else logged=no; fi
items=$({ command -v sqlite3 >/dev/null && sqlite3 "$DATA/history.db" 'select count(*) from history' 2>/dev/null; } || true)
[ -e "$DATA/key" ] && key=yes || key=no
unit=$(systemctl --user is-enabled atuin-auto-login 2>/dev/null) || unit=""
printf 'present\t%s\t%s\t%s\t%s\t%s\n' "$logged" "${addr:--}" "${items:--}" "$key" "${unit:-missing}"
REMOTE
}

fleet_addr=$(grep -o 'sync_address = "[^"]*"' "$ROOT/modules/shell/atuin.nix" 2>/dev/null | cut -d'"' -f2)
fail=0 ok=0 skip=0 warn=0

printf '%-14s %-8s %-26s %-7s %s\n' HOST STATE SYNC_ADDRESS ITEMS UNIT
while IFS=$'\t' read -r key target lan; do
  [ -n "$key" ] || continue
  line="" tried=""
  for t in "$target" "${fqdn[$key]:-}" "$lan"; do
    [ -n "$t" ] || continue
    [ "$t" = "$tried" ] && continue
    tried=$t
    line=$(probe "$t")
    [ -n "$line" ] && break
  done
  if [ -z "$line" ]; then
    printf '%-14s %-8s %s\n' "$key" SKIP "unreachable"
    skip=$((skip + 1))
    [ "$strict" = 1 ] && fail=$((fail + 1))
    continue
  fi
  IFS=$'\t' read -r present logged addr items _key unit <<<"$line"

  state=ok
  note=""
  if [ "$present" = absent ]; then
    state=absent note="no atuin binary — rebuild this host"
  elif [ "$logged" != yes ]; then
    state=no-login note="no session — bootstrap this host"
  elif [ -z "$addr" ] || [ "$addr" = - ]; then
    state=no-addr note="config has no sync_address — rebuild this host"
  elif [[ "$addr" == *api.atuin.sh* ]]; then
    state=public note="sync_address is the public server — the flake did not set it"
  fi

  if [ "$state" != ok ]; then
    fail=$((fail + 1))
  elif [ "$unit" = missing ] || [ "$unit" = disabled ]; then
    # The unit is recovery, not login: state survives it. Named so the drift from
    # the current generation stays visible without failing a converged host.
    state=ok-nounit note="atuin-auto-login $unit — rebuild to install it"
    warn=$((warn + 1))
    ok=$((ok + 1))
  else
    ok=$((ok + 1))
  fi

  printf '%-14s %-8s %-26s %-7s %s\n' "$key" "$state" "${addr:--}" "${items:--}" "${unit:--}"
  [ -n "$note" ] && printf '%-14s %s\n' "" "$note"
done <<<"$hosts"

printf 'atuin: %d ok, %d failed, %d skipped' "$ok" "$fail" "$skip"
[ "$warn" -gt 0 ] && printf ', %d without the auto-login unit' "$warn"
printf '\n'

if [ "$fail" -gt 0 ]; then
  printf 'fix one host:  ssh <host> "bash -s" < %s/atuin-bootstrap.sh\n' "$here" >&2
  [ -n "$fleet_addr" ] && printf 'fleet address: %s (modules/shell/atuin.nix)\n' "$fleet_addr" >&2
  exit 1
fi
exit 0
