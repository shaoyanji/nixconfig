#!/usr/bin/env bash
# Index markdown documentation and personal knowledge base vaults into local qmd collections
# and verify index freshness.
#
# Collections:
#   nixconfig - Personal Nix flake documentation, architecture, and runbooks
#   vault     - Personal Obsidian vault (zettels, schematics, notes)
#
# Modes:
#   ensure [all|nixconfig|vault]  Register collection(s) if missing + qmd update
#   check  [all|nixconfig|vault]  Verify collection(s) registered and index fresh
set -euo pipefail

MODE="${1:-ensure}"
TARGET="${2:-all}"
REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "/Volumes/data/projects/nixconfig")"
VAULT_DIR="/Volumes/data/Obsidian-Git-Sync"
if [ ! -d "$VAULT_DIR" ] && [ -d "$HOME/vaults/personal" ]; then
  VAULT_DIR="$(readlink -f "$HOME/vaults/personal" 2>/dev/null || echo "$HOME/vaults/personal")"
fi
QMD="${QMD_BIN:-qmd}"

if ! command -v "$QMD" >/dev/null 2>&1; then
  echo "qmd not found on PATH."
  echo "Fleet hosts ship it (pkgs.llm-agents.qmd); elsewhere:"
  echo "  nix run github:numtide/llm-agents.nix#qmd"
  exit 1
fi

have_collection() {
  local name="$1"
  "$QMD" collection list 2>/dev/null | grep -qE "^${name} \("
}

index_path() {
  "$QMD" status 2>/dev/null | awk '/^Index:/ {print $2}'
}

ensure_single() {
  local name="$1"
  local path="$2"
  local desc="$3"
  if [ ! -d "$path" ]; then
    echo "WARN  directory '$path' not found for collection '$name', skipping"
    return 0
  fi
  if have_collection "$name"; then
    echo "collection '${name}' already registered (${path})"
  else
    echo "registering collection '${name}' (${path})"
    "$QMD" collection add "${path}" --name "${name}" --mask "**/*.md"
    if [ -n "$desc" ]; then
      "$QMD" context add "qmd://${name}/" "$desc" >/dev/null 2>&1 || true
    fi
  fi
}

check_single() {
  local name="$1"
  local path="$2"
  if [ ! -d "$path" ]; then
    echo "WARN  directory '$path' not found for collection '$name'"
    return 0
  fi
  if ! have_collection "$name"; then
    echo "STALE  qmd collection '${name}' is not registered on this machine"
    echo "Run 'task dev:qmd:refresh' to register and index."
    exit 1
  fi
  idxfile="$(index_path)"
  if [ -z "$idxfile" ] || [ ! -f "$idxfile" ]; then
    echo "STALE  cannot locate the qmd index file ('qmd status' parse failed)"
    exit 1
  fi
  stale="$(find "${path}" -name '*.md' -not -path '*/.git/*' -not -path '*/.trash/*' -newer "$idxfile" 2>/dev/null | head -5)"
  if [ -n "$stale" ]; then
    echo "STALE  markdown in '${name}' changed after the last qmd index update:"
    echo "${stale}" | sed 's/^/       /'
    echo "Run 'task dev:qmd:refresh'."
    exit 1
  fi
  echo "OK     qmd collection '${name}' is registered and index is fresh (${path})"
}

case "$MODE" in
ensure | update)
  case "$TARGET" in
  nixconfig)
    ensure_single "nixconfig" "${REPO}" "NixOS, Darwin, and Home Manager fleet documentation and runbooks"
    ;;
  vault)
    ensure_single "vault" "${VAULT_DIR}" "Personal Obsidian knowledge base with zettels, schematics, and notes"
    ;;
  all)
    ensure_single "nixconfig" "${REPO}" "NixOS, Darwin, and Home Manager fleet documentation and runbooks"
    ensure_single "vault" "${VAULT_DIR}" "Personal Obsidian knowledge base with zettels, schematics, and notes"
    ;;
  *)
    echo "Unknown target: $TARGET (use nixconfig|vault|all)" >&2
    exit 2
    ;;
  esac
  "$QMD" update
  echo
  "$QMD" status | sed -n '1,12p'
  echo
  echo "Try searching:"
  echo "  qmd search 'query' -c vault       # search Obsidian vault"
  echo "  qmd search 'query' -c nixconfig   # search repo documentation"
  echo "  qmd search 'query'                # search across all collections"
  ;;
check)
  case "$TARGET" in
  nixconfig)
    check_single "nixconfig" "${REPO}"
    ;;
  vault)
    check_single "vault" "${VAULT_DIR}"
    ;;
  all)
    check_single "nixconfig" "${REPO}"
    check_single "vault" "${VAULT_DIR}"
    ;;
  *)
    echo "Unknown target: $TARGET (use nixconfig|vault|all)" >&2
    exit 2
    ;;
  esac
  ;;
*)
  echo "Unknown mode: $MODE (use ensure|check)" >&2
  exit 2
  ;;
esac
