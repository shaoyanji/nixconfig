#!/usr/bin/env bash
# Regression fixture for `task checks:kg` (scripts/task/kg-check.sh).
#
# kg-check.sh reads the compiled graph through the shared resolver, and
# KG_GRAPH=<file> makes it skip nix and judge a mutated copy — the drift path
# the gate itself provides. Each mutation is a real drift class the gate
# exists to refuse: a one-sided rename leaves an edge pointing at no node, and
# a projection that stopped reading files returns a nearly-empty graph.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Resolve the real compiled graph once through the gate's own resolver.
. "$repo/scripts/task/lib/kg-graph.sh"
G="$(kg_graph_path)" || { echo "fixture: graph resolve failed" >&2; exit 2; }
[ -s "$G" ] || { echo "fixture: no graph at $G" >&2; exit 2; }

fail=0

# 1. A one-sided rename — an edge endpoint no node carries.
jq '(.edges[0].to) = "ghost:renamed-away"' "$G" >"$tmp/renamed.json"
out=$(KG_GRAPH="$tmp/renamed.json" bash "$repo/scripts/task/kg-check.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'edge endpoints resolve'; then
  echo "ok   dangling endpoint refused, check named"
else
  echo "FAIL dangling endpoint: rc=$rc"; echo "$out" | tail -6; fail=1
fi

# 2. A projection that silently stopped reading files — the floor fires.
jq '.nodes = [] | .edges = []' "$G" >"$tmp/empty.json"
out=$(KG_GRAPH="$tmp/empty.json" bash "$repo/scripts/task/kg-check.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'non-trivial'; then
  echo "ok   empty projection refused, floor named"
else
  echo "FAIL empty projection: rc=$rc"; echo "$out" | tail -6; fail=1
fi

# 3. The real graph passes.
if KG_GRAPH="$G" bash "$repo/scripts/task/kg-check.sh" >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: gate refused the live graph"; fail=1
fi

[ $fail -eq 0 ] && echo "kg:test: all cases pass"
exit $fail
