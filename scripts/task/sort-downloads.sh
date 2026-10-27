#!/usr/bin/env bash
# scripts/task/sort-downloads.sh — sort finished downloads out of staging.
#
# The destination is decided by what the item IS (docs/storage-taxonomy.md), not
# by its extension alone: a `.tar.gz` is a phone image or a software bundle
# depending on what it is, and an ISO is a boot image, not "an .iso file".
# Extension rules are the fallback, and anything genuinely unknown is reported
# instead of guessed — staging is the one place a wrong move is cheap to avoid.
#
# Dry-run by default. Nothing moves, nothing is deleted, until --apply.
set -euo pipefail

# DATA_ROOT is overridable so the sorter can be exercised against a sandbox
# tree instead of the live pool; empty means autodetect.
DATA_ROOT="${DATA_ROOT:-}"
if [ -z "$DATA_ROOT" ]; then
  if [ -d "/srv/data" ]; then
    DATA_ROOT="/srv/data"
  elif [ -d "/Volumes/data" ]; then
    DATA_ROOT="/Volumes/data"
  else
    echo "Error: neither /srv/data nor /Volumes/data is mounted (set DATA_ROOT to override)." >&2
    exit 2
  fi
fi

DOWNLOADS="${DOWNLOADS:-$DATA_ROOT/downloads}"
BOOKS="${BOOKS:-$DATA_ROOT/books}"
VIDEO_DIR="${VIDEO_DIR:-$DATA_ROOT/arr}"
AUDIO_DIR="${AUDIO_DIR:-$DATA_ROOT/music}"
ISO_DIR="${ISO_DIR:-$DATA_ROOT/isos}"
APPLIANCE_DIR="${APPLIANCE_DIR:-$ISO_DIR/appliances}"
LINUX_DIR="${LINUX_DIR:-$ISO_DIR/linux}"
APPIMAGE_DIR="${APPIMAGE_DIR:-$DATA_ROOT/appimages}"
DEVICE_DIR="${DEVICE_DIR:-$DATA_ROOT/devices}"
SOFTWARE_DIR="${SOFTWARE_DIR:-$DATA_ROOT/software}"
PAPERLESS_CONSUME="${PAPERLESS_CONSUME:-$DATA_ROOT/paperless/consume}"
REJECTED="${REJECTED:-$DOWNLOADS/.rejected}"

QUIET_SECONDS="${QUIET_SECONDS:-120}"
JELLYFIN_URL="${JELLYFIN_URL:-http://127.0.0.1:8096}"
JELLYFIN_TOKEN="${JELLYFIN_TOKEN:-}"
PLEX_URL="${PLEX_URL:-http://127.0.0.1:32400}"
PLEX_TOKEN="${PLEX_TOKEN:-}"
RPC_SECRET_FILE="${RPC_SECRET_FILE:-/run/secrets/aria2-rpc-secret}"
RPC_URL="${RPC_URL:-http://127.0.0.1:6800/jsonrpc}"

# Second classification layer, opt-in. The kind rules below decide the common
# case from what the file IS; when they cannot place an item (or the name is
# ambiguous, as an ISO's name usually is), one local model call picks a
# destination from the fixed taxonomy list. It never supplies a media title —
# a title the media server cannot match is worse than an unplaced file.
CLASSIFY="${CLASSIFY:-0}"
CLASSIFY_BIN="${CLASSIFY_BIN:-jev-decide}"
CLASSIFY_PROVIDER="${CLASSIFY_PROVIDER:-typesafe}"
CLASSIFY_MIN_PROBABILITY="${CLASSIFY_MIN_PROBABILITY:-0.8}"
MODEL_CRITERIA=""

# A finished torrent seeds forever at seed-ratio 0, so "still seeding" is not a
# reason to leave an item staged. Set KEEP_SEED=1 to leave seeds alone.
KEEP_SEED="${KEEP_SEED:-0}"

APPLY=0
REPLACE=0
OWNERSHIP_FAILED=0

