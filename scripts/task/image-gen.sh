#!/usr/bin/env bash
# image-gen.sh — one prompt in, one JSON line out, uploaded, detachable.
#
#   PROMPT='...' bash image-gen.sh                    # {"id","url","path","size","prompt"}
#   PROMPT='...' DETACH=1 bash image-gen.sh           # starts a unit, prints {"unit","log","path"}
#   PROMPTS=/tmp/list.txt bash image-gen.sh --batch   # one prompt per line, JSONL at OUTDIR/index.jsonl
#
# WHY THIS EXISTS: the Go client already prints the delivery URL with `--json`,
# but reaching it by hand means remembering the size flag, the output flag, the
# session refresh and the 60-second token. Those are the caller's whole job here,
# so a prompt can be piped, backgrounded and consumed by jq without a human in
# the loop. `cpg` stays the transport; nothing below re-implements auth.
#
# The URL the CLI prints is session-gated — a bare fetch answers 401 — so the
# render is uploaded to Cloudinary before its URL is reported, and `.url` is the
# delivery URL a page can actually use. `UPLOAD=0` keeps a throwaway render local.
set -euo pipefail

repo=${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
IMAGES_ROOT=${IMAGES_ROOT:-$HOME/Pictures/generated}
SIZE=${SIZE:-1536x1024}
DETACH=${DETACH:-0}

say() { printf '%s\n' "$*" >&2; }

auth_ok() { cpg status --json 2>/dev/null | jq -e '.authenticated' >/dev/null 2>&1; }

# The token lives 60 s, so a pipeline that starts after a pause begins with a dead
# session and a bare 401. Refresh is cheap and idempotent; the browser login is not.
ensure_auth() {
  auth_ok && return 0
  cpg refresh >/dev/null 2>&1 || true
  auth_ok
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' |
    sed -e 's/^-*//' -e 's/-*$//' | cut -c1-48
}

# The bank is the account, so a render is uploaded before its URL is reported.
# `assets/<path-without-ext>` is the id the manifest, the adoption pass and
# `images:gc` all derive, so an uploaded asset and an adopted row are one path.
# A failed upload is reported, not fatal: the PNG is on disk and a later publish
# uploads it from there.
upload_bank() { # path -> delivery url
  local path=$1 rel id
  [ "${UPLOAD:-1}" = "1" ] || return 1
  [ -f "$repo/scripts/task/cloudinary.sh" ] || return 1
  case $path in
  "$IMAGES_ROOT"/src/*) rel=${path#"$IMAGES_ROOT/src/"} ;;
  *) rel="wall/$(date +%F)/$(basename "$path")" ;;
  esac
  id="assets/${rel%.*}"
  bash "$repo/scripts/task/cloudinary.sh" upload "$path" --public-id "$id"
}

# One generation. 401 buys one refresh and one retry; 429 is the burst window and
# gets a backoff, because a spent allowance reports itself differently and the
# caller can read `cpg usage` rather than being told "try later" forever.
gen_one() { # prompt out
  local prompt=$1 out=$2 tries=0 result rc bank
  mkdir -p "$(dirname "$out")"
  while :; do
    ensure_auth || { say "image-gen: not authenticated — run chatplayground-go login"; return 1; }
    result=$(cpg image --json -s "$SIZE" -o "$out" "$prompt" 2>&1) && [ -s "$out" ] || rc=$?
    if [ -s "$out" ] && printf '%s' "$result" | jq -e '.url' >/dev/null 2>&1; then
      bank=$(upload_bank "$out") || { say "image-gen: upload failed; the render is at $out and a publish sends it"; bank=""; }
      printf '%s\n' "$result" | jq -c --arg p "$out" --arg b "$bank" '
        if $b == "" then . + {path: $p, bank: false}
        else . + {path: $p, session_url: .url, url: $b, bank: true} end'
      return 0
    fi
    case "$result" in
      *401* | *UNAUTHENTICATED* | *'Sign in to continue'*)
        [ "$tries" -lt 1 ] || { say "image-gen: still unauthenticated after a refresh"; printf '%s\n' "$result" >&2; return 1; }
        tries=$((tries + 1)); cpg refresh >/dev/null 2>&1 || true; continue ;;
      *429* | *RATE_LIMITED*)
        [ "$tries" -lt 3 ] || { say "image-gen: burst window closed"; printf '%s\n' "$result" >&2; return 1; }
        tries=$((tries + 1)); say "image-gen: rate limited, waiting $((60 * tries))s"; sleep $((60 * tries)); continue ;;
    esac
    say "image-gen: generation failed (rc=${rc:-0})"
    printf '%s\n' "$result" >&2
    return 1
  done
}

# A detached run cannot inherit this shell, so the unit carries the variables it
# needs and the caller reads the same JSON from the log the moment it lands.
launch_detached() { # slug log
  local slug=$1 log=$2 unit
  unit="image-gen-$slug"
  systemctl --user stop "$unit" 2>/dev/null || true
  systemd-run --user --unit "$unit" --collect \
    --setenv=PROMPT="$PROMPT" --setenv=OUT="$OUT" --setenv=SIZE="$SIZE" \
    --setenv=IMAGES_ROOT="$IMAGES_ROOT" --setenv=DETACH=0 \
    --setenv=UPLOAD="${UPLOAD:-1}" --setenv=REPO="$repo" \
    -- bash "$0" >"$log" 2>&1
  jq -cn --arg unit "$unit" --arg log "$log" --arg path "$OUT" \
    '{unit: $unit, log: $log, path: $path}'
}

main() {
  if [ "${1:-}" = "--batch" ]; then
    local file=${PROMPTS:?--batch needs PROMPTS=<file, one prompt per line>}
    local outdir=${OUTDIR:-$IMAGES_ROOT/src/wall/$(date +%F)}
    [ -f "$file" ] || { say "image-gen: no prompts file at $file"; return 2; }
    local index=$outdir/index.jsonl
    mkdir -p "$outdir"
    local n=0 line out
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case $line in \#*) continue ;; esac
      n=$((n + 1))
      out=$outdir/$(printf '%03d' "$n")-$(slugify "$line").png
      say "image-gen: [$n] $out"
      PROMPT=$line OUT=$out gen_one "$line" "$out" >>"$index" || say "image-gen: [$n] failed, continuing"
    done <"$file"
    printf '%s\n' "$index"
    return 0
  fi

  : "${PROMPT:?PROMPT is required (or pass --batch with PROMPTS=<file>)}"
  if [ -z "${OUT:-}" ]; then
    OUT=$IMAGES_ROOT/src/wall/$(date +%F)/$(slugify "$PROMPT").png
  fi
  if [ "$DETACH" = "1" ]; then
    mkdir -p "$(dirname "$OUT")"
    launch_detached "$(slugify "$PROMPT")" "${LOG:-$IMAGES_ROOT/$(slugify "$PROMPT").log}"
    return 0
  fi
  gen_one "$PROMPT" "$OUT"
}

main "$@"
