#!/usr/bin/env bash
# freeapi.sh — the repo's one call site for apisfreellm.com's keyless APIs and
# the free search APIs it advertises (.agents/skills/apisfreellm).
#
# Usage
#   freeapi.sh ask QUESTION          /ask -> the answer as plain text
#   freeapi.sh chat PROMPT           /v1/chat/completions -> the message text
#   freeapi.sh complete PROMPT       /v1/completions -> choices[0].text
#   freeapi.sh search KIND QUERY     KIND=web|sites|news
#   freeapi.sh probe                 /health, then one chat call
#
# Env
#   SYSTEM=      system instructions for ask or chat
#   MAX_TOKENS=  ask/chat budget (default 512; the service allows 16000)
#   SIZE=        search page size, at most 100 (default 10)
#   FRESH=1      freeserp recency boost (web and sites)
#   FNA_KEY=     freenewsapi key; news needs one, web and sites do not. Unset,
#                the key is read from sops (`freenewsapi`) when it is there.
#   FORMAT=json  the raw response body instead of the rendered table
#
# Pacing is the service's own: 1 request per second, 2 in flight, so one call per
# process is the whole story. Nothing here loops over a query set, and a 429 that
# says the daily allowance is spent will not pass until 00:00 UTC — retrying it
# only spends the next day's first request.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BASE=${FREEAPI_BASE:-https://api.apisfreellm.com}
SERPER=${FREESERP_BASE:-https://freeserp.ai/api.php}
NEWS=${FREENEWS_BASE:-https://freenewsapi.ai/v1/search}

die() { printf 'freeapi: %s\n' "$*" >&2; exit 2; }

urienc() { jq -rn --arg v "$1" '$v|@uri'; }

# The news key is a sops secret, so a host that already holds the shop's keys
# needs nothing exported. FNA_KEY wins over the store, which is what lets a
# caller try a key without editing it in.
news_key_from_sops() {
  local key
  [ -r "$ROOT/scripts/task/lib/paths.sh" ] || return 1
  # shellcheck source=scripts/task/lib/paths.sh
  . "$ROOT/scripts/task/lib/paths.sh"
  key=$(secret_get '["freenewsapi"]') || return 1
  printf '%s\n' "$key"
}

# fetch URL [curl args...] — the body on stdout. 429 and 503 are the service's
# backpressure, so they get two more attempts with a 2s/4s pause; anything else
# prints the API's own error object and fails, because the status is the finding.
fetch() {
  local url=$1
  shift
  local attempt=0 out code
  while :; do
    attempt=$((attempt + 1))
    if ! out=$(curl -sS --max-time 120 -w '\n%{http_code}' "$@" "$url"); then
      printf 'freeapi: no answer from %s\n' "${url%%\?*}" >&2
      return 1
    fi
    code=${out##*$'\n'}
    out=${out%$'\n'*}
    case $code in
      2??)
        printf '%s\n' "$out"
        return 0
        ;;
      429 | 503)
        if [ "$attempt" -ge 3 ]; then
          printf 'freeapi: HTTP %s after %d attempts\n' "$code" "$attempt" >&2
          printf '%s\n' "$out" | head -c 400 >&2
          return 1
        fi
        printf 'freeapi: HTTP %s, attempt %d in %ds\n' "$code" "$attempt" "$((attempt * 2))" >&2
        sleep "$((attempt * 2))"
        ;;
      *)
        printf 'freeapi: HTTP %s\n' "$code" >&2
        printf '%s\n' "$out" | head -c 400 >&2
        return 1
        ;;
    esac
  done
}

cmd_ask() {
  local q=$1 url
  [ -n "$q" ] || die 'ask needs a question'
  url="$BASE/ask?q=$(urienc "$q")"
  if [ -n "${SYSTEM:-}" ]; then url="$url&system=$(urienc "$SYSTEM")"; fi
  if [ -n "${MAX_TOKENS:-}" ]; then url="$url&max_tokens=$MAX_TOKENS"; fi
  if [ "${FORMAT:-}" = json ]; then
    fetch "$url&format=json" | jq '{answer, model}'
  else
    fetch "$url"
  fi
}

