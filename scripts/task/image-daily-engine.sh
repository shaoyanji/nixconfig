#!/usr/bin/env bash
# image-daily-engine.sh — generation and publish machinery: the judge, the
# attempt ledger, staging, the manifest and deploy, and the roster helpers.
# Sources image-daily-lib.sh itself: a command that spends images or touches
# the bank sources this file, a read-only command sources the lib only.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


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
A portrait of a woman must read as a woman: a heavy square jaw, a thick neck, a
flat broad brow, a masculine or androgynous face, or a torso widened and
flattened by bulky armour is a defect — name it and reroll, however well the
image is made. The same reroll applies to a harsh cold read: sunken gaunt
cheeks, an angular hollowed jaw, a hard unblinking stare, or a smooth featureless
mannequin face — a visor that has swallowed the whole face counts — because that
is an unpleasant mask rather than a woman. A plate that reads as a man at all — a
male face, a flat chest, a male build — is a reject rather than a reroll: the row
itself is wrong, so do not spend a second image on it.
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


# A re-render overwrites the plate it replaces, and the earlier plate is the one
# an operator may want back: on 2026-11-16 the second Mortred read worse than the
# bust it replaced, and the better render survived only as a Cloudinary version.
# Copy the file away before the generator is pointed at its path. Stamped, so a
# slug can accumulate renders and `variants` lists them oldest first.

archive_prior() { # file
  local f=$1 rel stamp dest
  [ -f "$f" ] || return 0
  rel=${f#"$IMAGES_ROOT/src/"}
  rel=${rel#"$IMAGES_ROOT/published/"}
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  dest="$IMAGES_ROOT/variants/${rel%.*}.$stamp.${rel##*.}"
  # Two plates can be archived inside the same second, and a stamp that collides
  # overwrites the copy the operator just asked to keep — measured 2026-11-16,
  # when a restore overwrote its own source and put the replaced plate straight
  # back. A counter keeps both; the name stays sortable by when it was archived.
  local n=1
  while [ -e "$dest" ]; do
    n=$((n + 1))
    dest="$IMAGES_ROOT/variants/${rel%.*}.$stamp-$n.${rel##*.}"
  done
  mkdir -p "$(dirname "$dest")"
  cp -f "$f" "$dest" && say "archived prior render: variants/${dest#"$IMAGES_ROOT/variants/"}"
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
  archive_prior "$file"

  # 429 is a burst limit, not a spent day: `cpg usage` still reports the
  # allowance, so waiting is the right answer and recording a failure is not.
  # Measured 2026-11-10: 26 plates in 30 minutes, then every call for the next 21
  # seconds answered RATE_LIMITED while 74 images remained.
  # The size in the request is not the size in the file. Read the PNG before the
  # plate counts: a generation that ignored `-s` is deleted here and recorded as
  # a failure, not discovered as a stripe on someone's screen. Checked before the
  # call because a plate spent without a way to measure it is spent blind.
  command -v ffprobe >/dev/null || die "ffprobe is required to verify a plate's size (pkgs.ffmpeg)"
  local out rc=0 tries=0 wait got
  # The burst window is the real ceiling on this plan, so how long to wait for it
  # is a caller's decision: a nightly brief gives up after three tries and moves
  # on, a requested plate round waits the window out.
  local tries_max=${RATE_TRIES:-3} base=${RATE_WAIT:-60} ceiling=${RATE_WAIT_MAX:-900}
  # Waiting the burst window out is a budget per row, not per attempt: with
  # RATE_TRIES=8 and a 900 s ceiling one stuck row held the lock for two hours
  # while twenty other rows waited their turn (2026-11-16). A row that spends the
  # budget closes the window for the whole round — the next row would be probing
  # the same closed bucket, one ladder at a time.
  local waited=0 max_wait=${RATE_WAIT_TOTAL:-420}
  while :; do
    out=$(cpg image --json -s "$size" -o "$file" "$prompt" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ -s "$file" ]; then
      got=$(dimensions "$file")
      [ "$got" = "$size" ] && break
      rm -f "$file"
      record "$day" "$lane" "$id" "$file" "failed" \
        "asked for $size, got ${got:-no readable png}" "$prompt" "$n" "$rev"
      say "$id: asked for $size, got ${got:-unreadable}; plate discarded"
      return 1
    fi
    if printf '%s' "$out" | grep -q '429\|RATE_LIMITED'; then
      # A 429 at zero allowance is the day, not the bucket: the ladder below would
      # sleep out its whole budget against a limit that resets hours later, and the
      # round's kept plates stay unpublished until the loop reaches its end
      # (measured 2026-11-17: 1800 s slept at 100/100). Nothing is recorded, so the
      # row is still pending for the next slot.
      if [ "$(remaining || echo 1)" -le 0 ]; then
        say "$id: allowance spent — waiting cannot reopen the bucket"
        return 3
      fi
      tries=$((tries + 1))
      if [ "$tries" -gt "$tries_max" ] || [ "$waited" -ge "$max_wait" ]; then
        record "$day" "$lane" "$id" "$file" "failed" \
          "burst window closed after ${waited}s (${tries} attempt(s))" "$prompt" "$n" "$rev"
        say "$id: burst window still closed after ${waited}s — the round stops here"
        return 2
      fi
      wait=$((base * (1 << (tries - 1))))
      [ "$wait" -gt "$ceiling" ] && wait=$ceiling
      # Never sleep past what this row has left to spend.
      [ $((waited + wait)) -gt "$max_wait" ] && wait=$((max_wait - waited))
      [ "$wait" -gt 0 ] || wait=1
      say "$id: rate limited, waiting ${wait}s"
      sleep "$wait"
      waited=$((waited + wait))
      continue
    fi
    # A size the resolved model refuses is not a defect in the row: the free
    # catalog is resolved per call, and on 2026-11-18 ~90 plates answered
    # VALIDATION_FAILED on `size` at 1536x1024 while the same prompt and size
    # succeeded minutes later. Retry once at a size both models take — the plate
    # is smaller and every crop downstream is local.
    if printf '%s' "$out" | grep -q 'VALIDATION_FAILED' && printf '%s' "$out" | grep -q 'size' && [ "$size" != 1024x1024 ]; then
      say "$id: $size refused by the resolved model — retrying at 1024x1024"
      size=1024x1024
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
    if [ "$rc" -eq 3 ]; then
      say "lane $lane: allowance spent, stopping early"
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
  local day file rel out base
  while IFS= read -r file; do
    # A legacy row can carry a log line before its path: `say` wrote to stdout
    # until 2026-11-10 and `attempt` is read as a capture, so nine rows hold
    # "…rate limited…\n/path". The path is the last line either way.
    case $file in *$'\n'*) file=${file##*$'\n'} ;; esac
    rel=${file#"$IMAGES_ROOT/src/"}
    # The ledger is append-only and a path in it can be stale: a plate deleted for
    # being the wrong subject leaves a keep behind, and a slug re-rendered on a
    # later day leaves the earlier row pointing at the file the new render
    # replaced. Skipping is right — one old row must not fail the manifest — but
    # six lines per publish saying so is not: count them, say it once.
    if [ ! -f "$file" ]; then
      base=$(basename "$rel")
      if compgen -G "$IMAGES_ROOT/published/${rel%%/*}/*/$base" >/dev/null; then
        PUBLISH_SHIFTED=$((PUBLISH_SHIFTED + 1))
      else
        PUBLISH_GONE=$((PUBLISH_GONE + 1))
      fi
      continue
    fi
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
# The roster's own sentence is the plate's description, so the gallery can say what a
# plate shows without a second file to keep in sync. Only two pieces are machinery —
# the `arch:` token and the palette-tail — and both come out of the prose, which is
# what a reader wants. A row that is held keeps its text after the `hold:` prefix.

plates_description() {
  local roster=$repo/lib/image-daily/plates.txt
  {
    # A judge sentence first, as the weakest source: for the 2026-11-10 batch the
    # only prose that ever described the picture is the verdict's own sentence
    # ("clean minimalist dunes with smooth rolling curves"). A reason that is an
    # error or a backfill says nothing about the image, so it is skipped.
    if [ -f "$LEDGER" ]; then
      jq -r 'select(type == "object") | select((.prompt // "") == "")
        | (.reason // "") as $r
        | select($r != "")
        | select(($r | ascii_downcase | test("error|429|backfilled|rate limited|agy exited") | not))
        | [(.path | split("/") | last | sub("\\.(png|jpg|jpeg|webp)$"; "")), $r]
        | @tsv' "$LEDGER" 2>/dev/null || true
    fi
    # Briefs next, as the weakest real sentence: the oldest plates predate the ledger's
    # prompt column, and their sentence is still on the brief they came from. A
    # brief id carries its lane as a prefix, which is not part of the slug.
    if [ -f "$BRIEFS" ]; then
      jq -r '.briefs[]?
        | [(.id | sub("^(wall|blog|badge|site)-"; "") | sub("^(char|plate)-"; "")), (.prompt // "")]
        | @tsv' "$BRIEFS" 2>/dev/null || true
    fi
    # The ledger next, oldest to newest: every plate was made by a sentence, so a
    # plate the roster no longer carries (an older hand-run batch, a blog banner,
    # a badge) still reads as itself instead of showing an empty card.
    if [ -f "$LEDGER" ]; then
      jq -r 'select(type == "object") | select((.prompt // "") != "")
        | [(.path | split("/") | last | sub("\\.(png|jpg|jpeg|webp)$"; "")), .prompt]
        | @tsv' "$LEDGER" 2>/dev/null || true
    fi
    # The roster last, so its sentence wins over an earlier ledger prompt.
    if [ -f "$roster" ]; then
      awk -F'|' '/^#/ { next } NF < 2 { next } { print $1 "\t" $2 }' "$roster"
    fi
  } | awk -F'\t' '
    {
      # `d` is the map, so the sentence needs its own name: using `d` for both is a
      # fatal "attempt to use scalar as an array", and the whole description stream
      # then reads as no descriptions at all (2026-11-22, 651 empty cards).
      slug = $1
      desc = $2
      sub(/^hold: .* :: /, "", desc)
      gsub(/arch:[a-z0-9-]+/, "", desc)
      sub(/[[:space:]]*4k, photorealistic, realistic, neumorphism\.?[[:space:]]*$/, "", desc)
      gsub(/[[:space:]]+/, " ", desc)
      sub(/^ /, "", desc)
      sub(/ $/, "", desc)
      # A card has room for a sentence, not a paragraph: the verdict strings run long.
      if (length(desc) > 300) desc = substr(desc, 1, 297) "..."
      if (desc != "") d[slug] = desc
    }
    END { for (s in d) print s "\t" d[s] }'
}


build_index() {
  local out=$IMAGES_ROOT/published/manifest.json
  local shell=$repo/lib/image-daily/site/index.html
  local dist=$IMAGES_ROOT/site-dist
  [ -f "$shell" ] || die "missing the asset frontend at $shell"
  [ -s "$IMAGES_ROOT/published/urls.tsv" ] || die "no urls.tsv yet — the manifest is built from it"
  mkdir -p "$dist"
  # slug -> description, so a plate's sentence travels into the gallery. An empty
  # object is a roster that is missing or has no prose, not an error: the manifest
  # still builds, and `description` is then an empty string.
  # A file, not `--argjson`: the roster's prose is a hundred kilobytes, and one
  # argv entry is capped near 128 KB, so a 500-row roster failed the exec with
  # "Argument list too long" (2026-11-22, the first round to publish at 506 rows).
  # `--slurpfile` keeps the prose off the command line.
  # Shape travels with the manifest so the gallery can offer a phone filter: a
  # portrait plate cropped into a 1200x630 card is a stripe of itself. Measured
  # once per file and cached, because ffprobe over the whole tree on every
  # publish is the difference between a quick publish and a slow one.
  local shapes=$IMAGES_ROOT/published/shapes.tsv rel file dim
  [ -f "$shapes" ] || : >"$shapes"
  while IFS=$'\t' read -r rel _ _; do
    [ -n "$rel" ] || continue
    grep -qF -- "$rel"$'\t' "$shapes" && continue
    file=$IMAGES_ROOT/published/$rel
    [ -f "$file" ] || file=$IMAGES_ROOT/src/$rel
    [ -f "$file" ] || continue
    dim=$(dimensions "$file" 2>/dev/null) || continue
    [ -n "$dim" ] && printf '%s\t%s\n' "$rel" "$dim" >>"$shapes"
  done <"$IMAGES_ROOT/published/urls.tsv"
  local shape_file
  shape_file=$(mktemp) || die "no temp file for the asset shapes"
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") as $f | {key: $f[0], value: ($f[1] // "")}) | from_entries' \
    <"$shapes" >"$shape_file" || printf '{}\n' >"$shape_file"

  local meta_file
  meta_file=$(mktemp) || die "no temp file for the roster descriptions"
  plates_description |
    jq -R -s 'split("\n") | map(select(length > 0) | split("\t") as $f | {key: $f[0], value: ($f[1] // "")}) | from_entries' >"$meta_file" ||
    printf '{}\n' >"$meta_file"
  # Rows are path, URL, bytes. `public_id` is what a person searches and what
  # Cloudinary addresses; `day` is empty for a blog banner, whose slug carries it.
  jq -Rn --arg ts "$(date -u +%FT%TZ)" --argjson stop "$TAG_STOP" \
    --slurpfile meta "$meta_file" --slurpfile shape "$shape_file" '
    [inputs | select(length > 0) | split("\t")
      | {path: .[0], url: .[1], bytes: ((.[2] // "0") | tonumber)}]
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
        # The name a person reads, from the file name: a slug is a search key, not
        # a caption. `enhanced` is the same plate at 2400 px with a sharpen, which
        # is what a wallpaper wants; the stored upload stays the untouched render.
        title: ($a.name | sub("\\.(png|jpg|jpeg|webp)$"; "") | split("-")
          | map(select(length > 0) | (.[0:1] | ascii_upcase) + .[1:]) | join(" ")),
        description: ($meta[0][$a.name | sub("\\.(png|jpg|jpeg|webp)$"; "")] // ""),
        shape: ($shape[0][$a.path] // ""),
        enhanced: ($a.url | sub("/upload/"; "/upload/w_2400,c_limit,e_sharpen:70,q_auto:best,f_auto/")),
        tags: ([$a.public_id | split("/")[] | select(test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)
          | split("-")[] | split("_")[] | ascii_downcase
          | select(length > 2) | select(test("^[0-9]+$") | not) | select(. != $a.lane)
          | select(. as $t | ($stop | index($t)) == null)] | unique)
      })
    | sort_by(.path)
    | {generatedAt: $ts, count: length,
       tags: ([.[] | .tags[]] | group_by(.) | map({tag: .[0], count: length}) | sort_by(-.count, .tag)),
       assets: .}
  ' <"$IMAGES_ROOT/published/urls.tsv" >"$out.tmp" || {
    rm -f "$out.tmp" "$meta_file" "$shape_file"
    die "build_index: the manifest did not build (the served one is untouched)"
  }
  # Written beside and moved into place: a redirect that fails truncates its
  # target, and a truncated manifest.json reads as "0 assets served", which the
  # shrink guard then cannot compare against (2026-11-22).
  mv -f "$out.tmp" "$out"
  rm -f "$meta_file" "$shape_file"
  cp -f "$shell" "$dist/index.html"
  cp -f "$out" "$dist/manifest.json"
  say "manifest: $(jq -r '.count' "$out") asset(s), $(du -sh "$dist" | cut -f1) of frontend"
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


# Cloudinary is the bank. The manifest is a view of the account, not of the disk:
# an upload with no row is an asset the gallery cannot show, and the ways to get
# one are ordinary — a publish from a host holding a slice of the tree, or a render
# written by `images:gen` that no round picked up. Measured 2026-11-21: 796
# uploads, 195 with no row, 118 of them real plates that nothing could serve.
#
# The id is the path without its extension, so the row is derivable both ways, and
# a badge is addressed by host rather than by day. Adoption never rewrites a row
# that exists: the URL already being served is the one consumers have.

adopt_cloudinary() {
  local rows=$IMAGES_ROOT/published/urls.tsv
  local list=$IMAGES_ROOT/published/.ids.$$ all=$IMAGES_ROOT/published/.all.$$
  local add=$IMAGES_ROOT/published/.adopt.$$ have=$IMAGES_ROOT/published/.paths.$$
  local n=0 added=0
  [ -s "$rows" ] || return 0
  if ! bash "$repo/scripts/task/cloudinary.sh" list --prefix "${ADOPT_PREFIX:-assets/}" --json >"$list" 2>"$list.err"; then
    say "adopt: Cloudinary listing unreadable ($(head -1 "$list.err" 2>/dev/null)); the rows stay the manifest"
    rm -f "$list" "$list.err"
    return 0
  fi
  rm -f "$list.err"
  n=$(grep -c . "$list" || true)
  jq -r '
    select(.public_id and .secure_url)
    | (.format // "png") as $fmt
    | (.public_id | sub("^assets/"; "")) as $rel
    | ($rel | split("/")) as $parts
    | ($parts[0]) as $lane
    | if (($lane == "wall" or $lane == "site" or $lane == "blog") and ($parts | length) > 1) then
        [$rel + "." + $fmt, .secure_url, ((.bytes // 0) | tostring)] | @tsv
      elif ($lane == "fleet" and ($parts | length) == 2) then
        ["badge/" + $parts[1] + "." + $fmt, .secure_url, ((.bytes // 0) | tostring)] | @tsv
      else empty end
  ' "$list" >"$all"
  cut -f1 "$rows" >"$have"
  # One upload family is deliberately not gallery work: the 2026-11 batch of a
  # hundred `wallpaper-NNN` generics, made before the roster existed, is a test of
  # the generator rather than a plate anything asked for. They stay on the account
  # and out of the manifest; `ADOPT_SKIP=` (empty) adopts everything, and a real
  # deletion is `images:gc`, not invisibility.
  local skip=${ADOPT_SKIP-wallpaper-[0-9]+}
  awk -F'\t' -v have="$have" -v skip="$skip" '
    BEGIN { while ((getline l < have) > 0) seen[l] = 1 }
    !($1 in seen) && (skip == "" || $1 !~ skip)
  ' "$all" >"$add"
  added=$(grep -c . "$add" || true)
  if [ "${added:-0}" -gt 0 ] && [ "${DRY:-0}" != "1" ]; then
    cat "$rows" "$add" | sort -t"$(printf '\t')" -k1,1 >"$rows.merged" && mv -f "$rows.merged" "$rows"
  fi
  say "adopt: ${added:-0} upload(s) with no row, out of ${n:-0} on Cloudinary"
  rm -f "$list" "$all" "$add" "$have"
}


# Rotation is a judgement, not a timer: `in` is approval and priority, `out` is a
# rejection with its reason (lib/image-daily/rotation.json). The first approved id
# that resolves is the wallpaper, so the order is the operator's to move, not a
# sort of filenames. A rejected plate never rotates however new it is, and a plate
# in neither list is unjudged rather than bad, so nothing lands on a screen on the
# strength of its date alone. With no approval list yet, the newest unrejected
# plate is used, which is what a lane nobody has looked at gets.
# A wallpaper is landscape. A square plate under `swaybg -m fill` is cropped to a
# stripe of itself, which reads on a screen as a broken wallpaper rather than as a
# wrong request — so the shape is measured where the plate is chosen. The size a
# generator returns is not the size it was asked for until someone reads it.

dimensions() {
  ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$1" 2>/dev/null |
    awk -F, 'NF == 2 {print $1 "x" $2}'
}


landscape() {
  local d w h
  d=$(dimensions "$1")
  [ -n "$d" ] || return 1
  w=${d%x*}
  h=${d#*x}
  [ "$h" -gt 0 ] && [ $((w * 10 / h)) -ge 12 ]
}


resolve_plate() {
  local taste_root=$1 want=$2 candidate
  case $want in
    # A taste-test plate never entered the bank: it was drawn to pick a style,
    # so it sits in the folder beside generated/ rather than in a lane.
    taste/*)
      candidate=$taste_root/${want#taste/}
      [ -f "$candidate" ] && printf '%s\n' "$candidate" && return 0
      ;;
    *)
      # published wins over the original of the same id. Sorting whole paths
      # would put src/ above published/, because "s" > "p".
      for candidate in "$IMAGES_ROOT/published/wall/$want" "$IMAGES_ROOT/src/wall/$want"; do
        [ -f "$candidate" ] && printf '%s\n' "$candidate" && return 0
      done
      ;;
  esac
  return 1
}


# Rows with no kept plate: what a round is still waiting for. kept_plate answers
# per row and re-reads the ledger every time, so a whole-roster answer is one pass
# over both files instead.

roster_pending() { # roster
  local all kept
  all=$(mktemp) && kept=$(mktemp) || return 0
  awk -F'|' '!/^#/ && NF > 1 && $2 !~ /^hold:/ {print "photoreal-" $1}' "$1" | sort -u >"$all"
  { [ -f "$LEDGER" ] && jq -r 'select(type == "object") | select(.verdict == "keep") | .brief' "$LEDGER"; } 2>/dev/null | sort -u >"$kept"
  comm -23 "$all" "$kept" | wc -l | tr -d ' '
  rm -f "$all" "$kept"
}


# A round is a job, not a call: one plate is about a minute and a closed burst
# window can add a quarter of an hour. The unit outlives the shell that starts it,
# and the state file is what a later turn reads instead of a log it must watch.

launch_round() { # roster
  local roster=$1 unit stamp state=$IMAGES_ROOT/.round.json
  command -v systemd-run >/dev/null ||
    die "systemd-run is required to detach a round (run it in the foreground with DETACH=0)"
  stamp=$(date +%Y%m%d-%H%M%S)
  unit=image-plates-$stamp
  mkdir -p "$IMAGES_ROOT"
  # The env is passed explicitly: a unit inherits nothing from this shell, and the
  # RATE_* budget is what decides whether a closed window waits or ends the round.
  # The working directory matters: `$0` is a repo-relative path when the task runs
  # it, and a unit that starts in `$HOME` then cannot find the script and dies with
  # status 127 (2026-11-22, the first detached round of the day).
  systemd-run --user --unit "$unit" --collect \
    --working-directory="$repo" \
    --setenv=PATH="$PATH" \
    --setenv=REPO="$repo" --setenv=IMAGES_ROOT="$IMAGES_ROOT" \
    --setenv=ROSTER="$roster" --setenv=DETACH=0 \
    --setenv=ONLY="${ONLY:-}" --setenv=MAX_GEN="${MAX_GEN:-0}" \
    --setenv=SIZE="${SIZE:-1536x1024}" --setenv=FORCE="${FORCE:-0}" \
    --setenv=PUBLISH="${PUBLISH:-1}" --setenv=APPROVE="${APPROVE:-1}" \
    --setenv=PAGES="${PAGES:-1}" --setenv=DRY="${DRY:-0}" \
    --setenv=XS_SUMMARY="${XS_SUMMARY:-1}" \
    --setenv=RATE_TRIES="${RATE_TRIES:-8}" --setenv=RATE_WAIT="${RATE_WAIT:-300}" \
    --setenv=RATE_WAIT_MAX="${RATE_WAIT_MAX:-900}" --setenv=RATE_WAIT_TOTAL="${RATE_WAIT_TOTAL:-3600}" \
    -- bash "$0" plates >/dev/null
  jq -cn --arg unit "$unit" --arg roster "$roster" \
    --arg started "$(date -u +%FT%TZ)" --arg pending "$(roster_pending "$roster")" \
    --arg left "$(remaining || echo 0)" \
    '{state: "started", unit: $unit, roster: $roster, started: $started,
      pending: (($pending // "0") | tonumber), left: (($left // "0") | tonumber)}' |
    tee "$state"
}



# A slot's share of what the day has left: ceil(left / slots_left), clamped to the
# hourly burst ceiling and to at least one. One implementation, two callers — the
# slot wrapper in hosts/frieren/infra-stack.nix asks for `share`, and `today` prints
# what the next slot will take, so the readout cannot drift from the spend.

slot_share() { # left slots_left
  local left=$1 slots=${2:-1} cap
  case $left in "" | *[!0-9]*) left=0 ;; esac
  case $slots in "" | *[!0-9]* | 0) slots=1 ;; esac
  cap=$(((left + slots - 1) / slots))
  [ "$cap" -gt 25 ] && cap=25
  [ "$cap" -lt 1 ] && cap=1
  printf '%s\n' "$cap"
}

