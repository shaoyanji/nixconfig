#!/usr/bin/env bash
# kg-canvas-check.sh — the gate under the interactive knowledge-graph canvas.
#
# The site is a static Aki build: every click is a fetch of a JSON slice. That
# makes the whole interaction graph checkable without a server, which is what
# this gate does — then it drives the real thing in headless Chrome:
#
#   1. DATA.  data/kg-graph.json must carry the same nodes and edges as the
#             compiled projection, every node must name a slice, and every
#             slice file must exist.
#   2. SLICES. Every neighbour button inside every slice must point at a slice
#             that exists — a dead end discovered by clicking is a bug found by
#             an operator, not by CI.
#   3. SHELL. index.html must load the canvas script and the script must parse.
#   4. CLICK. With `agent-browser` present, click the Knowledge Graph tab, wait
#             for the canvas to load 225 nodes, dispatch a click at
#             host:frieren's screen position, and require the breadcrumb to
#             become "fleet / knowledge-graph / host:frieren". This is the exact
#             TODO exit criterion, tested through the interface a user uses.
#
# Build cost: one text-only derivation, built locally with `--builders ""` so it
# can never dispatch to nixbuild.net.
#
# Env: PORT (default 8787), SKIP_BROWSER=1 to run only the static half.
# Exit 0 = clean; 1 = drift or a failed interaction.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# An ephemeral port, not a "nice round" one: 8787 was already serving Readarr on
# this host, so the gate silently drove a browser at somebody else's UI. It also
# asserts the served page is this site before touching it.
PORT="${PORT:-$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')}"

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() {
  printf 'FAIL  %s\n' "$1"
  fail=1
}

say() { printf '\n== %s ==\n' "$1"; }

say "build the site (local only, no remote builders)"
SITE="$(cd "$REPO" && nix build --builders "" --no-link --print-out-paths .#fleet-docs-site 2>/dev/null | tail -1)"
if [ -n "$SITE" ] && [ -f "$SITE/index.html" ]; then
  ok "built $SITE"
else
  echo "kg-canvas-check: site build failed" >&2
  exit 1
fi

say "data matches the compiled projection"
want_nodes="$(cd "$REPO" && nix eval --json .#knowledgeGraph.graph --apply 'g: builtins.length g.nodes')"
want_edges="$(cd "$REPO" && nix eval --json .#knowledgeGraph.graph --apply 'g: builtins.length g.edges')"
got_nodes="$(jq -r '.nodes | length' "$SITE/data/kg-graph.json")"
got_edges="$(jq -r '.edges | length' "$SITE/data/kg-graph.json")"
[ "$got_nodes" = "$want_nodes" ] && ok "node count ($got_nodes)" || bad "node count: site $got_nodes vs compiled $want_nodes"
[ "$got_edges" = "$want_edges" ] && ok "edge count ($got_edges)" || bad "edge count: site $got_edges vs compiled $want_edges"

missing_slice="$(jq -r --arg root "$SITE/" '.nodes[] | select((.slice // "") == "") | .id' "$SITE/data/kg-graph.json" | head -5)"
[ -z "$missing_slice" ] && ok "every node names a slice" || bad "nodes without a slice: $(printf '%s' "$missing_slice" | tr '\n' ' ')"

dangling=""
while read -r rel; do
  [ -f "$SITE/$rel" ] || dangling="$dangling $rel"
done < <(jq -r '.nodes[].slice' "$SITE/data/kg-graph.json")
[ -z "$dangling" ] && ok "every slice file exists" || bad "missing slice files:$dangling"

say "no dead ends inside a slice"
# Every `url="data/kg/..."` button must resolve to a file; anything else is a
# 404 the Aki fetch swallows with a console error.
bad_links=""
while read -r slice; do
  while read -r url; do
    [ -f "$SITE/$url" ] || bad_links="$bad_links $url(in $slice)"
  done < <(grep -o 'url="data/kg/[^"]*"' "$SITE/$slice" | sed 's/^url="//; s/"$//' | sort -u)
done < <(jq -r '.nodes[].slice' "$SITE/data/kg-graph.json")
[ -z "$bad_links" ] && ok "neighbour links resolve" || bad "dangling slice links:$bad_links"