cmd_chat() {
  local prompt=$1 payload body
  [ -n "$prompt" ] || die 'chat needs a prompt'
  payload=$(jq -cn \
    --arg p "$prompt" \
    --arg sys "${SYSTEM:-}" \
    --argjson mt "${MAX_TOKENS:-512}" '
      {model: "free-ai", max_tokens: $mt,
       messages: ((if $sys == "" then [] else [{role: "system", content: $sys}] end)
                  + [{role: "user", content: $p}])}')
  body=$(fetch "$BASE/v1/chat/completions" -H 'Content-Type: application/json' -d "$payload")
  printf '%s\n' "$body" | jq -r '.choices[0].message.content // .error.message // empty'
}

cmd_complete() {
  local prompt=$1 payload body
  [ -n "$prompt" ] || die 'complete needs a prompt'
  payload=$(jq -cn --arg p "$prompt" --argjson mt "${MAX_TOKENS:-512}" \
    '{model: "free-ai", prompt: $p, max_tokens: $mt}')
  body=$(fetch "$BASE/v1/completions" -H 'Content-Type: application/json' -d "$payload")
  printf '%s\n' "$body" | jq -r '.choices[0].text // .error.message // empty'
}

cmd_search() {
  local kind=$1 q=$2 url body model key
  [ -n "$q" ] || die 'search needs a query'
  case $kind in
    web | sites)
      url="$SERPER?index=$kind&q=$(urienc "$q")&size=${SIZE:-10}"
      if [ "${FRESH:-}" = 1 ]; then url="$url&fresh=1"; fi
      body=$(fetch "$url")
      ;;
    news)
      key=${FNA_KEY:-}
      if [ -z "$key" ] && command -v sops >/dev/null 2>&1; then
        key=$(news_key_from_sops || true)
      fi
      if [ -z "$key" ]; then
        die 'news needs a free key: https://freenewsapi.ai/register.php, then sops freenewsapi or FNA_KEY=...'
      fi
      url="$NEWS?q=$(urienc "$q")&size=${SIZE:-10}"
      body=$(fetch "$url" -H "Authorization: Bearer $key")
      ;;
    *) die "KIND must be web, sites or news: $kind" ;;
  esac
  if [ "${FORMAT:-}" = json ]; then
    printf '%s\n' "$body" | jq .
    return 0
  fi
  # One shape for three APIs: the agent reads url, host, title, snippet. The
  # full body is still there under FORMAT=json when a field was dropped.
  model=$(printf '%s\n' "$body" | jq -c '
    {index: (.index // "news"), query: (.query // null), total: (.total // null),
     count: ((.results // []) | length),
     results: ((.results // []) | map(
       {url: .url,
        host: (.domain // .host // ""),
        title: (.title // ""),
        snippet: (((.snippet // .description // .ai_summary // "") | tostring) | gsub("\\s+"; " ") | .[0:200])}))}')
  if command -v toon >/dev/null 2>&1; then
    printf '%s\n' "$model" | toon -e
  else
    printf '%s\n' "$model" | jq .
  fi
}

cmd_probe() {
  local health answer
  health=$(fetch "$BASE/health" | jq -r '.status // "unknown"')
  sleep 1
  answer=$(fetch "$BASE/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model":"free-ai","messages":[{"role":"user","content":"Reply with the single word ok"}],"max_tokens":16}' |
    jq -r '.choices[0].message.content // empty')
  printf 'health  %s\nchat    %s\n' "$health" "${answer:-no answer}"
  [ "$health" = ok ] && [ -n "$answer" ]
}

usage() {
  sed -n '4,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
}

cmd=${1:-}
if [ $# -gt 0 ]; then shift; fi
case $cmd in
  ask) [ $# -ge 1 ] || die 'ask needs a question'; cmd_ask "$*" ;;
  chat) [ $# -ge 1 ] || die 'chat needs a prompt'; cmd_chat "$*" ;;
  complete) [ $# -ge 1 ] || die 'complete needs a prompt'; cmd_complete "$*" ;;
  search) [ $# -ge 2 ] || die 'search needs KIND and a query'; cmd_search "$1" "${*:2}" ;;
  probe) cmd_probe ;;
  *) usage; exit 2 ;;
esac
