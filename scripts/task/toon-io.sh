#!/usr/bin/env bash
# toon-io.sh — the agent data boundary as two functions. Source it; do not run it.
#
#   toon_emit  [text-renderer args...]   stdin JSON -> reader's format
#   toon_ingest [file|-]                 TOON | JSON -> JSON on stdout
#
# The rule (master-toon): JSON links the tools, TOON is what an agent reads and
# writes. Every emit site used to open-code `case "$FORMAT" in text|json|toon`;
# one function is the contract so a new task cannot emit raw JSON by accident.
#
# FORMAT env: toon (default — the agent), json (a program consumes it), text
# (a person at a terminal — runs the renderer args, e.g. `toon_emit jq -r '…'`).

toon_emit() {
  case "${FORMAT:-toon}" in
    json) cat ;;
    text) if [ "$#" -gt 0 ]; then "$@"; else toon -e; fi ;;
    *) toon -e ;;
  esac
}

# Agents may hand a task a TOON document where a tool wants JSON. Detection is
# "does jq accept it": a TOON array document also starts with `[`, so a first
# character check is not enough — parse, then decode only what is not JSON.
toon_ingest() {
  local src=${1:--} body
  if [ "$src" = "-" ]; then body=$(cat); else body=$(cat -- "$src"); fi
  if printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$body"
  else
    printf '%s' "$body" | toon -d
  fi
}
