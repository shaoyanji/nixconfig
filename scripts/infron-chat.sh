#!/usr/bin/env bash
# infron — one chat call on the Infron route, primary model then its backup.
#
# The route (llm.onerouter.pro) serves two `:free` ids that the fleet runs as its
# workhorses: deepseek-v4-flash-0731 as the primary and qwen3.8-27b as the backup.
# Both are billed at zero, and the account holds a $5 balance that nothing tops
# up, so every caller needs the same two facts — which model answers first, and
# what to fall back to. This is that one place: a script calls `infron` instead of
# hand-rolling curl, the model list, and the retry rule.
#
# Usage:
#   infron "explain this error"
#   printf '%s' "$diff" | infron --system "review this patch"
#   infron --model deepseek/deepseek-v4-flash-0731:free --max-tokens 256 "…"
#   infron --json "…"                 # raw API body instead of the content
#
# Environment:
#   INFRON_API_KEY        required; the shells export it from apikeys.yaml
#   INFRON_BASE_URL       default https://llm.onerouter.pro/v1
#   INFRON_MODEL          override the primary id (must stay `:free`)
#   INFRON_BACKUP_MODEL   override the backup id (must stay `:free`)
#
# Exit: 0 answered · 1 both models failed · 2 usage or configuration.
#
# The fallback covers the failures a caller cannot see coming: rate limit,
# overload, a 5xx, a timeout, or an empty completion. A 4xx that is not 429 is
# the request's own fault (bad model id, malformed body) and is reported without
# a second call, because a retry cannot fix it.
#
# A model id that does not end in `:free` is refused before any request is made:
# that suffix is what the router bills at zero, and a paid id spends the balance
# that keeps the free ones available.
set -uo pipefail

BASE="${INFRON_BASE_URL:-https://llm.onerouter.pro/v1}"
BASE="${BASE%/}"
PRIMARY="${INFRON_MODEL:-deepseek/deepseek-v4-flash-0731:free}"
BACKUP="${INFRON_BACKUP_MODEL:-qwen/qwen3.8-27b:free}"
SYSTEM=""
MAX_TOKENS=1024
TEMPERATURE=0.2
TIMEOUT=120
RAW=0
MODEL=""

die() {
  printf 'infron: %s\n' "$*" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
usage: infron [--model ID] [--system TEXT] [--max-tokens N] [--temperature F]
              [--timeout S] [--json] [prompt]

The prompt is the remaining arguments, or stdin when there are none.
Environment: INFRON_API_KEY (required), INFRON_BASE_URL, INFRON_MODEL,
INFRON_BACKUP_MODEL. Both model ids must end in `:free`.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --system)
      [ $# -ge 2 ] || die "--system needs a value"
      SYSTEM="$2"
      shift 2
      ;;
    --model)
      [ $# -ge 2 ] || die "--model needs a value"
      MODEL="$2"
      shift 2
      ;;
    --max-tokens)
      [ $# -ge 2 ] || die "--max-tokens needs a value"
      MAX_TOKENS="$2"
      shift 2
      ;;
    --temperature)
      [ $# -ge 2 ] || die "--temperature needs a value"
      TEMPERATURE="$2"
      shift 2
      ;;
    --timeout)
      [ $# -ge 2 ] || die "--timeout needs a value"
      TIMEOUT="$2"
      shift 2
      ;;
    --json)
      RAW=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option $1 (--help for usage)"
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -gt 0 ]; then
  PROMPT="$*"
else
  PROMPT="$(cat)"
fi
[ -n "$PROMPT" ] || die "no prompt (pass it as an argument or on stdin)"
[ -n "${INFRON_API_KEY:-}" ] || die "INFRON_API_KEY is not set — a shell exports it from apikeys.yaml, a script can pass it explicitly"

[ -z "$MODEL" ] || PRIMARY="$MODEL"

case "$PRIMARY" in
  *:free) ;;
  *) die "model '$PRIMARY' is not a :free id — a paid id spends the balance that keeps the free models working" ;;
esac
case "$BACKUP" in
  *:free) ;;
  *) die "backup model '$BACKUP' is not a :free id" ;;
esac

PAYLOAD="$(mktemp)"
trap 'rm -f "$PAYLOAD"' EXIT

# One JSON body. `--data-binary @file` keeps a prompt that starts with `@` or
# contains newlines intact; a shell-quoted inline body would need escaping that
# callers then get wrong.
build_payload() {
  jq -cn \
    --arg model "$1" \
    --arg sys "$SYSTEM" \
    --arg prompt "$PROMPT" \
    --argjson max "$MAX_TOKENS" \
    --argjson temp "$TEMPERATURE" '
      {
        model: $model,
        max_tokens: $max,
        temperature: $temp,
        messages: (
          (if $sys == "" then [] else [{role: "system", content: $sys}] end)
          + [{role: "user", content: $prompt}]
        )
      }' >"$PAYLOAD"
}

# attempt <model>
#   0  answered, body (or content) on stdout
#   1  retryable failure, already reported on stderr
#   3  fatal failure, already reported on stderr
attempt() {
  local model="$1" out code body content
  build_payload "$model" || return 3
  if ! out="$(curl -sS --max-time "$TIMEOUT" -w $'\n__code:%{http_code}' \
    -X POST "$BASE/chat/completions" \
    -H "Authorization: Bearer $INFRON_API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary "@$PAYLOAD" 2>&1)"; then
    printf 'infron: %s: no response (%s)\n' "$model" "$(printf '%s' "$out" | tail -1)" >&2
    return 1
  fi
  code="${out##*__code:}"
  body="${out%$'\n'__code:*}"
  case "$code" in
    200) ;;
    429 | 5?? | 000)
      printf 'infron: %s: HTTP %s\n' "$model" "$code" >&2
      return 1
      ;;
    *)
      printf 'infron: %s: HTTP %s: %s\n' "$model" "$code" \
        "$(printf '%s' "$body" | jq -r '.error.message? // empty' 2>/dev/null)" >&2
      return 3
      ;;
  esac
  content="$(printf '%s' "$body" | jq -r '.choices[0].message.content? // empty' 2>/dev/null)"
  if [ -z "$content" ]; then
    printf 'infron: %s: empty completion\n' "$model" >&2
    return 1
  fi
  if [ "$RAW" -eq 1 ]; then
    printf '%s\n' "$body"
  else
    printf '%s\n' "$content"
  fi
  return 0
}

attempt "$PRIMARY"
rc=$?
[ "$rc" -eq 0 ] && exit 0
[ "$rc" -eq 3 ] && exit 1

printf 'infron: falling back to %s\n' "$BACKUP" >&2
attempt "$BACKUP"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'infron: both models failed\n' >&2
  exit 1
fi
exit 0
