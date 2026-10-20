#!/usr/bin/env bash
# tailnet-routes.sh — advertised vs APPROVED subnet routes, per device.
#
# WHY THIS EXISTS: `tailscale set --advertise-routes` and "the route is in force"
# are two different facts. Advertising only records an OFFER; Tailscale serves an
# advertised subnet route only after it is approved (admin console, or the API),
# and `tailscale status` on the router shows the offer either way. So a resolver
# pair, a VLAN gateway or an exit node can look configured on every host while
# carrying zero traffic, and nothing in Nix can notice — approval is tailnet
# state, not host state. That is exactly how 10.99.0.53 sat advertised-but-dead
# on both frieren and delphi.
#
# Credentials: shared with tailnet-policy.sh through lib/tailnet-api.sh — an
# explicit TAILSCALE_API_TOKEN, else TAILSCALE.API.KEY from sops, else the fleet
# OAuth client, whose scope is `all:read`: enough to REPORT and not enough to
# APPROVE (the API answers 403 "calling actor does not have enough permissions").
# Widening that client's scopes needs no new secret; --approve starts working the
# moment it changes.
#
# Prefer `autoApprovers` in the policy file over approving by hand — that is what
# stops a new host needing this command at all: `task ops:tailnet:policy`.
#
# Usage:
#   tailnet-routes.sh                     # report; exit 1 if any route is unapproved
#   tailnet-routes.sh --approve <device>  # approve ALL advertised routes on <device>
#
# Exit: 0 = every advertised route is approved (or nothing is advertised);
#       1 = divergence found (report) / the approve call failed;
#       2 = no usable credential or the API could not be read.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
api="https://api.tailscale.com/api/v2"
# shellcheck source=lib/tailnet-api.sh
source "$here/lib/tailnet-api.sh"

mode="report"
device=""
case "${1:-}" in
  --approve)
    mode="approve"
    device="${2:-}"
    if [ -z "$device" ]; then
      echo "tailnet-routes.sh: --approve needs a device name (as it appears in the tailnet)" >&2
      exit 1
    fi
    ;;
  "" | --report) ;;
  *)
    echo "tailnet-routes.sh: unknown argument '$1' (use --report or --approve <device>)" >&2
    exit 1
    ;;
esac

token="$(tailnet_token)" || exit 2

auth="Authorization: Bearer $token"

devices="$(curl -sS -m 20 -H "$auth" "$api/tailnet/-/devices?fields=all")"
if ! jq -e '.devices' >/dev/null 2>&1 <<<"$devices"; then
  echo "tailnet-routes.sh: could not read the device list (scope too narrow, or not a tailnet API token?)" >&2
  echo "$devices" | head -3 >&2
  exit 2
fi

# The comma-joined list is what the API returns; a route is in force only when it
# appears in enabledRoutes. The subtraction is done in jq so one missing space
# cannot make an approved route look missing.
report() {
  jq -r '
    .devices
    | map(select((.advertisedRoutes // []) | length > 0))
    | map({
        name,
        id,
        advertised: .advertisedRoutes,
        unapproved: ((.advertisedRoutes // []) - (.enabledRoutes // []))
      })
    | if length == 0 then "no device advertises a route (nothing to approve)"
      else
        (.[] | "\(.name)\t\(.id)\tOFFERED  \(.advertised | join(","))\tAPPROVED \(((.advertised - .unapproved) | if length == 0 then "-" else join(",") end))"
             + (if (.unapproved | length) > 0 then "\tUNAPPROVED \(.unapproved | join(","))" else "" end))
      end' <<<"$devices"
}

if [ "$mode" = "report" ]; then
  if command -v column >/dev/null; then report | column -t -s $'\t'; else report; fi
  pending="$(jq '[.devices[] | ((.advertisedRoutes // []) - (.enabledRoutes // []))] | add // [] | length' <<<"$devices")"
  if [ "$pending" -gt 0 ]; then
    echo
    echo "$pending advertised route(s) are NOT in force. Approve them in the admin console"
    echo "(Machines -> <device> -> Edit route settings) or with a write-scoped token:"
    echo "  TAILSCALE_API_TOKEN=... bash scripts/task/tailnet-routes.sh --approve <device>"
    exit 1
  fi
  exit 0
fi

# --- approve -----------------------------------------------------------------
# `first(...)`, not `head -1`: closing the pipe early would SIGPIPE jq and
# take the script down under `set -o pipefail`.
target="$(jq -c --arg n "$device" \
  '.devices | map(select(.name == $n or (.name | startswith($n + ".")))) | first // empty | {id, name, routes: (.advertisedRoutes // [])}' <<<"$devices")"
if [ -z "$target" ]; then
  echo "tailnet-routes.sh: no device matching '$device' advertises a route" >&2
  exit 1
fi
id="$(jq -r '.id' <<<"$target")"
name="$(jq -r '.name' <<<"$target")"
routes="$(jq -c '.routes' <<<"$target")"
echo "approving on $name ($id): $routes"
code="$(curl -sS -m 20 -o /tmp/tailnet-approve.out -w '%{http_code}' \
  -X POST -H "$auth" -H 'Content-Type: application/json' \
  "$api/device/$id/routes" -d "{\"routes\":$routes}")"
if [ "$code" != "200" ]; then
  echo "tailnet-routes.sh: approve failed HTTP $code: $(head -c 300 /tmp/tailnet-approve.out)" >&2
  echo "  (403 here means the credential is read-only — see the header comment)" >&2
  exit 1
fi
jq -r '"now approved: " + ((.enabledRoutes // []) | join(","))' /tmp/tailnet-approve.out
