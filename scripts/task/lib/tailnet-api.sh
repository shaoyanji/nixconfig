#!/usr/bin/env bash
# tailnet-api.sh — resolve a Tailscale API bearer token. Sourced, not executed.
#
# Two callers need this (route approval, policy file), and the resolution order
# is the whole point of the file:
#
#   1. TAILSCALE_API_TOKEN  — a write-capable token passed in for one command.
#   2. TAILSCALE.API.KEY    — the same thing, from sops (private submodule).
#   3. TAILSCALE.CLIENT.*   — the fleet OAuth client, exchanged for a token.
#
# Step 3 currently yields scope `all:read`: enough to REPORT, not to approve or
# post a policy (the API answers 403 "calling actor does not have enough
# permissions"). Tailscale scopes are per-operation, so the write form is a
# credential with the `policy_file` scope (admin console → Trust credentials).
# Recreate the OAuth client with that scope and update TAILSCALE.CLIENT in sops —
# no code change: this function starts using it the moment the scope exists.
#
# Tailscale has no API for minting API keys or editing OAuth clients, so the
# credential itself is a console step by construction. Only the approval is not.
#
# Usage:  source "$(dirname "$0")/lib/tailnet-api.sh"
#         token="$(tailnet_token)" || exit 2

tailnet_api_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tailnet_api_secrets="$tailnet_api_repo/modules/secrets/apikeys.yaml"

# Prints the token on stdout, diagnostics on stderr. Returns 2 when there is no
# usable credential (callers map that to their own "cannot query" exit code).
tailnet_token() {
  if [ -n "${TAILSCALE_API_TOKEN:-}" ]; then
    printf '%s\n' "$TAILSCALE_API_TOKEN"
    return 0
  fi

  if [ ! -f "$tailnet_api_secrets" ]; then
    echo "no TAILSCALE_API_TOKEN and $tailnet_api_secrets is missing (is the modules/secrets submodule checked out?)" >&2
    return 2
  fi

  local key
  key="$(sops -d --extract '["TAILSCALE"]["API"]["KEY"]' "$tailnet_api_secrets" 2>/dev/null || true)"
  if [ -n "$key" ]; then
    printf '%s\n' "$key"
    return 0
  fi

  local client_id client_secret token
  client_id="$(sops -d --extract '["TAILSCALE"]["CLIENT"]["ID"]' "$tailnet_api_secrets" 2>/dev/null || true)"
  client_secret="$(sops -d --extract '["TAILSCALE"]["CLIENT"]["SECRET"]' "$tailnet_api_secrets" 2>/dev/null || true)"
  if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
    echo "neither TAILSCALE.API.KEY nor TAILSCALE.CLIENT.ID/SECRET is readable from sops" >&2
    return 2
  fi

  token="$(curl -sS -m 20 -X POST "https://api.tailscale.com/api/v2/oauth/token" \
    -d "grant_type=client_credentials" \
    -d "client_id=$client_id" \
    -d "client_secret=$client_secret" | jq -r '.access_token // empty' 2>/dev/null)"
  if [ -z "$token" ]; then
    echo "OAuth token exchange failed (TAILSCALE.CLIENT.ID/SECRET rejected?)" >&2
    return 2
  fi
  printf '%s\n' "$token"
}
