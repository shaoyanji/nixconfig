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
# The rule, stated once. The graph is compiled FROM THE WORKING TREE, so what
# invalidates it is a change to the tree's CONTENT, not the existence of a diff:
#   key = HEAD + sha1(git diff HEAD)
#   same key  -> reuse the cache
#   new key   -> evaluate, then store under that key
# Answering about the last commit while the operator is editing the tree is still
# worse than an evaluation — a changed tree always re-evaluates. What changed on
# 2026-11-02 is the dirty case: keying on "is dirty" re-evaluated on every call
# (~680 ms each) even when the tree had not moved between calls, which is most of
# why `ops:ask:plan` cost ~1 s. Measured: routing+jq over the compiled graph is
# 77 ms, `git diff | sha1sum` is 27 ms, and the eval on a miss was ~1.7 s with
# `nix eval` — 820 ms cold / 25 ms warm once the eval goes through `iets`
# (lib/iets.sh). KG_GRAPH (any caller's --graph) short circuits both: used as
# given, no eval, no cache. A resident daemon used to serve this and could not
# answer for a dirty tree at all; the eval cache answers for both.
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

# The graph itself. `iets` when it resolves (25 ms warm, same bytes as nix —
# `checks:kg:iets` compares them), nix otherwise. Both read the same flake
# attribute, so the cache file below is identical whichever answered.
kg_eval_graph() {
  # shellcheck source=lib/iets.sh
  . "${BASH_SOURCE[0]%/*}/iets.sh"
  iets_eval_json .#knowledgeGraph.graph
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
  # Content, not the dirty bit. `HEAD` covers staged+unstaged; untracked files are
  # irrelevant because a git flake does not see them either.
  digest="clean"
  if ! git -C "$REPO" diff HEAD --quiet -- . 2>/dev/null; then
    digest="$(git -C "$REPO" diff HEAD -- . 2>/dev/null | sha1sum | cut -c1-12)"
  fi
  path="$cache/kg-$rev-$digest.json"

  if [ "$refresh" = 1 ] || [ ! -s "$path" ]; then
    mkdir -p "$cache"
    # temp file + rename: a reader that races the eval would otherwise see a
    # half-written JSON, and jq would report a parse error rather than a miss.
    if ! (cd "$REPO" && kg_eval_graph) >"$path.tmp" 2>/dev/null; then
      rm -f "$path.tmp"
      echo "kg-graph: evaluating .#knowledgeGraph.graph failed" >&2
      return 1
    fi
    mv "$path.tmp" "$path"
    # One file per distinct working-tree content: bounded by a week, so an
    # afternoon of editing cannot leave a directory of graphs nobody will read.
    find "$cache" -maxdepth 1 -name 'kg-*.json' -type f -mtime +7 -delete 2>/dev/null || true
  fi

  printf '%s' "$path"
}
