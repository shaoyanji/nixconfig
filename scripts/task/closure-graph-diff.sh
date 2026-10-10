#!/usr/bin/env bash
# ==============================================================================
# CLOSURE GRAPH DIFF — Nix-native vs store-DB shell baseline
# ==============================================================================
# Verification harness for milestone 4 of `docs/control-plane-vision.md`.
# Produces the same five views from both implementations and diffs them:
#
#   scripts/task/closure-analysis.sh   store DB (`nix path-info --recursive`)
#   lib/closure-graph.nix              Nix graph (`pkgs.closureInfo`)
#
# Exit status is non-zero if any view differs, so this doubles as a gate.
# Usage: closure-graph-diff.sh [STORE_PATH]
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ROOT="${1:-$(readlink -f /run/current-system)}"
HOST="$(hostname)"
TOP_N=15

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- baseline ----------------------------------------------------------------
echo "==> shell baseline (store DB: nix path-info --recursive)"
t0=$SECONDS
bash scripts/task/closure-analysis.sh size "$ROOT" >"$tmp/shell.size"
bash scripts/task/closure-analysis.sh subsystems "$ROOT" >"$tmp/shell.subsystems"
bash scripts/task/closure-analysis.sh top "$TOP_N" "$ROOT" >"$tmp/shell.top"
bash scripts/task/closure-analysis.sh dot "$ROOT" >"$tmp/shell.dot"
bash scripts/task/closure-analysis.sh toml "$ROOT" >"$tmp/shell.toml"
bash scripts/task/closure-analysis.sh size "$ROOT" >/dev/null # keep narSize cache hot
shell_secs=$((SECONDS - t0))

# --- prototype ---------------------------------------------------------------
echo "==> nix-native prototype (Nix graph: pkgs.closureInfo)"
t0=$SECONDS
nix eval --impure --json --expr "
  let
    pkgs = import <nixpkgs> { };
    cg = import ${REPO_ROOT}/lib/closure-graph.nix { inherit (pkgs) lib; };
    g = cg.mkClosureGraph {
      inherit pkgs;
      host = \"${HOST}\";
      roots = [ \"${ROOT}\" ];
      rootLabel = \"${ROOT}\";
      topN = ${TOP_N};
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
" >"$tmp/nix.json"
nix_secs=$((SECONDS - t0))

for v in size subsystems top dot toml; do
  jq -jr ".$v" "$tmp/nix.json" >"$tmp/nix.$v"
done

# --- compare -----------------------------------------------------------------
fail=0
check() {
  local name="$1" want="$2" got="$3"
  if diff -u "$want" "$got" >"$tmp/$name.diff" 2>&1; then
    printf '  OK    %-12s identical\n' "$name"
  else
    printf '  FAIL  %-12s differs (%s diff lines)\n' "$name" "$(wc -l <"$tmp/$name.diff")"
    sed -n '1,30p' "$tmp/$name.diff" | sed 's/^/          /'
    fail=1
  fi
}

echo
echo "==> view-by-view diff"
check size "$tmp/shell.size" "$tmp/nix.size"
check subsystems "$tmp/shell.subsystems" "$tmp/nix.subsystems"
check top "$tmp/shell.top" "$tmp/nix.top"
check dot "$tmp/shell.dot" "$tmp/nix.dot"
check toml "$tmp/shell.toml" "$tmp/nix.toml"

# --- numeric / structural self-checks ----------------------------------------
echo
echo "==> numeric self-checks"
shell_bytes="$(nix path-info --json --json-format 1 --recursive "$ROOT" | jq '[.[].narSize] | add')"
nix_total="$(jq -r '.totalBytes' "$tmp/nix.json")"
nix_sum="$(jq -r '.sumNarSize' "$tmp/nix.json")"
printf '  shell Σ narSize : %s\n' "$shell_bytes"
if [ "$shell_bytes" = "$nix_total" ]; then
  printf '  closureInfo     : %s  (MATCH)\n' "$nix_total"
else
  printf '  closureInfo     : %s  (MISMATCH, expected %s)\n' "$nix_total" "$shell_bytes"
  fail=1
fi
if [ "$nix_sum" = "$nix_total" ]; then
  printf '  Σ parsed        : %s  (MATCH)\n' "$nix_sum"
else
  printf '  Σ parsed        : %s  (MISMATCH, expected %s)\n' "$nix_sum" "$nix_total"
  fail=1
fi

jq -r '.paths[]' "$tmp/nix.json" | sort >"$tmp/nix.paths"
nix path-info --json --json-format 1 --recursive "$ROOT" | jq -r 'keys[]' | sort >"$tmp/shell.paths"
if diff -q "$tmp/shell.paths" "$tmp/nix.paths" >/dev/null; then
  printf '  path set        : %s paths  (IDENTICAL)\n' "$(wc -l <"$tmp/nix.paths")"
else
  printf '  path set        : DIFFERS\n'
  diff "$tmp/shell.paths" "$tmp/nix.paths" | head -20 | sed 's/^/          /'
  fail=1
fi

# --- cost report --------------------------------------------------------------
echo
echo "==> cost"
printf '  shell baseline (5 views, cached path-info): %ss\n' "$shell_secs"
printf '  nix eval (single call, all 5 views)      : %ss\n' "$nix_secs"
printf '  closure-info derivation                  : %s\n' "$(jq -r '.infoPath' "$tmp/nix.json")"

echo
if [ "$fail" = 0 ]; then
  echo "RESULT: PARITY — the Nix-native closure graph reproduces the shell tool exactly."
else
  echo "RESULT: MISMATCH — see the diff above."
fi
exit "$fail"
