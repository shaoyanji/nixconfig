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
#   2b. NOTES. Every doc/skill slice must carry that note's own text, rendered
#             at build time, with no leftover placeholder, no empty box, and the
#             file's real heading inside it. The old site reached notes only
#             through one hardcoded forge URL; this replaces that transport.
#   2c. DERIVED. The notes index must list every note node, every closure figure
#             on the budgets page must recompute from closure-budgets.toml, every
#             navigation target must exist, and the retired hand-written pages
#             must be absent. This is the guard against typed facts.
#   3. SHELL. index.html must load the canvas script and the script must parse;
#             the slice must carry the search box and a chip per node type.
#   4. FILTER. Type a label into the real search box: the match set must
#             shrink, the typed node must remain visible, and the counter must
#             follow it. Toggle the `doc` chip off: exactly the doc count
#             disappears, hosts stay. Restore, and the full 225 return. Counts
#             come from the data, never hardcoded.
#   5. NEIGHBOURS. Searching `qmd` must DRAW the matches plus their 1-hop
#             neighbours (so the cluster is visible) while lighting only the
#             matches. Expected size is derived from the edge list.
#   6. SHARE. Load `#kg?q=frieren&types=host,doc` cold: it must land on the
#             graph rather than Overview, restore the box and the chips, and
#             draw exactly the nodes the filter names; editing the box must
#             update the hash an operator would copy.
#   7. CLICK. With `agent-browser` present, click the Knowledge Graph tab, wait
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
SITE="$(cd "$REPO" && nix build --builders "" --no-link --print-out-paths .#sites.fleet-docs-site 2>/dev/null | tail -1)"
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
want_docs="$(jq '[.nodes[] | select(.type == "doc")] | length' "$SITE/data/kg-graph.json")"
# A real doc node for the type-filter assertion. Deriving it from the data keeps
# the check honest now that the retired root narratives are no longer doc nodes
# (AGENTS.nix notes are a separate projection).
want_doc_id="$(jq -r '[.nodes[] | select(.type == "doc")][0].id' "$SITE/data/kg-graph.json")"
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

say "every note is readable inside the site"
# A doc/skill slice must carry its own note, rendered from the file at build
# time. Three failure modes are distinguishable here: the placeholder survived
# (the build step did not run), the note box is empty, and the wrong note landed
# (its first heading is not the file's). The old site had none of this — every
# note was an outbound link to one hardcoded forge URL.
note_slices="$(jq -r '.nodes[] | select(.type == "doc" or .type == "skill") | .slice' "$SITE/data/kg-graph.json")"
note_total="$(grep -c . <<<"$note_slices")"
default_notes="$(jq '[.nodes[] | select(.type == "doc" or .type == "skill")] | length' "$SITE/data/kg-graph.json")"
[ "$note_total" = "$default_notes" ] && ok "$note_total note slices" || bad "note slice count $note_total vs $default_notes note nodes"
# One Python pass over all 64 slices: per-slice jq+grep ran 64 processes and,
# worse, compared markdown source to rendered HTML. The comparison here is on
# TEXT after tags and markdown emphasis are stripped, which is what a reader
# actually sees.
if python3 - "$SITE" "$REPO" <<'PY'
import html, json, os, re, sys

site, repo = sys.argv[1], sys.argv[2]
graph = json.load(open(os.path.join(site, "data/kg-graph.json")))
problems = []


def text_of(fragment):
    # Tags out, entities in: a heading's `&` is `&amp;` in HTML, and `&amp;`
    # compares unequal to `&` until it is decoded.
    return html.unescape(re.sub(r"<[^>]+>", " ", fragment))


def norm(s):
    return re.sub(r"[`*_\[\]()<>\s]+", " ", s).strip().lower()


for node in graph["nodes"]:
    if node["type"] not in ("doc", "skill"):
        continue
    slice_rel = node["slice"]
    pane = json.load(open(os.path.join(site, slice_rel)))["#detail-pane"]["innerHTML"]
    if "<!--KG_NOTE-->" in pane:
        problems.append(slice_rel + " placeholder")
        continue
    marker = '<div class="note">'
    if marker not in pane:
        problems.append(slice_rel + " no-note-box")
        continue
    note = pane.split(marker, 1)[1]
    if not norm(text_of(note)):
        problems.append(slice_rel + " empty")
        continue
    path = node["path"] + ("/SKILL.md" if node["type"] == "skill" else "")
    try:
        lines = open(os.path.join(repo, path), encoding="utf-8").read().splitlines()
    except OSError:
        problems.append(slice_rel + " unreadable-" + path)
        continue
    heading = next((l[2:] for l in lines if l.startswith("# ")), None)
    if heading is None:
        problems.append(slice_rel + " no-heading-in-" + path)
    elif norm(heading) not in norm(text_of(note)):
        problems.append(slice_rel + " wrong-note(" + path + ")")