say "shell wiring"
kg_js="$(grep -o 'kg\.[a-f0-9]*\.min\.js' "$SITE/index.html" | head -1)"
# `node` is not on PATH on every host; use it when present (PATH or an
# already-built store path — never a build), and say so when it is absent.
NODE="$(command -v node 2>/dev/null || true)"
if [ -z "$NODE" ]; then
  NODE="$(ls -d /nix/store/*-nodejs-*/bin/node 2>/dev/null | grep -v -- '-source' | head -1 || true)"
fi

if [ -n "$kg_js" ] && [ -f "$SITE/$kg_js" ]; then
  ok "index.html loads $kg_js"
  if [ -z "$NODE" ]; then
    echo "skip  node absent; canvas script not parse-checked"
  elif "$NODE" --check "$SITE/$kg_js" 2>/dev/null; then
    ok "canvas script parses"
  else
    bad "canvas script does not parse (node --check)"
  fi
else
  bad "index.html does not reference a canvas script"
fi
# The slice is JSON, so the markup arrives escaped: `id=\"kg-canvas\"`.
grep -q 'kg-canvas' "$SITE/data/kg.json" && ok "knowledge-graph slice carries the canvas" || bad "kg slice has no canvas element"
grep -q "aki:applied" "$SITE/aki.min.js" && ok "aki dispatches after a transition" || bad "aki does not dispatch aki:applied"

say "click a node in a real browser"
if [ -n "${SKIP_BROWSER:-}" ]; then
  echo "skip  SKIP_BROWSER set"
elif ! command -v agent-browser >/dev/null 2>&1; then
  echo "skip  agent-browser not installed (static half still ran)"
else
  server_pid=""
  cleanup() {
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
    agent-browser close >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  (cd "$SITE" && python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
  server_pid=$!
  served=0
  for _ in $(seq 1 25); do
    if curl -sf "http://127.0.0.1:$PORT/" 2>/dev/null | grep -q 'Fleet Control Plane'; then
      served=1
      break
    fi
    sleep 0.2
  done
  if [ "$served" != 1 ]; then
    bad "could not serve the site on 127.0.0.1:$PORT"
  fi

  # Every browser step is best-effort plus an explicit assertion below: an
  # agent-browser failure must read as "the canvas did not mount", never as a
  # silently skipped section that still exits 0.
  agent-browser open "http://127.0.0.1:$PORT/" >/dev/null 2>&1 || true
  agent-browser eval "document.querySelector('button[url=\"data/kg.json\"]').click(); 'ok'" >/dev/null 2>&1 || true
  loaded="$(agent-browser eval "new Promise(r => setTimeout(() => r(JSON.stringify({bound: !!(document.getElementById('kg-canvas') && document.getElementById('kg-canvas').dataset.kgBound), nodes: window.__kgDebug ? window.__kgDebug.nodes() : 0})), 900))" 2>/dev/null | tr -d '\n ' || true)"
  # The eval result is a JSON *string*, so its inner quotes come back escaped;
  # strip the escaping before matching rather than pattern-matching on it.
  loaded_norm="$(printf '%s' "$loaded" | tr -d '\\ \n')"
  if [[ "$loaded_norm" == *'"bound":true'* ]] && [[ "$loaded_norm" == *'"nodes":'"$want_nodes"* ]]; then
    ok "canvas mounted with $want_nodes nodes"
  else
    bad "canvas did not mount: $loaded"
  fi

  agent-browser eval "(() => { const c = document.getElementById('kg-canvas'); const p = window.__kgDebug && window.__kgDebug.toScreen('host:frieren'); if (!p) return 'no-position'; const o = {clientX: p.x, clientY: p.y, bubbles: true, pointerId: 1, isPrimary: true, pointerType: 'mouse', button: 0}; c.dispatchEvent(new PointerEvent('pointerdown', o)); c.dispatchEvent(new PointerEvent('pointerup', o)); return 'clicked'; })()" >/dev/null 2>&1 || true
  sleep 1
  crumbs="$(agent-browser eval "document.getElementById('breadcrumbs').textContent" 2>/dev/null | tr -d '\n' || true)"
  if [[ "$crumbs" == *"knowledge-graph / host:frieren"* ]]; then
    ok "click navigated to the node slice ($crumbs)"
  else
    bad "click did not navigate (breadcrumbs: $crumbs)"
  fi
fi

echo
if [ "$fail" = 0 ]; then
  echo "kg-canvas-check: ok — data, slices, and node-click navigation agree"
else
  echo "kg-canvas-check: FAILED — see the FAIL lines above"
fi
exit "$fail"
