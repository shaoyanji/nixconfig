#!/usr/bin/env bash
# iets.sh — find numtide's `iets` evaluator, or report that it is unavailable.
# Not executable; source it.
#
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/iets.sh"
#   bin="$(resolve_iets)" || bin=""      # empty means "use nix eval"
#
# Why an evaluator of its own, when nix is right there: **Nix never answers
# `nix eval` from its eval cache.** Every graph read therefore pays a full
# evaluation — 1.7 s for `.#knowledgeGraph.graph` on delphi, 0.15-1.7 s for the
# leaf registries. `iets` traces the files an evaluation reads, so the second
# identical read is 24-27 ms (measured 2026-11-07, same box, `--timings`: 817
# cache entries validated in 20 ms). That is the same latency the deleted
# `kg-sidecar` bought with 27 MB of resident BEAM, so the daemon went and this
# stayed.
#
# EVAL ONLY. iets deliberately ignores a flake's `nixConfig`, so a build through
# it would lose the LAN/substituter set and compile what the cache serves. Every
# build path keeps using nix.
#
# Order: IETS_BIN, then PATH, then the revision pinned in flake.lock, built once
# into a GC-rooted out-link. Same shape as `resolve_qmd`, and `--builders ""` so
# resolving a tool can never spend remote build budget.
if [ -z "${REPO:-}" ]; then
  REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || true)"
fi
IETS_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-iets"

resolve_iets() {
  local repo="${1:-${REPO:-}}"
  if [ -n "${IETS_BIN:-}" ]; then
    command -v "$IETS_BIN" >/dev/null 2>&1 || return 1
    printf '%s\n' "$IETS_BIN"
    return 0
  fi
  if command -v iets >/dev/null 2>&1; then
    command -v iets
    return 0
  fi
  command -v nix >/dev/null 2>&1 || return 1
  [ -n "$repo" ] || return 1
  local installable link
  installable="$(jq -r '.nodes["iets"].locked
                     | select(.type == "github")
                     | "github:\(.owner)/\(.repo)/\(.rev)"' "$repo/flake.lock" 2>/dev/null)" || true
  [ -n "$installable" ] && [ "$installable" != "null" ] || return 1
  link="$IETS_CACHE/bin"
  if [ ! -x "$IETS_CACHE/iets/bin/iets" ]; then
    mkdir -p "$IETS_CACHE" || return 1
    nix build "$installable" --out-link "$IETS_CACHE/iets" --builders "" >/dev/null 2>&1 || return 1
  fi
  [ -x "$IETS_CACHE/iets/bin/iets" ] || return 1
  printf '%s\n' "$IETS_CACHE/iets/bin/iets"
}
