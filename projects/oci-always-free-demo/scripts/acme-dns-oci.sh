#!/usr/bin/env bash
# ACME DNS-01 hook for the ACME provider's exec challenge solver.
#
# The provider calls this as: acme-dns-oci.sh present|cleanup <fqdn> <value>
# and waits for the TXT record to be visible before asking the CA to validate.
#
# Environment (from acme_certificate.dns_challenge.config):
#   OCI_DNS_ZONE         required, public zone name, e.g. example.com
#   OCI_DNS_COMPARTMENT  only needed for private zones
#   OCI_DNS_TTL          default 60
#
# OCI replaces a whole RRSet per update and stores TXT values quoted, so this
# merges the existing values on present and removes only its own on cleanup.
# Needs: oci CLI authenticated with DNS rights, jq.
set -euo pipefail

action="${1:?usage: acme-dns-oci.sh present|cleanup <fqdn> <value>}"
fqdn="${2:?fqdn}"
value="${3:?value}"
zone="${OCI_DNS_ZONE:?OCI_DNS_ZONE must be the OCI DNS zone name}"
ttl="${OCI_DNS_TTL:-60}"
domain="${fqdn%.}"

for bin in oci jq; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "acme-dns-oci: missing required tool: $bin" >&2
    exit 1
  }
done

scope=()
if [[ -n "${OCI_DNS_COMPARTMENT:-}" ]]; then
  scope=(--compartment-id "$OCI_DNS_COMPARTMENT")
fi

current="$(oci dns record rrset get \
  --zone-name-or-id "$zone" \
  --domain "$domain" \
  --rtype TXT \
  "${scope[@]}" \
  --query 'data.items[].rdata' \
  --raw-output 2>/dev/null | tr -d '"' || true)"

case "$action" in
  present)
    values="$(printf '%s\n%s\n' "$current" "$value" | awk 'NF' | sort -u)"
    ;;
  cleanup)
    values="$(printf '%s\n' "$current" | awk -v skip="$value" 'NF && $0 != skip')"
    ;;
  *)
    echo "acme-dns-oci: unknown action $action" >&2
    exit 1
    ;;
esac

if [[ -z "$values" ]]; then
  oci dns record rrset delete \
    --zone-name-or-id "$zone" \
    --domain "$domain" \
    --rtype TXT \
    "${scope[@]}" \
    --force >/dev/null 2>&1 || true
  exit 0
fi

items="$(printf '%s\n' "$values" | jq -R . | jq -s --arg domain "$domain" --argjson ttl "$ttl" \
  '{items: map({domain: $domain, rtype: "TXT", rdata: ("\"" + . + "\""), ttl: $ttl})}')"

oci dns record rrset update \
  --zone-name-or-id "$zone" \
  --domain "$domain" \
  --rtype TXT \
  "${scope[@]}" \
  --items "$items" \
  --force >/dev/null

echo "acme-dns-oci: $action $domain -> $values" >&2
