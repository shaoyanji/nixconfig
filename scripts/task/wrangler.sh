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
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"
secrets=$(apikeys_file)

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

# wrangler is a dev tool and is not on every host's PATH, so a deploy that works
# from a task shell fell over with `exec: wrangler: not found` (2026-11-22,
# images:publish after a plate round). Ask Nix for the path the flake resolves
# instead of requiring a profile entry.
bin=$(command -v wrangler 2>/dev/null || true)
if [ -z "$bin" ]; then
  out=$(nix eval --raw nixpkgs#wrangler.outPath 2>/dev/null || true)
  [ -n "$out" ] && bin="$out/bin/wrangler"
fi
if [ -z "$bin" ] || [ ! -x "$bin" ]; then
  echo "wrangler.sh: wrangler is not on PATH and nix could not resolve it" >&2
  exit 1
fi

exec "$bin" "$@"
