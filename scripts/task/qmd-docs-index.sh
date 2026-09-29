#!/usr/bin/env bash
# Index this repo's markdown docs into a local qmd collection and
# verify index freshness.
#
# The collection (name: "nixconfig") lives in the running user's
# default qmd index, alongside any personal note collections. Agents
# on fleet hosts already have qmd on PATH (pkgs.llm-agents.qmd via
# modules/user/ai); elsewhere: nix run github:numtide/llm-agents.nix#qmd
#
# Modes:
#   ensure  (default) register collection if missing + qmd update
#   check             collection registered AND index >= newest .md mtime
#                     (read-only; exit 1 when missing or stale)
set -euo pipefail

MODE="${1:-ensure}"
REPO="$(git rev-parse --show-toplevel)"
NAME="nixconfig"
QMD="${QMD_BIN:-qmd}"

if ! command -v "$QMD" >/dev/null 2>&1; then
  echo "qmd not found on PATH."
  echo "Fleet hosts ship it (pkgs.llm-agents.qmd); elsewhere:"
  echo "  nix run github:numtide/llm-agents.nix#qmd"
  echo "Or point QMD_BIN at a qmd binary."
  exit 1
fi

have_collection() {
  "$QMD" collection list 2>/dev/null | grep -qE "^${NAME} \("
}

index_path() {
  "$QMD" status 2>/dev/null | awk '/^Index:/ {print $2}'
}

case "$MODE" in
ensure | update)
  if have_collection; then
    echo "collection '${NAME}' already registered"
  else
    echo "registering collection '${NAME}' (${REPO})"
    "$QMD" collection add "${REPO}" --name "${NAME}" --mask "**/*.md"
  fi
  "$QMD" update
  echo
  "$QMD" status | sed -n '1,8p'
  echo
  echo "Try it: qmd search 'impermanence disko' -c ${NAME}"
  ;;
check)
  if ! have_collection; then
    echo "STALE  qmd collection '${NAME}' is not registered on this machine"
    echo "Run 'task dev:qmd:refresh' to (re)index the repo docs."
    exit 1
  fi
  idxfile="$(index_path)"
  if [ -z "$idxfile" ] || [ ! -f "$idxfile" ]; then
    echo "STALE  cannot locate the qmd index file ('qmd status' parse failed)"
    exit 1
  fi
  stale="$(find "${REPO}" -name '*.md' -not -path '*/.git/*' -newer "$idxfile" | head -5)"
  if [ -n "$stale" ]; then
    echo "STALE  markdown changed after the last qmd index update:"
    echo "${stale}" | sed 's/^/       /'
    echo "Run 'task dev:qmd:refresh'."
    exit 1
  fi
  echo "OK    qmd collection '${NAME}' registered and index is fresh (${idxfile})"
  ;;
*)
  echo "Unknown mode: $MODE (use ensure|check)" >&2
  exit 2
  ;;
esac