usage() {
  cat <<'EOF'
Usage: sort-downloads.sh [--apply] [--replace] [--quiet SECONDS] [--classify]

  (no flags)   print the plan; change nothing
  --apply      move/delete/scan as planned
  --replace    allow overwriting a destination that exists with other content
  --quiet N    treat files modified within N seconds as still in flight (120)
  --classify   ask a local model to pick a destination when the rules cannot
               (needs jev-decide on PATH; ignored, with a warning, if absent)
  --keep-seed  leave a completed torrent seeding instead of releasing it
               (default: a finished seed is stopped so its item can be sorted)

Exit codes: 0 everything landed, 1 items need a human decision, 2 usage/root error.

--apply as root also normalises ownership (devji:users) and mode on what it
moves; as a normal user the moves still happen but the chown is reported.
EOF
}

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --replace) REPLACE=1 ;;
    --classify) CLASSIFY=1 ;;
    --keep-seed) KEEP_SEED=1 ;;
    --quiet)
      QUIET_SECONDS="${2:?--quiet needs a value}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

moved_media=0
moved_books=0
moved_other=0
pending=0
inflight=0
unknown=0
released=0

say() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }

# The knobs above are absolute; place() works in paths relative to DATA_ROOT so
# an overridden destination directory cannot escape the taxonomy by accident.
rel_of() { printf '%s\n' "${1#"$DATA_ROOT"/}"; }

# aria2 knows what is still in flight — including a finished torrent that is
# still seeding, which looks complete on disk but breaks when the file moves.
# Two maps, because a completed seed is a finished download, not a running one:
# ACTIVE blocks a move, SEEDING means "stop the seed, then move it".
declare -A ACTIVE=()
declare -A SEEDING=()
RPC_SECRET=""
load_active() {
  local json method gid path seeder completed total
  RPC_SECRET="$(cat "$RPC_SECRET_FILE" 2>/dev/null || sudo -n cat "$RPC_SECRET_FILE" 2>/dev/null || true)"
  if [ -z "$RPC_SECRET" ]; then
    # A seeding torrent has no control file, so without RPC its file looks idle.
    warn "note: aria2 state unreadable ($RPC_SECRET_FILE); judging by control files only"
    return 0
  fi
  for method in tellActive tellWaiting; do
    if [ "$method" = tellWaiting ]; then
      json="$(curl -sf -m 5 -X POST "$RPC_URL" -H 'Content-Type: application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"id\":\"sort\",\"method\":\"aria2.$method\",\"params\":[\"token:$RPC_SECRET\",0,100,[\"gid\",\"files\",\"seeder\",\"completedLength\",\"totalLength\"]]}" || true)"
    else
      json="$(curl -sf -m 5 -X POST "$RPC_URL" -H 'Content-Type: application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"id\":\"sort\",\"method\":\"aria2.$method\",\"params\":[\"token:$RPC_SECRET\",[\"gid\",\"files\",\"seeder\",\"completedLength\",\"totalLength\"]]}" || true)"
    fi
    [ -n "$json" ] || continue
    # Tab-separated: a downloaded path may contain spaces, so a space-delimited
    # read would split one file into several fields.
    while IFS=$'\t' read -r gid path seeder completed total; do
      [ -n "$path" ] || continue
      ACTIVE["$path"]="$gid"
      if [ "$seeder" = true ] && [ -n "$completed" ] && [ "$completed" = "$total" ]; then
        SEEDING["$path"]="$gid"
      fi
    # Every file of a torrent, not just the first: a multi-file payload is
    # detected by the largest file, which is rarely files[0].
    done < <(printf '%s' "$json" | jq -r '.result[]? as $t | ($t.files // [])[] | [($t.gid // ""), .path, ($t.seeder // false | tostring), ($t.completedLength // ""), ($t.totalLength // "")] | @tsv' 2>/dev/null || true)
  done
}