if problems:
    print(" ".join(problems))
    sys.exit(1)
PY
then
  ok "all $note_total notes render their own text"
else
  bad "note slices wrong (see list above)"
fi

say "pages are derived, and retired pages are gone"
for page in notes closures overview inventory kg; do
  [ -f "$SITE/data/$page.json" ] && ok "data/$page.json exists" || bad "data/$page.json missing"
done
# `debloat`/`services`/`closure` were hand-written tables that could not be
# reproduced from the repository; they were replaced rather than restyled.
for gone in debloat services closure; do
  [ ! -f "$SITE/data/$gone.json" ] && ok "data/$gone.json retired" || bad "data/$gone.json should not exist"
done

# The notes index must list every note node, and its rows must link to slices.
notes_rows="$(jq -r '.["#detail-pane"]["innerHTML"]' "$SITE/data/notes.json" | grep -o 'url="data/kg/' | wc -l)"
[ "$notes_rows" = "$note_total" ] && ok "notes index lists $notes_rows notes" || bad "notes index has $notes_rows rows, expected $note_total"

# Every budget figure on the closures page is recomputed from
# closure-budgets.toml; if the page and the file disagree, one of them is a
# literal and this gate is how that is found.
if python3 - "$SITE/data/closures.json" "$REPO/closure-budgets.toml" <<'PY'
import json, sys, tomllib

page = json.load(open(sys.argv[1]))["#detail-pane"]["innerHTML"]
b = tomllib.load(open(sys.argv[2], "rb"))
default = b.get("defaults", {}).get("headroom_pct", 0)
bad = []
for name, row in b.get("hosts", {}).items():
    base = row.get("baseline", {}).get("bytes")
    head = row.get("headroom_pct", default)
    total = row.get("bytes") or (base * (1 + head / 100) if base else None)
    if total is None:
        continue
    tenths = int(total / 107374182.4 + 0.5)
    label = "%d.%d GiB" % (tenths // 10, tenths % 10)
    if label not in page:
        bad.append("%s=%s" % (name, label))
missing = [n for n in b.get("hosts", {}) if n not in page]
if bad or missing:
    print("budget figures missing from the page: %s %s" % (" ".join(bad), " ".join(missing)))
    sys.exit(1)
PY
then
  ok "closures page figures recompute from closure-budgets.toml"
else
  bad "closures page disagrees with closure-budgets.toml"
fi

# No nav or sidebar button may point at a file the build did not make.
nav_bad=""
while read -r url; do
  [ -f "$SITE/$url" ] || nav_bad="$nav_bad $url"
done < <(grep -o 'url="data/[^"]*"' "$SITE/index.html" | sed 's/^url="//; s/"$//' | sort -u)
[ -z "$nav_bad" ] && ok "every navigation target exists" || bad "dangling navigation:$nav_bad"

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
grep -q 'kg-search' "$SITE/data/kg.json" && ok "slice carries the label search box" || bad "kg slice has no search box"
# The slice is JSON, so the markup is escaped; strip the backslashes before
# counting the distinct chips, otherwise the regex stops at the first `\"`.
chips="$(tr -d '\\' < "$SITE/data/kg.json" | grep -o 'data-kg-type="[a-z]*"' | sort -u | wc -l)"
[ "$chips" = 4 ] && ok "slice carries a chip for all four node types" || bad "kg slice has $chips of 4 type chips"
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

  # eval_json '<js returning JSON.stringify(...)>' -> decoded JSON text.
  # agent-browser returns the value as a JSON *string* (escaped quotes), so it
  # is decoded once with jq instead of pattern-matched with escapes in it.
  eval_json() {
    agent-browser eval "$1" 2>/dev/null | tr -d '\n' | jq -r . 2>/dev/null || true
  }

  agent-browser eval 'document.querySelector("[url=\"data/kg.json\"]").click(); "ok"' >/dev/null 2>&1 || true
  sleep 1

  loaded="$(eval_json 'JSON.stringify({bound: !!(document.getElementById("kg-canvas") && document.getElementById("kg-canvas").dataset.kgBound), nodes: window.__kgDebug ? window.__kgDebug.nodes() : 0, visible: window.__kgDebug ? window.__kgDebug.visible() : 0})')"
  l_bound="$(jq -r '.bound' <<<"$loaded" 2>/dev/null || echo false)"
  l_nodes="$(jq -r '.nodes' <<<"$loaded" 2>/dev/null || echo 0)"
  l_visible="$(jq -r '.visible' <<<"$loaded" 2>/dev/null || echo 0)"
  if [ "$l_bound" = true ] && [ "$l_nodes" = "$want_nodes" ] && [ "$l_visible" = "$want_nodes" ]; then
    ok "canvas mounted with $want_nodes nodes, all visible"
  else
    bad "canvas did not mount (bound=$l_bound nodes=$l_nodes visible=$l_visible, expected $want_nodes)"
  fi

  # Search. Asserts three things at once, because any one of them alone is a
  # weaker claim than "the filter works": the set SHRINKS, the typed node stays
  # visible (a filter that hides what you searched for is the bug class), and
  # the counter follows the same set the renderer uses.
  agent-browser eval '(() => { const i = document.getElementById("kg-search"); i.value = "frieren"; i.dispatchEvent(new Event("input")); return "typed"; })()' >/dev/null 2>&1 || true
  searched="$(eval_json 'JSON.stringify({visible: window.__kgDebug.visible(), hit: window.__kgDebug.isVisible("host:frieren"), count: document.getElementById("kg-count").textContent})')"
  s_visible="$(jq -r '.visible' <<<"$searched" 2>/dev/null || echo "")"
  s_hit="$(jq -r '.hit' <<<"$searched" 2>/dev/null || echo false)"
  s_count="$(jq -r '.count' <<<"$searched" 2>/dev/null || echo "")"
  if [ -n "$s_visible" ] && [ "$s_visible" -gt 0 ] && [ "$s_visible" -lt "$want_nodes" ] && [ "$s_hit" = true ]; then
    ok "search \"frieren\" narrows to $s_visible nodes and keeps host:frieren"
  else
    bad "search did not filter as expected: $searched"
  fi
  case "$s_count" in
    *"of $want_nodes nodes"*) ok "counter followed the filter ($s_count)" ;;
    *) bad "counter did not follow the filter: '$s_count'" ;;
  esac

  # Neighbour highlight. `qmd` is used deliberately: its matches (skill:qmd plus
  # a doc) have tag neighbours that do NOT match the query, so the lit set must
  # be strictly larger than the match set. `frieren` cannot prove this — every
  # one of its neighbours also matches, which is exactly the blind spot a
  # hardcoded query would leave.
  expect_drawn="$(jq '[.nodes[] | select(((.label|ascii_downcase)|contains("qmd")) or ((.id|ascii_downcase)|contains("qmd")))] as $m | [.edges[] | select(((.from as $f | $m|map(.id)|index($f)) != null) or ((.to as $t | $m|map(.id)|index($t)) != null))] | map(.from,.to) | unique | length' "$SITE/data/kg-graph.json")"
  agent-browser eval '(() => { const i = document.getElementById("kg-search"); i.value = "qmd"; i.dispatchEvent(new Event("input")); return "typed"; })()' >/dev/null 2>&1 || true
  focused="$(eval_json 'JSON.stringify({visible: window.__kgDebug.visible(), drawn: window.__kgDebug.drawn(), focus: window.__kgDebug.focus()})')"
  f_visible="$(jq -r '.visible' <<<"$focused" 2>/dev/null || echo 0)"
  f_drawn="$(jq -r '.drawn' <<<"$focused" 2>/dev/null || echo 0)"
  f_focus="$(jq -r '.focus' <<<"$focused" 2>/dev/null || echo 0)"
  if [ "$f_drawn" = "$expect_drawn" ] && [ "$f_drawn" -gt "$f_visible" ] && [ "$f_focus" = "$f_visible" ]; then
    ok "search draws its neighbourhood ($f_visible matches lit, $f_drawn drawn with neighbours)"
  else
    bad "neighbour highlight wrong: $focused (expected drawn=$expect_drawn > matches=$f_visible, lit=$f_visible)"
  fi

  # Type filter. Clearing the query first isolates the chip, and the expected
  # count is derived from the data (not hardcoded), so adding a host cannot
  # silently weaken this assertion.
  agent-browser eval '(() => { const i = document.getElementById("kg-search"); i.value = ""; i.dispatchEvent(new Event("input")); document.querySelector("[data-kg-type=doc]").click(); return "toggled"; })()' >/dev/null 2>&1 || true
  toggled="$(eval_json "JSON.stringify({visible: window.__kgDebug.visible(), doc: window.__kgDebug.isVisible(\"${want_doc_id}\"), host: window.__kgDebug.isVisible(\"host:frieren\")})")"
  t_visible="$(jq -r '.visible' <<<"$toggled" 2>/dev/null || echo "")"
  t_doc="$(jq -r '.doc' <<<"$toggled" 2>/dev/null || echo true)"
  t_host="$(jq -r '.host' <<<"$toggled" 2>/dev/null || echo false)"
  expect_visible=$((want_nodes - want_docs))
  if [ "$t_doc" = false ] && [ "$t_host" = true ] && [ "$t_visible" = "$expect_visible" ]; then
    ok "toggling doc off hides all $want_docs docs and nothing else"
  else
    bad "type toggle wrong: $toggled (expected visible=$expect_visible, doc=false, host=true)"
  fi

  # Restore the full graph before the navigation test, so that test measures
  # the click path rather than a filtered canvas.
  agent-browser eval '(() => { document.querySelector("[data-kg-type=doc]").click(); return "restored"; })()' >/dev/null 2>&1 || true
  restored="$(eval_json 'JSON.stringify({visible: window.__kgDebug.visible()})')"
  r_visible="$(jq -r '.visible' <<<"$restored" 2>/dev/null || echo 0)"
  [ "$r_visible" = "$want_nodes" ] && ok "clearing the filters restores all $want_nodes nodes" || bad "filters did not restore: $restored"

  agent-browser eval '(() => { const c = document.getElementById("kg-canvas"); const p = window.__kgDebug && window.__kgDebug.toScreen("host:frieren"); if (!p) return "no-position"; const o = {clientX: p.x, clientY: p.y, bubbles: true, pointerId: 1, isPrimary: true, pointerType: "mouse", button: 0}; c.dispatchEvent(new PointerEvent("pointerdown", o)); c.dispatchEvent(new PointerEvent("pointerup", o)); return "clicked"; })()' >/dev/null 2>&1 || true
  sleep 1
  crumbs="$(agent-browser eval 'document.getElementById("breadcrumbs").textContent' 2>/dev/null | tr -d '\n' || true)"
  if [[ "$crumbs" == *"knowledge-graph / host:frieren"* ]]; then
    ok "click navigated to the node slice ($crumbs)"
  else
    bad "click did not navigate (breadcrumbs: $crumbs)"
  fi

  # Shareable view. Aki transitions never touch the URL, so the hash is the only
  # state a filtered view has; loading it must land ON the graph (not Overview),
  # restore the box and the chips, and draw exactly the nodes the filter names.
  expect_hash="$(jq '[.nodes[] | select((.type == "host" or .type == "doc") and (((.label|ascii_downcase)|contains("frieren")) or ((.id|ascii_downcase)|contains("frieren"))))] | length' "$SITE/data/kg-graph.json")"
  agent-browser open "http://127.0.0.1:$PORT/#kg?q=frieren&types=host,doc" >/dev/null 2>&1 || true
  sleep 1
  shared="$(eval_json 'JSON.stringify({crumbs: document.getElementById("breadcrumbs").textContent, visible: window.__kgDebug ? window.__kgDebug.visible() : -1, q: document.getElementById("kg-search") ? document.getElementById("kg-search").value : null, chips: [].slice.call(document.querySelectorAll("[data-kg-type]")).map(function (c) { return c.getAttribute("data-kg-type") + "=" + (c.classList.contains("nav-active") ? "on" : "off"); }).join(",")})')"
  h_crumbs="$(jq -r '.crumbs' <<<"$shared" 2>/dev/null || echo "")"
  h_visible="$(jq -r '.visible' <<<"$shared" 2>/dev/null || echo -1)"
  h_q="$(jq -r '.q' <<<"$shared" 2>/dev/null || echo "")"
  h_chips="$(jq -r '.chips' <<<"$shared" 2>/dev/null || echo "")"
  if [[ "$h_crumbs" == *"knowledge-graph"* ]] && [ "$h_visible" = "$expect_hash" ] && [ "$h_q" = "frieren" ] && [ "$h_chips" = "host=on,skill=off,doc=on,tag=off" ]; then
    ok "#kg?q=frieren&types=host,doc opens the graph with $h_visible matching nodes"
  else
    bad "shareable hash did not restore the view: $shared (expected visible=$expect_hash, chips host=on,skill=off,doc=on,tag=off)"
  fi

  # Writing the other direction: an edit must update the hash an operator would
  # copy out of the address bar.
  agent-browser eval '(() => { const i = document.getElementById("kg-search"); i.value = "eisen"; i.dispatchEvent(new Event("input")); return "typed"; })()' >/dev/null 2>&1 || true
  hash_now="$(agent-browser eval 'window.location.hash' 2>/dev/null | tr -d '\n' || true)"
  case "$hash_now" in
    *q=eisen*) ok "typing updates the URL ($hash_now)" ;;
    *) bad "typing did not update the hash (got '$hash_now')" ;;
  esac
fi

echo
if [ "$fail" = 0 ]; then
  echo "kg-canvas-check: ok — data, slices, notes, budgets, filters, neighbours, and node-click navigation agree"
else
  echo "kg-canvas-check: FAILED — see the FAIL lines above"
fi
exit "$fail"
