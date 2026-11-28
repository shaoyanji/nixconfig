#!/usr/bin/env bash
# checks:resolver:loopback — the tailnet zone must never answer frieren.lan
# with a host-local loopback.
#
# pi-hole answers its own name with the address of the interface the query
# arrived on. The tailnet anycast address is bound on lo, so a tailnet client
# asking the anycast resolver for frieren.lan used to get 127.0.0.1 — an answer
# that means the CLIENT'S OWN loopback, not the server. Measured live
# 2026-11-27: @10.99.0.53 frieren.lan -> 127.0.0.1 while the same query to the
# LAN address answered 192.168.3.25. The fix pins dns.reply.host in the
# resolver module; this gate is what proves the pin keeps holding.
#
# RESOLVERS / ZONE override the probe targets (fixtures). A 127/8 or empty
# answer from a tailnet endpoint is a failure; anything else is an answer a
# tailnet client can actually use.
set -euo pipefail

RESOLVERS=${RESOLVERS:-"10.99.0.53"}
ZONE=${ZONE:-frieren.lan}

failed=""
nfailed=0
for ep in $RESOLVERS; do
  answer=$(dig +time=2 +tries=1 "@$ep" "$ZONE" A +short 2>/dev/null | head -1 || true)
  case "$answer" in
    127.* | ::1 | "")
      printf 'resolver-loopback: FAIL: %s answers %s with %s — a tailnet client cannot use a host-local answer\n' "$ep" "$ZONE" "${answer:-<empty>}" >&2
      failed="$failed $ep"
      nfailed=$((nfailed + 1))
      ;;
    *)
      printf 'resolver-loopback: %s answers %s -> %s\n' "$ep" "$ZONE" "$answer"
      ;;
  esac
done

if [ -n "$failed" ]; then
  printf 'resolver-loopback: FAIL: %s endpoint(s) return loopback:%s\n' "$nfailed" "$failed" >&2
  exit 1
fi
printf 'resolver-loopback: PASS: no tailnet endpoint answers loopback\n'
