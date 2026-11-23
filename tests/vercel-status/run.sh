#!/usr/bin/env bash
# Fixture for the Vercel fleet-status outlet (vercel/).
#
# The private side of the design is exactly one function — /api/ops — and its
# whole contract is "fail closed": no env → 503, no creds → 401 with a
# challenge, wrong creds → 401, and only correct creds proceed to the Edge
# Config read. The public probe is an allowlist — unknown names must die at
# 400 before any fetch, or it is an open proxy. smoke.mjs asserts both, plus
# the dead-endpoint probe shape, all without leaving loopback.
#
# Exit: 0 all cases pass, 1 a case failed, 2 fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

for f in vercel/vercel.json vercel/index.html vercel/ops.html \
         vercel/api/check.js vercel/api/ops.js; do
  [ -f "$repo/$f" ] || { echo "fixture: $f missing" >&2; exit 2; }
done
jq -e . "$repo/vercel/vercel.json" >/dev/null || { echo "fixture: vercel.json invalid" >&2; exit 2; }

if ! command -v node >/dev/null 2>&1; then
  echo "fixture: node not on PATH" >&2
  exit 2
fi
node "$here/smoke.mjs"
