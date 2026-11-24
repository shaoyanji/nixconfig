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
# never publishes. The judge is `image-daily judge` in tools/image-daily now;
# the shell callers above pass it the same flags they passed the function.


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
# eat the allowance. Generation is `image-daily attempt` and the lane loop is
# `image-daily lane` in tools/image-daily; the wrappers call them with the same
# contract (rc 0/1/2/3, a file path on stdout, say() on stderr).



# --- publish ----------------------------------------------------------------
# The published tree accumulates; a deploy replaces the whole site, so it must
# carry every earlier day or the history disappears on the second run.

# Staging is `image-daily stage` in tools/image-daily: it reads the lane's keep
# rows, skips shifted/gone source files safely, and crops blog banners itself.
# The ledger is append-only and a path in it can be stale — a plate deleted for
# being the wrong subject leaves a keep behind — so stale rows are counted and
# skipped, never fatal: one old row must not fail the manifest.


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

# The manifest is the Go tool's job now (tools/image-daily, .#cli.image.daily):
# it reads the same urls.tsv, ledger, briefs and roster the jq/awk used to and
# emits the same manifest byte for byte — verified against the live bank.
# The resolver (IMAGE_DAILY_BIN → PATH → one nix build) lives in
# image-daily-lib.sh as `image_daily_cli` so read-only scripts reach it too.


build_index() {
  local out=$IMAGES_ROOT/published/manifest.json
  local shell=$repo/lib/image-daily/site/index.html
  local dist=$IMAGES_ROOT/site-dist
  [ -f "$shell" ] || die "missing the asset frontend at $shell"
  [ -s "$IMAGES_ROOT/published/urls.tsv" ] || die "no urls.tsv yet — the manifest is built from it"
  mkdir -p "$dist"
  # Shape travels with the manifest so the gallery can offer a phone filter: a
  # portrait plate cropped into a 1200x630 card is a stripe of itself. Measured
  # once per file and cached in published/shapes.tsv — the tool owns the loop
  # now (`image-daily shapes`), ffprobe per uncached rel, published before src.
  "$(image_daily_cli)" shapes --root "$IMAGES_ROOT"

  # Written beside and moved into place: a redirect that fails truncates its
  # target, and a truncated manifest.json reads as "0 assets served", which the
  # shrink guard then cannot compare against (2026-11-22).
  local tmp
  tmp=$(mktemp) || die "no temp file for the manifest"
  "$(image_daily_cli)" manifest --root "$IMAGES_ROOT" --repo "$repo" >"$tmp" || {
    rm -f "$tmp"
    die "build_index: the manifest did not build (the served one is untouched)"
  }
  mv -f "$tmp" "$out"
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

# Adoption is `image-daily adopt` in tools/image-daily — same mapping rules, and
# the same skip family: the 2026-11 batch of a hundred `wallpaper-NNN` generics
# is a test of the generator rather than a plate anything asked for. They stay
# on the account and out of the manifest; `ADOPT_SKIP=` (empty) adopts
# everything, and a real deletion is `images:gc`, not invisibility.


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
    --arg started "$(date -u +%FT%TZ)" --arg pending "$("$(image_daily_cli)" pending --roster "$roster")" \
    --arg left "$(remaining || echo 0)" \
    '{state: "started", unit: $unit, roster: $roster, started: $started,
      pending: (($pending // "0") | tonumber), left: (($left // "0") | tonumber)}' |
    tee "$state"
}



# A slot's share is `image-daily share` in tools/image-daily: ceil(left /
# slots_left) clamped to the burst ceiling, one implementation for the slot
# wrapper in hosts/frieren/infra-stack.nix and for `today`.

