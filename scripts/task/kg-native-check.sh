#!/usr/bin/env bash
# kg-native-check.sh — the cold-bootstrap budget, measured instead of claimed.
#
# The TODO this closes said: "cold sidecar boot indexes all 225 nodes in < 20 ms
# with 0 calls to nix". Two halves, two assertions:
#
#   1. BUDGET. `--build-only` builds the native graph and exits without starting
#      the server. The gate runs it RUNS times and takes the MEDIAN: a single
#      sample on a NAS-mounted repo is dominated by read jitter (p90 on this
#      host is ~2x the median), and quoting one lucky run is how the previous
#      "~100 ms" number became folklore.
#   2. ZERO NIX CALLS. KGEngine.Native contains no subprocess primitive
#      (System.cmd / Port.open / :os.cmd). This is a static property of the
#      module, so it is checked statically — a runtime check could pass while a
#      fallback branch silently shells out.
#
# Also asserts parity: node/edge counts must equal the compiled projection, so
# a faster builder cannot buy speed by answering from a smaller graph.
#
# Env: KG_ELIXIR (interpreter), RUNS (default 7), BUDGET_MS (default 20).
# Exit 0 = within budget and parity-clean; 1 = regression or divergence.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
ENGINE="$REPO/tools/kg-engine/kg_engine.exs"
RUNS="${RUNS:-7}"
BUDGET_MS="${BUDGET_MS:-20}"

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() {
  printf 'FAIL  %s\n' "$1"
  fail=1
}

resolve_elixir() {
  if [ -n "${KG_ELIXIR:-}" ]; then
    printf '%s' "$KG_ELIXIR"
    return 0
  fi
  if command -v elixir >/dev/null 2>&1; then
    command -v elixir
    return 0
  fi
  # Same rule as kg-sidecar.sh: look up the store first (`--offline` never
  # reaches the network), then substitute. `--builders ""` keeps a miss from
  # turning into a remote build.
  local out
  out="$(nix build --no-link --offline --builders "" --print-out-paths nixpkgs#beamPackages.elixir 2>/dev/null | head -1)"
  if [ -z "$out" ]; then
    echo "kg-native-check: elixir not in the store; substituting (one-off)" >&2
    out="$(nix build --no-link --builders "" --print-out-paths nixpkgs#beamPackages.elixir 2>/dev/null | head -1)"
  fi
  [ -n "$out" ] && printf '%s' "$out/bin/elixir"
  return 0
}

ELIXIR_BIN="$(resolve_elixir)" || true
if [ -z "$ELIXIR_BIN" ] || [ ! -x "$ELIXIR_BIN" ]; then
  echo "kg-native-check: no Elixir interpreter (set KG_ELIXIR)" >&2
  exit 1
fi

echo "== zero subprocess in KGEngine.Native =="
if sed -n '/^defmodule KGEngine.Native/,/^end$/p' "$ENGINE" | grep -Eq 'System\.cmd|Port\.open|:os\.cmd'; then
  bad "KGEngine.Native shells out — the cold path must be native"
else
  ok "native builder contains no subprocess primitive"
fi

echo
echo "== parity with the compiled projection =="
want="$(cd "$REPO" && nix eval --json .#knowledgeGraph.graph --apply 'g: { nodes = builtins.length g.nodes; edges = builtins.length g.edges; }')"
want_nodes="$(jq -r '.nodes' <<<"$want")"
want_edges="$(jq -r '.edges' <<<"$want")"

samples=()
last=""
for _ in $(seq 1 "$RUNS"); do
  out="$("$ELIXIR_BIN" --erl "-noinput" "$ENGINE" --build-only --repo "$REPO" 2>/dev/null | tail -1)"
  last="$out"
  got_nodes="$(jq -r '.nodes' <<<"$out")"
  got_edges="$(jq -r '.edges' <<<"$out")"
  if [ "$got_nodes" != "$want_nodes" ] || [ "$got_edges" != "$want_edges" ]; then
    bad "graph diverged: native ${got_nodes}/${got_edges} vs compiled ${want_nodes}/${want_edges}"
    break
  fi
  samples+=("$(jq -r '.ms' <<<"$out")")
done

if [ "${#samples[@]}" -eq "$RUNS" ]; then
  ok "node/edge counts match the compiled graph ($want_nodes nodes, $want_edges edges) in $RUNS/$RUNS runs"
fi

echo
echo "== cold bootstrap budget (< ${BUDGET_MS} ms median) =="
if [ "${#samples[@]}" -gt 0 ]; then
  printf '%s\n' "${samples[@]}" | sort -n | awk -v budget="$BUDGET_MS" '
    { v[NR] = $1; seen = seen (NR > 1 ? ", " : "") $1 }
    END {
      n = NR
      med = (n % 2) ? v[(n + 1) / 2] : (v[n / 2] + v[n / 2 + 1]) / 2
      i90 = int(n * 0.9); if (i90 < 1) i90 = 1
      printf "samples: %s ms\nmedian:  %.1f ms\np90:     %.1f ms\nmax:     %.1f ms\n", seen, med, v[i90], v[n]
      exit (med < budget ? 0 : 1)
    }' || bad "median exceeds ${BUDGET_MS} ms"
fi

echo
if [ "$fail" = 0 ]; then
  echo "kg-native-check: ok — native graph, no subprocess, within budget"
else
  echo "kg-native-check: FAILED — see the FAIL lines above"
fi
exit "$fail"
