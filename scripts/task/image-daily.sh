#!/usr/bin/env bash
# image-daily.sh — one unattended pass over the day's image allowance.
#
#   image-daily.sh plan       what is due today, and what it would cost
#   image-daily.sh run        generate, judge, keep; every verdict to the ledger
#   image-daily.sh status     [gate] per-lane freshness, exit 1 when a lane is stale
#   image-daily.sh judge PATH judge one file with agy and print the verdict
#   image-daily.sh publish    upload kept assets to Cloudinary, write the manifest,
#                             deploy the search frontend
#   image-daily.sh blog [--dir PATH]
#                             Chirpy front matter per banner, and the JPEGs copied
#   image-daily.sh wallpaper  set the newest accepted wallpaper with swaybg
#
# WHY THIS EXISTS: the allowance is 100 images per day and it does not carry
# over, so a day nobody spends is a day thrown away — and a queue kept in a
# person's head rots the first week they are busy. The queue is a file with a
# `every` per brief (`lib/image-daily/briefs.json`): a brief is due when its
# lane's last accepted asset for that id is older than that, so the runner
# refreshes itself without anybody editing a rota.
#
# The two rules that keep it unattended:
#   1. Nothing is kept that a judge has not passed. agy reads the PNG and
#      answers the schema; a judge that cannot answer leaves the plate
#      `unjudged` — kept on disk, never published. Never blind-accept.
#   2. Every decision lands in the ledger (`ledger.jsonl`), so `status` can say
#      a lane is stale without trusting a timer's green light.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BRIEFS=${BRIEFS:-$repo/lib/image-daily/briefs.json}
# The pool's media tree is root:root 0770 (/Volumes/data/media), so a generated
# asset cannot live there without sudo. pics/generated is the writable, devji-owned
# neighbour.
IMAGES_ROOT=${IMAGES_ROOT:-/Volumes/data/pics/generated}
LANES_ORDER=(site wall blog fleet)
LEDGER=$IMAGES_ROOT/ledger.jsonl
STAGE=$IMAGES_ROOT/.judge

die() {
  echo "image-daily: $*" >&2
  exit 1
}
say() { echo "image-daily: $*"; }

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
record() { # day lane brief path verdict reason
  [ -d "$IMAGES_ROOT" ] || mkdir -p "$IMAGES_ROOT"
  jq -nc --arg ts "$(date -u +%FT%TZ)" --arg day "$1" --arg lane "$2" \
    --arg brief "$3" --arg path "$4" --arg verdict "$5" --arg reason "$6" \
    '{ts: $ts, day: $day, lane: $lane, brief: $brief, path: $path,
      verdict: $verdict, reason: $reason}' >>"$LEDGER"
}

# The last day a brief was accepted, empty when it never was.
last_keep() {
  [ -f "$LEDGER" ] || return 0
  jq -r --arg id "$1" 'select(.brief == $id and .verdict == "keep") | .day' "$LEDGER" |
    sort | tail -1
}

# --- the queue --------------------------------------------------------------
# TSV: id, lane, size, name, prompt — for the briefs that are due today.
due() {
  local filter=${1:-}
  jq -r '.briefs[] | [.id, .lane, .size, .name, .prompt, (.every | tostring)] | @tsv' "$BRIEFS" |
    while IFS=$'\t' read -r id lane size name prompt every; do
      [ -n "$filter" ] && [ "$lane" != "$filter" ] && continue
      local last now last_s
      last=$(last_keep "$id")
      now=$(epoch "$(today)")
      last_s=$(epoch "${last:-1970-01-01}")
      [ -n "$last" ] || last_s=0
      if [ "$last_s" -eq 0 ] || [ $(((now - last_s) / 86400)) -ge "$every" ]; then
        printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$lane" "$size" "$name" "$prompt"
      fi
    done
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
  n=$(cpg usage --json 2>/dev/null | jq -r '.usage.images.remaining // empty')
  case "$n" in
    '' | null) return 0 ;;
    *[!0-9]*) echo 1000 ;;
    *) echo "$n" ;;
  esac
}

