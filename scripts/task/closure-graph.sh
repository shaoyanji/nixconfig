#!/usr/bin/env bash
# ==============================================================================
# CLOSURE GRAPH (Nix-native) — prototype
# ==============================================================================
# The Nix counterpart of `closure-analysis.sh`: instead of a shell loop over
# `nix path-info`, this evaluates `lib/closure-graph.nix`, which traverses the
# store graph with `pkgs.closureInfo` (i.e. Nix's own `exportReferencesGraph`).
# Same numbers, one store-cached derivation, no `nix path-info` at all.
#
# Local store only — `closureInfo` builds locally, so unlike the shell tool this
# cannot read a remote store.
#
# Usage:
#   closure-graph.sh [--host NAME] [--root PATH] <command> [N]
#
# Commands:
#   size                     total closure size
#   subsystems (default)     subsystem breakdown
#   top [N]                  N biggest paths by own (nar) size
#   graph                    subsystem breakdown as terminal ASCII graph
#   dot                      raw Graphviz DOT
#   toml                     3-level tree (closure -> subsystem -> top packages)
#   json                     the raw prototype output (numbers + rollup)
#
# Flags: --host NAME (label only)  --root PATH (default: /run/current-system)
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="$(hostname)"
ROOT=""
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?--host needs a value}"; shift 2 ;;
    --host=*) HOST="${1#*=}"; shift ;;
    --root) ROOT="${2:?--root needs a value}"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --help | -h) sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
CMD="${POS[0]:-subsystems}"
N="${POS[1]:-15}"

[[ "$N" =~ ^[0-9]+$ ]] || N=15

# `builtins.storePath` only accepts a real store path, so resolve symlinks
# (`/run/current-system`) before handing the root to Nix — but keep the label
# the caller gave us, matching what closure-analysis.sh echoes.
ROOT_LABEL="${ROOT:-/run/current-system}"
ROOT="$(readlink -f "$ROOT_LABEL" 2>/dev/null || printf '%s' "$ROOT_LABEL")"
[ -n "$ROOT" ] || ROOT="$ROOT_LABEL"

# lib/closure-graph.nix is self-contained (it takes `lib` as an argument), so it
# is imported by absolute path: a single imported file is copied into the store
# alone, which would break any relative import inside it.
expr=$(
  cat <<EOF
let
  pkgs = import <nixpkgs> { };
  cg = import ${REPO_ROOT}/lib/closure-graph.nix { inherit (pkgs) lib; };
  g = cg.mkClosureGraph {
    inherit pkgs;
    host = "${HOST}";
    roots = [ "${ROOT}" ];
    rootLabel = "${ROOT_LABEL}";
    topN = ${N};
  };
in {
  size = cg.renderSize g;
  subsystems = cg.renderSubsystems g;
  top = cg.renderTop g;
  toml = cg.toTOML g;
  dot = cg.toDOT g;
  pathCount = g.pathCount;
  totalBytes = g.totalBytes;
  sumNarSize = g.sumNarSize;
  infoPath = g.infoPath;
  rollup = map (s: { inherit (s) name bytes paths; }) g.rollup;
  paths = map (e: e.path) g.entries;
}
EOF
)

case "$CMD" in
  json) nix eval --impure --json --expr "$expr" ;;
  graph)
    nix eval --impure --json --expr "$expr" | jq -jr '.dot' >"/tmp/closure-graph.$$.dot"
    if command -v graph-easy >/dev/null 2>&1; then
      graph-easy --as=boxart "/tmp/closure-graph.$$.dot"
    else
      cat "/tmp/closure-graph.$$.dot"
    fi
    rm -f "/tmp/closure-graph.$$.dot"
    ;;
  size | subsystems | top | toml | dot)
    nix eval --impure --json --expr "$expr" | jq -jr ".${CMD}"
    ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac
