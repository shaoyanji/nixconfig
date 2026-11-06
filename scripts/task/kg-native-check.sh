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
# Env: KG_ELIXIR (interpreter), RUNS (default 7), BUDGET_MS (default 400).
# Exit 0 = within budget and parity-clean; 1 = regression or divergence.
#
# The ceiling moved 20 -> 30 ms because 20 was a frieren number: the same builder
# read 21.0 ms median on delphi, so the gate reported the machine. It moved
# 30 -> 400 ms on 2026-11-05 for a real reason rather than a slower machine: the
# graph gained the module-import layer, and the native twin now OPENS AND SCANS
# every tracked `.nix` file instead of only the 57 documents. That is 210-235 ms
# median on a warm local checkout, measured with the walk in place and with
# 8-way parallel reads (which bought ~10 ms — the opens, not the CPU).
#
# The walk covers the WHOLE tree on both sides (`lib/nix-files.nix` and the
# Elixir twin), which is 301 files here: the four-root version missed `flake.nix`,
# the overlays and `tools/`. Real cost of the wider walk: 275 ms median on delphi
# (measured 2026-11-06, quiet host), still under the same budget. Symlinks are
# not followed — `result-*` points into store closures full of `.nix` files the
# flake source does not contain.
#
# 400 ms is still a regression gate, not a rubber stamp: the failure it exists for
# is a builder that shells out to `nix eval` (1-3 s) or rescans on every query,
# and both land far above it. Per-phase timing is one env var away —
# `KG_NATIVE_DEBUG=1` prints `[kg-native] modules: … ms`.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
ENGINE="$REPO/tools/kg-engine/kg_engine.exs"
RUNS="${RUNS:-7}"
BUDGET_MS="${BUDGET_MS:-400}"

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() {
  printf 'FAIL  %s\n' "$1"
  fail=1
}

# shellcheck source=lib/kg-elixir.sh
. "$REPO/scripts/task/lib/kg-elixir.sh"

ELIXIR_BIN="$(kg_resolve_elixir)" || true
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
want="$(cd "$REPO" && nix eval --json .?submodules=1#knowledgeGraph.graph --apply 'g: { nodes = builtins.length g.nodes; edges = builtins.length g.edges; }')"
want_nodes="$(jq -r '.nodes' <<<"$want")"
want_edges="$(jq -r '.edges' <<<"$want")"

samples=()
for _ in $(seq 1 "$RUNS"); do
  out="$("$ELIXIR_BIN" --erl "-noinput" "$ENGINE" --build-only --repo "$REPO" 2>/dev/null | tail -1)"
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
echo "== cold bootstrap budget (< ${BUDGET_MS} ms median, on $(hostname)) =="
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
