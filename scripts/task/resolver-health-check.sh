#!/usr/bin/env bash
# checks:resolver:health — probe the resolver endpoints clients actually use.
#
# Note resolver-independence (OPEN, 2026-10-19): a health probe can ship before
# full client-side fallback exists. The failover design since landed — LAN VIP
# 192.168.3.50 (VRRP frieren/minyx) and tailnet anycast 10.99.0.53 (frieren +
# delphi, docs/dns-failover.md) — but nothing in the check surface proves the
# endpoints answer. Sentinel watches hosts; this watches the service a client
# depends on, which is exactly the layer a failover is supposed to hide.
#
# A probe is red only when the endpoint itself stops answering — the failover
# doing its job (VIP moves to minyx, anycast moves to delphi) is invisible here
# by design, because it is invisible to clients by design.
#
# RESOLVERS overrides the endpoint list (fixture proof); ZONE overrides the
# query name. dig's own rc is captured before any pipe — a pipe through head
# would mask it.
set -euo pipefail

RESOLVERS=${RESOLVERS:-"192.168.3.50 10.99.0.53"}
ZONE=${ZONE:-frieren.lan}

failed=""
nfailed=0
for ep in $RESOLVERS; do
  if out=$(dig +time=2 +tries=1 "@$ep" "$ZONE" A +short 2>/dev/null) && [ -n "$out" ]; then
    printf 'resolver-health: %s answers %s -> %s\n' "$ep" "$ZONE" "$(printf '%s' "$out" | head -1)"
  else
    printf 'resolver-health: FAIL: %s does not answer %s\n' "$ep" "$ZONE" >&2
    failed="$failed $ep"
    nfailed=$((nfailed + 1))
  fi
done

if [ -n "$failed" ]; then
  printf 'resolver-health: FAIL: %s resolver endpoint(s) dead:%s\n' "$nfailed" "$failed" >&2
  exit 1
fi
printf 'resolver-health: PASS: every resolver endpoint answers\n'