# Releases a finished seed. `remove` stops it, and the download record is
# dropped too: a leftover record reappears in tellWaiting and would keep the
# item INFLIGHT forever.
release_seed() {
  local gid=$1
  curl -sf -m 5 -X POST "$RPC_URL" -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"sort\",\"method\":\"aria2.remove\",\"params\":[\"token:$RPC_SECRET\",\"$gid\"]}" >/dev/null || return 1
  sleep 1
  curl -sf -m 5 -X POST "$RPC_URL" -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"sort\",\"method\":\"aria2.removeDownloadResult\",\"params\":[\"token:$RPC_SECRET\",\"$gid\"]}" >/dev/null || true
  return 0
}

is_quiet() {
  local f=$1 age
  age=$(($(date +%s) - $(stat -c %Y "$f")))
  ((age >= QUIET_SECONDS))
}

# The largest regular file inside a torrent payload directory is the item. A
# directory is never moved wholesale — its siblings (README, flash script) are
# part of the download, not part of the taxonomy.
payload_of() {
  local item=$1
  if [ -d "$item" ]; then
    find "$item" -maxdepth 2 -type f ! -name '*.aria2' -printf '%s %p\n' 2>/dev/null |
      sort -rn | head -1 | cut -d' ' -f2- || true
  else
    printf '%s\n' "$item"
  fi
}

title_tag() {
  ffprobe -v error -show_entries format_tags=title -of default=nw=1:nk=1 "$1" 2>/dev/null |
    head -1 || true
}

year_in() {
  printf '%s' "$1" | grep -oE '(19|20)[0-9]{2}' | head -1 || true
}

squeeze() { printf '%s' "$1" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'; }

# --- second layer: model classification -------------------------------------
# Labels are taxonomy destinations, never free text, so an answer maps to one
# directory and nothing else. A video has no label on purpose: the title has to
# come from the file's own metadata, and a model would invent one.
model_setup() {
  [ "$CLASSIFY" = 1 ] || return 0
  if ! command -v "$CLASSIFY_BIN" >/dev/null 2>&1; then
    warn "classify: $CLASSIFY_BIN not on PATH — rules only"
    CLASSIFY=0
    return 0
  fi
  MODEL_CRITERIA="$(mktemp)"
  trap 'rm -f "$MODEL_CRITERIA"' EXIT
  cat >"$MODEL_CRITERIA" <<'JSON'
{
  "isos/linux": "a Linux or BSD operating system installer or live image",
  "isos/appliances": "a prebuilt appliance OS image: Home Assistant, Batocera, iVentoy, a NAS or firewall image, a Raspberry Pi image",
  "software": "application software, a game, a driver, font pack or utility installer",
  "software/windows": "a Microsoft Windows application or office suite installer",
  "devices": "phone or tablet firmware, recovery image, or rooting payload (oneplus, sdm845, twrp, nethunter)",
  "books": "a book, ebook, manual or scanned document",
  "music": "an album, song or other audio recording",
  "documents": "a letter, invoice, form or office document meant for the paperless archive",
  "reject": "a saved web page or other non-payload not worth keeping",
  "unknown": "not decidable from the filename, size and file type"
}
JSON
}

# Prints one label, or nothing when the model abstained / failed.
model_kind() {
  local file=$1 desc out
  [ "$CLASSIFY" = 1 ] || return 1
  desc="$(basename "$file") — $(stat -c %s "$file" 2>/dev/null | numfmt --to=iec-i --suffix=B 2>/dev/null || echo '?'), $(file -b "$file" 2>/dev/null | tr -s ' ' | cut -c1-90)"
  out="$("$CLASSIFY_BIN" classify --provider "$CLASSIFY_PROVIDER" --text "$desc" \
    --criteria "$MODEL_CRITERIA" --min-probability "$CLASSIFY_MIN_PROBABILITY" \
    --review-label unknown 2>/dev/null |
    jq -r 'select(.decisions.category.status == "selected") | .decisions.category.value' 2>/dev/null || true)"
  case "$out" in
    "" | unknown | null) return 1 ;;
  esac
  printf '%s\n' "$out"
}

