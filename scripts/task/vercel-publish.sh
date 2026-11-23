#!/usr/bin/env bash
# Push this host's sentinel status snapshot into the Vercel ops zone.
#
# The snapshot lives at /var/lib/fleet-sentinel/www/status.json (written by
# fleet-sentinel-collect). It goes to the project's Edge Config store as item
# `status:<host>`, which /api/ops serves behind OPS_BASIC_AUTH. The store has
# no public URL — reads require the connection string — so the private
# telemetry stays gated end to end.
#
# Env (both required):
#   VERCEL_TOKEN          vercel.com/account/tokens — scope it to the project
#   VERCEL_EDGE_CONFIG_ID ecfg_… — Storage → Edge Configs → the store's id
#
# Usage: vercel-publish.sh [STATUS_JSON]   (default: the sentinel path)
#        DRY_RUN=1 prints the payload instead of PATCHing.
set -euo pipefail

STATUS_FILE="${1:-/var/lib/fleet-sentinel/www/status.json}"
HOST="$(hostname -s)"
KEY="status:${HOST}"

[ -r "$STATUS_FILE" ] || { echo "vercel-publish: no readable snapshot at $STATUS_FILE" >&2; exit 2; }
jq -e . "$STATUS_FILE" >/dev/null || { echo "vercel-publish: $STATUS_FILE is not valid JSON" >&2; exit 2; }

PAYLOAD="$(jq -nc --arg k "$KEY" --slurpfile v "$STATUS_FILE" \
  '{items:[{operation:"upsert",key:$k,value:$v[0]}]}')"

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "vercel-publish: DRY_RUN — would upsert $KEY:"
  jq -r '.items[0].value | keys_unsorted[]' <<<"$PAYLOAD" | sed 's/^/  /'
  exit 0
fi

: "${VERCEL_TOKEN:?set VERCEL_TOKEN (vercel.com/account/tokens)}"
: "${VERCEL_EDGE_CONFIG_ID:?set VERCEL_EDGE_CONFIG_ID (ecfg_…)}"

curl -fsS -X PATCH \
  "https://api.vercel.com/v1/edge-config/${VERCEL_EDGE_CONFIG_ID}/items" \
  -H "Authorization: Bearer ${VERCEL_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD"
echo
echo "vercel-publish: upserted $KEY ($(jq -c 'length' <<<"$PAYLOAD") bytes payload)"
