#!/usr/bin/env bash
# The two legs of the voice loop on eisen, plus a round trip that proves both.
#
#   voice-loop.sh say TEXT [-v VOICE] [-o OUT.wav]   text -> speech (Qwen3-TTS)
#   voice-loop.sh hear FILE                          audio -> text (Parakeet, via stt.sh)
#   voice-loop.sh roundtrip TEXT [-v VOICE]          say, hear it back, compare
#
# `hear` delegates to the stt skill's script so the raw-bytes contract lives in
# one place; a second copy of it here is how the two drifted apart before.
set -euo pipefail

TTS=${TTS_URL:-http://tts.lan}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STT_SH=${STT_SH:-$HERE/../../stt/scripts/stt.sh}
# Named speakers only. `default` is not one of them, and the server answers
# `unknown speaker 'default'` only after the model has been cold-started, so it
# is cheaper to reject it here.
VOICES="vivian serena uncle_fu ryan aiden ono_anna sohee eric dylan"

die() {
  echo "voice-loop: $*" >&2
  exit 1
}

voice=aiden
min_overlap=0.6
out=""

warm_tts() {
  # On demand: the socket accepts at once and the model loads after it, so a
  # short probe reports health on a server that cannot answer yet.
  curl -fsS --max-time 60 "$TTS/health" >/dev/null ||
    die "$TTS is not answering — is eisen up? (task infra:status:eisen)"
}

say() {
  local text=${1:?say needs text}
  [ -n "$text" ] || die "say needs non-empty text"
  case " $VOICES " in
  *" $voice "*) : ;;
  *) die "unknown voice '$voice' — one of: $VOICES" ;;
  esac
  [ -n "$out" ] || out="say-$(date +%s).wav"
  warm_tts
  # Warm-up does not prove the model is loaded; the request itself gets a
  # generous budget because a cold start is ~15 s of weight loading.
  curl -fsS --fail-with-body --max-time 300 -X POST "$TTS/v1/audio/speech" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg t "$text" --arg v "$voice" '{model: "qwen3-tts", input: $t, voice: $v, response_format: "wav"}')" \
    -o "$out" ||
    die "tts request failed (is the speaker valid? is the model cold?)"
  [ -s "$out" ] || die "tts wrote no audio to $out"
  echo "voice-loop: say · $voice · $(wc -c <"$out") bytes · $out" >&2
}

hear() {
  local f=${1:?hear needs an audio file}
  [ -x "$STT_SH" ] || die "stt script not found at $STT_SH (set STT_SH)"
  "$STT_SH" --server "$f"
}

# TTS is never word-identical to its transcript: numbers, punctuation and
# casing all drift, so a round trip is scored by word overlap and the two texts
# are printed for a human to judge. 0.6 catches "wrong-speaker / wrong-model"
# failures without failing on a comma.
compare() {
  local want=$1 got=$2
  # `split` gives you a list keyed 1..n, so membership has to be tested against
  # a set built from the values — `w[i] in g` is always false, and that reads as
  # "nothing matched" rather than as a bug.
  awk -v want="$want" -v got="$got" '
    function norm(s) { s = tolower(s); gsub(/[^a-z0-9 ]/, " ", s); gsub(/ +/, " ", s); return s }
    BEGIN {
      n = split(norm(want), w, " "); m = split(norm(got), g, " ")
      if (n == 0) { print "0.00"; exit }
      for (j = 1; j <= m; j++) gset[g[j]] = 1
      for (i = 1; i <= n; i++) { if (w[i] in seen) continue; seen[w[i]] = 1; if (w[i] in gset) hit++ }
      printf "%.2f", hit / n
    }'
}

cmd=${1:-}
case "$cmd" in
say)
  shift
  text=""
  while [ $# -gt 0 ]; do
    case "$1" in
    -v) voice=${2:?-v needs a voice} && shift 2 ;;
    -o) out=${2:?-o needs a path} && shift 2 ;;
    *) text="${text:+$text }$1" && shift ;;
    esac
  done
  say "$text"
  ;;
hear) shift && hear "${1:?hear needs an audio file}" ;;
roundtrip)
  shift
  text=""
  while [ $# -gt 0 ]; do
    case "$1" in
    -v) voice=${2:?-v needs a voice} && shift 2 ;;
    --min-overlap) min_overlap=${2:?needs a number} && shift 2 ;;
    *) text="${text:+$text }$1" && shift ;;
    esac
  done
  [ -n "$text" ] || die "roundtrip needs text"
  out=$(mktemp --suffix=.wav)
  trap 'rm -f "$out"' EXIT
  say "$text"
  got=$(hear "$out")
  overlap=$(compare "$text" "$got")
  echo "said    $text" >&2
  echo "heard   $got" >&2
  echo "overlap $overlap (min $min_overlap)" >&2
  awk -v o="$overlap" -v m="$min_overlap" 'BEGIN { exit (o + 0 >= m + 0) ? 0 : 1 }' ||
    die "round trip does not close: $overlap < $min_overlap — check the speaker, the model, and the audio"
  ;;
-h | --help | "") sed -n '2,12p' "$0" ;;
*) die "unknown command '$cmd' — say | hear | roundtrip" ;;
esac
