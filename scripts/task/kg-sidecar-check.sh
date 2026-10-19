#!/usr/bin/env bash
# kg-sidecar-check.sh — the gate under the sidecar, mirroring checks:kg.
#
# Why a separate gate from `checks:kg`: that one is pure jq over a JSON file and
# costs ~1 s, so it can run in `checks:quick` and the pre-commit hook. This one
# boots a BEAM to prove the engine agrees with the same graph, which is heavier
# and belongs on demand or in CI, not in every commit.
#
# What it catches, each of which shipped broken once:
#   1. parity    — node/edge/type counts must equal the compiled graph exactly.
#                  A stale in-memory copy and a correct one are indistinguishable
#                  from a query alone.
#   2. answers   — blast-radius must equal the jq reverse-edge answer, and
#                  neighbors must contain its own centre.
#   3. interface — an unknown id must NOT be a success (it returned 200 OK), a
#                  missing parameter must be a usage error, and a multi-word
#                  query must arrive intact (it was truncated to its first word
#                  at two layers, both with exit 0).
#   4. lifecycle — `start` must not report success before readiness, and `stop`
#                  must actually remove the socket.
#
# Cost: ~2-4 s (one graph resolution, one boot, one reload-free session).
# Exit 0 = clean, 1 = drift. KG_GRAPH short circuits the resolution.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SIDE="$REPO/scripts/task/kg-sidecar.sh"

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() {
  printf 'FAIL  %s\n' "$1"
  fail=1
}

. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"
G="$(kg_graph_path)" || exit 1
export KG_GRAPH="$G"

say() { printf '\n== %s ==\n' "$1"; }

# The gate owns the daemon's life: it stops whatever is running first, so a
# stale process from an older build cannot answer for the code under test.
"$SIDE" stop >/dev/null 2>&1 || true

say "lifecycle"
if out="$("$SIDE" start 2>&1)"; then
  ok "start exits 0"
else
  bad "start failed: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"
fi
# `start` used to return 0 immediately after spawn, with the engine still running
# its nix eval — the first query then raced it.
if [ -S "${KG_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/kg.sock}" ]; then
  ok "socket exists after start"
else
  bad "no socket after start"
fi

say "parity with the compiled graph"
want_nodes="$(jq -r '.nodes | length' "$G")"
want_edges="$(jq -r '.edges | length' "$G")"
want_types="$(jq -r '[.nodes[].type] | group_by(.) | map({(.[0]): length}) | add | to_entries | sort_by(.key) | map("\(.key)=\(.value)") | join(",")' "$G")"

if got="$("$SIDE" status 2>/dev/null)"; then
  got_nodes="$(jq -r '.nodes' <<<"$got")"
  got_edges="$(jq -r '.edges' <<<"$got")"
  got_types="$(jq -r '.node_types | to_entries | sort_by(.key) | map("\(.key)=\(.value)") | join(",")' <<<"$got")"

  [ "$got_nodes" = "$want_nodes" ] && ok "node count ($got_nodes)" || bad "node count: engine $got_nodes vs graph $want_nodes"
  [ "$got_edges" = "$want_edges" ] && ok "edge count ($got_edges)" || bad "edge count: engine $got_edges vs graph $want_edges"
  [ "$got_types" = "$want_types" ] && ok "type counts ($got_types)" || bad "type counts: engine '$got_types' vs graph '$want_types'"
else
  bad "status failed"
fi

say "answers agree with jq"
seed_host="$(jq -r '[.edges[] | select(.to | startswith("host:")) | .to]
  | group_by(.) | sort_by(-length) | last | .[0] // "" | sub("^host:"; "")' "$G")"
if [ -n "$seed_host" ]; then
  want_impact="$(jq -r --arg h "host:$seed_host" \
    '[.edges[] | select(.to == $h) | .from] | unique | length' "$G")"
  got_impact="$("$SIDE" blast-radius "host:$seed_host" | jq -r '.impacted_count')"
  [ "$got_impact" = "$want_impact" ] &&
    ok "blast-radius host:$seed_host = $got_impact (matches jq)" ||
    bad "blast-radius host:$seed_host: engine $got_impact vs jq $want_impact"

  center="$("$SIDE" neighbors "host:$seed_host" 2 | jq -r '.nodes | map(.id) | index("host:'"$seed_host"'")')"
  [ "$center" != "null" ] && ok "neighbors depth 2 includes its centre" || bad "neighbors dropped its centre"
else
  bad "no host is mentioned anywhere; cannot derive an anchor"
fi

say "error contract"
if "$SIDE" blast-radius host:__no_such_node__ >/dev/null 2>&1; then
  bad "unknown id succeeded (must fail: 404, exit 1)"
else
  rc=$?
  [ "$rc" = 1 ] && ok "unknown id exits 1" || bad "unknown id exits $rc (expected 1)"
fi

if "$SIDE" blast-radius "" >/dev/null 2>&1; then
  bad "missing argument succeeded (must be a usage error)"
else
  rc=$?
  [ "$rc" = 2 ] && ok "missing argument exits 2" || bad "missing argument exits $rc (expected 2)"
fi

say "argument integrity"
# The regression: `search nix eval` reached the engine as `nix` and answered a
# different question with exit 0. Assert on the term the ENGINE echoes back, not
# on the shell, because both layers used to eat it.
term="nix eval"
echoed="$("$SIDE" search "$term" | jq -r '.query')"
[ "$echoed" = "$term" ] && ok "multi-word term survives the task layer ($echoed)" ||
  bad "multi-word term truncated: engine saw '$echoed', not '$term'"

encoded="$("$SIDE" search 'a&b=c d' | jq -r '.query')"
[ "$encoded" = 'a&b=c d' ] && ok "reserved characters survive encoding" ||
  bad "reserved characters mangled: '$encoded'"

say "shutdown"
if "$SIDE" stop >/dev/null 2>&1; then ok "stop exits 0"; else bad "stop failed"; fi
if [ -S "${KG_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/kg.sock}" ]; then
  bad "socket survived stop"
else
  ok "socket removed"
fi

echo
if [ "$fail" = 0 ]; then
  echo "kg-sidecar-check: ok — engine, graph, and interface agree"
else
  echo "kg-sidecar-check: DRIFT — see the FAIL lines above"
fi
exit "$fail"
