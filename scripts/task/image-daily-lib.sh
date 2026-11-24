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
# Words a slug carries for grammar rather than meaning. Tags are derived from the
# public id, so this list is the only editorial judgement in the manifest.
TAG_STOP='["the","and","for","new","post","with","its","this","that","them","they","when","where","which","while","your","you","our","not","one","own","out","from","into","than","then","was","were","have","has","had","can","did","get","got","just","like","more","most","about","after","before","how","what","why","all","but","any","two","via","now","yet","also","still","even","only","such","some","been","being","both","each","here","there","these","those","under","very","will","would","should","much","many","other","over","same","part"]'
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

# --- ledger -----------------------------------------------------------------
# One row per generation attempt. The ledger is append-only: a re-roll is a new
# row, never an edit, so the re-roll rate is readable later.

# record is `image-daily record` in tools/os.

# The last day a brief was accepted at its current revision, empty when it never
# was. A rewritten prompt is a new revision: the plate the old sentence made must
# not count as freshness, or a fixed brief keeps its defect for a whole `every`.

# The last day a brief at this revision spent an image, whatever the verdict.

# Images a brief has spent since its last keep, counting only the verdicts that
# judge the prompt: `unjudged` and `failed` are the judge or the pool falling
# over, and repeating those would park a brief for somebody else's outage.

# A brief that never earns a keep is parked: it returns after PARK_DAYS with a
# clean slate, so a prompt the judge refuses costs a few plates a week instead of
# every slot. Measured 2026-11-10: eight character briefs, never kept, re-rendered
# twice per slot for weeks — 16 to 20 images a slot, every slot.
PARK_AFTER=${PARK_AFTER:-3}
PARK_DAYS=${PARK_DAYS:-7}

# last_keep/last_attempt/strikes/is_parked are `image-daily due`/`parked` internals in tools/os — one ledger pass per call.

# --- the queue --------------------------------------------------------------
# TSV: id, lane, size, name, prompt, every, rev, expect — for the briefs that are
# due today. `expect` is what the plate must show, and it is the only field the
# judge can hold a name against: a keep verdict says the image answers the prompt,
# which it does when the prompt was the weak part. It stays last because tab is
# IFS whitespace and `read` collapses a run of it: an empty `expect` in any other
# position shifted every field after it.

# due is `image-daily due` in tools/os.

# A character plate needs the character described, not just named. The generator
# does not know these people, so `Fern, 4k, realistic, neumorphism` is an
# instruction to draw the word: on 2026-11-10 seven of eight such briefs came back
# as a fern leaf, a power symbol, a periodic-table tile, a sky, a dashboard, a
# devil and a settings row, and every one of them was judged `keep` because the
# judge was holding the same weak prompt. This refuses to spend on one again.

# briefs_guard is `image-daily guard` in tools/os.

# `LANES="wall site"` narrows any subcommand to a subset of the shard order.

# select_lanes is `image-daily lanes` in tools/os; LANES_ORDER lives there as lanesDefault.

# lane_budget/lane_setting are `image-daily budget` and `image-daily setting` in tools/os.

# The pool answers `remaining: "unlimited"` on a lifetime plan, and the real
# ceiling is then the hourly burst (429), not a day count. Translate it to a
# number the arithmetic can use; every caller already treats 0 as "stop".

# remaining is `image-daily remaining` in tools/os — same refresh-once retry, same unlimited translation.

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
