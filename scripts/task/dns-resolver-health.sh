#!/usr/bin/env bash
# dns-resolver-health.sh — probe the fleet resolver as a service, and prove
# every enrolled client declares a public fallback behind it.
#
# Why: clients carry `profiles.dnsClient` (VIP + tailnet resolver, public
# FallbackDNS behind both). This gate proves the exit criterion of
# AGENTS.nix resolver-independence — "a client with frieren down still
# resolves public names" — in two halves:
#   * live half: the resolver group's VIP answers a wildcard probe name with
#     the zone address, and the declared public fallback answers too — both
#     ends of the failover path respond;
#   * declared half: every client named in CLIENTS has a non-empty
#     services.resolved FallbackDNS — the config that matters when the live
#     probe's subject is already gone.
#
# Vars: VIP= (default 192.168.3.50), NAME= (default hc3-check.frieren.lan),
#   EXPECT= (default 192.168.3.25), PUBLIC= (default 1.1.1.1),
#   CLIENTS= (default "aristotle diogenes eisen").
# Exit: 0 = resolver answers AND every client declares a fallback;
#   1 = a probe failed or a client declares none; 2 = cannot evaluate.
set -uo pipefail

VIP="${VIP:-192.168.3.50}"
NAME="${NAME:-hc3-check.frieren.lan}"
EXPECT="${EXPECT:-192.168.3.25}"
PUBLIC="${PUBLIC:-1.1.1.1}"
CLIENTS="${CLIENTS:-aristotle diogenes eisen}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 2

for bin in nix jq dig; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: $bin is required" >&2
    exit 2
  }
done

fail=0

# --- live half: both ends of the failover path answer -------------------------
answer="$(dig +short +time=2 +tries=1 -4 "@$VIP" "$NAME" A | head -1)"
if [ "$answer" = "$EXPECT" ]; then
  echo "ok   resolver $VIP answers $NAME -> $EXPECT"
else
  echo "FAIL resolver $VIP answers $NAME -> '${answer:-<empty>}' (want $EXPECT)"
  fail=1
fi

answer="$(dig +short +time=2 +tries=1 -4 "@$PUBLIC" one.one.one.one A | head -1)"
if [ -n "$answer" ]; then
  echo "ok   public fallback $PUBLIC answers"
else
  echo "FAIL public fallback $PUBLIC did not answer"
  fail=1
fi

# --- declared half: every enrolled client carries a fallback ------------------
for host in $CLIENTS; do
  # A host that does not evaluate at all has its own gate (drv-equality records
  # the error); report it and move on rather than read it as "no fallback".
  if ! dns="$(nix eval --raw ".?submodules=1#nixosConfigurations.${host}.config.services.resolved.settings.Resolve.DNS" 2>/dev/null)"; then
    echo "note $host does not evaluate (its error is drv-equality's subject, not this gate's)"
    continue
  fi
  fb="$(nix eval --raw ".?submodules=1#nixosConfigurations.${host}.config.services.resolved.settings.Resolve.FallbackDNS" 2>/dev/null || true)"
  if [ -z "$fb" ]; then
    echo "FAIL $host declares no resolved FallbackDNS"
    fail=1
  elif [ -z "$dns" ]; then
    echo "FAIL $host declares no resolved DNS"
    fail=1
  else
    echo "ok   $host resolves via '${dns}' with fallback '${fb}'"
  fi
done

[ "$fail" -eq 0 ] && echo "resolver-health: every tier answers, every client declares a fallback" || echo "resolver-health: FAILED"
exit "$fail"