# Places by label. Returns 1 for a label this script will not honour, so the
# caller can fall back to reporting instead of guessing.
model_place() {
  local file=$1 label=$2 base
  base=$(basename "$file")
  case "$label" in
    isos/linux) place "$file" "$LINUX_DIR/$base" 0644 other ;;
    isos/appliances) place "$file" "$APPLIANCE_DIR/$base" 0644 other ;;
    software) place "$file" "$SOFTWARE_DIR/$base" 0644 other ;;
    software/windows) place "$file" "$SOFTWARE_DIR/windows/$base" 0644 other ;;
    devices) place "$file" "$DEVICE_DIR/oneplus6/$base" 0644 other ;;
    books) place "$file" "$BOOKS/$base" 0644 books ;;
    music) place "$file" "$AUDIO_DIR/$base" 0644 media ;;
    documents)
      if [ -w "$PAPERLESS_CONSUME" ]; then
        place "$file" "$PAPERLESS_CONSUME/$base" 0644 other
      else
        say "PENDING  $base — paperless consume is not writable"
        pending=$((pending + 1))
      fi
      ;;
    reject)
      say "JUNK     $base — classified as a saved page, not a payload"
      if [ "$APPLY" = 1 ]; then
        mkdir -p "$REJECTED"
        mv -f "$file" "$REJECTED/"
      fi
      moved_other=$((moved_other + 1))
      ;;
    *) return 1 ;;
  esac
  return 0
}

# Only used when a release name states no year, where the quality tags are the
# one thing left to strip. A name WITH a year is cut at the year instead, which
# drops every tag after it without needing to know their names.
strip_tags() {
  printf '%s' "$1" | sed -E '
    s/\[[^]]*\]//g
    s/[._]+/ /g
    s/[[:space:]]*(480p|576p|720p|1080p|2160p|4k|8k)([[:space:]]|$)/ /Ig
    s/[[:space:]]*(bluray|blu-ray|brrip|bdrip|dvdrip|dvdscr|webrip|web-dl|hdtv|remux)([[:space:]]|$)/ /Ig
    s/[[:space:]]*(x264|x265|h264|h265|hevc|xvid|divx|10bit|8bit)([[:space:]]|$)/ /Ig
    s/[[:space:]]*(aac|ac3|eac3|dts|flac|mp3|opus|atmos)([[:space:]]|$)/ /Ig
    s/[[:space:]]+/ /g
  '
}

title_before_year() {
  local raw=$1 year=$2
  if [ -n "$year" ]; then
    printf '%s' "$raw" | sed -E "s/[._ ]*${year}.*\$//"
  else
    printf '%s' "$raw"
  fi
}

