#!/usr/bin/env bash
# Fixture for the Vercel fleet-status outlet (vercel/).
#
# The public probe /api/check must stay an allowlist — unknown names die at
# 400 before any fetch, otherwise it is an open proxy. The page must not ship
# or reference any gated store/token machinery: private ops telemetry stays
# on the tailnet by design. smoke.mjs asserts both without leaving loopback.
#
# Exit: 0 all cases pass, 1 a case failed, 2 fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

for f in vercel/vercel.json vercel/index.html vercel/api/check.js; do
  [ -f "$repo/$f" ] || { echo "fixture: $f missing" >&2; exit 2; }
done
jq -e . "$repo/vercel/vercel.json" >/dev/null || { echo "fixture: vercel.json invalid" >&2; exit 2; }

if ! command -v node >/dev/null 2>&1; then
  echo "fixture: node not on PATH" >&2
  exit 2
fi
node "$here/smoke.mjs"
