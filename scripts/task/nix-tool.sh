#!/usr/bin/env bash
# nix-tool.sh — resolve an agent/dev tool without paying its closure.
#
#   nix-tool.sh resolve <name>        print the binary's store/PATH path
#   nix-tool.sh run <name> [args...]  resolve, then exec with args
#   nix-tool.sh registry              the name -> attr table
#
# One contract for "this tool is callable, closure or not": the binary on PATH
# wins (installed is free), otherwise the tool is fetched FRESH from the
# llm-agents flake — never the repo's pin. These tools are cache-served
# (cache.numtide.com), so `nix run github:numtide/llm-agents.nix#<attr>` is a
# substituter hit, not a build; always taking upstream HEAD is deliberate —
# this category of tool is meant to ride the fresh cache, not the lock.
# `--builders ""` keeps a resolve off the remote builders.
#
# The registry maps the name you call to a full installable — upstream
# `github:numtide/llm-agents.nix#<attr>` for cache-served tools, this flake for
# repo wrappers ({REPO} and {SYSTEM} are substituted) — plus the binary inside.
# Add a row; don't special-case callers.
set -euo pipefail

REPO=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-tools"
LLM="github:numtide/llm-agents.nix"     # fresh upstream — cache-served by design

# name|installable|bin
registry() {
  cat <<EOF
agy|${LLM}#antigravity-cli|agy
agy-gemini|git+file://{REPO}?submodules=1#cli.ai.agy-gemini|agy-gemini
qmd|${LLM}#qmd|qmd
toon|${LLM}#toon|toon
ai-memory|${LLM}#ai-memory|ai-memory
agent-browser|${LLM}#agent-browser|agent-browser
dsh|${LLM}#dsh|dsh
freebuff|${LLM}#freebuff|freebuff
hermes-agent|${LLM}#hermes-agent|hermes-agent
reasonix|${LLM}#reasonix|reasonix
jev|${LLM}#jev|jev-decide
EOF
}

row() {  # row <name> -> raw "installable bin" ({REPO}/{SYSTEM} unexpanded)
  local name=$1 line
  line=$(grep -E "^${name}\|" <(registry) | head -1) || true
  [ -n "$line" ] || return 1
  printf '%s %s\n' "$(cut -d'|' -f2 <<<"$line")" "$(cut -d'|' -f3 <<<"$line")"
}

resolve() {  # resolve <name> -> path on stdout, noise on stderr
  local name=$1 inst bin link sys
  read -r inst bin < <(row "$name") || {
    echo "nix-tool: '$name' is not in the registry (nix-tool.sh registry lists it)" >&2
    return 2
  }
  if command -v "$bin" >/dev/null 2>&1; then
    command -v "$bin"; return 0
  fi
  command -v nix >/dev/null 2>&1 || return 1
  link="$CACHE_DIR/$name"
  if [ ! -x "$link/bin/$bin" ]; then
    # Placeholders only expand on the miss path — an installed tool costs a
    # `command -v`, never a nix eval.
    sys=$(nix eval --impure --expr builtins.currentSystem --raw)
    inst=${inst//\{REPO\}/$REPO}
    inst=${inst//\{SYSTEM\}/$sys}
    echo "==> $bin not on PATH; fetching $inst" >&2
    mkdir -p "$CACHE_DIR"
    nix build "$inst" --out-link "$link" --builders "" >/dev/null 2>&1 \
      || { echo "nix-tool: fetch of $inst failed" >&2; return 1; }
  fi
  [ -x "$link/bin/$bin" ] || { echo "nix-tool: $link has no bin/$bin" >&2; return 1; }
  printf '%s\n' "$link/bin/$bin"
}

case "${1:-}" in
  resolve) resolve "$2" ;;
  run)
    name=$2; shift 2
    bin=$(resolve "$name")
    exec "$bin" "$@"
    ;;
  registry) registry ;;
  *)
    echo "usage: nix-tool.sh resolve|run <name> [args] | registry" >&2
    exit 2
    ;;
esac