# --- judging ----------------------------------------------------------------
# agy is the judge: it is a different model family from the generator, it reads
# the PNG with its own tools, and it needs --dangerously-skip-permissions
# because there is no TTY to approve a file read. A judge that fails is not a
# rejection — `unjudged` says the plate was never looked at, which is why it
# never publishes.
judge_image() { # png lane intent
  local png=$1 lane=$2 intent=$3 verdict text
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
attempt() { # brief id lane size name prompt day
  local id=$1 lane=$2 size=$3 name=$4 prompt=$5 day=$6
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
        record "$day" "$lane" "$id" "$file" "failed" "rate limited after $tries attempts"
        say "$id: still rate limited after $tries attempts"
        return 2
      fi
      wait=$((60 * (1 << (tries - 1))))
      say "$id: rate limited, waiting ${wait}s"
      sleep "$wait"
      continue
    fi
    record "$day" "$lane" "$id" "$file" "failed" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
    say "$id: generation failed (rc=$rc)"
    return 1
  done
  printf '%s' "$file"
}

run_lane() { # lane budget
  local lane=$1 budget=$2 day intent spent=0 left=0 v verdict defect
  day=$(today)
  intent=$(lane_setting "$lane" intent)
  # One usage call per lane, decremented locally: the counter moves only when a
  # plate is actually spent, and a per-iteration read would be a burst of API
  # calls against an endpoint with a rate limit.
  left=$(remaining || echo 0)
  say "lane $lane: budget $budget ($left left)"

  local rows
  rows=$(due "$lane") || rows=""
  if [ -z "$rows" ]; then
    say "lane $lane: nothing due"
    return 0
  fi

  while IFS=$'\t' read -r id _ size name prompt; do
    [ "$spent" -ge "$budget" ] && break
    [ "$left" -gt 0 ] || { say "allowance spent"; break; }

    if [ "${DRY:-0}" = "1" ]; then
      say "would generate $id ($size) -> $lane/$day/$name"
      spent=$((spent + 1))
      continue
    fi

    local file rc=0
    file=$(attempt "$id" "$lane" "$size" "$name" "$prompt" "$day") || rc=$?
    if [ "$rc" -eq 2 ]; then
      say "lane $lane: rate limited, stopping early"
      break
    fi
    [ "$rc" -eq 0 ] || continue
    left=$((left - 1))
    v=$(judge_image "$file" "$lane" "$intent")
    verdict=$(printf '%s' "$v" | jq -r '.verdict')
    defect=$(printf '%s' "$v" | jq -r '.defect // ""')
    spent=$((spent + 1))

    if [ "$verdict" = "reroll" ] && [ -n "$defect" ] && [ "$left" -gt 0 ] && [ "$spent" -lt "$budget" ]; then
      say "$id: reroll — $defect"
      rm -f "$file"
      file=$(attempt "$id" "$lane" "$size" "$name" "$prompt (Change only this: $defect.)" "$day") || continue
      left=$((left - 1))
      v=$(judge_image "$file" "$lane" "$intent")
      verdict=$(printf '%s' "$v" | jq -r '.verdict')
      defect=$(printf '%s' "$v" | jq -r '.defect // ""')
      spent=$((spent + 1))
    fi

    record "$day" "$lane" "$id" "$file" "$verdict" \
      "$(printf '%s' "$v" | jq -r '.reason + (if (.defect // "") == "" then "" else " | " + .defect end)')"
    say "$id: $verdict"
  done <<<"$rows"
}

# --- publish ----------------------------------------------------------------
# The published tree accumulates; a deploy replaces the whole site, so it must
# carry every earlier day or the history disappears on the second run.
stage_publish() {
  local day file rel out
  while IFS= read -r file; do
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
  jq -Rn --arg ts "$(date -u +%FT%TZ)" '
    [inputs | select(length > 0) | split("\t") | {path: .[0], url: .[1], bytes: ((.[2] // "0") | tonumber)}]
    | map(. + {
        public_id: (.path | sub("\\.(png|jpg|jpeg|webp)$"; "")),
        lane: (.path | split("/")[0]),
        name: (.path | split("/") | last),
        day: (.path | try (capture("(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})").d) catch "")
      })
    | sort_by(.path)
    | {generatedAt: $ts, count: length, assets: .}
  ' <"$IMAGES_ROOT/published/urls.tsv" >"$out"
  cp -f "$shell" "$dist/index.html"
  cp -f "$out" "$dist/manifest.json"
  say "manifest: $(jq -r '.count' "$out") asset(s), $(du -sh "$dist" | cut -f1) of frontend"
}

# --- subcommands ------------------------------------------------------------
cmd_plan() {
  need jq cpg
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
  mkdir -p "$IMAGES_ROOT" "$STAGE"
  exec 9>"$IMAGES_ROOT/.run.lock"
  flock -n 9 || { say "another run holds the lock"; exit 0; }

  local day marker
  day=$(today)
  marker=$IMAGES_ROOT/.done/$day
  if [ -f "$marker" ] && [ "${FORCE:-0}" != "1" ]; then
    say "$day already ran; FORCE=1 to spend again"
    exit 0
  fi

  local rem lane budget
  rem=$(remaining)
  [ -n "$rem" ] || die "cpg usage answered nothing — run cpg status --json"
  say "$day: $rem images available"

  select_lanes
  for lane in "${lane_list[@]}"; do
    budget=$(lane_budget "$lane")
    [ "$budget" -gt "$rem" ] && budget=$rem
    run_lane "$lane" "$budget"
    rem=$(remaining || echo 0)
  done

  # Whatever is left is discretionary: the storybook project takes it, and the
  # printer is idempotent, so a nearly-finished book simply stops.
  # Opt-in, not default. Two books of uniform spreads filled the allowance with
  # the same style on every page, which is the one thing a 100-image day should
  # not buy; a varied bank is worth more than 32 plates of the same look.
  local left
  left=$(remaining || echo 0)
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
  # The Pages project is the search frontend, so it deploys index.html and
  # manifest.json and nothing else. `PAGES=0` leaves the manifest local.
  if [ "${PAGES:-1}" = "1" ]; then
    local project=${PROJECT:-bountystash-assets}
    nix-shell -p wrangler --run \
      "bash '$repo/scripts/task/pages-deploy.sh' '$IMAGES_ROOT/site-dist' --project-name=$project --branch=main" ||
      say "publish: the frontend deploy failed; the manifest is written locally and the site still serves the last one"
  fi
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
  blog) shift && cmd_blog "$@" ;;
  wallpaper) cmd_wallpaper ;;
  *) die "usage: image-daily.sh plan|run|status|judge PATH|publish|blog [--dir PATH]|wallpaper" ;;
esac
