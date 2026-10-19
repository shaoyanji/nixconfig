# ==============================================================================
# lib/aki-site.nix — Aki-Powered Nix-Native Static Documentation & Closure Explorer
# ==============================================================================
# An ultra-minimal hypermedia site (~270 B aki JS primitive) generated natively
# by Nix at build time. Emits index.html, aki.min.js, style.css, and static JSON
# slice transitions for instant, zero-daemon exploration of host inventories,
# closure attribution graphs, and debloat milestones.
# ==============================================================================
{
  pkgs,
  lib ? pkgs.lib,
  # Compiled registry from lib/inventory.nix (flake output `inventory`). Callers
  # in the flake pass it so this site cannot disagree with the hosts about a
  # host's kind/status/role; the TOML fallback exists only for a standalone
  # `nix-build lib/aki-site.nix` and is NOT defaults-normalised.
  inventory ? null,
}: let
  inventoryFile = ../inventory.toml;
  rawInventory =
    if builtins.pathExists inventoryFile
    then builtins.fromTOML (builtins.readFile inventoryFile)
    else {hosts = {};};
  inv =
    if inventory != null
    then inventory
    else rawInventory;

  skills = import ./skills.nix {inherit lib;};
  kg = import ./knowledge-graph.nix {
    inherit lib skills;
    inventory = inv;
  };

  # Aki hypermedia driver with delegated click listener for dynamic DOM mutations
  akiJs = ''
    (() => {
      function pollTelemetry() {
        fetch('data/live.json')
          .then(r => r.json())
          .then(d => {
            const el = document.getElementById('live-status-badge');
            if (el && d.uptime) {
              el.innerHTML = "🟢 " + d.hostname + ": " + d.uptime + " (Gen " + d.generation + ", load " + d.load + ")";
            }
          })
          .catch(() => {});
      }

      document.addEventListener('DOMContentLoaded', pollTelemetry);
      setInterval(pollTelemetry, 30000);

      document.addEventListener('click', (e) => {
        const el = e.target.closest('[url][fn="onclick"], [url]:not([fn])');
        if (!el) return;
        const url = el.getAttribute('url');
        if (!url) return;
        e.preventDefault();
        document.querySelectorAll('.nav-active').forEach(n => n.classList.remove('nav-active'));
        el.classList.add('nav-active');
        fetch(url)
          .then(r => r.json())
          .then(data => {
            Object.entries(data).forEach(([sel, props]) => {
              const target = document.querySelector(sel);
              if (target) Object.assign(target, props);
            });
            pollTelemetry();
            // Slices that own imperative widgets (the knowledge-graph canvas)
            // rebuild their DOM here, so they subscribe to this instead of
            // having Aki know about canvas internals.
            document.dispatchEvent(new CustomEvent('aki:applied', {detail: data}));
          })
          .catch(err => console.error("Aki transition failed:", err));
      });
    })();
  '';

  # Interactive knowledge-graph canvas (Gap D, canvas half).
  #
  # Aki transitions replace #detail-pane.innerHTML, so this file owns its own
  # lifecycle: it initialises whenever a slice introduces #kg-canvas and leaves
  # everything else to the runtime. No template literals — `${` inside a Nix
  # indented string would be interpolated — so string concatenation only.
  #
  # Interaction contract, matching the TODO exit criterion: a click on ANY node
  # performs an Aki transition to that node's static slice (data/kg/<type>-<hash>.json).
  # Hover inspects without navigating; pan/zoom never navigate.
  kgJs = ''
    (() => {
      var GRAPH_URL = 'data/kg-graph.json';
      var COLORS = {host: '#7aa2f7', skill: '#9ece6a', doc: '#e0af68', tag: '#bb9af7'};
      var RADII = {host: 6, skill: 5, doc: 5, tag: 3};
      var loaded = null;
      var layoutCache = null;

      function fetchGraph() {
        if (!loaded) {
          loaded = fetch(GRAPH_URL, {cache: 'no-cache'}).then(function (r) {
            if (!r.ok) throw new Error('HTTP ' + r.status + ' for ' + GRAPH_URL);
            return r.json();
          });
        }
        return loaded;
      }

      function akiGo(url) {
        var b = document.createElement('button');
        b.setAttribute('url', url);
        b.style.display = 'none';
        document.body.appendChild(b);
        b.click();
        b.remove();
      }

      // Deterministic force layout (Fruchterman-Reingold). Deterministic matters:
      // the same build must draw the same picture, and a re-mount must not jump.
      function computeLayout(graph) {
        var nodes = graph.nodes;
        var n = nodes.length;
        var k = Math.sqrt((1000 * 1000) / Math.max(n, 1));
        var pos = {};
        var index = {};
        nodes.forEach(function (d, i) {
          index[d.id] = i;
          var a = i * 2.399963229728653;
          var r = Math.sqrt(i + 0.5) * k * 0.7;
          pos[d.id] = {x: Math.cos(a) * r, y: Math.sin(a) * r, dx: 0, dy: 0};
        });
        var edges = graph.edges
          .map(function (e) { return [index[e.from], index[e.to]]; })
          .filter(function (p) { return p[0] !== undefined && p[1] !== undefined; });
        var iterations = 180;
        for (var it = 0; it < iterations; it++) {
          var t = k * 0.25 * (1 - it / iterations) + 1;
          var i, j;
          for (i = 0; i < n; i++) { nodes[i]._dx = 0; nodes[i]._dy = 0; }
          for (i = 0; i < n; i++) {
            var a = nodes[i], pa = pos[a.id];
            for (j = i + 1; j < n; j++) {
              var b = nodes[j], pb = pos[b.id];
              var dx = pa.x - pb.x, dy = pa.y - pb.y;
              var d2 = dx * dx + dy * dy;
              if (d2 < 1) { dx = 0.7; dy = 0.7; d2 = 1; }
              if (d2 > 400000) continue;
              var f = (k * k) / d2;
              a._dx += dx * f; a._dy += dy * f;
              b._dx -= dx * f; b._dy -= dy * f;
            }
          }
          edges.forEach(function (p) {
            var a = nodes[p[0]], b = nodes[p[1]];
            var pa = pos[a.id], pb = pos[b.id];
            var dx = pa.x - pb.x, dy = pa.y - pb.y;
            var d = Math.sqrt(dx * dx + dy * dy) || 0.01;
            var f = (d * d) / k;
            a._dx -= (dx / d) * f; a._dy -= (dy / d) * f;
            b._dx += (dx / d) * f; b._dy += (dy / d) * f;
          });
          nodes.forEach(function (d) {
            var p = pos[d.id];
            var m = Math.sqrt(d._dx * d._dx + d._dy * d._dy) || 1;
            var step = Math.min(m, t) / m;
            p.x += d._dx * step;
            p.y += d._dy * step;
            // Weak gravity keeps disconnected tags from drifting to infinity.
            p.x *= 0.995;
            p.y *= 0.995;
          });
        }
        return {pos: pos, index: index};
      }

      function mount() {
        var canvas = document.getElementById('kg-canvas');
        if (!canvas || canvas.dataset.kgBound) return;
        canvas.dataset.kgBound = '1';

        var tip = document.getElementById('kg-tip');
        var ctx = canvas.getContext('2d');
        var view = {x: 0, y: 0, k: 1};
        var graph = null;
        var pos = null;
        var hover = null;
        var drag = null;
        var fitted = false;

        function toWorld(mx, my) {
          return {x: (mx - view.x) / view.k, y: (my - view.y) / view.k};
        }

        function draw() {
          if (!graph) return;
          var dpr = window.devicePixelRatio || 1;
          var w = canvas.clientWidth || 800;
          var h = canvas.clientHeight || 560;
          if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
            canvas.width = Math.round(w * dpr);
            canvas.height = Math.round(h * dpr);
          }
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          ctx.clearRect(0, 0, w, h);
          ctx.save();
          ctx.translate(view.x, view.y);
          ctx.scale(view.k, view.k);

          ctx.lineWidth = 1 / view.k;
          ctx.strokeStyle = 'rgba(65, 72, 104, 0.55)';
          ctx.beginPath();
          graph.edges.forEach(function (e) {
            var a = pos[e.from], b = pos[e.to];
            if (!a || !b) return;
            ctx.moveTo(a.x, a.y);
            ctx.lineTo(b.x, b.y);
          });
          ctx.stroke();

          graph.nodes.forEach(function (d) {
            var p = pos[d.id];
            var r = RADII[d.type] || 4;
            ctx.beginPath();
            ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
            ctx.fillStyle = COLORS[d.type] || '#c0caf5';
            ctx.fill();
            if (d === hover) {
              ctx.lineWidth = 2 / view.k;
              ctx.strokeStyle = '#ffffff';
              ctx.stroke();
            }
          });

          // Host names only: 225 labels at once is noise, and hosts are the
          // nodes an operator is usually looking for.
          ctx.fillStyle = '#c0caf5';
          ctx.font = (11 / view.k) + 'px monospace';
          graph.nodes.forEach(function (d) {
            if (d.type !== 'host' && d.type !== 'doc') return;
            var p = pos[d.id];
            ctx.fillText(d.label, p.x + 8 / view.k, p.y + 3 / view.k);
          });
          ctx.restore();
        }

        function fit() {
          var w = canvas.clientWidth || 800;
          var h = canvas.clientHeight || 560;
          var xs = graph.nodes.map(function (d) { return pos[d.id].x; });
          var ys = graph.nodes.map(function (d) { return pos[d.id].y; });
          var minX = Math.min.apply(null, xs), maxX = Math.max.apply(null, xs);
          var minY = Math.min.apply(null, ys), maxY = Math.max.apply(null, ys);
          var pad = 40;
          var k = Math.min((w - pad * 2) / Math.max(maxX - minX, 1),
                           (h - pad * 2) / Math.max(maxY - minY, 1));
          view.k = Math.min(Math.max(k, 0.15), 2.5);
          view.x = w / 2 - ((minX + maxX) / 2) * view.k;
          view.y = h / 2 - ((minY + maxY) / 2) * view.k;
          fitted = true;
        }

        function nearest(mx, my) {
          var w = toWorld(mx, my);
          var best = null;
          var bestD = Infinity;
          graph.nodes.forEach(function (d) {
            var p = pos[d.id];
            var dx = p.x - w.x, dy = p.y - w.y;
            var d2 = dx * dx + dy * dy;
            if (d2 < bestD) { bestD = d2; best = d; }
          });
          var limit = (RADII[best && best.type] || 4) + 8 / view.k;
          return bestD <= limit * limit ? best : null;
        }

        function at(e) {
          var r = canvas.getBoundingClientRect();
          return {x: e.clientX - r.left, y: e.clientY - r.top};
        }

        function showTip(node, mx, my) {
          if (!tip || !node) { if (tip) tip.style.display = 'none'; return; }
          tip.textContent = node.id + '  ·  ' + node.type + '  ·  ' + node.degree +
            ' links — click to open its slice';
          tip.style.display = 'block';
          tip.style.left = Math.min(mx + 14, canvas.clientWidth - 20) + 'px';
          tip.style.top = Math.max(my - 34, 8) + 'px';
        }

        canvas.addEventListener('pointerdown', function (e) {
          // Capture is a nicety; a synthetic PointerEvent (the gate drives one)
          // has no live pointer id, and a throw here would kill the click path.
          try { canvas.setPointerCapture(e.pointerId); } catch (err) {}
          var p = at(e);
          drag = {x: p.x, y: p.y, sx: p.x, sy: p.y, node: nearest(p.x, p.y), moved: false};
        });

        canvas.addEventListener('pointermove', function (e) {
          var p = at(e);
          if (drag) {
            var dx = p.x - drag.x, dy = p.y - drag.y;
            if (Math.abs(p.x - drag.sx) + Math.abs(p.y - drag.sy) > 3) drag.moved = true;
            if (drag.node) {
              pos[drag.node.id].x += dx / view.k;
              pos[drag.node.id].y += dy / view.k;
            } else {
              view.x += dx;
              view.y += dy;
            }
            drag.x = p.x; drag.y = p.y;
            draw();
            return;
          }
          var node = nearest(p.x, p.y);
          if (node !== hover) {
            hover = node;
            canvas.style.cursor = node ? 'pointer' : 'grab';
            draw();
          }
          showTip(node, p.x, p.y);
        });

        canvas.addEventListener('pointerup', function (e) {
          if (!drag) return;
          var wasMoved = drag.moved;
          var node = drag.node;
          drag = null;
          if (!wasMoved && node) akiGo(node.slice);
        });

        canvas.addEventListener('pointerleave', function () {
          hover = null;
          if (tip) tip.style.display = 'none';
          draw();
        });

        canvas.addEventListener('wheel', function (e) {
          e.preventDefault();
          var p = at(e);
          var before = toWorld(p.x, p.y);
          var factor = Math.exp(-e.deltaY * 0.0015);
          view.k = Math.min(Math.max(view.k * factor, 0.1), 6);
          view.x = p.x - before.x * view.k;
          view.y = p.y - before.y * view.k;
          draw();
        }, {passive: false});

        var zoomIn = document.getElementById('kg-zoom-in');
        var zoomOut = document.getElementById('kg-zoom-out');
        var reset = document.getElementById('kg-reset');
        if (zoomIn) zoomIn.addEventListener('click', function () { view.k *= 1.25; draw(); });
        if (zoomOut) zoomOut.addEventListener('click', function () { view.k /= 1.25; draw(); });
        if (reset) reset.addEventListener('click', function () { fit(); draw(); });

        fetchGraph().then(function (g) {
          graph = g;
          if (!layoutCache) layoutCache = computeLayout(g);
          pos = layoutCache.pos;
          if (!fitted) fit();
          draw();

          // Introspection hook: `checks:kg:canvas` drives a real click at a
          // node's screen position and asserts the slice transition. Without it
          // the canvas click path could only be eyeballed.
          window.__kgDebug = {
            nodes: function () { return graph.nodes.length; },
            toScreen: function (id) {
              var p = pos[id];
              if (!p) return null;
              var r = canvas.getBoundingClientRect();
              return {x: r.left + p.x * view.k + view.x, y: r.top + p.y * view.k + view.y, id: id};
            }
          };
        }).catch(function (err) {
          var pane = document.getElementById('kg-canvas');
          if (pane) pane.insertAdjacentText('afterend', 'Graph unavailable: ' + err.message);
        });
      }

      document.addEventListener('DOMContentLoaded', mount);
      // `fitted` is per-mount state inside `mount()`, so a re-mount (new canvas
      // element after an Aki transition) refits on its own; nothing to reset here.
      document.addEventListener('aki:applied', mount);
      if (document.readyState !== 'loading') mount();
    })();
  '';

  styleCss = ''
    :root {
      --bg: #1a1b26;
      --card-bg: #24283b;
      --border: #414868;
      --text: #c0caf5;
      --text-muted: #7aa2f7;
      --heading: #7dcfff;
      --accent: #bb9af7;
      --green: #9ece6a;
      --red: #f7768e;
      --yellow: #e0af68;
      --code-bg: #16161e;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "JetBrains Mono", monospace;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      padding: 1.5rem;
    }
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border);
      margin-bottom: 1.5rem;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }
    .brand h1 {
      font-size: 1.35rem;
      color: var(--heading);
      letter-spacing: -0.02em;
    }
    .badge {
      display: inline-block;
      padding: 0.2rem 0.6rem;
      font-size: 0.75rem;
      font-weight: 600;
      border-radius: 9999px;
      text-transform: uppercase;
    }
    .badge-green { background: rgba(158, 206, 106, 0.2); color: var(--green); border: 1px solid var(--green); }
    .badge-yellow { background: rgba(224, 175, 104, 0.2); color: var(--yellow); border: 1px solid var(--yellow); }
    .badge-blue { background: rgba(122, 162, 247, 0.2); color: var(--text-muted); border: 1px solid var(--text-muted); }
    nav {
      display: flex;
      gap: 0.5rem;
      margin-bottom: 1.5rem;
      flex-wrap: wrap;
    }
    .tab-btn {
      background: var(--card-bg);
      color: var(--text);
      border: 1px solid var(--border);
      padding: 0.5rem 1rem;
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.9rem;
      transition: all 0.15s ease;
    }
    .tab-btn:hover {
      border-color: var(--accent);
      color: #fff;
    }
    .tab-btn.nav-active {
      background: var(--accent);
      color: #1a1b26;
      font-weight: 600;
      border-color: var(--accent);
    }
    #breadcrumbs {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-bottom: 1rem;
      font-family: monospace;
    }
    .layout-grid {
      display: grid;
      grid-template-columns: 240px 1fr;
      gap: 1.5rem;
    }
    @media (max-width: 800px) {
      .layout-grid { grid-template-columns: 1fr; }
    }
    aside {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1rem;
      height: fit-content;
    }
    aside h3 {
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-muted);
      margin-bottom: 0.75rem;
    }
    .side-list {
      display: flex;
      flex-direction: column;
      gap: 0.4rem;
    }
    .side-btn {
      text-align: left;
      background: transparent;
      color: var(--text);
      border: 1px solid transparent;
      padding: 0.4rem 0.6rem;
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.85rem;
      transition: all 0.15s ease;
      font-family: monospace;
    }
    .side-btn:hover {
      background: rgba(122, 162, 247, 0.1);
      border-color: var(--border);
    }
    .side-btn.nav-active {
      background: rgba(187, 154, 247, 0.2);
      border-color: var(--accent);
      color: var(--accent);
    }
    main {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1.5rem;
      min-height: 480px;
    }
    .card-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1rem;
      margin: 1rem 0;
    }
    .card {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 1rem;
    }
    .card h4 {
      color: var(--heading);
      margin-bottom: 0.5rem;
      font-size: 0.95rem;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 1rem 0;
      font-size: 0.88rem;
    }
    th, td {
      border: 1px solid var(--border);
      padding: 0.55rem 0.75rem;
      text-align: left;
    }
    th {
      background: var(--bg);
      color: var(--heading);
    }
    code, pre {
      font-family: "JetBrains Mono", monospace;
      background: var(--code-bg);
      padding: 0.2rem 0.4rem;
      border-radius: 4px;
      font-size: 0.85rem;
    }
    pre {
      padding: 0.75rem;
      overflow-x: auto;
      margin: 0.75rem 0;
      border: 1px solid var(--border);
    }
  '';

  # Asset fingerprinting hashes for immutable caching (Gap B)
  cssHash = builtins.substring 0 8 (builtins.hashString "sha256" styleCss);
  jsHash = builtins.substring 0 8 (builtins.hashString "sha256" akiJs);
  kgHash = builtins.substring 0 8 (builtins.hashString "sha256" kgJs);
  cssFileName = "style.${cssHash}.css";
  jsFileName = "aki.${jsHash}.min.js";
  kgFileName = "kg.${kgHash}.min.js";

  # Top-level shell
  indexHtml = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Fleet Control Plane & Closure Explorer</title>
      <link rel="stylesheet" href="${cssFileName}">
      <script src="${jsFileName}" defer></script>
      <script src="${kgFileName}" defer></script>
    </head>
    <body>
      <header>
        <div class="brand">
          <h1>Fleet Control Plane</h1>
          <span id="live-status-badge" class="badge badge-green">🟢 frieren: Active Production</span>
        </div>
        <div>
          <span class="badge badge-blue">Aki Hypermedia</span>
        </div>
      </header>

      <nav>
        <button class="tab-btn nav-active" url="data/overview.json">Overview</button>
        <button class="tab-btn" url="data/inventory.json">Fleet Inventory</button>
        <button class="tab-btn" url="data/kg.json">Knowledge Graph</button>
        <button class="tab-btn" url="data/closure.json">Closure Graph</button>
        <button class="tab-btn" url="data/debloat.json">Debloat Playbook</button>
        <button class="tab-btn" url="data/services.json">Services & Ingress</button>
      </nav>

      <div id="breadcrumbs">fleet / overview</div>

      <div class="layout-grid">
        <aside>
          <div id="sidebar-title"><h3>Navigation</h3></div>
          <div id="sidebar-pane" class="side-list">
            <button class="side-btn nav-active" url="data/overview.json">Mainframe Summary</button>
            <button class="side-btn" url="data/inventory.json">Host Matrix</button>
            <button class="side-btn" url="data/kg.json">Knowledge Graph</button>
            <button class="side-btn" url="data/closure.json">Closure Rollup</button>
            <button class="side-btn" url="data/debloat.json">Debloat Status</button>
            <button class="side-btn" url="data/services.json">Port Map</button>
          </div>
        </aside>

        <main id="detail-pane">
          <h2>Fleet Mainframe & Storage Steward</h2>
          <p style="margin: 0.75rem 0; color: var(--text-muted);">
            Welcome to the Nix-native Fleet Control Plane and Static Closure Explorer.
            Driven entirely by pre-compiled hypermedia transitions with zero server daemons.
          </p>

          <div class="card-grid">
            <div class="card">
              <h4>System Generation</h4>
              <p>Generation 82 booted & nominal</p>
              <p><small style="color: var(--green);">Auto-upgrade active (04:00 daily)</small></p>
            </div>
            <div class="card">
              <h4>Closure Footprint</h4>
              <p>33.8 GiB total (3,946 store paths)</p>
              <p><small style="color: var(--text-muted);">Debloat roadmap targeting ~16-17 GiB floor</small></p>
            </div>
            <div class="card">
              <h4>Storage Health</h4>
              <p>1TB NVMe SSD + 2TB NAS HDD pool</p>
              <p><small style="color: var(--green);">0 Btrfs errors; SMART nominal (34°C)</small></p>
            </div>
            <div class="card">
              <h4>Mesh & Gateways</h4>
              <p>SimpleX Mesh & SMP Relay active</p>
              <p><small style="color: var(--heading);">Hermes gateway connected to Telegram</small></p>
            </div>
          </div>

          <h3 style="margin-top: 1.5rem; margin-bottom: 0.5rem; color: var(--heading);">Quick Navigation</h3>
          <p>Click any tab above to explore fleet hosts, dive into derivation closure trees, or view the debloat execution playbook.</p>
        </main>
      </div>
    </body>
    </html>
  '';

  # JSON Slices
  overviewJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / overview";};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Mainframe & Storage Steward</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Welcome to the Nix-native Fleet Control Plane and Static Closure Explorer.
          Driven entirely by pre-compiled hypermedia transitions with zero server daemons.
        </p>
        <div class="card-grid">
          <div class="card">
            <h4>System Generation</h4>
            <p>Generation 82 booted & nominal</p>
            <p><small style="color: var(--green);">Auto-upgrade active (04:00 daily)</small></p>
          </div>
          <div class="card">
            <h4>Closure Footprint</h4>
            <p>33.8 GiB total (3,946 store paths)</p>
            <p><small style="color: var(--text-muted);">Debloat roadmap targeting ~16-17 GiB floor</small></p>
          </div>
          <div class="card">
            <h4>Storage Health</h4>
            <p>1TB NVMe SSD + 2TB NAS HDD pool</p>
            <p><small style="color: var(--green);">0 Btrfs errors; SMART nominal (34°C)</small></p>
          </div>
          <div class="card">
            <h4>Mesh & Gateways</h4>
            <p>SimpleX Mesh & SMP Relay active</p>
            <p><small style="color: var(--heading);">Hermes gateway connected to Telegram</small></p>
          </div>
        </div>
      '';
    };
  };

  # Host list for sidebar
  hostKeys = builtins.attrNames (inv.hosts or {});
  activeHosts = builtins.filter (h: (inv.hosts.${h}.status or "") == "active") hostKeys;

  hostSidebarButtons = lib.concatStringsSep "\n" (
    map (
      h: ''<button class="side-btn" url="data/host-${h}.json">${h} (${inv.hosts.${h}.kind or "nix"})</button>''
    )
    activeHosts
  );

  inventoryJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / inventory";};
    "#sidebar-pane" = {innerHTML = hostSidebarButtons;};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Device & Host Inventory</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Canonical registry of active production devices, compute tiers, and roles.
        </p>
        <table>
          <thead>
            <tr>
              <th>Host</th>
              <th>Status</th>
              <th>Kind</th>
              <th>Arch</th>
              <th>Role</th>
            </tr>
          </thead>
          <tbody>
            ${lib.concatStringsSep "\n" (
          map (h: let
            info = inv.hosts.${h};
          in ''
            <tr>
              <td><strong><button class="side-btn" style="padding:0; border:none; color:var(--heading); cursor:pointer;" url="data/host-${h}.json">${h}</button></strong></td>
              <td><span class="badge ${
              if info.status == "active"
              then "badge-green"
              else "badge-yellow"
            }">${info.status}</span></td>
              <td>${info.kind or "nix"}</td>
              <td><code>${info.arch or "x86_64-linux"}</code></td>
              <td>${info.role or "N/A"}</td>
            </tr>
          '')
          activeHosts
        )}
          </tbody>
        </table>
      '';
    };
  };

  # Individual host pages
  mkHostJson = h: let
    info = inv.hosts.${h} or {};
    hw = info.hardware or {};
    net = info.network or {};
  in
    builtins.toJSON {
      "#breadcrumbs" = {textContent = "fleet / inventory / ${h}";};
      "#detail-pane" = {
        innerHTML = ''
          <h2>${h} — ${info.role or "Fleet Host"}</h2>
          <p style="margin: 0.5rem 0 1rem 0;"><span class="badge ${
            if (info.status or "") == "active"
            then "badge-green"
            else "badge-yellow"
          }">${info.status or "active"}</span> &bull; <code>${info.kind or "nixos"}</code> &bull; <code>${info.arch or "x86_64-linux"}</code></p>

          <div class="card-grid">
            <div class="card">
              <h4>Hardware Profile</h4>
              <p><strong>Model:</strong> ${hw.model or "Generic"}</p>
              <p><strong>CPU:</strong> ${hw.cpu or "x86_64"}</p>
              <p><strong>RAM:</strong> ${hw.ram or "N/A"}</p>
              <p><strong>GPU:</strong> ${hw.gpu or "Integrated"}</p>
            </div>
            <div class="card">
              <h4>Network & Access</h4>
              <p><strong>LAN IP:</strong> ${net.lan_ip or "DHCP"}</p>
              <p><strong>Tailscale:</strong> ${
            if net.tailscale or false
            then "Enabled"
            else "Disabled"
          }</p>
              <p><strong>SSH Alias:</strong> <code>${net.ssh_alias or h}</code></p>
            </div>
          </div>

          <h3 style="margin-top: 1.25rem; margin-bottom: 0.5rem; color: var(--heading);">Status Detail</h3>
          <p style="color: var(--text);">${info.status_detail or "Operational."}</p>
        '';
      };
    };

  # Closure attribution page
  closureJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / closure";};
    "#sidebar-pane" = {
      innerHTML = ''
        <button class="side-btn nav-active" url="data/closure.json">Attribution Rollup</button>
        <button class="side-btn" url="data/debloat.json">Debloat Playbook</button>
      '';
    };
    "#detail-pane" = {
      innerHTML = ''
        <h2>Closure Attribution & Subsystem Rollup</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Measured on <strong>frieren</strong> generation 81/82 over 3,946 Nix store paths.
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Exclusive Bytes</h4>
            <p><strong>15.4 GiB (46%)</strong></p>
            <p><small style="color: var(--text-muted);">Reachable from exactly 1 owner; reclaimed when that owner goes.</small></p>
          </div>
          <div class="card">
            <h4>Shared Substrate</h4>
            <p><strong>16.2 GiB (48%)</strong></p>
            <p><small style="color: var(--text-muted);">Shared across 2+ owners (glibc, Python, LLVM, Mesa, GTK).</small></p>
          </div>
          <div class="card">
            <h4>Core Subsystem</h4>
            <p><strong>2.2 GiB (6%)</strong></p>
            <p><small style="color: var(--text-muted);">Kernel, initrd, firmware (809 MiB), fonts (262 MiB).</small></p>
          </div>
        </div>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.75rem; color: var(--heading);">Top Owners by Exclusive Bytes</h3>
        <table>
          <thead>
            <tr>
              <th>Owner Service / Target</th>
              <th>Exclusive Size</th>
              <th>Major Components</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>home-manager-devji</code></td>
              <td>9.4 GiB</td>
              <td>qmd (904 MiB), chromium (703 MiB), zen-browser (400 MiB)</td>
            </tr>
            <tr>
              <td><code>stirling-pdf.service</code></td>
              <td>1,008 MiB</td>
              <td>openjdk-25 (655 MiB), stirling-pdf (348 MiB)</td>
            </tr>
            <tr>
              <td><code>home-assistant.service</code></td>
              <td>929 MiB</td>
              <td>homeassistant core, frontend (270 MiB), botocore</td>
            </tr>
            <tr>
              <td><code>immich</code> (server + ML)</td>
              <td>790 MiB</td>
              <td>immich server, openvino (141 MiB), onnxruntime</td>
            </tr>
            <tr>
              <td><code>uptime-kuma.service</code></td>
              <td>380 MiB</td>
              <td>npm-deps, uptime-kuma</td>
            </tr>
            <tr>
              <td><code>readarr.service</code></td>
              <td>301 MiB</td>
              <td>readarr, dotnet-runtime</td>
            </tr>
            <tr>
              <td><code>plex.service</code></td>
              <td>213 MiB</td>
              <td>plexmediaserver</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Debloat playbook page
  debloatJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / debloat";};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Closure Debloat Playbook (33.8 GiB &rarr; ~16-17 GiB)</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Safe tier 1 configuration wins and structural debloat milestones.
        </p>

        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Target</th>
              <th>Savings</th>
              <th>Status</th>
              <th>Action / Implementation</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>T1-1</strong></td>
              <td>Chromium Deduplication</td>
              <td>~703 MiB</td>
              <td><span class="badge badge-green">Reclaimed</span></td>
              <td>Removed duplicate chromium from home packages in Gen 81.</td>
            </tr>
            <tr>
              <td><strong>T1-2</strong></td>
              <td>JetBrains Mono Font Pruning</td>
              <td>~262 MiB</td>
              <td><span class="badge badge-green">Applied</span></td>
              <td>Replaced 228 MiB nerd-fonts with upstream jetbrains-mono (~3 MiB).</td>
            </tr>
            <tr>
              <td><strong>T1-3</strong></td>
              <td>nixpkgs Store Decoupling</td>
              <td>~399 MiB</td>
              <td><span class="badge badge-green">Applied</span></td>
              <td>Decoupled <code>pkgs.path</code> in nix-path &rarr; <code>flake:nixpkgs</code>.</td>
            </tr>
            <tr>
              <td><strong>T1-6</strong></td>
              <td>CUPS & HPLIP Print Drivers</td>
              <td>~70 MiB</td>
              <td><span class="badge badge-green">Applied</span></td>
              <td>Disabled <code>services.printing</code> and drivers on headless NAS.</td>
            </tr>
            <tr>
              <td><strong>T1-4</strong></td>
              <td>MBROLA Speech Dispatcher</td>
              <td>~645 MiB</td>
              <td><span class="badge badge-yellow">Evaluating</span></td>
              <td>Requires package override for desktop browser TTS.</td>
            </tr>
            <tr>
              <td><strong>Sudo PATH</strong></td>
              <td>Non-Login /run/wrappers/bin</td>
              <td>Quality</td>
              <td><span class="badge badge-green">Resolved</span></td>
              <td>Exported in bashrcExtra and home.sessionPath for seamless sudo.</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Services & Ingress page
  servicesJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / services";};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Active Ingress & Production Ports</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Declarative service catalog hosted on frieren (<code>192.168.3.25</code>).
        </p>

        <table>
          <thead>
            <tr>
              <th>Port</th>
              <th>Protocol</th>
              <th>Service</th>
              <th>Scope & Function</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>80 / 443</code></td>
              <td>HTTP/HTTPS</td>
              <td>Nginx Reverse Proxy</td>
              <td>LAN & Tailnet ingress with SSL termination</td>
            </tr>
            <tr>
              <td><code>53 / 5335</code></td>
              <td>DNS</td>
              <td>Pi-hole FTL / Unbound</td>
              <td>Recursive DNS caching and LAN ad-blocking</td>
            </tr>
            <tr>
              <td><code>5223</code></td>
              <td>ED25519 TLS</td>
              <td>smp-server</td>
              <td>SimpleX Chat fleet messaging relay server</td>
            </tr>
            <tr>
              <td><code>5225</code></td>
              <td>WebSocket</td>
              <td>simplex-chat</td>
              <td>SimpleX Chat daemon (Hermes / devji / guckloch)</td>
            </tr>
            <tr>
              <td><code>6800 / 6801</code></td>
              <td>RPC / HTTP</td>
              <td>aria2 / AriaNg</td>
              <td>Declarative download daemon and web dashboard</td>
            </tr>
            <tr>
              <td><code>8088</code></td>
              <td>HTTP</td>
              <td>Kiwix Offline Wiki</td>
              <td>19.2M Wikipedia & 14.5k ArchWiki offline articles</td>
            </tr>
            <tr>
              <td><code>8123</code></td>
              <td>HTTP</td>
              <td>Home Assistant</td>
              <td>Smart home automation platform</td>
            </tr>
            <tr>
              <td><code>26000</code></td>
              <td>HTTP / PXE</td>
              <td>iVentoy</td>
              <td>Network PXE multi-ISO boot server</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Knowledge Graph slice (Gap D)
  kgJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / knowledge-graph";};
    "#sidebar-pane" = {
      innerHTML = ''
        <button class="side-btn nav-active" url="data/kg.json">Graph Overview</button>
        <button class="side-btn" url="data/inventory.json">Host Matrix</button>
        <button class="side-btn" url="data/closure.json">Closure Rollup</button>
      '';
    };
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Knowledge Graph & Architectural Projection</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Deterministic structural view compiled directly from repository AST: hosts, skill manuals, and living docs.
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Entities (Nodes)</h4>
            <p><strong>${toString (builtins.length kg.graph.nodes)}</strong> total nodes</p>
            <p><small style="color: var(--text-muted);">${toString kg.graph.stats.hosts} hosts &bull; ${toString kg.graph.stats.skills} skills &bull; ${toString kg.graph.stats.docs} docs</small></p>
          </div>
          <div class="card">
            <h4>Mentions (Edges)</h4>
            <p><strong>${toString kg.graph.stats.edges}</strong> explicit connections</p>
            <p><small style="color: var(--green);">Zero embeddings &bull; Token-exact AST</small></p>
          </div>
          <div class="card">
            <h4>Query Interface</h4>
            <p><code>task ops:kg</code></p>
            <p><small style="color: var(--heading);">Instant sub-second projection</small></p>
          </div>
        </div>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.5rem; color: var(--heading);">Interactive projection</h3>
        <p style="margin-bottom: 0.75rem; color: var(--text-muted);">
          Drag to pan &middot; wheel to zoom &middot; <strong>click any node to open its slice</strong>.
          Hover inspects without navigating.
        </p>
        <div style="position: relative;">
          <canvas id="kg-canvas" style="width: 100%; height: 560px; display: block; background: var(--bg); border: 1px solid var(--border); border-radius: 6px; cursor: grab; touch-action: none;"></canvas>
          <div id="kg-tip" style="display: none; position: absolute; pointer-events: none; background: var(--card-bg); border: 1px solid var(--accent); border-radius: 4px; padding: 0.3rem 0.5rem; font-size: 0.75rem; color: var(--text); white-space: nowrap;"></div>
        </div>
        <p style="margin-top: 0.75rem; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
          <button class="tab-btn" id="kg-zoom-in">+</button>
          <button class="tab-btn" id="kg-zoom-out">&minus;</button>
          <button class="tab-btn" id="kg-reset">Fit</button>
          <span style="margin-left: 1rem;">
            <span class="badge badge-blue">host</span>
            <span class="badge badge-green">skill</span>
            <span class="badge badge-yellow">doc</span>
            <span class="badge" style="background: rgba(187, 154, 247, 0.2); color: var(--accent); border: 1px solid var(--accent);">tag</span>
          </span>
        </p>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.75rem; color: var(--heading);">Graph Projection Layers</h3>
        <table>
          <thead>
            <tr>
              <th>Layer</th>
              <th>Count</th>
              <th>Canonical Source</th>
              <th>Role in Fleet</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Hosts</strong></td>
              <td>${toString kg.graph.stats.hosts}</td>
              <td><code>inventory.toml</code></td>
              <td>Physical servers, workstations, VPS, and preserved states</td>
            </tr>
            <tr>
              <td><strong>Skills</strong></td>
              <td>${toString kg.graph.stats.skills}</td>
              <td><code>.agents/skills/*/SKILL.md</code></td>
              <td>Autonomous agent runbooks and operational skills</td>
            </tr>
            <tr>
              <td><strong>Living Documents</strong></td>
              <td>${toString kg.graph.stats.docs}</td>
              <td>Root markdown & <code>docs/*.md</code></td>
              <td>Fleet architecture, invariants, and system handoffs</td>
            </tr>
            <tr>
              <td><strong>Edges (Mentions)</strong></td>
              <td>${toString kg.graph.stats.edges}</td>
              <td>AST Token Parser</td>
              <td>Explicit cross-subsystem knowledge references</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # --- interactive canvas data ----------------------------------------------
  # The graph itself is the canonical projection (`lib/knowledge-graph.nix`).
  # The site adds ONLY presentation fields — a static slice URL per node and a
  # degree — so a canvas click is an ordinary Aki transition to a JSON file.
  # No daemon, no router, no client-side graph query language.
  # nixpkgs exposes `escapeXML` (a superset of what HTML text needs: & < > " ').
  escH = s: lib.escapeXML (toString s);
  nodeSlug = id: builtins.substring 0 16 (builtins.hashString "sha256" id);
  sliceRel = n: "data/kg/${n.type}-${nodeSlug n.id}.json";
  sliceForId = id: let
    sep = builtins.split ":" id;
    ty = builtins.head sep;
  in "data/kg/${ty}-${nodeSlug id}.json";

  # Degree and incident edges computed once here rather than in the browser:
  # the slice a click lands on must already contain its neighbours, because the
  # page it navigates to is fetched, not computed.
  degree =
    lib.foldl'
    (acc: e:
      acc
      // {
        "${e.from}" = (acc.${e.from} or 0) + 1;
        "${e.to}" = (acc.${e.to} or 0) + 1;
      })
    {}
    kg.graph.edges;

  incident =
    lib.foldl'
    (acc: e:
      acc
      // {
        "${e.from}" =
          (acc.${e.from} or [])
          ++ [
            {
              dir = "out";
              id = e.to;
            }
          ];
        "${e.to}" =
          (acc.${e.to} or [])
          ++ [
            {
              dir = "in";
              id = e.from;
            }
          ];
      })
    {}
    kg.graph.edges;

  siteNodes =
    map
    (n:
      n
      // {
        slice = sliceRel n;
        degree = degree.${n.id} or 0;
      })
    kg.graph.nodes;

  kgGraphJson = builtins.toJSON {
    schemaVersion = kg.graph.schemaVersion;
    generatedBy = kg.graph.generatedBy;
    stats = kg.graph.stats;
    nodes = siteNodes;
    edges = kg.graph.edges;
  };

  kgSlice = n: let
    inc = incident.${n.id} or [];
    outward = lib.filter (x: x.dir == "out") inc;
    inward = lib.filter (x: x.dir == "in") inc;
    links = xs:
      if xs == []
      then "<p><small>none</small></p>"
      else
        "<p>"
        + lib.concatMapStringsSep "\n" (x: ''
          <button class="side-btn" url="${sliceForId x.id}">${escH x.id}</button>
        '') (lib.take 40 xs)
        + (lib.optionalString (builtins.length xs > 40) ''<small>… ${toString (builtins.length xs - 40)} more</small>'')
        + "</p>";

    # Real navigation targets, so a slice is not a dead end: the host inventory
    # page for an active host, the repository blob for a doc or skill.
    onward = let
      hostPage =
        lib.optionalString (n.type == "host" && builtins.elem n.label activeHosts)
        ''<button class="tab-btn" url="data/host-${n.label}.json">Inventory page</button>'';
      blob =
        lib.optionalString (n.type == "doc" || n.type == "skill")
        ''<a class="tab-btn" style="text-decoration:none;" href="https://github.com/shaoyanji/nixconfig/blob/main/${n.path or ""}">Source</a>'';
    in
      hostPage + blob;

    # Values are HTML fragments already (escaped here, once), so the row
    # renderer above never re-escapes or double-escapes a path.
    meta =
      [
        ["id" "<code>${escH n.id}</code>"]
        ["type" (escH n.type)]
        ["links" (toString (degree.${n.id} or 0))]
      ]
      ++ lib.optional (n ? path) ["path" "<code>${escH n.path}</code>"]
      ++ lib.optional (n ? status) ["status" (escH n.status)]
      ++ lib.optional (n ? kind) ["kind" (escH n.kind)]
      ++ lib.optional (n ? description) ["description" (escH n.description)]
      ++ lib.optional (n ? tags) ["tags" (escH (lib.concatStringsSep ", " n.tags))];
  in
    builtins.toJSON {
      "#breadcrumbs" = {textContent = "fleet / knowledge-graph / ${n.id}";};
      "#detail-pane" = {
        innerHTML = ''
          <h2>${escH n.label}</h2>
          <p style="margin: 0.75rem 0; color: var(--text-muted);">${escH (n.description or "Structural node of the fleet knowledge projection.")}</p>
          <table>
            <tbody>
              ${lib.concatMapStringsSep "\n" (r: ''<tr><th>${escH (builtins.head r)}</th><td>${builtins.elemAt r 1}</td></tr>'') meta}
            </tbody>
          </table>

          <h3 style="margin-top: 1.25rem; color: var(--heading);">This node mentions (${toString (builtins.length outward)})</h3>
          ${links outward}

          <h3 style="margin-top: 1.25rem; color: var(--heading);">Mentioned by (${toString (builtins.length inward)})</h3>
          ${links inward}

          <p style="margin-top: 1.5rem; display: flex; gap: 0.5rem; flex-wrap: wrap;">
            <button class="tab-btn" url="data/kg.json">&larr; Back to the graph</button>
            ${onward}
          </p>
        '';
      };
    };

  kgSliceFiles =
    map (n: {
      name = sliceRel n;
      file = pkgs.writeText "kg-slice-${nodeSlug n.id}.json" (kgSlice n);
    })
    kg.graph.nodes;

  # Fallback live telemetry (Gap A)
  fallbackLiveJson = builtins.toJSON {
    hostname = "frieren";
    generation = "booted";
    uptime = "nominal";
    load = "0.0";
    memory = {
      used_mb = 0;
      total_mb = 0;
    };
    timestamp = "static-build";
  };

  # Individual JSON files for active hosts
  hostJsonFiles =
    map (h: {
      name = "data/host-${h}.json";
      file = pkgs.writeText "host-${h}.json" (mkHostJson h);
    })
    activeHosts;
in
  pkgs.runCommand "fleet-docs-site" {
    meta = {
      description = "Aki-powered static fleet documentation and closure explorer";
    };
  } ''
    mkdir -p $out/data/kg
    cat <<'EOF' > $out/index.html
    ${indexHtml}
    EOF

    cat <<'EOF' > $out/${jsFileName}
    ${akiJs}
    EOF

    cat <<'EOF' > $out/${cssFileName}
    ${styleCss}
    EOF

    # Backward-compatible unhashed copies
    cp $out/${jsFileName} $out/aki.min.js
    cp $out/${cssFileName} $out/style.css

    cat <<'EOF' > $out/${kgFileName}
    ${kgJs}
    EOF
    cp $out/${kgFileName} $out/kg.min.js

    cp ${pkgs.writeText "overview.json" overviewJson} $out/data/overview.json
    cp ${pkgs.writeText "inventory.json" inventoryJson} $out/data/inventory.json
    cp ${pkgs.writeText "kg.json" kgJson} $out/data/kg.json
    cp ${pkgs.writeText "closure.json" closureJson} $out/data/closure.json
    cp ${pkgs.writeText "debloat.json" debloatJson} $out/data/debloat.json
    cp ${pkgs.writeText "services.json" servicesJson} $out/data/services.json
    cp ${pkgs.writeText "live.json" fallbackLiveJson} $out/data/live.json
    cp ${pkgs.writeText "kg-graph.json" kgGraphJson} $out/data/kg-graph.json

    ${lib.concatStringsSep "\n" (
      map (hj: "cp ${hj.file} $out/${hj.name}") hostJsonFiles
    )}

    ${lib.concatStringsSep "\n" (
      map (s: "cp ${s.file} $out/${s.name}") kgSliceFiles
    )}

    # Pre-compress static assets for Nginx gzip_static (zero runtime CPU)
    gzip -9k $out/index.html $out/*.js $out/*.css $out/data/*.json $out/data/kg/*.json
  ''
