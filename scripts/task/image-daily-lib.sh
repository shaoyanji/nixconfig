#!/usr/bin/env bash
# image-daily-lib.sh — shared vocabulary for the image-daily command family:
# environment resolution, the ledger, the brief book. Sourced, never run —
# every image-daily-<cmd>.sh sources this first (image-daily-engine.sh does
# it for the commands that spend or publish).
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
LANES_ORDER=(site wall blog fleet badge)
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

record() { # day lane brief path verdict reason [prompt] [attempt] [rev]
  [ -d "$IMAGES_ROOT" ] || mkdir -p "$IMAGES_ROOT"
  jq -nc --arg ts "$(date -u +%FT%TZ)" --arg day "$1" --arg lane "$2" \
    --arg brief "$3" --arg path "$4" --arg verdict "$5" --arg reason "$6" \
    --arg prompt "${7:-}" --argjson attempt "${8:-1}" --argjson rev "${9:-1}" \
    '{ts: $ts, day: $day, lane: $lane, brief: $brief, path: $path,
      verdict: $verdict, reason: $reason, prompt: $prompt, attempt: $attempt,
      rev: $rev}' >>"$LEDGER"
}


# The last day a brief was accepted at its current revision, empty when it never
# was. A rewritten prompt is a new revision: the plate the old sentence made must
# not count as freshness, or a fixed brief keeps its defect for a whole `every`.

last_keep() { # id [rev]
  [ -f "$LEDGER" ] || return 0
  jq -r --arg id "$1" --argjson rev "${2:-1}" \
    'select(.brief == $id and .verdict == "keep" and (.rev // 1) == $rev) | .day' "$LEDGER" |
    sort | tail -1
}


# The last day a brief at this revision spent an image, whatever the verdict.

last_attempt() { # id [rev]
  [ -f "$LEDGER" ] || return 0
  jq -r --arg id "$1" --argjson rev "${2:-1}" \
    'select(.brief == $id and (.rev // 1) == $rev) | .day' "$LEDGER" | sort | tail -1
}


# Images a brief has spent since its last keep, counting only the verdicts that
# judge the prompt: `unjudged` and `failed` are the judge or the pool falling
# over, and repeating those would park a brief for somebody else's outage.

strikes() { # id [rev]
  [ -f "$LEDGER" ] || {
    echo 0
    return 0
  }
  jq -r --arg id "$1" --argjson rev "${2:-1}" \
    'select(.brief == $id and (.rev // 1) == $rev) | .verdict' "$LEDGER" |
    awk '/^keep$/{n=0; next} /^(reroll|reject)$/{n++} END{print n+0}'
}


# A brief that never earns a keep is parked: it returns after PARK_DAYS with a
# clean slate, so a prompt the judge refuses costs a few plates a week instead of
# every slot. Measured 2026-11-10: eight character briefs, never kept, re-rendered
# twice per slot for weeks — 16 to 20 images a slot, every slot.
PARK_AFTER=${PARK_AFTER:-3}
PARK_DAYS=${PARK_DAYS:-7}

is_parked() { # id [rev]
  [ "$(strikes "$1" "${2:-1}")" -ge "$PARK_AFTER" ] || return 1
  local tried
  tried=$(last_attempt "$1" "${2:-1}")
  [ -n "$tried" ] || return 1
  [ $((($(epoch "$(today)") - $(epoch "$tried")) / 86400)) -lt "$PARK_DAYS" ]
}


# --- the queue --------------------------------------------------------------
# TSV: id, lane, size, name, prompt, every, rev, expect — for the briefs that are
# due today. `expect` is what the plate must show, and it is the only field the
# judge can hold a name against: a keep verdict says the image answers the prompt,
# which it does when the prompt was the weak part. It stays last because tab is
# IFS whitespace and `read` collapses a run of it: an empty `expect` in any other
# position shifted every field after it.

due() {
  local filter=${1:-}
  jq -r '.briefs[] | [.id, .lane, .size, .name, .prompt, (.every | tostring), (.rev // 1), (.expect // "")] | @tsv' "$BRIEFS" |
    while IFS=$'\t' read -r id lane size name prompt every rev expect; do
      [ -n "$filter" ] && [ "$lane" != "$filter" ] && continue
      local last now last_s
      last=$(last_keep "$id" "$rev")
      now=$(epoch "$(today)")
      last_s=$(epoch "${last:-1970-01-01}")
      [ -n "$last" ] || last_s=0
      # FORCE=1 ignores the park, the same way it ignores freshness: a rewritten
      # prompt is exactly what a parked brief is waiting for.
      if [ "${FORCE:-0}" != "1" ] && is_parked "$id" "$rev"; then continue; fi
      # FORCE=1 re-renders a brief whose freshness promise has not expired. A plate
      # judged `keep` that still answered the wrong reading of its own name is the
      # case this exists for; narrow it with ONLY= so a forced pass replaces named
      # briefs and nothing else.
      if [ "${FORCE:-0}" = "1" ] || [ "$last_s" -eq 0 ] || [ $(((now - last_s) / 86400)) -ge "$every" ]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$lane" "$size" "$name" "$prompt" "$rev" "$expect"
      fi
    done
}


# A character plate needs the character described, not just named. The generator
# does not know these people, so `Fern, 4k, realistic, neumorphism` is an
# instruction to draw the word: on 2026-11-10 seven of eight such briefs came back
# as a fern leaf, a power symbol, a periodic-table tile, a sky, a dashboard, a
# devil and a settings row, and every one of them was judged `keep` because the
# judge was holding the same weak prompt. This refuses to spend on one again.

briefs_guard() {
  local id prompt expect words bad=0
  while IFS=$'\t' read -r id prompt expect words; do
    [ -n "$expect" ] || { say "briefs: $id has no expect line"; bad=1; }
    case "$prompt" in
      *anime*) ;;
      *) say "briefs: $id does not name the anime"; bad=1 ;;
    esac
    if [ "${words:-0}" -lt 25 ]; then
      say "briefs: $id prompt is ${words:-0} words — describe the character, not the name"
      bad=1
    fi
  done < <(jq -r '.briefs[] | select(.id | startswith("wall-char-"))
    | [.id, .prompt, (.expect // ""), ((.prompt | split(" ") | length) | tostring)] | @tsv' "$BRIEFS")
  # A badge is a profile picture, so the same rule holds: the prompt names the
  # subject and `expect` says what the plate must show. The 2026-11-10 batch sent
  # `Fern, 4k, realistic, neumorphism` and shipped a fern leaf, a power symbol and
  # a periodic-table tile, all judged `keep` against the same weak sentence.
  while IFS=$'\t' read -r id prompt expect words; do
    [ -n "$expect" ] || { say "briefs: $id has no expect line"; bad=1; }
    if [ "${words:-0}" -lt 25 ]; then
      say "briefs: $id prompt is ${words:-0} words — describe the subject, not the name"
      bad=1
    fi
  done < <(jq -r '.briefs[] | select(.id | startswith("badge-"))
    | [.id, .prompt, (.expect // ""), ((.prompt | split(" ") | length) | tostring)] | @tsv' "$BRIEFS")
  # The wall lane's intent is illustrated art with one clear subject, and the
  # judge holds every plate to that intent, not to the brief. A wall prompt that
  # names no style is therefore rendered as a photograph and refused at judging
  # time. Measured 2026-11-12: a 42-plate burst sent photographic sentences and
  # nine came back "photorealistic rather than illustrative" or "no focal point",
  # each refusal spending a second image. Style and focal point are stated in the
  # brief, so the drift never reaches the judge.
  while IFS=$'\t' read -r id prompt expect; do
    [ -n "$expect" ] || { say "briefs: $id has no expect line"; bad=1; }
    case "$prompt" in
      *illustration* | *illustrated* | *"cel-shaded"*) ;;
      *) say "briefs: $id names no illustrative style — the judge refuses a photographic plate"; bad=1 ;;
    esac
    case "$prompt" in
      *"one clear focal point"*) ;;
      *) say "briefs: $id names no focal point"; bad=1 ;;
    esac
  done < <(jq -r '.briefs[] | select(.id | startswith("wall-"))
    | [.id, .prompt, (.expect // "")] | @tsv' "$BRIEFS")
  return $bad
}


# `LANES="wall site"` narrows any subcommand to a subset of the shard order.

select_lanes() {
  if [ -n "${LANES:-}" ]; then
    read -r -a lane_list <<<"$LANES"
  else
    lane_list=("${LANES_ORDER[@]}")
  fi
}


lane_budget() { jq -r --arg l "$1" '.lanes[$l].budget // 0' "$BRIEFS"; }


lane_setting() { jq -r --arg l "$1" --arg k "$2" '.lanes[$l][$k] // empty' "$BRIEFS"; }



# The pool answers `remaining: "unlimited"` on a lifetime plan, and the real
# ceiling is then the hourly burst (429), not a day count. Translate it to a
# number the arithmetic can use; every caller already treats 0 as "stop".

remaining() {
  local n
  # `remaining: "unlimited"` is the plan talking, not the day. The entitlement
  # still carries `imagesPerDay`, so the ceiling the arithmetic needs is the quota
  # minus what has been spent. Measured 2026-11-10: 89 of 100 spent while the plan
  # answered "unlimited", and a 25-plate slot walked straight into 429s with
  # eleven images left in the day.
  n=$(cpg usage --json 2>/dev/null | jq -r '
    if (.entitlement.limits.imagesPerDay | type) == "number"
    then (.entitlement.limits.imagesPerDay - (.usage.images.used // 0))
    else (.usage.images.remaining // empty) end' 2>/dev/null)
  # An unreadable pool is not an empty one. The session token lives 60 s and is
  # minted from the stored cookie, so a 401 here is usually a stale token:
  # refresh once and ask again. Still empty means the session is gone, and the
  # caller has to say so instead of spending nothing and calling it a full day.
  if [ -z "$n" ] || [ "$n" = null ]; then
    cpg refresh >/dev/null 2>&1 || true
    n=$(cpg usage --json 2>/dev/null | jq -r '
      if (.entitlement.limits.imagesPerDay | type) == "number"
      then (.entitlement.limits.imagesPerDay - (.usage.images.used // 0))
      else (.usage.images.remaining // empty) end' 2>/dev/null)
  fi
  case "$n" in
    '' | null) return 0 ;;
    -*) echo 0 ;;
    *[!0-9]*) echo 1000 ;;
    *) echo "$n" ;;
  esac
}

