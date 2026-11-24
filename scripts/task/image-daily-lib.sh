#!/usr/bin/env bash
# image-daily-lib.sh — shared vocabulary for the image-daily command family:
# environment resolution, the ledger, the brief book. Sourced, never run —
# every image-daily-<cmd>.sh sources this first, and `image_daily_cli` here is
# how they reach the Go tool the spend/publish machinery lives in now.
set -euo pipefail

# A checkout resolves its own root. A store-baked copy of this one file has no
# `../..`, so a caller that ships it into a store path must pass REPO; without it
# this resolved to `/` and every `$repo/lib/...` became `//lib/...`. Measured
# 2026-11-15..17: four slots, twenty passes, every one dead in four seconds.
repo=${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
BRIEFS=${BRIEFS:-$repo/lib/image-daily/briefs.json}
# The pool's media tree is root:root 0770 (/Volumes/data/media), so a generated
# asset cannot live there without sudo. pics/generated is the writable, devji-owned
# neighbour. A Linux host has no /Volumes at all, and the shard still has to run
# there: delphi publishes the same bank from a home directory.
if [ -z "${IMAGES_ROOT:-}" ]; then
  if [ -d /Volumes/data/pics ]; then
    IMAGES_ROOT=/Volumes/data/pics/generated
  else
    IMAGES_ROOT=$HOME/Pictures/generated
  fi
fi
LEDGER=$IMAGES_ROOT/ledger.jsonl
STAGE=$IMAGES_ROOT/.judge

die() {
  echo "image-daily: $*" >&2
  exit 1
}

# stderr, not stdout: `attempt` is read as `file=$(attempt …)`, so a log line on
# stdout becomes part of the path. Measured 2026-11-10: a 429 retry inside a
# capture recorded "image-daily: wall-char-stark: rate limited, waiting 120s\n/path"
# as the plate, and the next publish tried to copy that string.

say() { echo "image-daily: $*" >&2; }

# Refuse a root that cannot be one. The alternative is what happened: nothing to
# read, a four-second exit 1, and a green timer that looks like a spent allowance.
[ -f "$BRIEFS" ] ||
  die "no briefs at $BRIEFS — this script resolved its root to '$repo'; set REPO to the checkout root"

need() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "$c is not on PATH"
  done
}

today() { date +%Y-%m-%d; }

epoch() { date -d "$1" +%s 2>/dev/null; }

# --- ledger and queue ---------------------------------------------------------
# One row per generation attempt. The ledger is append-only: a re-roll is a new
# row, never an edit, so the re-roll rate is readable later. record, last_keep,
# last_attempt, strikes and is_parked are `image-daily record`/`due`/`parked`
# internals in tools/os — the why comments moved with the code.
PARK_AFTER=${PARK_AFTER:-3}

# due, guard, lanes, budget, setting and remaining are `image-daily due|guard|
# lanes|budget|setting|remaining` in tools/os; LANES_ORDER lives there as
# lanesDefault, and `LANES="wall site"` narrows a subcommand the same way.

# Where the Go tool lives. A slot's PATH closure already carries it; a hand run
# resolves it from the checkout with a one-off nix build, the way
# site-target.sh resolves static-serve. IMAGE_DAILY_BIN wins for tests.
image_daily_cli() {
  if [ -n "${IMAGE_DAILY_BIN:-}" ]; then
    printf '%s\n' "$IMAGE_DAILY_BIN"
    return 0
  fi
  if command -v image-daily >/dev/null 2>&1; then
    command -v image-daily
    return 0
  fi
  local out
  out=$(cd "$repo" && nix build --builders "" --no-link --print-out-paths '.?submodules=1#cli.image.daily' 2>/dev/null | tail -1)
  [ -n "$out" ] || die "image-daily CLI missing: not on PATH and .#cli.image.daily did not build"
  printf '%s/bin/image-daily\n' "$out"
}