# A media server needs a name it can match. The container's title tag is the
# best source; otherwise the release name is cut at its year, which is where
# quality tags begin. Series are placed in the TV layout because SxxExx is
# unambiguous. A film with no year anywhere is still placed and tagged `guess:`
# in the output — the caller reports it — because leaving it in staging forever
# is worse than a name the operator can correct later.
video_target() {
  local f=$1 ext raw sxe season ep show year name base part
  ext="${f##*.}"
  raw="$(basename "$f" ."$ext")"

  sxe=$(printf '%s' "$raw" | grep -oiE 's[0-9]{1,2}e[0-9]{1,2}' | head -1 || true)
  if [ -n "$sxe" ]; then
    season=$(printf '%s' "$sxe" | sed -E 's/^[Ss]0*([0-9]+).*/\1/')
    ep=$(printf '%s' "$sxe" | sed -E 's/^.*[Ee]0*([0-9]+)$/\1/')
    show=$(printf '%s' "$raw" | sed -E 's/[._ -]*[Ss][0-9]{1,2}[Ee][0-9]{1,2}.*//' | tr '._' '  ')
    show="$(squeeze "$show")"
    year="$(year_in "$show")"
    name="$(squeeze "$(title_before_year "$show" "$year")")"
    [ -n "$name" ] || return 1
    base="$name"
    [ -n "$year" ] && base="$name ($year)"
    printf 'ok:%s/Season %02d/%s - S%02dE%02d.%s\n' \
      "$base" "$((10#$season))" "$base" "$((10#$season))" "$((10#$ep))" "$ext"
    return 0
  fi

  name="$(title_tag "$f")"
  if [ -n "$name" ]; then
    # archive.org and friends append the source URL to the title tag.
    name="${name%% - *}"
    year="$(year_in "$name")"
    [ -n "$year" ] && name="$(squeeze "$(title_before_year "$name" "$year")")"
  else
    year="$(year_in "$raw")"
    name="$(title_before_year "$raw" "$year" | tr '._' '  ')"
    name="$(squeeze "$name")"
    if [ -z "$year" ]; then
      name="$(squeeze "$(strip_tags "$name")")"
    fi
  fi
  # A part marker belongs in the filename, not in the title.
  name="$(printf '%s' "$name" | sed -E 's/[[:space:]]*[Pp][Aa][Rr][Tt][[:space:]]*[0-9]+//; s/[[:space:]]*[Pp][Tt][[:space:]]*[0-9]+//; s/[[:space:]]*[Cc][Dd][[:space:]]*[0-9]+//')"
  name="$(squeeze "$name")"
  # A title with no letters is a hashed filename, not a name.
  printf '%s' "$name" | grep -q '[[:alpha:]]' || return 1
  if [ -n "$year" ]; then quality=ok; else quality=guess; fi
  base="$name"
  [ -n "$year" ] && base="$name ($year)"
  part=$(printf '%s' "$raw" | grep -oiE '(part|pt|cd|disc)[ ._-]*[0-9]+' | head -1 | grep -oE '[0-9]+' || true)
  if [ -n "$part" ]; then
    printf '%s:%s/%s - part%s.%s\n' "$quality" "$base" "$base" "$part" "$ext"
  else
    printf '%s:%s/%s.%s\n' "$quality" "$base" "$base" "$ext"
  fi
}

# A directory of videos is one set, not one file. Moving only its largest file
# would scatter a lecture series or a split film across the next few runs, each
# part named on its own — so the set moves under one title.
video_set() {
  local item=$1 count raw year name base
  [ -d "$item" ] || return 1
  count=$(find "$item" -maxdepth 2 -type f \
    \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mov' \
    -o -iname '*.webm' -o -iname '*.m4v' -o -iname '*.mpg' -o -iname '*.mpeg' \) 2>/dev/null | wc -l)
  # One video is enough: a release folder carries its own subtitles and
  # samples, and splitting the video from them is how a library ends up with
  # subtitles the player cannot find.
  [ "$count" -ge 1 ] || return 1
  raw=$(basename "$item")
  year=$(year_in "$raw")
  name=$(title_before_year "$raw" "$year" | tr '._' '  ')
  name=$(squeeze "$name")
  [ -n "$year" ] || name=$(squeeze "$(strip_tags "$name")")
  printf '%s' "$name" | grep -q '[[:alpha:]]' || return 1
  base=$name
  [ -n "$year" ] && base="$name ($year)"
  if [ -n "$year" ]; then quality=ok; else quality=guess; fi
  printf '%s:%s\n' "$quality" "$base"
}

# Directories move whole: nothing inside is renamed, because a set's own file
# names are what the operator recognises.
place_dir() {
  local src=$1 dest_abs=$2 kind=$3 rel dest
  rel="$(rel_of "$dest_abs")"
  dest="$DATA_ROOT/$rel"
  if [ -e "$dest" ]; then
    if [ "$REPLACE" = 1 ]; then
      say "REPLACE  $(basename "$src")/ -> $rel (existing directory replaced)"
      if [ "$APPLY" = 1 ]; then rm -rf "$dest"; fi
    else
      say "CONFLICT $(basename "$src")/ — $rel exists (rerun with --replace)"
      pending=$((pending + 1))
      return 0
    fi
  else
    say "MOVE     $(basename "$src")/ -> $rel/"
  fi
  if [ "$APPLY" = 1 ]; then
    mkdir -p "$(dirname "$dest")"
    if ! mv -f "$src" "$dest"; then
      warn "MOVE FAILED $(basename "$src")/ -> $rel (run with sudo)"
      pending=$((pending + 1))
      return 0
    fi
    if ! chown -R devji:users "$dest" 2>/dev/null; then OWNERSHIP_FAILED=1; fi
    chmod 0755 "$dest" 2>/dev/null || true
    find "$dest" -type f -exec chmod 0644 {} + 2>/dev/null || true
  fi
  case "$kind" in
    media) moved_media=$((moved_media + 1)) ;;
    *) moved_other=$((moved_other + 1)) ;;
  esac
}

