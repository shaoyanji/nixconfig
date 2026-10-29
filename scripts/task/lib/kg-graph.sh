#!/usr/bin/env bash
# kg-graph.sh — the ONE graph resolver behind kg-ask, kg-bench, kg-check and
# kg-query. Not executable; source it.
#
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/kg-graph.sh"
#   graph="$(kg_graph_path)" || exit 1     # cached, or KG_GRAPH if set
#   graph="$(kg_graph_path 1)"             # force a refresh (--refresh)
#
# Why a shared file rather than four copies: the rule below is subtle enough that
# the copies had already drifted — three cached with a temp file and one resolved
# uncached — and a cache rule that differs per caller is a bug factory, because
# its two failure modes ("the graph is stale" and "the graph is slow") each get
# picked silently by whichever copy you happen to call.
#
# The rule, stated once. The graph is compiled FROM THE WORKING TREE, so:
#   clean tree  -> reuse the cache, keyed by revision
#   dirty tree  -> always re-evaluate
# Answering about the last commit while the operator is editing the tree is worse
# than the ~1 s a warm evaluation costs. KG_GRAPH (any caller's --graph) short
# circuits both: the path is used as given, no eval, no cache.
#
# Requires: git, nix and awk. REPO (the repo root) is taken from the caller when
# exported, and derived from this file's own location otherwise — kg-ask.sh never
# set it, so `task ops:ask` died with "kg-graph: REPO is not set" at query time
# while every other kg:* script worked. A path that is knowable here is not a
# precondition to impose on nine callers.
# kg_usage <path-to-script> — print that script's leading `#` comment block (the
# shebang is skipped), one `# ` stripped. Each kg:* script used to hardcode a
# line range for this, which silently truncates the help the moment a comment is
# added above it. Pass "${BASH_SOURCE[0]}" from the caller: inside a function the
# value would otherwise be this library's own path.
if [ -z "${REPO:-}" ]; then
  REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || true)"
fi

kg_usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${1:-/dev/null}"
}

kg_graph_path() {
  local refresh="${1:-0}" cache rev path dirty
  if [ -n "${KG_GRAPH:-}" ]; then
    printf '%s' "$KG_GRAPH"
    return 0
  fi
  [ -n "${REPO:-}" ] || {
    echo "kg-graph: REPO is not set" >&2
    return 1
  }

  cache="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig"
  rev="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo untracked)"
  path="$cache/kg-$rev.json"

  dirty=0
  git -C "$REPO" diff --quiet -- . 2>/dev/null || dirty=1

  if [ "$refresh" = 1 ] || [ "$dirty" = 1 ] || [ ! -s "$path" ]; then
    mkdir -p "$cache"
    # temp file + rename: a reader that races the eval would otherwise see a
    # half-written JSON, and jq would report a parse error rather than a miss.
    if ! (cd "$REPO" && nix eval --json .#knowledgeGraph.graph) >"$path.tmp" 2>/dev/null; then
      rm -f "$path.tmp"
      echo "kg-graph: nix eval .#knowledgeGraph.graph failed" >&2
      return 1
    fi
    mv "$path.tmp" "$path"
  fi

  printf '%s' "$path"
}
