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
#   data                     machine-readable traversal payload for closure-menu.sh:
#                            every subsystem with ALL of its packages, each already
#                            rendered to human units by the same `human` used above,
#                            so the menu never re-implements size formatting.
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
    --help | -h)
      # Print the comment header (title + body) and stop at the first
      # non-comment line, dropping trailing rule lines. Written this way so the
      # block can be edited without line numbers going stale — and because the
      # header has a rule line directly under the title, "stop at the next
      # rule" would print only that title and silently truncate help.
      awk 'NR <= 2 { next }
           /^[^#]/ { exit }
           { rows[++n] = $0 }
           END {
             while (n > 0 && (rows[n] ~ /^# =+$/ || rows[n] ~ /^#?[ \t]*$/)) n--
             for (i = 1; i <= n; i++) { sub(/^# ?/, "", rows[i]); print rows[i] }
           }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    --*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
CMD="${POS[0]:-subsystems}"
N="${POS[1]:-15}"

[[ "$N" =~ ^[0-9]+$ ]] || N=15

# `data` feeds the gum explorer, which lists every package inside a subsystem
# rather than a truncated top-N. Every other view keeps the small default.
PER=${PER:-8}
[ "$CMD" = "data" ] && PER=1000000

# `builtins.storePath` only accepts a real store path, so resolve symlinks
# (`/run/current-system`) before handing the root to Nix — but keep the label
# the caller gave us, matching what closure-analysis.sh echoes.
ROOT_LABEL="${ROOT:-/run/current-system}"
ROOT="$(readlink -f "$ROOT_LABEL" 2>/dev/null || printf '%s' "$ROOT_LABEL")"
[ -n "$ROOT" ] || ROOT="$ROOT_LABEL"

# lib/closure-graph.nix is self-contained (it takes `lib` as an argument), so it
# is imported by absolute path: a single imported file is copied into the store
# alone, which would break any relative import inside it.
#
# The Nix body below is a QUOTED heredoc (`<<'EOF'`), so the shell expands
# nothing inside it. That is deliberate: an unquoted heredoc over Nix source is
# a landmine — a stray backtick or `$` in a comment or a Nix string is silently
# command-substituted (this cost us a "wastedBytes: command not found" on stderr
# from a comment, while the eval still returned rc=0 and correct JSON). Inputs
# cross the boundary as exported environment variables instead, read with
# `builtins.getEnv` — safe here because reaching the ambient <nixpkgs> already
# requires `--impure`.
export CG_REPO_ROOT="$REPO_ROOT" \
  CG_HOST="$HOST" CG_ROOT="$ROOT" CG_ROOT_LABEL="$ROOT_LABEL" \
  CG_TOP_N="$N" CG_TOP_PER="$PER"
expr=$(
  cat <<'EOF'
let
  env = builtins.getEnv;
  pkgs = import <nixpkgs> { };
  cg = import (env "CG_REPO_ROOT" + "/lib/closure-graph.nix") { inherit (pkgs) lib; };
  g = cg.mkClosureGraph {
    inherit pkgs;
    host = env "CG_HOST";
    roots = [ (env "CG_ROOT") ];
    rootLabel = env "CG_ROOT_LABEL";
    topN = builtins.fromJSON (env "CG_TOP_N");
    topPerSubsystem = builtins.fromJSON (env "CG_TOP_PER");
  };
  pct = s:
    if g.totalBytes != 0
    then cg.fmt1 (100.0 * s.bytes / g.totalBytes)
    else "0.0";
  lib = pkgs.lib;
  # Version-stripping heuristic: drop everything from the first "-<digit>".
  #   chromium-unwrapped-154.0.8037.97 -> chromium-unwrapped
  #   llvm-21.1.8-lib                  -> llvm
  #   python3.14-torch-2.13.0-lib      -> python3.14-torch
  # Deliberately a heuristic: a name carrying "-unstable-<date>" can strip mid
  # name. That is why every group prints its members verbatim — the key is a
  # grouping hint for a human, never a fact to act on unverified.
  versionStrip = n: let
    m = builtins.match "(.*?)-[0-9].*" n;
  in
    if m == null
    then n
    else builtins.head m;
  # Two versions of one package in a single closure is pure waste: the second
  # copy buys nothing. wastedBytes is the optimistic saving if the closure could
  # be reduced to one version (total minus the largest member).
  dupGroups = lib.sort (a: b: a.wastedBytes > b.wastedBytes) (map (grp: let
    sorted = lib.sort (x: y: x.narSize > y.narSize) grp;
    tot = lib.foldl' (x: e: x + e.narSize) 0 grp;
    biggest = (builtins.head sorted).narSize;
  in {
    name = versionStrip (builtins.head grp).name;
    count = builtins.length grp;
    totalBytes = tot;
    totalHuman = cg.human tot;
    wastedBytes = tot - biggest;
    wastedHuman = cg.human (tot - biggest);
    members = map (e: {
      inherit (e) name path narSize;
      narSizeHuman = cg.human e.narSize;
      subsystem = cg.subsystemOf e.name;
    }) sorted;
  }) (lib.filter (grp: builtins.length grp > 1) (lib.attrValues (lib.groupBy (e: versionStrip e.name) g.entries))));
  # Recomputed once here so the payload and the per-group rows cannot drift.
  dupTotal = lib.foldl' (a: d: a + d.wastedBytes) 0 dupGroups;
in {
  size = cg.renderSize g;
  subsystems = cg.renderSubsystems g;
  top = cg.renderTop g;
  toml = cg.toTOML g;
  dot = cg.toDOT g;
  data = {
    # rootPath is the RESOLVED store path; `label` is what the caller asked for
    # (/run/current-system). Consumers that shell out (nix why-depends,
    # nix-store --referrers) need the former, humans want the latter.
    inherit (g) host label pathCount totalBytes rootName rootPath;
    totalHuman = cg.human g.totalBytes;
    duplicates = dupGroups;
    dupWastedBytes = dupTotal;
    dupWastedHuman = cg.human dupTotal;
    subsystems = map (s: {
      inherit (s) name bytes paths;
      bytesHuman = cg.human s.bytes;
      percent = pct s;
      pkgs = map (e: {
        inherit (e) name base narSize path;
        narSizeHuman = cg.human e.narSize;
      }) s.top;
    }) g.rollup;
  };
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
  data) nix eval --impure --json --expr "$expr" | jq -c '.data' ;;
  size | subsystems | top | toml | dot)
    nix eval --impure --json --expr "$expr" | jq -jr ".${CMD}"
    ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac
