#!/usr/bin/env bash
# image-daily.sh — one unattended pass over the day's image allowance.
#
#   image-daily.sh plan       what is due today, and what it would cost
#   image-daily.sh run        generate, judge, keep; every verdict to the ledger
#   image-daily.sh status     [gate] per-lane freshness, exit 1 when a lane is stale
#   image-daily.sh judge PATH judge one file with agy and print the verdict
#   image-daily.sh publish    upload kept assets to Cloudinary, write the manifest,
#                             deploy the search frontend
#   image-daily.sh post       SLUG= TITLE= one motion: banner, judge, upload,
#                             manifest, front matter in the blog checkout
#   image-daily.sh blog [--dir PATH]
#                             Chirpy front matter per banner, and the JPEGs copied
#   image-daily.sh gc         destroy Cloudinary public ids nothing references
#   image-daily.sh wallpaper  set the newest accepted wallpaper with swaybg
#
# WHY THIS EXISTS: the allowance is 100 images per day and it does not carry
# over, so a day nobody spends is a day thrown away — and a queue kept in a
# person's head rots the first week they are busy. The queue is a file with a
# `every` per brief (`lib/image-daily/briefs.json`): a brief is due when its
# lane's last accepted asset for that id is older than that, so the runner
# refreshes itself without anybody editing a rota.
#
# The rules that keep it unattended:
#   1. Nothing is kept that a judge has not passed. agy reads the PNG and
#      answers the schema; a judge that cannot answer leaves the plate
#      `unjudged` — kept on disk, never published. Never blind-accept.
#   2. Every generation attempt lands in the ledger (`ledger.jsonl`) with the
#      prompt that produced it, so `status` can say a lane is stale without
#      trusting a timer's green light and the re-roll rate is readable later.
#   3. A brief that spends three images without a keep is parked for a week, so
#      a prompt the judge keeps refusing costs a few plates, not every slot.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BRIEFS=${BRIEFS:-$repo/lib/image-daily/briefs.json}
# The pool's media tree is root:root 0770 (/Volumes/data/media), so a generated
# asset cannot live there without sudo. pics/generated is the writable, devji-owned
# neighbour.
IMAGES_ROOT=${IMAGES_ROOT:-/Volumes/data/pics/generated}
LANES_ORDER=(site wall blog fleet)
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
  case "$n" in
    '' | null) return 0 ;;
    -*) echo 0 ;;
    *[!0-9]*) echo 1000 ;;
    *) echo "$n" ;;
  esac
}

# One ledger column: the judge's sentence plus the named defect, so a re-roll's
# cause is readable without parsing two fields.
reason_of() {
  printf '%s' "$1" | jq -r '.reason + (if (.defect // "") == "" then "" else " | " + .defect end)'
}

# --- judging ----------------------------------------------------------------
# agy is the judge: it is a different model family from the generator, it reads
# the PNG with its own tools, and it needs --dangerously-skip-permissions
# because there is no TTY to approve a file read. A judge that fails is not a
# rejection — `unjudged` says the plate was never looked at, which is why it
# never publishes.
judge_image() { # png lane intent [expect]
  local png=$1 lane=$2 intent=$3 expect=${4:-} verdict text
  mkdir -p "$STAGE"
  [ -d "$STAGE/.git" ] || git -C "$STAGE" init -q 2>/dev/null || true

  local prompt
  prompt=$(cat <<EOF
Read the image file at $png (a PNG on this machine; open it with your file tool).
Judge it as $intent.
Keep only when: the subject is recognisable at a glance and there is a clear
focal point, with no garbled lettering and no malformed faces or hands. A short
prompt that lands a deliberate image is a keep: spare is not the same as
generic, so do not mark an image down for carrying few words.
Otherwise answer "reroll" and put in "defect" one concrete, actionable defect
(the thing to change, e.g. "the horizon is not level"). Use "reject" only when
the image is unusable and the prompt is wrong, not the render.
Do not write any file. Do not ask a question. Do not describe the plan.
Answer on ONE line and nothing else, exactly this JSON:
{"verdict":"keep|reroll|reject","reason":"...","defect":"..."}
EOF
)
  # A name is not a subject. `Fern, 4k, realistic, neumorphism` was answered with a
  # fern leaf and judged a keep, because nothing in the prompt or the lane intent
  # said the subject is a person. When the brief states what the plate must show,
  # the judge can tell a correct render of the wrong thing from a correct plate.
  if [ -n "$expect" ]; then
    prompt+="
The plate must show: $expect. A literal reading of a name — a plant, a chemical
element, a generic icon, a settings row, a dashboard — is a reroll even when the
image itself is well made, because it is the wrong subject."
  fi

  local model_args=()
  [ -n "${GEMINI_MODEL:-}" ] && model_args=(--model "$GEMINI_MODEL")

  local raw rc=0
  # Measured on frieren, 2026-11-10: `--mode plan` (and therefore the default)
  # answers with a plan file and a question for the operator, and `--mode auto`
  # is not available on this account. `--mode accept-edits` with
  # `--disable-slash-commands` answers in ~52 s. `--json-schema` is deliberately
  # not used: it made the turn run past 200 s with no result, while a one-line
  # JSON reply parses cleanly.
  raw=$(cd "$STAGE" && agy --dangerously-skip-permissions --mode accept-edits \
    --disable-slash-commands "${model_args[@]}" \
    --print-timeout 180s --print "$prompt" --output-format json 2>/dev/null) || rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$raw" ]; then
    printf '{"verdict":"unjudged","reason":"agy exited %s","defect":""}' "$rc"
    return 0
  fi

  # agy prints {status, response, usage}. The reply is text, so lift the first
  # JSON object out of it rather than trusting the whole string to parse.
  text=$(printf '%s' "$raw" | jq -r '.response // empty' 2>/dev/null || true)
  verdict=$(printf '%s' "$text" | tr -d '\n' | grep -oE '\{.*\}' | head -1 |
    jq -c 'select(.verdict != null)' 2>/dev/null || true)
  if [ -z "$verdict" ]; then
    printf '{"verdict":"unjudged","reason":"agy answered without a verdict object","defect":""}'
    return 0
  fi
  printf '%s' "$verdict"
}

# --- generation -------------------------------------------------------------
# One call, one plate. A named defect is re-rolled once; a verdict of "keep" is
# final, and the re-roll budget is one per brief per day so a bad prompt cannot
# eat the allowance.
attempt() { # brief id lane size name prompt day [attempt] [rev]
  local id=$1 lane=$2 size=$3 name=$4 prompt=$5 day=$6 n=${7:-1} rev=${8:-1}
  local dir="$IMAGES_ROOT/src/$lane/$day"
  mkdir -p "$dir"
  local file="$dir/$name"
  mkdir -p "$(dirname "$file")"

  # 429 is a burst limit, not a spent day: `cpg usage` still reports the
  # allowance, so waiting is the right answer and recording a failure is not.
  # Measured 2026-11-10: 26 plates in 30 minutes, then every call for the next 21
  # seconds answered RATE_LIMITED while 74 images remained.
  local out rc=0 tries=0 wait
  while :; do
    out=$(cpg image --json -s "$size" -o "$file" "$prompt" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ -s "$file" ]; then break; fi
    if printf '%s' "$out" | grep -q '429\|RATE_LIMITED'; then
      tries=$((tries + 1))
      if [ "$tries" -gt 3 ]; then
        record "$day" "$lane" "$id" "$file" "failed" "rate limited after $tries attempts" "$prompt" "$n" "$rev"
        say "$id: still rate limited after $tries attempts"
        return 2
      fi
      wait=$((60 * (1 << (tries - 1))))
      say "$id: rate limited, waiting ${wait}s"
      sleep "$wait"
      continue
    fi
    record "$day" "$lane" "$id" "$file" "failed" \
      "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" "$prompt" "$n" "$rev"
    say "$id: generation failed (rc=$rc)"
    return 1
  done
  printf '%s' "$file"
}

run_lane() { # lane budget
  local lane=$1 budget=$2 day intent spent=0 left=0 v verdict defect expect
  LANE_SPENT=0
  day=$(today)
  intent=$(lane_setting "$lane" intent)
  # One usage call per lane, decremented locally: the counter moves only when a
  # plate is actually spent, and a per-iteration read would be a burst of API
  # calls against an endpoint with a rate limit.
  left=$(remaining || echo 0)
  say "lane $lane: budget $budget ($left left)"

  local rows
  rows=$(due "$lane") || rows=""
  # ONLY=id,id narrows a pass to named briefs: a requested plate should not wait
  # behind every other due entry in the lane, and should not drag them along.
  if [ -n "${ONLY:-}" ]; then
    rows=$(printf '%s\n' "$rows" | awk -F'\t' -v want=",${ONLY}," 'index(want, "," $1 ",")')
  fi
  if [ -z "$rows" ]; then
    say "lane $lane: nothing due"
    return 0
  fi

  while IFS=$'\t' read -r id _ size name prompt rev expect; do
    [ "$spent" -ge "$budget" ] && break
    [ "$left" -gt 0 ] || { say "allowance spent"; break; }

    if [ "${DRY:-0}" = "1" ]; then
      say "would generate $id ($size) -> $lane/$day/$name"
      spent=$((spent + 1))
      continue
    fi

    # Each generation is its own row, carrying the exact prompt it was sent:
    # the first plate and its re-roll used to collapse into one row, which hid
    # the re-roll rate the ledger exists to measure.
    local file rc=0 sent=$prompt n=1
    file=$(attempt "$id" "$lane" "$size" "$name" "$sent" "$day" "$n" "$rev") || rc=$?
    if [ "$rc" -eq 2 ]; then
      say "lane $lane: rate limited, stopping early"
      break
    fi
    [ "$rc" -eq 0 ] || continue
    left=$((left - 1))
    v=$(judge_image "$file" "$lane" "$intent" "$expect")
    verdict=$(printf '%s' "$v" | jq -r '.verdict')
    defect=$(printf '%s' "$v" | jq -r '.defect // ""')
    spent=$((spent + 1))
    record "$day" "$lane" "$id" "$file" "$verdict" "$(reason_of "$v")" "$sent" "$n" "$rev"

    if [ "$verdict" = "reroll" ] && [ -n "$defect" ] && [ "$left" -gt 0 ] && [ "$spent" -lt "$budget" ]; then
      say "$id: reroll — $defect"
      rm -f "$file"
      sent="$prompt (Change only this: $defect.)"
      n=2
      file=$(attempt "$id" "$lane" "$size" "$name" "$sent" "$day" "$n" "$rev") || continue
      left=$((left - 1))
      v=$(judge_image "$file" "$lane" "$intent" "$expect")
      verdict=$(printf '%s' "$v" | jq -r '.verdict')
      spent=$((spent + 1))
      record "$day" "$lane" "$id" "$file" "$verdict" "$(reason_of "$v")" "$sent" "$n" "$rev"
    fi

    say "$id: $verdict"
  done <<<"$rows"
  LANE_SPENT=$spent
}

# --- publish ----------------------------------------------------------------
# The published tree accumulates; a deploy replaces the whole site, so it must
# carry every earlier day or the history disappears on the second run.
stage_publish() {
  local day file rel out
  while IFS= read -r file; do
    # The ledger is append-only and a path in it can be stale: a plate deleted for
    # being the wrong subject leaves a keep behind. Skip what is not on disk rather
    # than failing the whole manifest on one old row.
    [ -f "$file" ] || { say "publish: ledger path is gone ($file)"; continue; }
    rel=${file#"$IMAGES_ROOT/src/"}
    if [ "$lane" = "blog" ]; then
      # 3:2 out of the generator, 1200x630 in the page. The crop is local work,
      # so it costs no image and keeps og:image at a few hundred KB instead of
      # the 2 MB PNG.
      out=$IMAGES_ROOT/published/blog/$(basename "${file%.png}").jpg
      banner_crop "$file" "$out" || say "blog: could not crop $file"
      continue
    fi
    mkdir -p "$IMAGES_ROOT/published/$(dirname "$rel")"
    cp -f "$file" "$IMAGES_ROOT/published/$rel"
  done < <(jq -r --arg l "$lane" 'select(.verdict == "keep" and .lane == $l) | .path' "$LEDGER" 2>/dev/null | sort -u)
}

# ffmpeg is the only image tool on this host (no magick, no vips, no cwebp) and
# it is enough for the one transform this pipeline needs: cover-crop to 1200x630.
banner_crop() { # png jpg
  command -v ffmpeg >/dev/null 2>&1 || { say "ffmpeg is not on PATH"; return 1; }
  mkdir -p "$(dirname "$2")"
  ffmpeg -loglevel error -y -i "$1" \
    -vf "scale=1200:630:force_original_aspect_ratio=increase,crop=1200:630" \
    -q:v 3 "$2"
}

# The deployable is the frontend plus the manifest, both small: the bytes are on
# Cloudinary, and the page fetches the manifest and searches it. Nothing here
# copies an image into the deployed tree, so a deploy is a few KB however many
# plates the bank holds.
build_index() {
  local out=$IMAGES_ROOT/published/manifest.json
  local shell=$repo/lib/image-daily/site/index.html
  local dist=$IMAGES_ROOT/site-dist
  [ -f "$shell" ] || die "missing the asset frontend at $shell"
  [ -s "$IMAGES_ROOT/published/urls.tsv" ] || die "no urls.tsv yet — the manifest is built from it"
  mkdir -p "$dist"
  # Rows are path, URL, bytes. `public_id` is what a person searches and what
  # Cloudinary addresses; `day` is empty for a blog banner, whose slug carries it.
  jq -Rn --arg ts "$(date -u +%FT%TZ)" --argjson stop "$TAG_STOP" '
    [inputs | select(length > 0) | split("\t") | {path: .[0], url: .[1], bytes: ((.[2] // "0") | tonumber)}]
    | map(. + {
        public_id: (.path | sub("\\.(png|jpg|jpeg|webp)$"; "")),
        lane: (.path | split("/")[0]),
        name: (.path | split("/") | last),
        # `capture` yields no value when the pattern is absent — that is not an
        # error, so `try/catch` never sees it, and an empty `day` drops the whole
        # object out of `map`. A blog banner carries its date in the slug instead.
        day: ((.path | capture("(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})").d) // "")
      }
      | . as $a
      | . + {
        tags: ([$a.public_id | split("/")[] | select(test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)
          | split("-")[] | split("_")[] | ascii_downcase
          | select(length > 2) | select(test("^[0-9]+$") | not) | select(. != $a.lane)
          | select(. as $t | ($stop | index($t)) == null)] | unique)
      })
    | sort_by(.path)
    | {generatedAt: $ts, count: length,
       tags: ([.[] | .tags[]] | group_by(.) | map({tag: .[0], count: length}) | sort_by(-.count, .tag)),
       assets: .}
  ' <"$IMAGES_ROOT/published/urls.tsv" >"$out"
  cp -f "$shell" "$dist/index.html"
  cp -f "$out" "$dist/manifest.json"
  say "manifest: $(jq -r '.count' "$out") asset(s), $(du -sh "$dist" | cut -f1) of frontend"
}

# --- subcommands ------------------------------------------------------------
cmd_plan() {
  need jq cpg
  briefs_guard || die "briefs: a character brief is not bank-ready (see above)"
  local rem lane rows n total=0
  rem=$(remaining)
  [ -n "$rem" ] || die "cpg usage answered nothing — is the session alive? (cpg status --json)"
  say "allowance remaining: $rem"
  select_lanes
  for lane in "${lane_list[@]}"; do
    rows=$(due "$lane") || rows=""
    n=$(printf '%s' "$rows" | grep -c . || true)
    total=$((total + n))
    printf '  %-6s due %2s  budget %2s  max_age %s d\n' "$lane" "$n" \
      "$(lane_budget "$lane")" "$(lane_setting "$lane" max_age_days)"
    [ "$n" -gt 0 ] && printf '%s\n' "$rows" | awk -F'\t' '{printf "         - %-22s %s\n", $1, $3}'
  done
  if [ "$rem" -ge 1000 ]; then
    printf '  leftover after the queue: unlimited on this plan (the hourly burst is the ceiling)\n'
  else
    printf '  leftover after the queue: %s (unspent unless STORYBOOK=1)\n' "$((rem - total))"
  fi
}

cmd_run() {
  need jq cpg agy git
  briefs_guard || die "briefs: a character brief is not bank-ready (see above)"
  mkdir -p "$IMAGES_ROOT" "$STAGE"
  exec 9>"$IMAGES_ROOT/.run.lock"
  flock -n 9 || { say "another run holds the lock"; exit 0; }

  local day marker
  day=$(today)
  # A day can be spent in more than one pass: the generator's burst limit is 25 an
  # hour, so four slots 6h20 apart each spend a slice. The marker is per slot, or
  # the second slot of the day would read as a repeat of the first.
  marker=$IMAGES_ROOT/.done/$day
  [ -n "${SLOT:-}" ] && marker=$marker.${SLOT}
  if [ -f "$marker" ] && [ "${FORCE:-0}" != "1" ]; then
    say "$day already ran; FORCE=1 to spend again"
    exit 0
  fi

  local rem lane budget
  rem=$(remaining)
  [ -n "$rem" ] || die "cpg usage answered nothing — run cpg status --json"
  # Daytime slots hold a slice back. A plate someone asked for during the day is
  # worth more than the queue's next due entry, and a slot that spends the day at
  # 13:20 leaves nothing for that. The last slot runs with RESERVE=0 and sweeps
  # whatever demand and budget the day left.
  local reserve=${RESERVE:-0}
  if [ "$reserve" -le 0 ]; then
    say "$day: $rem images available"
  elif [ "$rem" -gt "$reserve" ]; then
    say "$day: $rem images available, $reserve held for ad-hoc requests"
    rem=$((rem - reserve))
  else
    say "$day: $rem images available, all $reserve reserved for ad-hoc requests"
    rem=0
  fi

  local cap=${CAP:-0} spent_total=0 room
  select_lanes
  for lane in "${lane_list[@]}"; do
    budget=$(lane_budget "$lane")
    [ "$budget" -gt "$rem" ] && budget=$rem
    if [ "$cap" -gt 0 ]; then
      room=$((cap - spent_total))
      [ "$room" -gt 0 ] || { say "cap $cap reached; the next slot takes the rest"; break; }
      [ "$budget" -gt "$room" ] && budget=$room
    fi
    run_lane "$lane" "$budget"
    spent_total=$((spent_total + LANE_SPENT))
    rem=$(remaining || echo 0)
  done

  # Whatever is left is discretionary: the storybook project takes it, and the
  # printer is idempotent, so a nearly-finished book simply stops.
  # Opt-in, not default. Two books of uniform spreads filled the allowance with
  # the same style on every page, which is the one thing a 100-image day should
  # not buy; a varied bank is worth more than 32 plates of the same look.
  local left
  left=$(remaining || echo 0)
  if [ "$reserve" -gt 0 ]; then
    left=$((left - reserve))
    [ "$left" -lt 0 ] && left=0
  fi
  if [ "${STORYBOOK:-0}" = "1" ] && [ "$left" -gt 0 ] && [ -n "${STORYBOOK_DIR:-}" ] &&
    [ -f "$repo/.agents/skills/cpg-storybook/scripts/storybook.py" ]; then
    say "storybook: $left images left, printing $((left / 3)) spread(s)"
    [ "${DRY:-0}" = "1" ] || python3 "$repo/.agents/skills/cpg-storybook/scripts/storybook.py" \
      run --limit "$((left / 3))" || say "storybook stopped early (see its ledger)"
  elif [ "$left" -gt 0 ]; then
    say "leftover: $left images unused (STORYBOOK=1 with STORYBOOK_DIR to spend them)"
  fi

  if [ "${PUBLISH:-1}" = "1" ] && [ "${DRY:-0}" != "1" ]; then
    cmd_publish || say "publish failed; assets are on disk and the lane reads stale until it succeeds"
  fi

  # A dry run has spent nothing, so it must not claim the day: the marker is what
  # makes the 06:10 run a no-op, and marking a DRY pass would silence the night.
  if [ "${DRY:-0}" != "1" ]; then
    mkdir -p "$IMAGES_ROOT/.done"
    date -u +%FT%TZ >"$marker"
  fi
  say "$day done"
}

cmd_status() {
  need jq
  local stale=0 lane newest age max
  [ -f "$LEDGER" ] || { say "no ledger yet at $LEDGER"; exit 1; }
  select_lanes
  for lane in "${lane_list[@]}"; do
    newest=$(jq -r --arg l "$lane" 'select(.verdict == "keep" and .lane == $l) | .day' "$LEDGER" | sort | tail -1)
    max=$(lane_setting "$lane" max_age_days)
    if [ -z "$newest" ]; then
      printf '  %-6s never  stale\n' "$lane"
      stale=1
      continue
    fi
    age=$((($(epoch "$(today)") - $(epoch "$newest")) / 86400))
    if [ -n "$max" ] && [ "$age" -gt "$max" ]; then
      printf '  %-6s %s  %sd old (max %s)  STALE\n' "$lane" "$newest" "$age" "$max"
      stale=1
    else
      printf '  %-6s %s  %sd old (max %s)\n' "$lane" "$newest" "$age" "${max:-—}"
    fi
  done
  local parked=0 id rev
  while IFS=$'\t' read -r id rev; do
    if is_parked "$id" "$rev"; then parked=$((parked + 1)); fi
  done < <(jq -r '.briefs[] | [.id, (.rev // 1)] | @tsv' "$BRIEFS")
  [ "$parked" -eq 0 ] ||
    printf '  %-6s %s brief(s) parked: %s rejections without a keep\n' "" "$parked" "$PARK_AFTER"
  printf '  remaining today: %s\n' "$(remaining 2>/dev/null || echo '?')"
  exit "$stale"
}

cmd_judge() {
  need jq agy
  local path=${1:?usage: image-daily.sh judge PATH [lane]}
  [ -f "$path" ] || die "$path does not exist"
  judge_image "$(readlink -f "$path")" "${2:-wall}" "$(lane_setting "${2:-wall}" intent)"
  echo
}

# The Pages project is the search frontend: index.html and manifest.json, nothing
# else. One implementation, because a new post publishes the same manifest a
# nightly slot does.
deploy_frontend() {
  [ "${PAGES:-1}" = "1" ] || { say "PAGES=0: frontend not deployed"; return 0; }
  local project=${PROJECT:-bountystash-assets}
  nix-shell -p wrangler --run \
    "bash '$repo/scripts/task/pages-deploy.sh' '$IMAGES_ROOT/site-dist' --project-name=$project --branch=main" ||
    say "publish: the frontend deploy failed; the manifest is written locally and the site still serves the last one"
}

cmd_publish() {
  need jq
  local lane
  [ -d "$IMAGES_ROOT/src" ] || die "nothing generated yet under $IMAGES_ROOT/src"
  for lane in site wall blog; do
    [ "$(lane_setting "$lane" publish)" = "true" ] || continue
    stage_publish
  done
  build_index
  say "$(find "$IMAGES_ROOT/published" \( -name '*.png' -o -name '*.jpg' \) | wc -l) asset(s) staged"
  if [ "${DRY:-0}" = "1" ]; then
    say "dry run: not uploading"
    return 0
  fi
  # Cloudinary is the asset plane, not a deployed gallery: the delivery URL
  # carries its own resize (`f_auto,q_auto,w_1200`), so a consumer picks the
  # size it needs from one upload and this tree never becomes a website. The
  # urls.tsv beside the assets is the manifest a consumer reads.
  local rel url
  : >"$IMAGES_ROOT/published/urls.tsv"
  while IFS= read -r file; do
    rel=${file#"$IMAGES_ROOT/published/"}
    url=$(bash "$repo/scripts/task/cloudinary.sh" upload "$file" --public-id "assets/${rel%.*}") || {
      say "publish: upload failed for $rel"
      return 1
    }
    printf '%s\t%s\t%s\n' "$rel" "$url" "$(stat -c%s "$file")" >>"$IMAGES_ROOT/published/urls.tsv"
    say "uploaded $rel"
  done < <(find "$IMAGES_ROOT/published" \( -name '*.png' -o -name '*.jpg' \) | sort)
  say "$(wc -l <"$IMAGES_ROOT/published/urls.tsv") asset(s) on Cloudinary"
  build_index
  deploy_frontend
}

# The consumer of the blog lane is a Chirpy checkout, not this gallery: hand over
# the front matter the theme reads for the in-page hero and for og:image, and the
# JPEG next to it when a checkout path is given.
cmd_blog() { # [--dir PATH]
  need jq
  local dir="" src=$IMAGES_ROOT/published/blog f slug alt
  if [ "${1:-}" = "--dir" ]; then dir=${2:?--dir needs a path}; fi
  [ -d "$src" ] || die "no banners under $src yet — run images:publish first"
  for f in "$src"/*.jpg; do
    [ -f "$f" ] || continue
    slug=$(basename "${f%.jpg}")
    alt=$(jq -r --arg id "blog-$slug" '.briefs[] | select(.id == $id) | .prompt' "$BRIEFS")
    if [ -n "$dir" ]; then
      mkdir -p "$dir/assets/img/banners"
      cp -f "$f" "$dir/assets/img/banners/"
    fi
    url=$(awk -F'\t' -v k="blog/$slug.jpg" '$1 == k { print $2 }' \
      "$IMAGES_ROOT/published/urls.tsv" 2>/dev/null)
    [ -n "$url" ] || url=$(bash "$repo/scripts/task/cloudinary.sh" upload "$f" \
      --public-id "shaoyanji/banners/$slug")
    printf 'image:\n  path: %s\n  alt: %s\n\n' "$url" "${alt:-$slug}"
  done
}

# One motion from a title to a post that has a banner. The banner is generated,
# judged and uploaded before the file exists, so a post cannot ship with a hero
# that 404s, and no JPEG enters the tree.
# One front-matter field from a draft, unquoted. A draft is the source of the body
# and of the metadata the generator never asks for (description, author, the toc
# flags); the banner, the date and the title are the generator's.
fm_field() {
  awk -v k="$1" '/^---$/{n++; next} n==1 && index($0, k":")==1 {
      v=substr($0, length(k)+2); sub(/^ +/, "", v); gsub(/^"|"$/, "", v); print v; exit
    }' "$2"
}

cmd_post() {
  need jq cpg agy ffmpeg git
  local slug=${SLUG:-} title=${TITLE:-} prompt=${PROMPT:-} alt=${ALT:-}
  local blog=${BLOG_DIR:-$HOME/Documents/shaoyanji.is-a.dev}
  [ -n "$slug" ] || die "SLUG=<url-slug> is required"
  [ -n "$title" ] || die 'TITLE="the post title" is required'
  [ -d "$blog/.git" ] || die "no blog checkout at $blog (BLOG_DIR=...)"
  [ -n "$alt" ] || alt=$title
  [ -n "$prompt" ] || prompt="A blog banner for an engineering post titled \"$title\". One clear subject, realistic photographic style, natural light, shallow depth of field, no text, no lettering, no logos, nothing to read."
  local day post file verdict defect jpg url card body='' tsv=$IMAGES_ROOT/published/urls.tsv
  day=$(today)
  post=$blog/_posts/$day-$slug.md
  if [ -f "$post" ] && [ "${FORCE:-0}" != "1" ]; then
    die "$post exists — FORCE=1 to rewrite its front matter (the body is kept)"
  fi
  # A promotion starts from a draft: same slug, an older date, a body already
  # written. `DRAFT=1` finds it beside the target, `DRAFT=<path>` names it.
  local draft=''
  case ${DRAFT:-} in
  '' | 0) ;;
  1)
    draft=$(ls -1 "$blog"/_posts/*-"$slug".md 2>/dev/null | grep -v "/$day-" | head -1 || true)
    [ -n "$draft" ] || die "DRAFT=1: no _posts/*-$slug.md beside $post to promote"
    ;;
  *)
    draft=${DRAFT#./}
    case $draft in /*) ;; *) draft=$blog/$draft ;; esac
    ;;
  esac
  [ -z "$draft" ] || [ -f "$draft" ] || die "no draft at $draft"
  [ "$(remaining || echo 0)" -gt 0 ] || die "no images left today"

  say "$slug: generating a banner"
  file=$(attempt "blog-$slug" blog 1536x1024 "$slug.png" "$prompt" "$day") || die "generation failed"
  verdict=$(judge_image "$file" blog "$(lane_setting blog intent)")
  if [ "$(printf '%s' "$verdict" | jq -r '.verdict')" = "reroll" ]; then
    defect=$(printf '%s' "$verdict" | jq -r '.defect // "the composition"')
    say "$slug: reroll — $defect"
    rm -f "$file"
    file=$(attempt "blog-$slug" blog 1536x1024 "$slug.png" \
      "$prompt (Change only this: $defect.)" "$day") || die "reroll failed"
    verdict=$(judge_image "$file" blog "$(lane_setting blog intent)")
  fi
  say "judge: $(printf '%s' "$verdict" | jq -r '.verdict + " — " + .reason')"
  [ "$(printf '%s' "$verdict" | jq -r '.verdict')" = "keep" ] ||
    die "the judge did not keep $file; nothing was uploaded"

  record "$day" blog "blog-$slug" "$file" keep "$(printf '%s' "$verdict" | jq -r '.reason')"
  jpg=$IMAGES_ROOT/published/blog/$slug.jpg
  banner_crop "$file" "$jpg" || die "could not crop the banner"
  url=$(bash "$repo/scripts/task/cloudinary.sh" upload "$jpg" --public-id "assets/blog/$slug") ||
    die "upload failed"
  say "cloudinary: $url"

  # The manifest is the reference list: a new upload of the same slug replaces the
  # old row instead of joining it, so a regenerated banner does not appear twice.
  mkdir -p "$(dirname "$tsv")"
  [ -f "$tsv" ] && grep -v "^blog/$slug\.jpg	" "$tsv" >"$tsv.new" || true
  printf 'blog/%s.jpg\t%s\t%s\n' "$slug" "$url" "$(stat -c%s "$jpg")" >>"$tsv.new"
  mv -f "$tsv.new" "$tsv"
  build_index
  deploy_frontend

  card=$(bash "$repo/scripts/task/cloudinary.sh" url "assets/blog/$slug" \
    --transform 'f_jpg,q_auto,w_1200,h_630,c_fill')
  # The public id carries no extension; the delivery URL names the format anyway,
  # and the other fifteen posts are `.jpg`, so a scraper never has to guess.
  card=$card.jpg
  # Two sources for the metadata: a draft (a promotion) or an existing post
  # (`FORCE=1`). The body is everything after the second fence either way.
  local fm_src=''
  if [ -n "$draft" ]; then
    fm_src=$draft
  elif [ -f "$post" ]; then
    fm_src=$post
  fi
  [ -z "$fm_src" ] || body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$fm_src" | sed '/./,$!d')
  [ -z "$fm_src" ] || [ -n "$body" ] || die "$fm_src has no body after its front matter"
  local cats=${CATEGORIES:-} tgs=${TAGS:-} desc=${DESCRIPTION:-} author=${AUTHOR:-}
  local pin=false toc=true comments=false math=false mermaid=false
  if [ -n "$fm_src" ]; then
    [ -n "$cats" ] || cats=$(fm_field categories "$fm_src")
    [ -n "$tgs" ] || tgs=$(fm_field tags "$fm_src")
    [ -n "$desc" ] || desc=$(fm_field description "$fm_src")
    [ -n "$author" ] || author=$(fm_field author "$fm_src")
    pin=$(fm_field pin "$fm_src")
    toc=$(fm_field toc "$fm_src")
    comments=$(fm_field comments "$fm_src")
    math=$(fm_field math "$fm_src")
    mermaid=$(fm_field mermaid "$fm_src")
    pin=${pin:-false}
    toc=${toc:-true}
    comments=${comments:-false}
    math=${math:-false}
    mermaid=${mermaid:-false}
  fi
  cats=${cats:-Blog}
  tgs=${tgs:-technology}
  cats=${cats#[}
  cats=${cats%]}
  tgs=${tgs#[}
  tgs=${tgs%]}
  {
    printf -- '---\n'
    printf 'layout: post\n'
    printf 'title: "%s"\n' "${title//\"/\\\"}"
    printf 'date: %s 00:00:00 +0000\n' "$day"
    printf 'categories: [%s]\n' "$cats"
    printf 'tags: [%s]\n' "$tgs"
    [ -z "$desc" ] || printf 'description: "%s"\n' "${desc//\"/\\\"}"
    [ -z "$author" ] || printf 'author: %s\n' "$author"
    printf 'image:\n  path: %s\n  alt: "%s"\n' "$card" "${alt//\"/\\\"}"
    if [ -n "$fm_src" ]; then
      printf 'pin: %s\ntoc: %s\ncomments: %s\nmath: %s\nmermaid: %s\n' \
        "$pin" "$toc" "$comments" "$math" "$mermaid"
    fi
    printf -- '---\n\n'
    [ -z "$body" ] || printf '%s\n' "$body"
  } >"$post"
  say "post: $post"
  local paths=("${post#"$blog"/}")
  if [ -n "$draft" ] && [ "$draft" != "$post" ]; then
    rm -f "$draft"
    paths+=("${draft#"$blog"/}")
  fi
  git -C "$blog" add -A -- "${paths[@]}"
  if ! git -C "$blog" diff --cached --quiet -- "${paths[@]}" 2>/dev/null; then
    git -C "$blog" commit -q -m "post: $title" \
      -m "Banner from the image queue, on Cloudinary where the crop lives in the URL."
  fi
  say "commit: $(git -C "$blog" log --oneline -1)"
  if [ "${PUSH:-0}" = "1" ]; then
    git -C "$blog" push -q origin HEAD && say "pushed: the site deploys from this"
  else
    say "not pushed — PUSH=1 lands it"
  fi
}

# Cloudinary keeps every public id forever, so a renamed asset or a superseded
# convention leaves an id that nothing serves and every listing shows. The
# references are the manifest and the blog checkout; everything else under
# GC_PREFIX is garbage. `DRY=1` prints the list instead of destroying it.
cmd_gc() {
  need jq curl git
  local prefix=${GC_PREFIX:-shaoyanji/} blog=${BLOG_DIR:-$HOME/Documents/shaoyanji.is-a.dev}
  local keep=$IMAGES_ROOT/.gc-keep ids id n=0 gone=0
  [ -s "$IMAGES_ROOT/published/urls.tsv" ] || die "no urls.tsv yet — run images:publish first"
  {
    cut -f1 "$IMAGES_ROOT/published/urls.tsv" | sed 's/\.\(png\|jpg\|jpeg\|webp\)$//; s#^#assets/#'
    if [ -d "$blog" ]; then
      grep -rhoE 'image/upload/[^)[:space:]"]+' "$blog/_config.yml" "$blog/_posts" 2>/dev/null |
        sed -e 's#.*image/upload/##' -e 's#^v[0-9]*/##' -e 's#^[a-z0-9]*_[^/]*/##' \
          -e 's/\.\(png\|jpg\|jpeg\|webp\)$//'
    fi
  } | sort -u >"$keep"
  say "references: $(wc -l <"$keep") public id(s)"
  ids=$(bash "$repo/scripts/task/cloudinary.sh" list --prefix "$prefix") || die "could not list $prefix"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    # `grep ... && continue` returns 1 when the id is absent, and errexit would
    # take that as the function failing; the absent case is the point.
    if grep -qxF "$id" "$keep"; then continue; fi
    if [ "${DRY:-0}" = "1" ]; then
      say "would destroy $id"
      gone=$((gone + 1))
      continue
    fi
    bash "$repo/scripts/task/cloudinary.sh" destroy "$id" >/dev/null &&
      { say "destroyed $id"; gone=$((gone + 1)); }
  done <<<"$ids"
  say "$n under $prefix, $gone orphan(s)"
}

cmd_wallpaper() {
  local newest
  newest=$(find "$IMAGES_ROOT/published/wall" "$IMAGES_ROOT/src/wall" -name '*.png' 2>/dev/null |
    sort -r | head -1)
  [ -n "$newest" ] || die "no wallpaper generated yet"
  [ "${DRY:-0}" = "1" ] && { say "$newest"; return 0; }
  command -v swaybg >/dev/null || die "swaybg is not installed on this host"
  pkill -x swaybg 2>/dev/null || true
  setsid swaybg -m fill -i "$newest" >/dev/null 2>&1 &
  say "$(basename "$newest")"
}

case "${1:-plan}" in
  plan) cmd_plan ;;
  run) cmd_run ;;
  status) cmd_status ;;
  judge) shift && cmd_judge "$@" ;;
  publish) cmd_publish ;;
  post) cmd_post ;;
  gc) cmd_gc ;;
  blog) shift && cmd_blog "$@" ;;
  wallpaper) cmd_wallpaper ;;
  *) die "usage: image-daily.sh plan|run|status|judge PATH|publish|post|gc|blog [--dir PATH]|wallpaper" ;;
esac
