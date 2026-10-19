(() => {
  var GRAPH_URL = 'data/kg-graph.json';
  var COLORS = {host: '#7aa2f7', skill: '#9ece6a', doc: '#e0af68', tag: '#bb9af7'};
  var RADII = {host: 6, skill: 5, doc: 5, tag: 3};
  var loaded = null;
  var layoutCache = null;
  // Filter state lives OUTSIDE mount(): an Aki transition rebuilds the
  // canvas DOM, and a filter the operator just typed must survive a trip
  // into a node slice and back.
  //
  // `q` is the normalised (trimmed, lowercased) query the matcher uses;
  // `raw` is what the operator typed, so the box never rewrites their case.
  // Aki transitions do not touch the URL, so the hash is the only shareable
  // state a filtered view has — both directions are implemented below.
  //
  // No two adjacent single quotes may appear in this file: inside a Nix
  // indented string that pair is an escape sequence, so JS writes empty
  // strings with double quotes (this exact line failed to parse once).
  var ALL_TYPES = ["host", "skill", "doc", "tag"];
  var HASH_PREFIX = "#kg";
  var filterState = {types: {host: true, skill: true, doc: true, tag: true}, q: "", raw: ""};

  function allTypesOn() {
    return ALL_TYPES.every(function (t) { return filterState.types[t]; });
  }

  function applyFilter(h) {
    filterState.q = h.q;
    filterState.raw = h.raw;
    filterState.types = h.types;
  }

  // `#kg?q=frieren&types=host,doc` — an omitted field means "empty query"
  // and "all types", so the default view carries no hash at all.
  function readHash() {
    var h = window.location.hash || "";
    if (h.indexOf(HASH_PREFIX + "?") !== 0) return null;
    var params = new URLSearchParams(h.slice(HASH_PREFIX.length + 1));
    var types = {};
    ALL_TYPES.forEach(function (t) { types[t] = true; });
    var rawTypes = params.get("types");
    if (rawTypes !== null) {
      ALL_TYPES.forEach(function (t) { types[t] = false; });
      rawTypes.split(",").forEach(function (t) {
        if (types.hasOwnProperty(t)) types[t] = true;
      });
    }
    var raw = params.get("q") || "";
    return {raw: raw, q: raw.trim().toLowerCase(), types: types};
  }

  // replaceState, not pushState: a keystroke must not create a history
  // entry — the shared link is the only thing worth keeping.
  function writeHash() {
    var base = window.location.pathname + window.location.search;
    if (!filterState.q && allTypesOn()) {
      if ((window.location.hash || "").indexOf(HASH_PREFIX) === 0) {
        history.replaceState(null, "", base);
      }
      return;
    }
    var parts = [];
    if (filterState.q) parts.push("q=" + encodeURIComponent(filterState.q));
    if (!allTypesOn()) {
      parts.push(
        "types=" + ALL_TYPES.filter(function (t) { return filterState.types[t]; }).join(",")
      );
    }
    history.replaceState(null, "", base + HASH_PREFIX + "?" + parts.join("&"));
  }

  var initial = readHash();
  if (initial) applyFilter(initial);

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
    var adj = null;
    var byId = null;
    var hover = null;
    var drag = null;
    var fitted = false;

    function toWorld(mx, my) {
      return {x: (mx - view.x) / view.k, y: (my - view.y) / view.k};
    }

    function typeOn(d) {
      return !!filterState.types[d.type];
    }

    // A MATCH is what the query asked for: type enabled, and label or id
    // contains the query. The counter reports matches, because that is the
    // answer to what the operator typed.
    function matches(d) {
      if (!typeOn(d)) return false;
      var q = filterState.q;
      return !q || d._label.indexOf(q) >= 0 || d._id.indexOf(q) >= 0;
    }

    // One place decides three sets, so draw, hit-testing, fit and the
    // debug hook can never disagree:
    //   match  — passes the query (the "N of M" count)
    //   drawn  — what exists on screen: matches, plus the 1-hop neighbourhood
    //            of the matches while a query is active
    //   bright — what is highlighted: the hovered node + neighbours, or the
    //            matches while searching, or everything when idle
    // A search therefore shows its cluster with the matches lit and their
    // neighbours present-but-dimmed, instead of deleting the context that
    // makes a hit meaningful.
    function scene() {
      var matchSet = {};
      var neighbour = {};
      var drawn = {};
      var bright = {};
      var q = filterState.q;

      graph.nodes.forEach(function (d) { if (matches(d)) matchSet[d.id] = true; });

      graph.nodes.forEach(function (d) {
        if (!typeOn(d)) return;
        if (!q || matchSet[d.id]) {
          drawn[d.id] = true;
          return;
        }
        neighbour[d.id] = true; // provisional: confirmed below
      });

      if (q) {
        var near = {};
        Object.keys(matchSet).forEach(function (id) {
          (adj[id] || []).forEach(function (n) { near[n] = true; });
        });
        Object.keys(near).forEach(function (id) {
          if (drawn[id]) return; // a match stays drawn and bright
          var node = byId[id];
          if (node && typeOn(node)) drawn[id] = true;
        });
      }

      if (hover) {
        bright[hover.id] = true;
        (adj[hover.id] || []).forEach(function (n) {
          if (drawn[n]) bright[n] = true;
        });
      } else if (q) {
        bright = matchSet;
      } else {
        bright = drawn;
      }

      return {match: matchSet, drawn: drawn, bright: bright};
    }

    function draw() {
      if (!graph) return;
      var s = scene();
      var on = s.drawn;
      var focus = filterState.q || hover ? s.bright : null;
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
      ctx.beginPath();
      graph.edges.forEach(function (e) {
        var a = pos[e.from], b = pos[e.to];
        if (!a || !b || !on[e.from] || !on[e.to]) return;
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
      });
      ctx.strokeStyle = focus ? 'rgba(122, 162, 247, 0.8)' : 'rgba(65, 72, 104, 0.55)';
      ctx.stroke();

      graph.nodes.forEach(function (d) {
        if (!on[d.id]) return;
        var p = pos[d.id];
        var r = RADII[d.type] || 4;
        var lit = !focus || focus[d.id];
        ctx.globalAlpha = lit ? 1 : (filterState.q ? 0.45 : 0.16);
        ctx.beginPath();
        ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
        ctx.fillStyle = COLORS[d.type] || '#c0caf5';
        ctx.fill();
        if (d === hover) {
          ctx.lineWidth = 2 / view.k;
          ctx.strokeStyle = '#ffffff';
          ctx.stroke();
        }
        ctx.globalAlpha = 1;
      });

      // Host names only: 225 labels at once is noise, and hosts are the
      // nodes an operator is usually looking for. With a focus set, the
      // neighbours that light up are the point, so their names matter too.
      ctx.fillStyle = '#c0caf5';
      ctx.font = (11 / view.k) + 'px monospace';
      graph.nodes.forEach(function (d) {
        if (!on[d.id]) return;
        var lit = !focus || focus[d.id];
        if (!lit) return;
        if (!filterState.q && !hover && d.type !== 'host' && d.type !== 'doc') return;
        var p = pos[d.id];
        ctx.fillText(d.label, p.x + 8 / view.k, p.y + 3 / view.k);
      });
      ctx.restore();
    }

    // Fit the requested nodes, falling back to all of them when a filter
    // matches nothing — an empty canvas with no way back is a dead end.
    function fit(list) {
      var w = canvas.clientWidth || 800;
      var h = canvas.clientHeight || 560;
      var nodes = list && list.length ? list : graph.nodes;
      var xs = nodes.map(function (d) { return pos[d.id].x; });
      var ys = nodes.map(function (d) { return pos[d.id].y; });
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
      // Hit-test the DRAWN set, not the match set: while searching, the
      // dimmed neighbours are context you can still click through to.
      var drawn = scene().drawn;
      graph.nodes.forEach(function (d) {
        if (!drawn[d.id]) return;
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
    // Fit means "fit what I can see", not "reset my filter".
    if (reset) reset.addEventListener('click', function () { refresh(); });

    // One path for every filter change: recompute the visible set, refit,
    // repaint, and update the counter. Any control that changes what is
    // shown calls this, so the three cannot disagree.
    function refresh() {
      if (!graph) return;
      var s = scene();
      // Fit what is DRAWN (matches keep their neighbourhood in view); the
      // counter reports MATCHES (the answer to what was typed).
      fit(graph.nodes.filter(function (d) { return s.drawn[d.id]; }));
      draw();
      var counter = document.getElementById('kg-count');
      if (counter) {
        counter.textContent = Object.keys(s.match).length + ' of ' + graph.nodes.length + ' nodes';
      }
    }

    fetchGraph().then(function (g) {
      graph = g;
      // Match against lowercased strings prepared once; `matches` is called
      // for every node on every repaint and must not allocate.
      graph.nodes.forEach(function (d) {
        d._label = String(d.label || "").toLowerCase();
        d._id = d.id.toLowerCase();
      });
      if (!layoutCache) layoutCache = computeLayout(g);
      pos = layoutCache.pos;

      // Adjacency once per mount: focus highlighting is a 1-hop question
      // asked on every repaint, and scanning 387 edges each time is waste.
      adj = {};
      byId = {};
      graph.nodes.forEach(function (d) {
        adj[d.id] = [];
        byId[d.id] = d;
      });
      graph.edges.forEach(function (e) {
        if (adj[e.from] && adj[e.to]) {
          adj[e.from].push(e.to);
          adj[e.to].push(e.from);
        }
      });

      if (!fitted) fit();

      // Controls. The search box and the type chips are ordinary DOM, so the
      // gate drives them exactly as an operator would.
      var search = document.getElementById('kg-search');
      if (search) {
        search.value = filterState.raw;
        search.addEventListener('input', function () {
          filterState.raw = search.value;
          filterState.q = search.value.trim().toLowerCase();
          writeHash();
          refresh();
        });
      }

      var chips = document.querySelectorAll('[data-kg-type]');
      for (var c = 0; c < chips.length; c++) {
        (function (chip) {
          var t = chip.getAttribute('data-kg-type');
          chip.classList.toggle('nav-active', !!filterState.types[t]);
          chip.addEventListener('click', function () {
            filterState.types[t] = !filterState.types[t];
            chip.classList.toggle('nav-active', filterState.types[t]);
            writeHash();
            refresh();
          });
        })(chips[c]);
      }

      refresh();

      // Introspection hook: `checks:kg:canvas` drives a real click at a
      // node's screen position, types into the search box and toggles a
      // type chip. Without it those paths could only be eyeballed.
      window.__kgDebug = {
        nodes: function () { return graph.nodes.length; },
        visible: function () { return Object.keys(scene().match).length; },
        drawn: function () { return Object.keys(scene().drawn).length; },
        focus: function () { return Object.keys(scene().bright).length; },
        isVisible: function (id) {
          var hit = null;
          graph.nodes.forEach(function (d) { if (d.id === id) hit = d; });
          return !!hit && matches(hit);
        },
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

  // A shared `#kg?...` link must land ON the graph: index.html shows the
  // Overview slice, and clicking the tab is the same transition an operator
  // would make. Without this the hash would be readable but useless.
  var started = false;
  function start() {
    if (started) return;
    started = true;
    if (initial) {
      var tab = document.querySelector('button[url="data/kg.json"]');
      if (tab) tab.click();
    } else {
      mount();
    }
  }

  // Pasted or edited hash on an open page: adopt it and re-open the graph
  // slice so the chips and the search box re-render from the new state.
  window.addEventListener('hashchange', function () {
    var h = readHash();
    if (!h) return;
    applyFilter(h);
    var tab = document.querySelector('button[url="data/kg.json"]');
    if (tab) tab.click();
  });

  // `fitted` is per-mount state inside `mount()`, so a re-mount (new canvas
  // element after an Aki transition) refits on its own; nothing to reset here.
  document.addEventListener('DOMContentLoaded', start);
  document.addEventListener('aki:applied', mount);
  if (document.readyState !== 'loading') start();
})();
