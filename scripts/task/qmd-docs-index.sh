#!/usr/bin/env bash
# Register and refresh the qmd collections, and verify their freshness.
# nixconfig indexes the nix tree too (`**/*.{nix,md}`): the module that carries a
# fact and the page that explains it are one search away, so a prose duplicate in
# docs/ has no alibi. Modes: ensure [all|nixconfig|vault], check [all|...]
set -euo pipefail

MODE="${1:-ensure}"
TARGET="${2:-all}"
REPO="$(git rev-parse --show-toplevel)"
VAULT_DIR="/Volumes/data/Obsidian-Git-Sync"
if [ ! -d "$VAULT_DIR" ] && [ -d "$HOME/vaults/personal" ]; then
  VAULT_DIR="$(readlink -f "$HOME/vaults/personal" 2>/dev/null || echo "$HOME/vaults/personal")"
fi
# The published blog is a collection of its own: an article that shipped is a
# fact someone will search for later, and it lives outside this repo.
BLOG_DIR="/home/devji/Documents/shaoyanji.is-a.dev"
[ -d "$BLOG_DIR" ] || BLOG_DIR="${BLOG_DIR/#\/home\/devji/$HOME}"
# qmd is not on every host's PATH (delphi carries the agents but not qmd), and a
# gate that cannot run is not a gate — so resolve it instead of refusing.
# Order: an explicit QMD_BIN, then PATH, then the llm-agents revision pinned in
# flake.lock, built once into a GC-rooted out-link. Same pattern as
# scripts/task/nix-fmt.sh, and `--builders ""` so resolving a tool never spends
# remote build budget.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-qmd"

resolve_qmd() {
  if [ -n "${QMD_BIN:-}" ]; then
    command -v "$QMD_BIN" >/dev/null 2>&1 || return 1
    printf '%s\n' "$QMD_BIN"
    return 0
  fi
  if command -v qmd >/dev/null 2>&1; then
    command -v qmd
    return 0
  fi
  command -v nix >/dev/null 2>&1 || return 1
  local installable link
  installable="$(jq -r '.nodes["llm-agents"].locked
                     | select(.type == "github")
                     | "github:\(.owner)/\(.repo)/\(.rev)"' "$REPO/flake.lock" 2>/dev/null)" || true
  [ -n "$installable" ] || return 1
  link="$CACHE_DIR/qmd"
  if [ ! -x "$link/bin/qmd" ]; then
    echo "==> qmd is not on PATH; resolving the llm-agents pin from flake.lock (once)" >&2
    mkdir -p "$CACHE_DIR"
    nix build "${installable}#qmd" --out-link "$link" --builders "" >/dev/null 2>&1 || return 1
  fi
  [ -x "$link/bin/qmd" ] || return 1
  printf '%s\n' "$link/bin/qmd"
}

if ! QMD="$(resolve_qmd)"; then
  cat >&2 <<'HINT'
qmd is not on PATH and the llm-agents pin in flake.lock could not be built.
Set QMD_BIN=/path/to/qmd, or call it through a shell:

  nix shell "$(jq -r '.nodes["llm-agents"].locked | "github:\(.owner)/\(.repo)/\(.rev)"' flake.lock)#qmd" -c qmd status
HINT
  exit 1
fi

have_collection() {
  local name="$1"
  "$QMD" collection list 2>/dev/null | grep -qE "^${name} \("
}

index_path() {
  "$QMD" status 2>/dev/null | awk '/^Index:/ {print $2}'
}

collection_mask() {
  "$QMD" collection show "$1" 2>/dev/null | sed -n 's/^  Pattern:  //p' | head -1
}

ensure_single() {
  local name="$1"
  local path="$2"
  local desc="$3"
  local mask="${4:-**/*.md}"
  if [ ! -d "$path" ]; then
    echo "WARN  directory '$path' not found for collection '$name', skipping"
    return 0
  fi
  if have_collection "$name"; then
    local current
    current="$(collection_mask "$name")"
    if [ "$current" = "$mask" ]; then
      echo "collection '${name}' already registered (${path}, ${mask})"
    else
      # A mask is registration-time state with no in-place setter; re-register so
      # an existing index starts combing the nix tree instead of only markdown.
      echo "updating collection '${name}' mask: ${current:-?} -> ${mask}"
      "$QMD" collection remove "$name" >/dev/null
      "$QMD" collection add "${path}" --name "${name}" --mask "${mask}"
      if [ -n "$desc" ]; then
        "$QMD" context add "qmd://${name}/" "$desc" >/dev/null 2>&1 || true
      fi
    fi
  else
    echo "registering collection '${name}' (${path}, ${mask})"
    "$QMD" collection add "${path}" --name "${name}" --mask "${mask}"
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
  stale="$(find "${path}" \( -name '*.md' -o -name '*.nix' \) -not -path '*/.git/*' -not -path '*/.trash/*' -newer "$idxfile" 2>/dev/null | head -5)"
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
    ensure_single "nixconfig" "${REPO}" "NixOS, Darwin, and Home Manager fleet documentation, runbooks and nix modules" "**/*.{nix,md}"
    ;;
  vault)
    ensure_single "vault" "${VAULT_DIR}" "Personal Obsidian knowledge base with zettels, schematics, and notes" "**/*.md"
    ;;
  all)
    ensure_single "nixconfig" "${REPO}" "NixOS, Darwin, and Home Manager fleet documentation, runbooks and nix modules" "**/*.{nix,md}"
    ensure_single "vault" "${VAULT_DIR}" "Personal Obsidian knowledge base with zettels, schematics, and notes" "**/*.md"
    ensure_single "blog" "${BLOG_DIR}" "Published articles on shaoyanji.is-a.dev: Jekyll posts, drafts and authoring notes" "**/*.md"
    ;;
  blog)
    ensure_single "blog" "${BLOG_DIR}" "Published articles on shaoyanji.is-a.dev: Jekyll posts, drafts and authoring notes" "**/*.md"
    ;;
  *)
    echo "Unknown target: $TARGET (use nixconfig|vault|blog|all)" >&2
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
  echo "  qmd search 'query' -c blog        # search published articles"
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
    check_single "blog" "${BLOG_DIR}"
    ;;
  blog)
    check_single "blog" "${BLOG_DIR}"
    ;;
  *)
    echo "Unknown target: $TARGET (use nixconfig|vault|blog|all)" >&2
    exit 2
    ;;
  esac
  ;;
*)
  echo "Unknown mode: $MODE (use ensure|check)" >&2
  exit 2
  ;;
esac
