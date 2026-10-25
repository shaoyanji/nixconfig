#!/usr/bin/env bash
# Transcribe one audio file and print the text to stdout.
#
#   stt.sh FILE                 auto: local voxtype if it is installed, else the eisen server
#   stt.sh --server FILE        force http://eisen.lan/stt (Parakeet, always resident)
#   stt.sh --local FILE         force voxtype; fetches it from numtide's flake if absent
#   stt.sh --out TEXT FILE      also write the transcript to TEXT
#
# stdout carries the transcript and nothing else, so `stt.sh a.mp3 > notes.txt`
# is safe to feed to qmd or a document. Every diagnostic goes to stderr.
set -euo pipefail

SERVER=${STT_SERVER:-http://eisen.lan/stt}
# 25 MB is the server's cap: ~26 min of 16 kHz mono wav, and a raw 44.1 kHz
# stereo upload of the same audio would cross it, which is one reason the
# conversion below always runs.
MAX_BYTES=$((25 * 1024 * 1024))
mode=auto
out=

die() {
  echo "stt: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
  --server) mode=server && shift ;;
  --local) mode=local && shift ;;
  --out) out="${2:?-out needs a path}" && shift 2 ;;
  -h | --help) sed -n '2,10p' "$0" && exit 0 ;;
  --*) die "unknown flag $1" ;;
  *) break ;;
  esac
done
[ $# -eq 1 ] || die "usage: stt.sh [--server|--local] [--out FILE] FILE"
src=$1
[ -s "$src" ] || die "$src is missing or empty"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
audio=$work/in.wav

# Always re-encode: a 44.1 kHz stereo m4a, a wav at the wrong rate and a clean
# 16 kHz mono wav all land on the one shape both engines accept, and the
# conversion is cheaper than diagnosing "garbled speech" later.
if command -v ffmpeg >/dev/null; then
  ffmpeg -nostdin -loglevel error -y -i "$src" -ar 16000 -ac 1 -c:a pcm_s16le "$audio" ||
    die "ffmpeg could not decode $src (is it really audio?)"
else
  case "$src" in
  *.wav) cp "$src" "$audio" ;;
  *) die "ffmpeg is not installed and $src is not a wav — install ffmpeg, or supply 16 kHz mono PCM wav" ;;
  esac
fi
size=$(wc -c <"$audio")
[ "$size" -le "$MAX_BYTES" ] || die "$(($size / 1024 / 1024)) MB after conversion, over the ${MAX_BYTES} MB cap — split the audio"

started=$(date +%s)
if [ "$mode" = auto ]; then
  if command -v voxtype >/dev/null; then mode=local; else mode=server; fi
fi

# Into a file, not a pipeline: `tee /dev/stdout` fails when stdout is a socket
# or a pipe owned by something else, and that failure used to look like a
# transcription error under pipefail.
transcript=$work/out.txt
case "$mode" in
local)
  if command -v voxtype >/dev/null; then
    voxtype transcribe "$audio" >"$transcript"
  else
    # Only on an explicit --local: this resolves a flake and builds the tool,
    # which is not something an implicit fallback should spend.
    nix shell github:numtide/llm-agents.nix#voxtype --command voxtype transcribe "$audio" >"$transcript"
  fi
  ;;
server)
  # Two questions, two budgets: is anything listening (2 s — an off host must
  # not cost a minute of the caller's time), then does it answer /health (60 s,
  # because the ONNX sessions load after the socket accepts).
  authority=${SERVER#*://}
  authority=${authority%%/*}
  host=${authority%%:*}
  port=${authority##*:}
  [ "$port" = "$authority" ] && port=80
  timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null ||
    die "nothing listening on $host:$port — eisen is off (task infra:wol:eisen), or its nginx is down"
  curl -fsS --max-time 60 "$SERVER/health" >/dev/null ||
    die "$SERVER is not answering — eisen may be off (task infra:wol:eisen), or the generation predates parakeet-stt"
  # --data-binary, never -F: the endpoint takes raw bytes and ffmpeg chokes on
  # a multipart body. --fail-with-body so a 4xx prints its reason instead of
  # being mistaken for a transcript.
  curl -fsS --fail-with-body --max-time 120 -X POST "$SERVER/transcribe" \
    -H "Content-Type: audio/wav" --data-binary "@$audio" >"$transcript"
  ;;
esac
cat "$transcript"
[ -z "$out" ] || cat "$transcript" >"$out"
echo "stt: $mode · ${size} bytes · $(( $(date +%s) - started ))s" >&2
