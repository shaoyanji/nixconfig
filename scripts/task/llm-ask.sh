#!/usr/bin/env bash
# llm-ask.sh — ask the local stack, and when it is not answering, ask free-ai.
#
# The order is the point: the local model is free to run and private, free-ai is
# neither, so a reachable router always wins. "Not answering" is a connection
# error, a timeout, a non-2xx status or a body with no message text — the cases
# where a caller would otherwise carry an empty answer onward.
#
# Usage
#   llm-ask.sh QUESTION
#
# Env
#   LLM_LOCAL_URL      chat completions URL (default the eisen router:
#                      http://eisen:8000/v1/chat/completions). The router proxies
#                      llama-swap and normalises a missing `model`, so no model
#                      name is sent.
#   LLM_LOCAL_TIMEOUT  seconds to wait for the connection (default 8)
#   LOCAL_ONLY=1       no fallback: a local failure is the answer
#   SYSTEM=, MAX_TOKENS=, FORMAT=   read here and passed to freeapi.sh on fallback
#
# Task: freeapi:fallback · fallback facts: .agents/skills/apisfreellm
# Exit: 0 answered (local or free-ai) · 1 neither answered · 2 bad input
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
LOCAL=${LLM_LOCAL_URL:-http://eisen:8000/v1/chat/completions}
CONNECT=${LLM_LOCAL_TIMEOUT:-8}

q=${1:-}
if [ -z "$q" ]; then
  printf 'llm-ask: needs a question\n' >&2
  exit 2
fi

payload=$(jq -cn --arg p "$q" --arg sys "${SYSTEM:-}" --argjson mt "${MAX_TOKENS:-512}" '
  {max_tokens: $mt,
   messages: ((if $sys == "" then [] else [{role: "system", content: $sys}] end)
              + [{role: "user", content: $p}])}')

# Empty on anything short of a complete reply, including an error object or a
# proxy page that is not JSON at all.
local_answer() {
  local out
  out=$(curl -sS --connect-timeout "$CONNECT" --max-time 120 \
    -H 'Content-Type: application/json' -d "$payload" "$LOCAL") || return 1
  printf '%s\n' "$out" |
    jq -er '.choices[0].message.content // empty' 2>/dev/null
}

if answer=$(local_answer) && [ -n "$answer" ]; then
  printf '%s\n' "$answer"
  exit 0
fi

if [ "${LOCAL_ONLY:-}" = 1 ]; then
  printf 'llm-ask: no answer from %s and LOCAL_ONLY=1\n' "${LOCAL%%\?*}" >&2
  exit 1
fi

# Named on stderr so a caller can tell which model wrote the answer: the two
# backends differ in privacy, in speed and in who can see the prompt.
printf 'llm-ask: no answer from %s — using free-ai\n' "${LOCAL%%\?*}" >&2
exec bash "$ROOT/scripts/task/freeapi.sh" ask "$q"
