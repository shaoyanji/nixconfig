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
# WHERE THE BINARY COMES FROM, in order: `WRANGLER`, PATH, the store copy that is
# already realised, then a nixpkgs evaluation. The eval is last because it is the
# only leg that can fail for a reason the deploy has nothing to do with — it
# resolves `nixpkgs` through the flake registry over the network, and on
# 2026-11-28 the CV ATS publish died there while the store held a working
# 4.156.0. The store already answers "where is wrangler"; asking nixpkgs first
# made a local question look like a remote one.
#
# `--which` prints the resolved binary and reads no secret, so the lookup can be
# gated without an age key.
#
# Usage: wrangler.sh [--which] <wrangler args...>
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"

resolve_wrangler() {
  if [ -n "${WRANGLER:-}" ]; then
    if [ ! -x "$WRANGLER" ]; then
      echo "wrangler.sh: WRANGLER=$WRANGLER is not executable" >&2
      return 1
    fi
    printf '%s\n' "$WRANGLER"
    return 0
  fi

  local found
  found=$(command -v wrangler 2>/dev/null || true)
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi

  # Newest realised copy wins; the glob is filtered to versioned directories so
  # `wrangler-pnpm-deps` cannot match.
  found=$(ls -d /nix/store/*-wrangler-[0-9]*/bin/wrangler 2>/dev/null | sort -V | tail -1 || true)
  if [ -n "$found" ] && [ -x "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi

  # Last leg. An evaluation can name a path that was never built, so the build
  # follows it, and both write their stderr to one file that the failure prints:
  # the old message swallowed the reason and so read as "nix is broken".
  local err out
  err=$(mktemp "${TMPDIR:-/tmp}/wrangler-lookup.XXXXXX")
  if out=$(nix eval --raw nixpkgs#wrangler.outPath 2>"$err") && [ -x "$out/bin/wrangler" ]; then
    rm -f "$err"
    printf '%s\n' "$out/bin/wrangler"
    return 0
  fi
  if out=$(nix build --no-link --print-out-paths nixpkgs#wrangler 2>>"$err" | tail -1) && [ -x "$out/bin/wrangler" ]; then
    rm -f "$err"
    printf '%s\n' "$out/bin/wrangler"
    return 0
  fi
  echo "wrangler.sh: nothing from WRANGLER, PATH, the store, or nixpkgs; nix last said:" >&2
  tail -5 "$err" | sed 's/^/  /' >&2
  rm -f "$err"
  return 1
}

if [ "${1:-}" = "--which" ]; then
  resolve_wrangler
  exit 0
fi

secrets=$(apikeys_file) || exit 1

token="$(sops -d --extract '["CLOUDFLARE"]["API"]["TOKEN"]' "$secrets")"
if [ -z "$token" ]; then
  echo "wrangler.sh: CLOUDFLARE.API.TOKEN is empty" >&2
  exit 1
fi
export CLOUDFLARE_API_TOKEN="$token"

bin=$(resolve_wrangler)
exec "$bin" "$@"
