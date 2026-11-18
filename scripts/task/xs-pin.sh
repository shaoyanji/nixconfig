#!/usr/bin/env bash
# xs-pin.sh — keep the cablehead/xs release pin on the latest release.
#
# modules/services/agent-turns.nix serves the upstream prebuilt binary, so the pin is
# a version and one hash per architecture, both inline: the URL is built from the
# version, and splitting them across files is the drift the pin exists to prevent.
# Nothing recomputed it though — a release landed upstream and the store kept serving
# the previous one until someone noticed.
#
# So the release is a `[[pin]]` in lib/pins.toml. The pre-commit refresh runs this,
# and a newer release rewrites the version and BOTH hashes together, in the same
# commit as the bump. Hashes are only written after every tarball prefetches, so a
# half-updated pin (new version, old hash) cannot be produced by this script.
#
# The `[[pin]]` entry is not cosmetic: `pins-refresh.sh --check` compares the pinned
# file to HEAD, so a bump staged here and committed carries the file the gate read.
#
# XS_PIN=report prints drift and writes nothing (the opt-out for a host with a slow
# link or an upstream you do not want to follow unattended).
#
# Usage: xs-pin.sh            sync to the latest release
#        xs-pin.sh --verify   prefetch the PINNED version and compare its hashes
# Env:   XS_PIN=report · XS_REPO=cablehead/xs
# Exit:  0 in sync, bumped, or verified · 1 a release or hash could not be fetched
#        · 2 the pin could not be read
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
file="$root/modules/services/agent-turns.nix"
repo=${XS_REPO:-cablehead/xs}
mode=${1:-}

[ -f "$file" ] || { echo "xs-pin: no pin at $file" >&2; exit 2; }

pinned=$(sed -n '/pname = "cross-stream"/,/^  };/p' "$file" |
  sed -n 's/^ *version = "\([^"]*\)";/\1/p' | head -1)
[ -n "$pinned" ] || { echo "xs-pin: no version after pname = cross-stream in $file" >&2; exit 2; }

url_for() { # version arch
  printf 'https://github.com/%s/releases/download/v%s/cross-stream-v%s-linux-%s.tar.gz' \
    "$repo" "$1" "$1" "$2"
}

sri_for() { # version arch — prints the SRI hash, or fails
  local raw
  raw=$(nix-prefetch-url --type sha256 "$(url_for "$1" "$2")" 2>/dev/null) || return 1
  [ -n "$raw" ] || return 1
  if nix hash convert --hash-algo sha256 --to sri "$raw" 2>/dev/null; then
    return 0
  fi
  nix --extra-experimental-features nix-command hash to-sri --type sha256 "$raw" 2>/dev/null
}

pinned_hash() { # arch
  sed -n '/^  hashes = {/,/^  };/p' "$file" |
    sed -n "s/^ *$1 = \"\(.*\)\";/\1/p" | head -1
}

if [ "$mode" = --verify ]; then
  rc=0
  for arch in arm64 amd64; do
    want=$(pinned_hash "$arch")
    [ -n "$want" ] || { echo "xs-pin: no $arch hash in $file" >&2; rc=2; continue; }
    got=$(sri_for "$pinned" "$arch") || { echo "xs-pin: could not fetch $pinned/$arch" >&2; rc=1; continue; }
    if [ "$want" = "$got" ]; then
      printf 'ok    %-5s %s\n' "$arch" "$want"
    else
      printf 'DRIFT %-5s pinned %s, v%s is %s\n' "$arch" "$want" "$pinned" "$got"
      rc=1
    fi
  done
  exit "$rc"
fi

latest=$(curl -sSf --max-time 20 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null |
  jq -r '.tag_name // empty' | sed 's/^v//')
[ -n "$latest" ] || { echo "xs-pin: could not read the latest release of $repo" >&2; exit 1; }

if [ "$latest" = "$pinned" ]; then
  echo "xs-pin: $pinned is the latest release"
  exit 0
fi

if [ "${XS_PIN:-}" = report ]; then
  echo "xs-pin: $pinned pinned, $latest upstream — run without XS_PIN=report to bump"
  exit 0
fi

# Both hashes before either is written: a version with one stale hash fails only on
# that architecture, which is the build nobody runs until the deploy.
arm64=$(sri_for "$latest" arm64) || { echo "xs-pin: no arm64 asset for $latest" >&2; exit 1; }
amd64=$(sri_for "$latest" amd64) || { echo "xs-pin: no amd64 asset for $latest" >&2; exit 1; }

python3 - "$file" "$pinned" "$latest" "$arm64" "$amd64" <<'PY'
import re, sys
path, old, new, arm64, amd64 = sys.argv[1:6]
src = open(path).read()
i = src.index('pname = "cross-stream";')
head, tail = src[:i], src[i:]
needle = f'version = "{old}";'
assert needle in tail, "pinned version string not found in the cross-stream block"
tail = tail.replace(needle, f'version = "{new}";', 1)
for arch, value in (("arm64", arm64), ("amd64", amd64)):
    tail = re.sub(r'(\b%s = )"sha256-[^"]*"' % arch, lambda m: m.group(1) + '"' + value + '"', tail, count=1)
open(path, 'w').write(head + tail)
PY

echo "xs-pin: $pinned -> $latest (arm64, amd64 hashes rewritten)"
