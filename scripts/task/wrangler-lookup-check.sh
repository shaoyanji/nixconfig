#!/usr/bin/env bash
# wrangler-lookup-check.sh — the publish path can find a runnable wrangler by
# itself.
#
# `pages-deploy.sh` reaches Cloudflare only through wrangler.sh, so a lookup that
# fails is a publish that fails after its build has already succeeded. The case
# that happened (2026-11-28, CV ATS): the store held a working wrangler, the
# script asked nixpkgs instead, and that evaluation refused over the network. So
# the leg that matters here stubs `nix` to fail and requires the answer anyway.
#
# The other two legs cover what a deploy also lacks: wrangler on PATH (a symlink
# elsewhere must win over the store copy) and a working `sops` (the token must
# not be read to find a binary, but a real run must still stop when it cannot be).
#
# External state, like `checks:images` on a missing asset root: where nothing is
# realised and nixpkgs cannot be reached, the gate says so and exits 0 after the
# legs that always hold.
#
# Exit 0 all legs held, 1 a leg failed.
set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo/scripts/task/wrangler.sh"
bash_bin=${BASH:-$(command -v bash)}
work=$(mktemp -d "${TMPDIR:-/tmp}/wrangler-lookup.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/no-nix" "$work/no-sops" "$work/path-bin" "$work/override"
printf '#!/bin/sh\necho "nix: stubbed, refusing on purpose" >&2\nexit 1\n' >"$work/no-nix/nix"
printf '#!/bin/sh\necho "sops: stubbed, refusing on purpose" >&2\nexit 1\n' >"$work/no-sops/sops"
chmod +x "$work/no-nix/nix" "$work/no-sops/sops"

fails=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

store_copy=$(ls -d /nix/store/*-wrangler-[0-9]*/bin/wrangler 2>/dev/null | sort -V | tail -1 || true)
bin=$(env -u WRANGLER "$bash_bin" "$script" --which 2>/dev/null || true)
if [ -z "$bin" ]; then
  # No answer while the store holds one is the bug, not a missing prerequisite: a
  # lookup that asks the network for what is already on disk is exactly how the
  # 2026-11-28 publish died.
  if [ -n "$store_copy" ]; then
    bad "$store_copy is in the store but the script did not find it"
  else
    printf 'skip nothing realised here (realise one: nix shell nixpkgs#wrangler)\n'
  fi
else
  if [ -x "$bin" ]; then
    ok "--which resolved an executable: $bin"
  else
    bad "--which printed $bin, which is not executable"
  fi
  version=$("$bin" --version 2>/dev/null | tr -d '[:space:]' || true)
  case "$version" in
    [0-9]*.[0-9]*) ok "the resolved binary runs: $version" ;;
    *) bad "the resolved binary printed no version (got '${version}')" ;;
  esac
  if [ "$(env -u WRANGLER "$bash_bin" "$script" --which 2>/dev/null)" = "$bin" ]; then
    ok "two lookups agree"
  else
    bad "two lookups disagreed"
  fi
  if [ "$(WRANGLER="$bin" "$bash_bin" "$script" --which 2>/dev/null)" = "$bin" ]; then
    ok "WRANGLER is honoured"
  else
    bad "WRANGLER was not honoured"
  fi
fi

# The 2026-11-28 failure: a realised copy in the store, and nix unable to answer.
if [ -n "$store_copy" ]; then
  if PATH="$work/no-nix:$PATH" env -u WRANGLER "$bash_bin" "$script" --which 2>/dev/null | grep -q .; then
    ok "a realised store copy resolves while nix refuses"
  else
    bad "a realised store copy was not enough when nix refused"
  fi
fi

if [ -n "$bin" ]; then
  # A copy that is not the store path proves the precedence, not the answer.
  ln -sf "$bin" "$work/path-bin/wrangler"
  if [ "$(PATH="$work/path-bin:$PATH" "$bash_bin" "$script" --which 2>/dev/null)" = "$work/path-bin/wrangler" ]; then
    ok "PATH wins over the store copy"
  else
    bad "a wrangler on PATH was not preferred over the store copy"
  fi

  # Finding a binary must not need the token, but running it must.
  if PATH="$work/no-sops:$PATH" "$bash_bin" "$script" --which >/dev/null 2>&1; then
    ok "--which needs no sops"
  else
    bad "--which refused when sops was unavailable"
  fi
  if out=$(PATH="$work/no-sops:$PATH" "$bash_bin" "$script" --version 2>&1); then
    bad "a real run proceeded with sops refusing"
  else
    case "$out" in
      *stubbed*) ok "a real run stops when the token cannot be read" ;;
      *) bad "a real run failed for a reason other than the token: ${out}" ;;
    esac
  fi
fi

# An explicit wrong path is a claim about which binary to use; falling back would
# publish with something else and never say so.
if WRANGLER="$work/override/wrangler" "$bash_bin" "$script" --which >/dev/null 2>&1; then
  bad "a WRANGLER that does not exist was accepted"
else
  ok "a WRANGLER that does not exist is refused, not quietly replaced"
fi

if [ "$fails" -gt 0 ]; then
  printf '\nwrangler-lookup-check: %d leg(s) failed\n' "$fails" >&2
  exit 1
fi
printf '\nwrangler-lookup-check: the publish path resolves wrangler on its own\n'