same_content() {
  local a=$1 b=$2
  [ -f "$b" ] || return 1
  [ "$(stat -c %s "$a")" = "$(stat -c %s "$b")" ] || return 1
  [ "$(sha256sum "$a" | cut -d' ' -f1)" = "$(sha256sum "$b" | cut -d' ' -f1)" ]
}

place() {
  local src=$1 dest_abs=$2 mode=$3 kind=$4 dest rel
  rel="$(rel_of "$dest_abs")"
  dest="$DATA_ROOT/$rel"
  if [ -e "$dest" ]; then
    if same_content "$src" "$dest"; then
      say "DUP      $(basename "$src") — identical to $rel, staged copy dropped"
      if [ "$APPLY" = 1 ]; then rm -f "$src"; fi
      return 0
    fi
    if [ "$REPLACE" = 1 ]; then
      say "REPLACE  $(basename "$src") -> $rel (other content overwritten)"
      if [ "$APPLY" = 1 ]; then rm -f "$dest"; fi
    else
      say "CONFLICT $(basename "$src") — $rel exists with other content (rerun with --replace)"
      pending=$((pending + 1))
      return 0
    fi
  else
    say "MOVE     $(basename "$src") -> $rel"
  fi
  if [ "$APPLY" = 1 ]; then
    mkdir -p "$(dirname "$dest")"
    if ! mv -f "$src" "$dest"; then
      # Downloads and arr/ are different subvolumes here, so this is a copy plus
      # an unlink — and the unlink happens inside an aria2-owned directory.
      warn "MOVE FAILED $(basename "$src") -> $rel (run with sudo)"
      pending=$((pending + 1))
      return 0
    fi
    if ! chown devji:users "$dest" 2>/dev/null; then OWNERSHIP_FAILED=1; fi
    chmod "$mode" "$dest" 2>/dev/null || true
  fi
  case "$kind" in
    media) moved_media=$((moved_media + 1)) ;;
    books) moved_books=$((moved_books + 1)) ;;
    *) moved_other=$((moved_other + 1)) ;;
  esac
}

