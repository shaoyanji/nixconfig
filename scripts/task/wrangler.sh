#!/usr/bin/env bash
# wrangler.sh — run wrangler with the Cloudflare API token from sops.
#
# WHY THIS EXISTS: `wrangler login` is an OAuth device grant whose token lives
# five minutes and is refreshed only with a TTY. In an unattended shell that is
# a dead end, and the error it produces ("set CLOUDFLARE_API_TOKEN") is the
# only thing that says so. The token already exists in sops at
# CLOUDFLARE.API.TOKEN, so every deploy path should read it there instead of
# depending on an interactive session.
#
# No rebuild is involved: sops decrypts at run time with the user's age key.
#
# Usage: wrangler.sh <wrangler args...>
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
secrets="$repo/modules/secrets/apikeys.yaml"

if [ ! -f "$secrets" ]; then
  echo "wrangler.sh: $secrets missing (is the modules/secrets submodule checked out?)" >&2
  exit 1
fi

token="$(sops -d --extract '["CLOUDFLARE"]["API"]["TOKEN"]' "$secrets")"
if [ -z "$token" ]; then
  echo "wrangler.sh: CLOUDFLARE.API.TOKEN is empty" >&2
  exit 1
fi
export CLOUDFLARE_API_TOKEN="$token"

exec wrangler "$@"