classify() {
  local item=$1 file lname ext rel out guessed label
  if out=$(video_set "$item"); then
    case "$out" in
      guess:*)
        rel="${out#guess:}"
        say "GUESS    $(basename "$item")/ — no year to match on; placed as arr/$rel/"
        ;;
      *) rel="${out#ok:}" ;;
    esac
    place_dir "$item" "$VIDEO_DIR/$rel" media
    return 0
  fi
  file=$(payload_of "$item")
  if [ -z "$file" ]; then
    say "UNKNOWN  $item — empty or unreadable directory"
    unknown=$((unknown + 1))
    return 0
  fi
  lname=$(basename "$file" | tr '[:upper:]' '[:lower:]')
  ext="${lname##*.}"

  # Kind first: these are decided by what the payload is, not by extension.
  case "$lname" in
    *.appimage)
      place "$file" "$APPIMAGE_DIR/$(basename "$file")" 0755 other
      return 0
      ;;
    *.html | *.htm)
      say "JUNK     $(basename "$file") — saved web page, not a payload"
      if [ "$APPLY" = 1 ]; then
        mkdir -p "$REJECTED"
        mv -f "$file" "$REJECTED/"
      fi
      moved_other=$((moved_other + 1))
      return 0
      ;;
    *nethunter* | *sdm845* | *sdm850* | *oneplus* | *twrp*)
      place "$file" "$DEVICE_DIR/oneplus6/$(basename "$file")" 0644 other
      return 0
      ;;
    *.iso)
      # An ISO is not automatically Linux: an office suite is software and an
      # appliance image belongs beside its siblings. The name is read first;
      # an uninformative name goes to the model rather than into linux/.
      case "$lname" in
        *haos* | *home*assistant* | *batocera* | *iventoy* | *proxmox* | *pfsense* | *opnsense* | *openwrt* | *raspios*)
          place "$file" "$APPLIANCE_DIR/$(basename "$file")" 0644 other
          return 0
          ;;
        *linux* | *ubuntu* | *debian* | *arch* | *nixos* | *kali* | *fedora* | *alpine* | *gentoo* | *manjaro* | *mint* | *tails* | *winux* | *freebsd* | *windows* | *win10* | *win11*)
          place "$file" "$LINUX_DIR/$(basename "$file")" 0644 other
          return 0
          ;;
      esac
      if label=$(model_kind "$file"); then
        say "MODEL    $(basename "$file") — name names no OS; model says $label"
        model_place "$file" "$label" && return 0
      fi
      say "UNKNOWN  $(basename "$file") — ISO of unknown kind; place it by hand or rerun with --classify"
      unknown=$((unknown + 1))
      return 0
      ;;
    *.img | *.img.gz | *.img.xz | *.img.lzma | *.img.zst | *.raw.xz)
      place "$file" "$APPLIANCE_DIR/$(basename "$file")" 0644 other
      return 0
      ;;
    # Compound suffixes belong here, not in the extension case below: `${f##*.}`
    # on `tool-1.2.tar.gz` is `gz`, so a `.tar.gz` rule there never matches.
    *.tar.gz | *.tgz | *.tar.xz | *.tar.zst | *.tar.bz2 | *.tar)
      place "$file" "$SOFTWARE_DIR/$(basename "$file")" 0644 other
      return 0
      ;;
  esac

  case "$ext" in
    mp4 | mkv | avi | mov | wmv | flv | webm | m4v | ts | mpg | mpeg)
      if ! out=$(video_target "$file"); then
        say "UNKNOWN  $(basename "$file") — no usable title in the file metadata or the name"
        unknown=$((unknown + 1))
        return 0
      fi
      case "$out" in
        guess:*) rel="${out#guess:}"; guessed=1 ;;
        *) rel="${out#ok:}"; guessed=0 ;;
      esac
      if [ "$guessed" = 1 ]; then
        say "GUESS    $(basename "$file") — no year to match on; placed as arr/$rel"
      fi
      place "$file" "$VIDEO_DIR/$rel" 0644 media
      ;;
    mp3 | flac | m4a | ogg | opus | wav | wma | aac | alac)
      place "$file" "$AUDIO_DIR/$(basename "$file")" 0644 media
      ;;
    pdf | epub | mobi | azw3 | djvu | djv)
      place "$file" "$BOOKS/$(basename "$file")" 0644 books
      ;;
    doc | docx | odt | rtf | xlsx | pptx | csv)
      if [ -w "$PAPERLESS_CONSUME" ]; then
        place "$file" "$PAPERLESS_CONSUME/$(basename "$file")" 0644 other
      else
        say "PENDING  $(basename "$file") — paperless consume is not writable"
        pending=$((pending + 1))
      fi
      ;;
    zip | 7z | deb | rpm | exe | msi | dmg | pkg | apk | xz | zst | bz2)
      place "$file" "$SOFTWARE_DIR/$(basename "$file")" 0644 other
      ;;
    *)
      if label=$(model_kind "$file"); then
        say "MODEL    $(basename "$file") — no extension rule; model says $label"
        model_place "$file" "$label" && return 0
      fi
      say "UNKNOWN  $(basename "$file") — no taxonomy rule; add one before moving it"
      unknown=$((unknown + 1))
      ;;
  esac
}

scan_media_libraries() {
  ((moved_media > 0)) || return 0
  [ "$APPLY" = 1 ] || return 0
  if [ -n "$JELLYFIN_TOKEN" ]; then
    curl -sf -X POST "$JELLYFIN_URL/Library/Refresh?api_key=$JELLYFIN_TOKEN" >/dev/null &&
      say "jellyfin: library scan triggered" ||
      warn "jellyfin: scan trigger failed"
  else
    warn "jellyfin: no JELLYFIN_TOKEN, scan not triggered"
  fi
  if [ -n "$PLEX_TOKEN" ]; then
    curl -sf -X GET "$PLEX_URL/library/sections/all/refresh?X-Plex-Token=$PLEX_TOKEN" >/dev/null &&
      say "plex: library scan triggered" ||
      warn "plex: scan trigger failed"
  else
    warn "plex: no PLEX_TOKEN, scan not triggered"
  fi
}

post_books() {
  ((moved_books > 0)) || return 0
  [ "$APPLY" = 1 ] || return 0
  if [ -x "$BOOKS/batch2md.sh" ]; then
    (cd "$BOOKS" && ./batch2md.sh) || warn "batch2md reported failures; qmd not refreshed"
    command -v qmd >/dev/null 2>&1 && qmd update >/dev/null 2>&1 || true
  fi
}

model_setup
load_active
say "=== sort-downloads ($([ "$APPLY" = 1 ] && echo apply || echo dry-run)) — $DOWNLOADS ==="

shopt -s nullglob
for item in "$DOWNLOADS"/*; do
  name=$(basename "$item")
  case "$name" in
    *.aria2 | *.sh | .*) continue ;;
  esac
  # In-flight is not a decision for a human: a timer must keep exiting 0 while
  # something downloads, or the check pages every time the pool is busy.
  if [ -e "$item.aria2" ]; then
    say "INFLIGHT $name — control file present, still downloading"
    inflight=$((inflight + 1))
    continue
  fi
  payload=$(payload_of "$item")
  if [ -n "$payload" ] && [ -n "${ACTIVE["$payload"]:-}" ]; then
    if [ -n "${SEEDING["$payload"]:-}" ] && [ "$KEEP_SEED" != 1 ]; then
      # A complete seed is a finished download: keeping it would leave the item
      # staged forever, because seed-ratio 0 never releases it on its own.
      say "SEEDSTOP $name — complete and only seeding; released to be sorted"
      released=$((released + 1))
      if [ "$APPLY" = 1 ]; then
        release_seed "${SEEDING["$payload"]}" || warn "SEEDSTOP $name — aria2 refused to release it"
      fi
    else
      say "INFLIGHT $name — aria2 still holds it (active or seeding); stop the task first"
      inflight=$((inflight + 1))
      continue
    fi
  fi
  if ! is_quiet "$item"; then
    say "INFLIGHT $name — modified less than ${QUIET_SECONDS}s ago"
    inflight=$((inflight + 1))
    continue
  fi
  classify "$item"
  if [ "$APPLY" = 1 ] && [ -d "$item" ] && [ -z "$(ls -A "$item" 2>/dev/null)" ]; then
    rmdir "$item"
  fi
done

scan_media_libraries
post_books

if [ "$APPLY" = 1 ] && [ "$OWNERSHIP_FAILED" = 1 ]; then
  warn "some destinations kept their original owner — run with sudo to normalise devji:users"
fi

say ""
if [ "$APPLY" = 1 ]; then verb=moved; else verb=planned; fi
if [ "$APPLY" = 1 ]; then seed_verb=released; else seed_verb="to release"; fi
say "$verb: $moved_other other, $moved_media media, $moved_books books · seeds $seed_verb: $released · inflight: $inflight · pending: $pending · unknown: $unknown"
if ((unknown > 0 || pending > 0)); then
  say "needs a human decision before this staging dir is empty"
  exit 1
fi
exit 0
