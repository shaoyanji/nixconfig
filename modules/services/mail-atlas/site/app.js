import { startQiField } from "./particles.js";

const API = "/api";
const LIMIT = 48;

const state = {
  q: "",
  cat: "",
  // The working set, not a Gmail label: `inbox` is what has not been decided
  // yet, and a decision removes a letter from it.
  box: "inbox",
  counts: { inbox: 0, queued: 0 },
  // How many rows are already in the list, so "more" is a continuation and not
  // a second first page.
  offset: 0,
  taxonomy: [],
  glyphs: {},
  results: [],
  focus: -1,
  total: 0,
  // Rows marked with the space bar. A decision applies to this set when it is
  // not empty, and to the focused row otherwise — the reason the list can queue
  // thirty newsletters in one keystroke pair.
  selected: new Set(),
  queued: new Map(),
  reader: { messageId: null, actions: [] },
};

const el = {
  q: document.getElementById("q"),
  form: document.getElementById("search-form"),
  chips: document.getElementById("chips"),
  hint: document.getElementById("hint"),
  categories: document.getElementById("categories"),
  results: document.getElementById("results"),
  count: document.getElementById("result-count"),
  batchState: document.getElementById("batch-state"),
  meta: document.getElementById("result-meta"),
  letters: document.getElementById("stat-letters"),
  inbox: document.getElementById("stat-inbox"),
  queuedStat: document.getElementById("stat-queued"),
  boxTabs: document.getElementById("box-tabs"),
  boxTitle: document.getElementById("box-title"),
  actionBar: document.getElementById("action-bar"),
  more: document.getElementById("more"),
  hermesOpen: document.getElementById("hermes-open"),
  command: document.getElementById("command"),
  commandForm: document.getElementById("command-form"),
  commandText: document.getElementById("command-text"),
  commandState: document.getElementById("command-state"),
  commandClose: document.getElementById("command-close"),
  dot: document.getElementById("link-dot"),
  link: document.getElementById("link-state"),
  readoutHits: document.getElementById("ro-hits"),
  readoutMs: document.getElementById("ro-ms"),
  viewTags: document.getElementById("view-tags"),
  graphNote: document.getElementById("graph-note"),
  graphTip: document.getElementById("graph-tip"),
  reader: document.getElementById("reader"),
  readerKicker: document.getElementById("reader-kicker"),
  readerSubject: document.getElementById("reader-subject"),
  readerMeta: document.getElementById("reader-meta"),
  readerBody: document.getElementById("reader-body"),
  act: {
    archive: document.getElementById("act-archive"),
    delete: document.getElementById("act-delete"),
    hermes: document.getElementById("act-hermes"),
  },
  actState: document.getElementById("act-state"),
  instruct: document.getElementById("instruct-form"),
  instruction: document.getElementById("instruction"),
};

const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ESC[c]);

// A JSON column and a text[] column can arrive as a string or as an array,
// depending on the driver: normalise once, here.
function toArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return value
        .split(",")
        .map((v) => v.trim())
        .filter(Boolean);
    }
  }
  return [];
}

async function getJSON(path) {
  const response = await fetch(path, { headers: { accept: "application/json" } });
  if (!response.ok) throw new Error(`HTTP ${response.status} on ${path}`);
  return response.json();
}

async function postJSON(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: { accept: "application/json", "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} on ${path}`);
  return response.json();
}

// Postgres renders an offset as `+00`. V8 accepts that only while there are no
// fractional seconds — with them it returns Invalid Date, which is how every
// `now()` timestamp reached the page as a blank.
function parseTime(value) {
  if (!value) return null;
  const d = new Date(String(value).replace(/([+-]\d{2})$/, "$1:00"));
  return Number.isNaN(d.getTime()) ? null : d;
}

function when(value) {
  const d = parseTime(value);
  return d ? d.toISOString().slice(0, 10) : "";
}

// A box change is read as "how long ago", not as a date: a handled row is
// asking whether the thing you asked for has happened yet.
function since(value) {
  const d = parseTime(value);
  if (!d) return "";
  const minutes = Math.round((Date.now() - d.getTime()) / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  const days = Math.round(hours / 24);
  return days < 31 ? `${days} d ago` : when(value);
}

function debounce(fn, ms) {
  let timer = null;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}

function hash(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0) / 4294967295;
}

/* ------------------------------------------------------------------ */
/* fuzzy matching: one classifier, two renderers                       */
/* ------------------------------------------------------------------ */

// 0 = untouched, 1 = exact substring, 2 = subsequence ("fuzzy"). The list and
// the graph labels both read this, so a hit looks the same in both places.
function classify(text, tokens) {
  const src = String(text ?? "");
  const lower = src.toLowerCase();
  const out = new Array(src.length).fill(0);
  if (!tokens.length || !src) return out;

  for (const token of tokens) {
    let from = 0;
    for (;;) {
      const at = lower.indexOf(token, from);
      if (at < 0) break;
      for (let k = at; k < at + token.length; k++) out[k] = 1;
      from = at + token.length;
    }
  }

  for (const token of tokens) {
    if (lower.includes(token)) continue;
    // Greedy subsequence, but only inside a window: without one, "invoice"
    // would match letters scattered across a 200-character subject.
    const window = Math.min(lower.length, token.length * 4 + 6);
    let cursor = 0;
    const hits = [];
    for (const ch of token) {
      const at = lower.indexOf(ch, cursor);
      if (at < 0 || at - cursor > window) break;
      hits.push(at);
      cursor = at + 1;
    }
    if (hits.length === token.length) for (const k of hits) if (!out[k]) out[k] = 2;
  }

  return out;
}

function markHTML(text, tokens) {
  const src = String(text ?? "");
  const cls = classify(src, tokens);
  let html = "";
  let run = 0;
  let buffer = "";
  const flush = () => {
    if (!buffer) return;
    html += run === 1 ? `<mark>${buffer}</mark>` : run === 2 ? `<mark class="fz">${buffer}</mark>` : buffer;
    buffer = "";
  };
  for (let i = 0; i < src.length; i++) {
    if (cls[i] !== run) {
      flush();
      run = cls[i];
    }
    buffer += esc(src[i]);
  }
  flush();
  return html;
}

/* ------------------------------------------------------------------ */
/* the field of relations                                              */
/* ------------------------------------------------------------------ */

const field = (() => {
  const canvas = document.getElementById("atlas-graph");
  const empty = document.getElementById("graph-empty");
  const ctx = canvas.getContext("2d");
  const dpr = Math.min(window.devicePixelRatio || 1, 2);

  const CAT = [240, 201, 135];
  const TAG = [62, 240, 221];
  const MAIL = [228, 251, 246];
  const QUERY = [255, 214, 160];
  // Canvas text needs the Han family spelled out: without it every gate glyph
  // falls back to whatever the OS happens to have and turns into tofu.
  const FONT = '"Atlas Han", ui-monospace, monospace';

  let nodes = [];
  let links = [];
  let width = 0;
  let height = 0;
  let alpha = 0;
  let hovered = null;
  let openMail = null;
  let onTag = null;
  let onCategory = null;
  // One clock for the whole session. Resetting it on hover made the sweep and
  // every spark jump backwards under the pointer, which read as jitter.
  const start = performance.now();
  let tokens = [];
  let hitCount = 0;
  let raf = null;

  const rgba = (c, a) => `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${a.toFixed(3)})`;

  function resize() {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    width = rect.width;
    height = rect.height;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    anchors();
    kick();
  }

  function ringRadius() {
    return Math.max(64, Math.min(width, height) * 0.27);
  }

  function anchorFor(node) {
    const r1 = ringRadius();
    const cx = width / 2;
    const cy = height / 2;
    const kind = node.kind;
    if (kind === "query") return { x: cx, y: cy, r: 0 };
    const radius =
      kind === "category" ? r1 : kind === "tag" ? r1 * 1.42 : r1 * (1.66 + hash(node.id) * 0.38);
    const angle = node.angle;
    return {
      x: cx + Math.cos(angle) * radius * (width > height ? 1.12 : 0.95),
      y: cy + Math.sin(angle) * radius,
      r: radius,
    };
  }

  function anchors() {
    for (const node of nodes) {
      const a = anchorFor(node);
      node.ax = a.x;
      node.ay = a.y;
      if (node.x == null) {
        node.x = a.x;
        node.y = a.y;
      }
    }
  }

  // Stable identity: a node keeps its position across keystrokes and only its
  // heat and anchor move, so typing looks like the field responding rather
  // than the graph being rebuilt.
  function setData({ query, results, taxonomy }) {
    tokens = query
      .toLowerCase()
      .split(/[\s,;:]+/)
      .filter((t) => t.length > 1)
      .slice(0, 6);

    const previous = new Map(nodes.map((n) => [n.id, n]));
    const catOrder = taxonomy.map((c) => c.id);
    const tagOwner = new Map();
    for (const cat of taxonomy) {
      for (const tag of cat.tags || []) tagOwner.set(tag.id, cat.id);
    }

    const top = results.slice(0, 30);
    const catHits = new Map();
    const tagHits = new Map();
    let maxScore = 0;
    for (const mail of top) {
      maxScore = Math.max(maxScore, mail.score);
      for (const c of mail.categories) catHits.set(c, (catHits.get(c) || 0) + 1);
      for (const t of mail.tags) tagHits.set(t, (tagHits.get(t) || 0) + 1);
    }
    const maxCat = Math.max(1, ...catHits.values());
    const maxTag = Math.max(1, ...tagHits.values());

    const next = [];
    const add = (node) => {
      const old = previous.get(node.id);
      next.push({
        x: old ? old.x : null,
        y: old ? old.y : null,
        vx: old ? old.vx : 0,
        vy: old ? old.vy : 0,
        ...node,
      });
    };

    add({ id: "query", kind: "query", label: query, heat: query ? 1 : 0.2, angle: 0 });

    catOrder.forEach((id, index) => {
      const cat = taxonomy[index];
      const hits = catHits.get(id) || 0;
      const base = cat.mailCount || 0;
      add({
        id: `cat:${id}`,
        kind: "category",
        label: cat.label,
        glyph: cat.glyph,
        count: base,
        hits,
        heat: query ? hits / maxCat : Math.min(1, base / Math.max(1, ...taxonomy.map((c) => c.mailCount || 0))),
        angle: (index / Math.max(catOrder.length, 1)) * Math.PI * 2 - Math.PI / 2,
        cat: id,
      });
    });

    const tagList = [...tagHits.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 14)
      .map(([tag, hits]) => ({ tag, hits, heat: hits / maxTag }));

    tagList.forEach(({ tag, hits, heat }, index) => {
      const owner = tagOwner.get(tag);
      const cat = next.find((n) => n.id === `cat:${owner}`);
      const baseAngle = cat ? cat.angle : -Math.PI / 2;
      const spread = 0.42;
      const offset = tagList.length > 1 ? (index / (tagList.length - 1) - 0.5) * spread * 2 : 0;
      add({
        id: `tag:${tag}`,
        kind: "tag",
        label: tag,
        hits,
        heat,
        angle: baseAngle + offset,
        cat: owner || null,
      });
    });

    const catIndexAngle = new Map(next.filter((n) => n.kind === "category").map((n) => [n.cat, n.angle]));
    const tagAngle = new Map(next.filter((n) => n.kind === "tag").map((n) => [n.id.slice(4), n.angle]));

    top.forEach((mail, index) => {
      const heat = maxScore > 0 ? Math.max(0.12, mail.score / maxScore) : 0.3;
      const tag = mail.tags.find((t) => tagAngle.has(t));
      // Golden-ratio spread rather than per-id noise: successive letters fan out
      // around their tag instead of stacking into a radial line.
      const spread = (index * 0.61803398875) % 1;
      const angle = tag
        ? tagAngle.get(tag) + (spread - 0.5) * 0.6
        : (catIndexAngle.get(mail.categories[0]) ?? -Math.PI / 2) + (spread - 0.5) * 0.7;
      add({
        id: `mail:${mail.id}`,
        kind: "mail",
        label: mail.subject,
        sender: mail.sender,
        date: when(mail.sentAt),
        mailId: mail.id,
        tags: mail.tags,
        heat,
        angle,
      });
    });

    const nextLinks = [];
    const linked = new Set();
    for (const node of next) {
      if (node.kind === "category") {
        nextLinks.push({ from: "query", to: node.id, heat: node.heat, rest: ringRadius() });
      }
      if (node.kind === "tag") {
        const from = node.cat ? `cat:${node.cat}` : "query";
        nextLinks.push({ from, to: node.id, heat: node.heat, rest: ringRadius() * 0.42 });
      }
    }
    for (const mail of top) {
      const nodeId = `mail:${mail.id}`;
      const viaTag = mail.tags
        .map((t) => `tag:${t}`)
        .filter((id) => next.some((n) => n.id === id))
        .slice(0, 2);
      const viaCat = mail.categories.map((c) => `cat:${c}`).filter((id) => next.some((n) => n.id === id));
      const seen = new Set();
      for (const from of [...viaTag, ...viaCat]) {
        if (seen.has(from)) continue;
        seen.add(from);
        linked.add(nodeId);
        nextLinks.push({ from, to: nodeId, heat: (mail.score / Math.max(1, maxScore)) * 0.9, rest: ringRadius() * 0.46 });
      }
      if (!seen.size) {
        nextLinks.push({ from: "query", to: nodeId, heat: 0.4, rest: ringRadius() * 0.9 });
        linked.add(nodeId);
      }
    }

    nodes = next;
    links = nextLinks;
    anchors();
    hitCount = results.length;
    empty.classList.toggle("hidden", results.length > 0 || Boolean(query));
    kick();

    canvas.dataset.hot = String(nodes.filter((n) => n.heat > 0.15).length);
    canvas.dataset.layout = `${nodes.length}/${links.length}`;
    canvas.setAttribute(
      "aria-label",
      results.length
        ? `Relation graph: ${results.length} letters across ${catHits.size} gates`
        : "Relation graph of the taxonomy",
    );
  }

  function step() {
    alpha *= 0.982;
    const byId = new Map(nodes.map((n) => [n.id, n]));

    for (let i = 0; i < nodes.length; i++) {
      const a = nodes[i];
      for (let j = i + 1; j < nodes.length; j++) {
        const b = nodes[j];
        let dx = b.x - a.x;
        let dy = b.y - a.y;
        let d2 = dx * dx + dy * dy;
        if (d2 < 4) {
          dx = (hash(a.id + b.id) - 0.5) * 2;
          dy = (hash(b.id + a.id) - 0.5) * 2;
          d2 = 4;
        }
        const weight = (a.kind === "mail" ? 0.35 : 1) * (b.kind === "mail" ? 0.35 : 1);
        const f = (2400 / d2) * weight;
        const d = Math.sqrt(d2);
        const fx = (dx / d) * f;
        const fy = (dy / d) * f;
        a.vx -= fx;
        a.vy -= fy;
        b.vx += fx;
        b.vy += fy;
      }
    }

    for (const link of links) {
      const a = byId.get(link.from);
      const b = byId.get(link.to);
      if (!a || !b) continue;
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const d = Math.hypot(dx, dy) || 1;
      const f = (d - link.rest) * 0.0085 * (0.5 + link.heat);
      const fx = (dx / d) * f;
      const fy = (dy / d) * f;
      a.vx += fx;
      a.vy += fy;
      b.vx -= fx;
      b.vy -= fy;
    }

    for (const node of nodes) {
      if (node.kind === "query") {
        node.x += (width / 2 - node.x) * 0.3;
        node.y += (height / 2 - node.y) * 0.3;
        node.vx = 0;
        node.vy = 0;
        continue;
      }
      const pull = node.kind === "mail" ? 0.05 : node.kind === "tag" ? 0.032 : 0.02;
      node.vx += (node.ax - node.x) * pull;
      node.vy += (node.ay - node.y) * pull;
      node.vx *= 0.82;
      node.vy *= 0.82;
      const cap = 9;
      node.vx = Math.max(-cap, Math.min(cap, node.vx));
      node.vy = Math.max(-cap, Math.min(cap, node.vy));
      node.x += node.vx;
      node.y += node.vy;
      const pad = 26;
      node.x = Math.max(pad, Math.min(width - pad, node.x));
      node.y = Math.max(pad + 8, Math.min(height - pad, node.y));
    }
  }

  function curve(link, byId) {
    const a = byId.get(link.from);
    const b = byId.get(link.to);
    if (!a || !b) return null;
    const mx = (a.x + b.x) / 2;
    const my = (a.y + b.y) / 2;
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const bow = (hash(link.from + link.to) - 0.5) * 0.28;
    return { a, b, cx: mx - dy * bow, cy: my + dx * bow };
  }

  function pointOn(c, t) {
    const u = 1 - t;
    return {
      x: u * u * c.a.x + 2 * u * t * c.cx + t * t * c.b.x,
      y: u * u * c.a.y + 2 * u * t * c.cy + t * t * c.b.y,
    };
  }

  function guides() {
    const r1 = ringRadius();
    const cx = width / 2;
    const cy = height / 2;
    ctx.save();
    ctx.strokeStyle = "rgba(62, 240, 221, 0.055)";
    ctx.lineWidth = 1;
    for (const scale of [1, 1.42, 1.88]) {
      ctx.beginPath();
      ctx.ellipse(cx, cy, r1 * scale * (width > height ? 1.12 : 0.95), r1 * scale, 0, 0, 6.283185);
      ctx.stroke();
    }
    ctx.strokeStyle = "rgba(62, 240, 221, 0.08)";
    for (let i = 0; i < 72; i++) {
      const angle = (i / 72) * Math.PI * 2;
      const inner = r1 * 1.86;
      const outer = inner + (i % 6 === 0 ? 6 : 2.5);
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(angle) * inner * (width > height ? 1.12 : 0.95), cy + Math.sin(angle) * inner);
      ctx.lineTo(cx + Math.cos(angle) * outer * (width > height ? 1.12 : 0.95), cy + Math.sin(angle) * outer);
      ctx.stroke();
    }
    ctx.restore();
  }

  // A label drawn run by run, so a matched token is gold inside the word the
  // way `mark` is in the list — the graph reads with the same eye as the page.
  function drawLabel(text, x, y, opts = {}) {
    const { size = 9, color = "rgba(133, 179, 168, 0.9)", align = "center", tokens: toks = null } = opts;
    ctx.font = `${size}px ${FONT}`;
    ctx.textBaseline = "middle";
    ctx.textAlign = "left";
    const cls = toks ? classify(text, toks) : null;
    const widths = [];
    let total = 0;
    for (const ch of text) {
      const w = ctx.measureText(ch).width;
      widths.push(w);
      total += w;
    }
    // A label that runs off the canvas is a label nobody reads: clamp it to
    // the panel, but only after it has been measured.
    const left = align === "center" ? x - total / 2 : align === "right" ? x - total : x;
    const clamped = Math.max(6, Math.min(left, width - total - 6));
    let cursor = clamped;
    let i = 0;
    while (i < text.length) {
      const level = cls ? cls[i] : 0;
      let slice = "";
      let widthSum = 0;
      while (i < text.length && (cls ? cls[i] : 0) === level) {
        slice += text[i];
        widthSum += widths[i];
        i++;
      }
      ctx.fillStyle =
        level === 1 ? "rgba(240, 201, 135, 0.98)" : level === 2 ? "rgba(240, 201, 135, 0.7)" : color;
      ctx.fillText(slice, cursor, y);
      cursor += widthSum;
    }
  }

  function draw(now) {
    ctx.clearRect(0, 0, width, height);
    if (!nodes.length) return;
    guides();
    const byId = new Map(nodes.map((n) => [n.id, n]));
    const elapsed = (now - start) / 1000;
    // A phone-sized field cannot hold thirty labels: thin them to what is hot.
    const narrow = width < 520;

    // A slow sweep around the outer ring: the instrument is running, not a
    // picture. Twenty-six short arcs trailing the leading edge is enough.
    {
      const r1 = ringRadius();
      const cx = width / 2;
      const cy = height / 2;
      const rx = r1 * 1.88 * (width > height ? 1.12 : 0.95);
      const sweep = (elapsed * 0.22) % (Math.PI * 2);
      for (let i = 0; i < 26; i++) {
        const a = sweep - i * 0.02;
        ctx.strokeStyle = `rgba(62, 240, 221, ${(0.15 * (1 - i / 26)).toFixed(3)})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.ellipse(cx, cy, rx, r1 * 1.88, 0, a - 0.02, a);
        ctx.stroke();
      }
    }

    // Links: bowed, and the hotter the link the brighter the current in it.
    for (const link of links) {
      const c = curve(link, byId);
      if (!c) continue;
      const heat = link.heat;
      const strong = link.from === "query";
      ctx.strokeStyle = strong
        ? `rgba(62, 240, 221, ${(0.08 + heat * 0.4).toFixed(3)})`
        : `rgba(62, 240, 221, ${(0.06 + heat * 0.3).toFixed(3)})`;
      ctx.lineWidth = strong ? 1 : 0.75;
      ctx.beginPath();
      ctx.moveTo(c.a.x, c.a.y);
      ctx.quadraticCurveTo(c.cx, c.cy, c.b.x, c.b.y);
      ctx.stroke();

      if (heat > 0.32) {
        const phase = (elapsed * (0.16 + heat * 0.34) + hash(link.to)) % 1;
        const p = pointOn(c, phase);
        ctx.fillStyle = `rgba(240, 201, 135, ${(0.25 + heat * 0.6).toFixed(3)})`;
        ctx.shadowColor = "rgba(240, 201, 135, 0.8)";
        ctx.shadowBlur = 7;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 1.05 + heat * 1.1, 0, 6.283185);
        ctx.fill();
        ctx.shadowBlur = 0;
      }
    }

    for (const node of nodes) {
      const heat = node.heat;
      const breathe = 0.5 + 0.5 * Math.sin(elapsed * 1.7 + hash(node.id) * 6.28);
      if (node.kind === "category") {
        const r = 5 + heat * 3.4;
        ctx.strokeStyle = rgba(CAT, 0.2 + heat * 0.7);
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.arc(node.x, node.y, r, 0, 6.283185);
        ctx.stroke();
        ctx.fillStyle = rgba(CAT, 0.1 + heat * 0.8);
        ctx.beginPath();
        ctx.arc(node.x, node.y, 2.1 + heat * 1.7, 0, 6.283185);
        ctx.fill();
        // The gauge: how much of this gate's mail the current query touches.
        ctx.strokeStyle = rgba(CAT, 0.1);
        ctx.lineWidth = 1.6;
        ctx.beginPath();
        ctx.arc(node.x, node.y, r + 4.5, 0, 6.283185);
        ctx.stroke();
        if (heat > 0.02) {
          ctx.strokeStyle = rgba(CAT, 0.3 + heat * 0.6);
          ctx.beginPath();
          ctx.arc(node.x, node.y, r + 4.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, heat));
          ctx.stroke();
        }
        if (heat > 0.3) {
          ctx.fillStyle = rgba(CAT, 0.04 + heat * 0.09 * breathe);
          ctx.beginPath();
          ctx.arc(node.x, node.y, r * 2.1, 0, 6.283185);
          ctx.fill();
        }
        drawLabel(narrow && heat < 0.2 ? node.glyph : `${node.glyph} ${node.label}`, node.x, node.y - r - 12, {
          size: narrow ? 8.6 : 9.5,
          color: heat > 0.1 ? "rgba(240, 201, 135, 0.95)" : "rgba(133, 179, 168, 0.3)",
          tokens: tokens.length && heat > 0.1 ? tokens : null,
        });
        if (node.hits) {
          drawLabel(`${node.hits}`, node.x, node.y + r + 12, {
            size: 8,
            color: "rgba(62, 240, 221, 0.8)",
          });
        }
      } else if (node.kind === "tag") {
        const r = 2.6 + heat * 3.2;
        ctx.save();
        ctx.translate(node.x, node.y);
        ctx.rotate(Math.PI / 4);
        ctx.strokeStyle = rgba(TAG, 0.25 + heat * 0.65);
        ctx.lineWidth = 1;
        ctx.strokeRect(-r, -r, r * 2, r * 2);
        ctx.fillStyle = rgba(TAG, 0.12 + heat * 0.6);
        ctx.fillRect(-r * 0.55, -r * 0.55, r * 1.1, r * 1.1);
        ctx.restore();
        if (heat > 0.16 && (!narrow || heat > 0.45)) {
          drawLabel(node.label, node.x, node.y - r - 8, {
            size: 8.6,
            color: "rgba(62, 240, 221, 0.88)",
            tokens,
          });
        }
      } else if (node.kind === "mail") {
        const r = 1.7 + heat * 3;
        if (heat > 0.55) {
          ctx.shadowColor = "rgba(62, 240, 221, 0.75)";
          ctx.shadowBlur = 8;
        }
        ctx.fillStyle = rgba(MAIL, 0.28 + heat * 0.68);
        ctx.beginPath();
        ctx.arc(node.x, node.y, r, 0, 6.283185);
        ctx.fill();
        ctx.shadowBlur = 0;
        if (node === hovered) {
          ctx.strokeStyle = rgba(TAG, 0.95);
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.arc(node.x, node.y, r + 4.5, 0, 6.283185);
          ctx.stroke();
        }
      } else if (node.kind === "query") {
        const pulse = 0.6 + 0.4 * Math.sin(elapsed * 2);
        // A soft well at the centre: everything on the chart is held by it.
        const well = ctx.createRadialGradient(node.x, node.y, 0, node.x, node.y, ringRadius() * 0.85);
        well.addColorStop(0, `rgba(62, 240, 221, ${(0.05 + pulse * 0.05).toFixed(3)})`);
        well.addColorStop(1, "rgba(62, 240, 221, 0)");
        ctx.fillStyle = well;
        ctx.beginPath();
        ctx.arc(node.x, node.y, ringRadius() * 0.85, 0, 6.283185);
        ctx.fill();
        ctx.save();
        ctx.translate(node.x, node.y);
        ctx.rotate(Math.PI / 4);
        ctx.strokeStyle = rgba(QUERY, 0.85);
        ctx.lineWidth = 1.2;
        ctx.strokeRect(-5.5, -5.5, 11, 11);
        ctx.fillStyle = rgba(QUERY, 0.12 + pulse * 0.18);
        ctx.fillRect(-5.5, -5.5, 11, 11);
        ctx.restore();
        ctx.strokeStyle = rgba(QUERY, 0.5);
        ctx.lineWidth = 1;
        for (const [dx, dy] of [
          [-13, 0],
          [13, 0],
          [0, -13],
          [0, 13],
        ]) {
          ctx.beginPath();
          ctx.moveTo(node.x + dx * 0.72, node.y + dy * 0.72);
          ctx.lineTo(node.x + dx, node.y + dy);
          ctx.stroke();
        }
        if (node.label) {
          ctx.shadowColor = "rgba(255, 214, 160, 0.55)";
          ctx.shadowBlur = 10;
          drawLabel(node.label, node.x, node.y - 21, {
            size: 11.5,
            color: "rgba(255, 232, 195, 0.98)",
            tokens,
          });
          ctx.shadowBlur = 0;
        }
      }
    }

    // A faint second ring around the hovered node, so the pointer has an anchor.
    if (hovered) {
      ctx.strokeStyle = "rgba(62, 240, 221, 0.5)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(hovered.x, hovered.y, 11, 0, 6.283185);
      ctx.stroke();
    }
  }

  // The sweep and the sparks move with the clock, so the clock has to keep
  // ticking. Stopping the loop at rest made the pointer the only thing that
  // drew a settled graph, and every mousemove then re-timed the sweep in one
  // jump — the jitter. Idle frames are drawn too, just at half rate.
  let lastPaint = 0;
  function loop(now) {
    const busy = alpha > 0.02;
    if (busy) step();
    if (busy || now - lastPaint > 46) {
      draw(now);
      lastPaint = now;
    }
    raf = requestAnimationFrame(loop);
  }

  function kick() {
    alpha = 1;
    if (!raf) raf = requestAnimationFrame(loop);
  }

  // Nothing outside the loop paints the canvas. Not the pointer: a mousemove
  // that drew its own frame changed the phase of the sweep and the sparks, and
  // the field moved at pointer speed instead of at its own. The hover ring
  // lands on the next frame, which nobody can see.

  function hit(event) {
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    let best = null;
    let bestD = Infinity;
    for (const node of nodes) {
      const reach = node.kind === "mail" ? 9 : 15;
      const d = Math.hypot(node.x - x, node.y - y);
      if (d < reach && d < bestD) {
        best = node;
        bestD = d;
      }
    }
    return best;
  }

  function tipFor(node) {
    if (node.kind === "mail") {
      return `<span class="tip-kind">letter · ${esc(node.date || "")}</span>
        <span class="tip-sub">${esc(node.label)}</span>
        <span class="tip-meta">${esc(node.sender || "")}</span>
        ${node.tags.length ? `<span class="tip-tags">${node.tags.map((t) => `#${esc(t)}`).join(" ")}</span>` : ""}`;
    }
    if (node.kind === "tag") {
      return `<span class="tip-kind">tag</span><span class="tip-sub">${esc(node.label)}</span>
        <span class="tip-meta">${node.hits} of ${hitCount} letters in view</span>`;
    }
    if (node.kind === "category") {
      return `<span class="tip-kind">gate</span><span class="tip-sub">${esc(node.glyph)} ${esc(node.label)}</span>
        <span class="tip-meta">${node.hits ? `${node.hits} matched now · ` : ""}${node.count} placed</span>`;
    }
    return `<span class="tip-kind">query</span><span class="tip-sub">${esc(node.label || "the whole sea")}</span>`;
  }

  canvas.addEventListener("mousemove", (event) => {
    const node = hit(event);
    hovered = node;
    const rect = canvas.getBoundingClientRect();
    if (node) {
      el.graphTip.style.display = "block";
      el.graphTip.innerHTML = tipFor(node);
      const x = Math.max(60, Math.min(rect.width - 60, node.x));
      el.graphTip.style.left = `${x}px`;
      el.graphTip.style.top = `${node.y}px`;
      canvas.style.cursor = node.kind === "mail" ? "pointer" : "crosshair";
    } else {
      el.graphTip.style.display = "none";
      canvas.style.cursor = "crosshair";
    }
  });

  canvas.addEventListener("mouseleave", () => {
    hovered = null;
    el.graphTip.style.display = "none";
  });

  canvas.addEventListener("click", (event) => {
    const node = hit(event);
    if (!node) return;
    if (node.kind === "mail" && openMail) openMail(node.mailId);
    else if (node.kind === "tag" && onTag) onTag(node.label);
    else if (node.kind === "category" && onCategory) onCategory(node.cat);
  });

  const observer = new ResizeObserver(debounce(resize, 90));
  observer.observe(canvas.parentElement);

  return {
    setData,
    resize,
    onOpen(fn) {
      openMail = fn;
    },
    onTag(fn) {
      onTag = fn;
    },
    onCategory(fn) {
      onCategory = fn;
    },
  };
})();

/* ------------------------------------------------------------------ */
/* results                                                             */
/* ------------------------------------------------------------------ */

function normalize(row) {
  return {
    id: row.id,
    messageId: row.messageId,
    sender: plain(row.sender) || "",
    subject: plain(row.subject) || "(no subject)",
    sentAt: row.sentAt,
    snippet: row.snippet || "",
    score: Number(row.score || 0),
    box: row.box || "inbox",
    boxChangedAt: row.boxChangedAt || null,
    boxReason: row.boxReason || "",
    tags: toArray(row.tags).filter((t) => typeof t === "string"),
    categories: toArray(row.categories),
    bodyLength: row.bodyLength,
    attachmentPath: row.attachmentPath,
  };
}

/* Bodies are markdown by design: the importer runs html2markdown, so what is
 * stored is a faithful conversion, not clean prose. Rendering that verbatim is
 * what put `###` and `‌` runs on the page, so presentation runs one
 * cleaner over it. The stored body is never rewritten — it is the record. */
const INVISIBLE =
  /[\u0000-\u0008\u000B-\u001F\u007F\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180E\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0]/g;

// html2markdown escapes what it does not understand, and some senders
// double-escape on the way: `\u00E4` and `&ldquo;` reach the page as literal
// punctuation unless they are unpacked here and now.
const ENTITIES = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
  ensp: " ",
  emsp: " ",
  thinsp: " ",
  zwnj: "",
  zwj: "",
  shy: "",
  ndash: "–",
  mdash: "—",
  hellip: "…",
  lsquo: "‘",
  rsquo: "’",
  ldquo: "“",
  rdquo: "”",
  laquo: "«",
  raquo: "»",
  sbquo: "‚",
  bdquo: "„",
  middot: "·",
  bull: "•",
  dagger: "†",
  sect: "§",
  para: "¶",
  copy: "©",
  reg: "®",
  trade: "™",
  deg: "°",
  plusmn: "±",
  times: "×",
  divide: "÷",
  frac12: "½",
  euro: "€",
  pound: "£",
  yen: "¥",
  cent: "¢",
  szlig: "ß",
  eacute: "é",
  egrave: "è",
  auml: "ä",
  ouml: "ö",
  uuml: "ü",
  Auml: "Ä",
  Ouml: "Ö",
  Uuml: "Ü",
};

function unescapeEntities(s) {
  return s.replace(/&(#[xX]?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,9});/g, (whole, name) => {
    if (name[0] === "#") {
      const code =
        name[1] === "x" || name[1] === "X" ? parseInt(name.slice(2), 16) : Number(name.slice(1));
      if (!Number.isFinite(code) || code <= 0 || code > 0x10ffff) return " ";
      try {
        return String.fromCodePoint(code);
      } catch {
        return " ";
      }
    }
    const named = ENTITIES[name] ?? ENTITIES[name.toLowerCase()];
    return named === undefined ? " " : named;
  });
}

function cleanLine(line) {
  return line
    .replace(/^\s{0,3}#{1,6}\s*/, "")
    .replace(/^\s{0,3}>\s?/, "")
    .replace(/^\s*```.*$/, "")
    .replace(/^\s*\[[^\]]+\]:\s*\S+\s*$/, "")
    .replace(/^\s*[\[\]]{1,2}\s*$/, "")
    // A rule line the emphasis pass has already eaten down to two characters.
    .replace(/^[\s_*\-=~|+#]{1,6}$/, "")
    .replace(/^\s*[-*+]\s+/, "· ")
    .replace(/^\s*([-*_])\1{2,}\s*$/, "")
    .replace(/\s+$/, "");
}

// `lines` keeps paragraph breaks for the reader; the list wants one line.
function plain(text, { lines = false } = {}) {
  let s = String(text ?? "").replace(/\r\n?/g, "\n");
  s = s.replace(/<!--[\s\S]*?-->/g, " ");
  // Before tags: an angle autolink is the one thing inside <…> worth keeping.
  s = s.replace(/<((?:https?|mailto):[^>\s]+)>/g, "$1");
  // Entities first, tags second, entities again: `&lt;video …&gt;` is HTML
  // that was escaped twice, and stripping it as text would print the tag.
  s = unescapeEntities(s);
  s = s.replace(/<\/?[a-zA-Z][^>]*>/g, " ");
  s = unescapeEntities(s);
  s = s.replace(/\u00a0/g, " ");
  s = s.replace(INVISIBLE, "");
  s = s.replace(/\\(u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|.)/g, (whole, seq) => {
    if (/^u/i.test(seq) || /^x/i.test(seq)) {
      const code = parseInt(seq.slice(1), 16);
      return code > 0 && code <= 0x10ffff ? String.fromCharCode(code) : "";
    }
    // `\n` as two characters is a line an importer could not resolve, not a
    // path; a backslash in `%USERPROFILE%\Desktop` is a backslash.
    if (seq === "n" || seq === "r") return lines ? "\n" : " ";
    if (seq === "t") return " ";
    return /[\\`*_{}\[\]()#+\-.!~>|/]/.test(seq) ? seq : whole;
  });
  // Senders double-escape one more time than they mean to: `\\u00FC` is `ü`.
  if (s.includes("\\")) s = s.replace(/\\(u[0-9a-fA-F]{4})/g, (whole, seq) => {
    const code = parseInt(seq.slice(1), 16);
    return code > 0 && code <= 0x10ffff ? String.fromCharCode(code) : "";
  });
  s = s.replace(/!\[([^\]]*)\]\([^)]*\)/g, "$1");
  s = s.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1");
  s = s.replace(/!?\[([^\]]*)\]\[[^\]]*\]/g, "$1");
  // html2markdown nests an image inside a link inside a line break, and the
  // text regex above cannot pair a bracket whose partner is on another line.
  // What is left of such a link is `](url)` — the URL is already gone.
  s = s.replace(/\]\((?:[^()\s]|\([^)]*\)){0,2000}\)/g, "");
  // eBay-style templates bracket a reference id to keep it out of markdown:
  // `[#a08-epuho7evfw#]` is the id, not a link.
  s = s.replace(/\[\s*(#[^\]\n]{1,80}#)\s*\]/g, "$1");
  s = s.replace(/#_(?=#)/g, "# ");
  s = s.replace(/(\*\*|__)([\s\S]+?)\1/g, "$2");
  s = s.replace(/~~([\s\S]+?)~~/g, "$1");
  s = s.replace(/`([^`\n]+)`/g, "$1");
  s = s.replace(/(^|\s)\*([^*\n]+)\*(?=\s|$)/g, "$2");
  s = s.replace(/(^|\s)_([^_\n]+)_(?=\s|$)/g, "$2");
  // Line-level markdown (`###`, `-`, `>`, a rule) is stripped in *both* modes:
  // the list wants one line, but a heading is still a heading, and a separator
  // run that survives the single-line collapse is the one thing that reads as
  // broken markdown.
  s = s
    .split("\n")
    .map(cleanLine)
    .join(lines ? "\n" : " ");
  // An emphasis marker whose partner fell on the other side of a line break,
  // or was never there at all, is punctuation the page should not repeat.
  s = s.replace(/(^|[\s([{·>])(\*{1,3}|_{2,3})(?=\S)/g, "$1");
  s = s.replace(/(\S)(\*{2,3}|_{2,3})(?=[\s.,;:!?)\]}]|$)/g, "$1");
  s = s.replace(/(^|\s)[*_]{2,}(?=\s|$)/g, " ");
  s = s.replace(/^[*+]\s+/gm, "· ");
  if (!lines) return s.replace(/\s+/g, " ").trim();
  return s.replace(/\n{3,}/g, "\n\n").trim();
}

function snippetHTML(text, tokens) {
  const clean = plain(text);
  const marked = esc(clean).replace(/&lt;&lt;/g, "\u0001").replace(/&gt;&gt;/g, "\u0002");
  // ts_headline already decided what matched: keep its choice, add the fuzzy
  // pass only where it found nothing.
  if (marked.includes("\u0001")) {
    return marked.replace(/\u0001(.*?)\u0002/g, "<mark>$1</mark>");
  }
  return markHTML(clean, tokens);
}

function currentTokens() {
  return state.q
    .toLowerCase()
    .split(/[\s,;:]+/)
    .filter((t) => t.length > 1)
    .slice(0, 6);
}

function renderResults() {
  el.results.textContent = "";
  el.count.textContent = state.results.length ? `· ${state.results.length}` : "";
  const tokens = currentTokens();
  const max = Math.max(1, ...state.results.map((r) => r.score));

  if (!state.results.length) {
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = state.q ? "nothing in the sea answers to that" : "the archive is quiet";
    el.results.append(li);
    return;
  }

  state.results.forEach((mail, index) => {
    const li = document.createElement("li");
    li.className = `letter${index === state.focus ? " focus" : ""}${index < 3 ? " top" : ""}`;
    li.dataset.index = String(index);
    li.tabIndex = -1;

    const idx = document.createElement("div");
    idx.className = "idx";
    idx.textContent = String(index + 1).padStart(2, "0");
    const check = document.createElement("span");
    check.className = "check";
    check.setAttribute("role", "checkbox");
    check.setAttribute("aria-checked", String(state.selected.has(mail.messageId)));
    check.title = "space marks this letter";
    check.addEventListener("click", (event) => {
      event.stopPropagation();
      toggleSelect(index);
    });
    if (state.selected.has(mail.messageId)) li.dataset.selected = "1";
    if (state.queued.has(mail.messageId)) li.dataset.queued = state.queued.get(mail.messageId);
    li.dataset.box = mail.box;

    const body = document.createElement("div");

    const top = document.createElement("div");
    top.className = "top";
    const gate = state.glyphs[mail.categories[0]];
    if (gate) {
      const mark = document.createElement("span");
      mark.className = "cgate";
      mark.textContent = gate;
      mark.title = mail.categories[0];
      top.append(mark);
    }
    const sender = document.createElement("span");
    sender.className = "sender";
    sender.innerHTML = markHTML(mail.sender, tokens);
    const date = document.createElement("span");
    date.className = "when";
    date.textContent = when(mail.sentAt);
    top.append(sender, date);
    if (mail.box && mail.box !== "inbox") {
      const mark = document.createElement("span");
      mark.className = `boxmark ${mail.box}`;
      const ago = since(mail.boxChangedAt);
      mark.textContent = ago ? `${mail.box} · ${ago}` : mail.box;
      if (mail.boxReason) mark.title = mail.boxReason;
      top.append(mark);
    }

    const subject = document.createElement("div");
    subject.className = "subject";
    subject.innerHTML = markHTML(mail.subject, tokens);

    body.append(top, subject);

    if (mail.snippet) {
      const snippet = document.createElement("p");
      snippet.className = "snippet";
      snippet.innerHTML = snippetHTML(mail.snippet, tokens);
      body.append(snippet);
    }

    if (mail.tags.length) {
      const tags = document.createElement("div");
      tags.className = "tags";
      for (const tag of mail.tags.slice(0, 6)) {
        const span = document.createElement("span");
        const cls = classify(tag, tokens);
        span.className = `tag${cls.some((v) => v > 0) ? " hot" : ""}`;
        span.innerHTML = markHTML(tag, tokens);
        tags.append(span);
      }
      body.append(tags);
    }

    const heat = document.createElement("span");
    heat.className = "heat";
    const bar = document.createElement("i");
    bar.style.transform = `scaleX(${(mail.score / max).toFixed(3)})`;
    heat.append(bar);

    li.append(check, idx, body, heat);
    li.addEventListener("click", () => openReader(mail.id));
    el.results.append(li);
  });
}

/* ------------------------------------------------------------------ */
/* a list of decisions, not one letter at a time                       */
/* ------------------------------------------------------------------ */

const BATCH_LABEL = { archive: "archive", delete: "delete", hermes: "Hermes" };
let batchArmedUntil = 0;
let batchTimer = null;

// The focused row is the fallback target, so a decision never needs a second
// gesture: mark rows with space, or just walk to one and press the letter.
// Decisions are keyed by Message-ID, never by row id: the archive keys on the
// header, and a re-import renumbers the row but not the message.
function targetIds() {
  if (state.selected.size) return [...state.selected];
  // No walk yet means the first row, not nothing: a search then `x` should arm
  // something instead of looking like a dead key.
  const mail = state.results[state.focus] ?? state.results[0];
  return mail?.messageId ? [mail.messageId] : [];
}

function toggleSelect(index) {
  const mail = state.results[index];
  if (!mail?.messageId) return;
  state.focus = index;
  if (state.selected.has(mail.messageId)) state.selected.delete(mail.messageId);
  else state.selected.add(mail.messageId);
  renderResults();
  renderSelection();
  el.results.children[index]?.scrollIntoView({ block: "nearest" });
}

function renderSelection() {
  const n = state.selected.size;
  el.batchState.textContent = n
    ? `${n} marked · a archive · x delete · space clear`
    : "space marks · a archive · x delete";
  el.batchState.classList.toggle("live", n > 0);
}

function resetBatch() {
  batchArmedUntil = 0;
  clearTimeout(batchTimer);
  state.selected.clear();
  renderSelection();
}

// One request per row is honest and idempotent: the endpoint upserts a single
// (message, kind), so a retried batch is the same batch. Concurrency is capped
// because fifty sockets to loopback help nobody.
async function postActions(ids, kind, instruction) {
  const queue = [...ids];
  const done = [];
  const workers = Array.from({ length: Math.min(6, queue.length) }, async () => {
    for (;;) {
      const id = queue.shift();
      if (!id) return;
      try {
        await postJSON(`${API}/atlas-act`, { messageId: id, kind, instruction });
        done.push(id);
      } catch (error) {
        console.error(error);
      }
    }
  });
  await Promise.all(workers);
  return done;
}

async function batch(kind) {
  const ids = targetIds();
  if (!ids.length) return;

  // Deletion is irreversible enough to ask twice — in the list as well as in
  // the reader, and for the whole marked set at once.
  if (kind === "delete") {
    if (Date.now() > batchArmedUntil) {
      batchArmedUntil = Date.now() + 4000;
      el.batchState.textContent = `press x again to queue ${ids.length} for deletion`;
      el.batchState.classList.add("live", "armed");
      clearTimeout(batchTimer);
      batchTimer = setTimeout(() => {
        el.batchState.classList.remove("armed");
        renderSelection();
      }, 4000);
      return;
    }
    batchArmedUntil = 0;
    clearTimeout(batchTimer);
    el.batchState.classList.remove("armed");
  }

  const instruction = kind === "hermes" ? el.instruction.value.trim() : "";
  if (kind === "hermes" && !instruction) {
    revealInstruction();
    return;
  }

  el.batchState.textContent = `queueing ${ids.length}…`;
  el.batchState.classList.add("live");
  const done = await postActions(ids, kind, instruction);
  for (const id of done) state.queued.set(id, kind);
  state.selected.clear();
  renderSelection();
  for (const id of done) leaveWorkingSet(id);
  renderResults();
  el.batchState.textContent = done.length
    ? `${done.length} queued · ${BATCH_LABEL[kind]}`
    : `the archive did not answer`;
  el.batchState.classList.add("live");
}

/* ------------------------------------------------------------------ */
/* taxonomy + chips                                                    */
/* ------------------------------------------------------------------ */

function renderCategories() {
  el.categories.textContent = "";
  const total = state.taxonomy.reduce((sum, c) => sum + (c.mailCount || 0), 0);

  const all = document.createElement("button");
  all.className = `cat${state.cat === "" ? " active" : ""}`;
  all.type = "button";
  all.innerHTML = `<span class="glyph">總</span><span>All gates</span><span class="n">${total}</span>`;
  all.addEventListener("click", () => setCategory(""));
  el.categories.append(all);

  for (const cat of state.taxonomy) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `cat${state.cat === cat.id ? " active" : ""}`;
    button.title = cat.description;
    const glyph = document.createElement("span");
    glyph.className = "glyph";
    glyph.textContent = cat.glyph;
    const label = document.createElement("span");
    label.textContent = cat.label;
    const n = document.createElement("span");
    n.className = "n";
    n.textContent = String(cat.mailCount ?? 0);
    button.append(glyph, label, n);
    button.addEventListener("click", () => setCategory(cat.id));
    el.categories.append(button);
  }
}

// What the answer is made of, in the rail: tags by how much of the result set
// they claim. Clicking one is the same act as clicking it in the graph.
function renderViewTags() {
  el.viewTags.textContent = "";
  const counts = new Map();
  if (state.results.length) {
    for (const mail of state.results) {
      for (const tag of mail.tags) counts.set(tag, (counts.get(tag) || 0) + 1);
    }
  } else {
    for (const cat of state.taxonomy) {
      for (const tag of cat.tags || []) if (tag.count > 0) counts.set(tag.id, tag.count);
    }
  }
  const list = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 9);
  if (!list.length) {
    const none = document.createElement("span");
    none.className = "vt empty-tag";
    none.textContent = "nothing placed yet";
    el.viewTags.append(none);
    return;
  }
  for (const [tag, count] of list) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "vt";
    button.innerHTML = `${esc(tag)} <span class="n">${count}</span>`;
    button.addEventListener("click", () => {
      el.q.value = tag;
      runSearch({ inhale: true });
    });
    el.viewTags.append(button);
  }
}

function renderChips(suggestions = []) {
  el.chips.textContent = "";
  const items = suggestions
    .filter((s) => s.id !== state.q)
    .slice(0, 7)
    .map((s) => ({ id: s.id, count: s.mailCount, fuzzy: true }));

  const fallback = () => {
    const seen = [];
    for (const cat of state.taxonomy) {
      for (const tag of cat.tags || []) {
        if (tag.count > 0) seen.push({ id: tag.id, count: tag.count, fuzzy: false });
      }
    }
    return seen.sort((a, b) => b.count - a.count).slice(0, 7);
  };

  // With no query there is no suggestion to make: the inbox is the inbox, and a
  // row of "most worn" tags above it is noise in the one view that is not about
  // searching.
  if (!state.q) return;

  const list = items.length ? items : fallback();
  if (!list.length) return;

  const label = document.createElement("span");
  label.className = "label";
  label.textContent = items.length ? "did you mean" : state.q ? "also in the sea" : "most worn";
  el.chips.append(label);

  for (const item of list) {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = `chip${item.fuzzy ? " gold" : ""}`;
    chip.innerHTML = `${esc(item.id)} <span class="n">${item.count}</span>`;
    chip.addEventListener("click", () => {
      el.q.value = item.id;
      runSearch();
    });
    el.chips.append(chip);
  }

  if (state.cat) {
    const clear = document.createElement("button");
    clear.type = "button";
    clear.className = "chip";
    clear.textContent = `× ${state.cat}`;
    clear.addEventListener("click", () => setCategory(""));
    el.chips.append(clear);
  }
}

/* ------------------------------------------------------------------ */
/* search                                                              */
/* ------------------------------------------------------------------ */

let qi = null;
let request = 0;

function searchPoint() {
  const rect = el.form.getBoundingClientRect();
  return { x: rect.left + 42, y: rect.top + rect.height / 2 };
}

async function runSearch({ updateURL = true, inhale = false, append = false } = {}) {
  const q = el.q.value.trim();
  state.q = q;
  if (!append) {
    state.focus = -1;
    state.offset = 0;
    // A selection belongs to the list it was made in. A new answer is a new list.
    state.selected.clear();
    state.queued.clear();
  }

  if (updateURL) {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (state.cat) params.set("cat", state.cat);
    if (state.box !== "inbox") params.set("box", state.box);
    const next = params.toString();
    history.replaceState(null, "", next ? `?${next}` : location.pathname);
  }

  const point = searchPoint();
  if (inhale && qi) qi.inhale(point.x, point.y);
  if (qi) qi.react({ hits: null });

  const started = performance.now();
  el.meta.innerHTML = '<span class="spinner"></span>seeking';
  el.readoutHits.textContent = "—";
  el.readoutMs.textContent = "…";

  const url = `${API}/atlas-search?q=${encodeURIComponent(q)}&cat=${encodeURIComponent(
    state.cat,
  )}&box=${encodeURIComponent(state.box)}&off=${state.offset}&lim=${LIMIT}`;

  const mine = ++request;
  try {
    const rows = await getJSON(url);
    if (mine !== request) return;
    const elapsed = Math.round(performance.now() - started);
    const page = (Array.isArray(rows) ? rows : []).map(normalize);
    state.results = append ? [...state.results, ...page] : page;
    state.offset += page.length;
    // A full page means the cap, not the end: the list says so instead of
    // pretending forty-eight is the whole inbox.
    el.more.hidden = page.length < LIMIT;
    el.dot.className = "dot live";
    el.link.textContent = "linked";
    el.meta.textContent = q ? `by likeness · ${elapsed} ms` : `newest · ${elapsed} ms`;
    el.readoutHits.textContent = String(state.results.length);
    el.readoutMs.textContent = String(elapsed);
    document.body.dataset.void = state.results.length ? "0" : q ? "1" : "0";

    const cats = new Set();
    const tags = new Set();
    for (const mail of state.results) {
      for (const c of mail.categories) cats.add(c);
      for (const t of mail.tags) tags.add(t);
    }
    el.graphNote.textContent = `${state.results.length} letters · ${cats.size} gates · ${tags.size} tags`;
    field.setData({ query: q, results: state.results, taxonomy: state.taxonomy });
    if (qi) {
      qi.react({ hits: state.results.length, ms: elapsed });
      // A heartbeat where the answer landed: the field pushes out from the
      // graph's centre, then draws back in behind it.
      const graph = document.getElementById("atlas-graph").getBoundingClientRect();
      const cx = graph.left + graph.width / 2;
      const cy = graph.top + graph.height / 2;
      qi.burst(cx, cy, 15000);
      setTimeout(() => qi.burst(cx, cy, -9000), 190);
    }
  } catch (error) {
    console.error(error);
    if (mine !== request) return;
    state.results = [];
    el.dot.className = "dot down";
    el.link.textContent = "unreachable";
    el.meta.textContent = "the archive did not answer";
    el.readoutHits.textContent = "!";
    el.readoutMs.textContent = "—";
    if (qi) qi.react({ hits: 0 });
  } finally {
    if (mine === request) {
      renderResults();
      renderViewTags();
    }
  }

  if (q.length >= 2) {
    try {
      const suggestions = await getJSON(`${API}/atlas-tags?q=${encodeURIComponent(q)}&lim=7`);
      renderChips(Array.isArray(suggestions) ? suggestions : []);
    } catch {
      renderChips([]);
    }
  } else {
    renderChips([]);
  }
}

function setCategory(cat) {
  state.cat = state.cat === cat ? "" : cat;
  renderCategories();
  runSearch({ inhale: true });
}

/* ------------------------------------------------------------------ */
/* the working set: inbox / queued / handled / all                     */
/* ------------------------------------------------------------------ */

const BOX_TITLE = { inbox: "Inbox", queued: "Queued", done: "Handled", all: "Every letter" };

function renderBoxTabs() {
  for (const tab of el.boxTabs.querySelectorAll("button")) {
    tab.setAttribute("aria-selected", String(tab.dataset.box === state.box));
  }
  el.boxTitle.textContent = BOX_TITLE[state.box] || "Inbox";
}

function setBox(box) {
  if (state.box === box) return;
  state.box = box;
  renderBoxTabs();
  runSearch({ inhale: true });
}

function renderCounts() {
  el.inbox.textContent = String(state.counts.inbox ?? 0);
  el.queuedStat.textContent = String(state.counts.queued ?? 0);
}

// A decision takes the letter out of the working set the moment it is asked
// for. The server has already moved its box; this keeps the list honest without
// a round trip, and `queued` is where the letter can be found again.
function leaveWorkingSet(messageId) {
  const mail = state.results.find((m) => m.messageId === messageId);
  if (!mail) return;
  mail.box = "queued";
  // The local move is a real one, so its age starts now instead of showing the
  // previous box's date until the next search.
  mail.boxChangedAt = new Date().toISOString();
  mail.boxReason = "decision queued";
  state.counts.inbox = Math.max(0, (state.counts.inbox ?? 0) - 1);
  state.counts.queued = (state.counts.queued ?? 0) + 1;
  renderCounts();
  if (state.box !== "inbox") return;
  state.results = state.results.filter((m) => m.messageId !== messageId);
  state.focus = Math.min(state.focus, state.results.length - 1);
  renderResults();
  renderViewTags();
}

/* ------------------------------------------------------------------ */
/* reader                                                              */
/* ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ */
/* the three decisions                                                */
/* ------------------------------------------------------------------ */

const ACT_LABEL = { archive: "archive", delete: "queue deletion", hermes: "send to Hermes" };

let armedUntil = 0;
let armTimer = null;

function renderActions() {
  const byKind = new Map(state.reader.actions.map((a) => [a.kind, a]));
  for (const [kind, button] of Object.entries(el.act)) {
    const row = byKind.get(kind);
    button.dataset.status = row ? row.status : "";
    button.querySelector(".act-label").textContent =
      row && row.status === "pending"
        ? `${kind === "hermes" ? "Hermes" : kind} · queued`
        : ACT_LABEL[kind];
  }
  const pending = state.reader.actions.filter((a) => a.status === "pending");
  if (pending.length) {
    el.actState.textContent = pending.map((a) => `${a.kind} queued`).join(" · ");
    el.actState.classList.add("live");
  } else {
    el.actState.textContent = "";
    el.actState.classList.remove("live");
  }
}

function revealInstruction() {
  el.instruct.hidden = false;
  el.instruction.focus();
}

async function act(kind) {
  const { messageId } = state.reader;
  if (!messageId) return;

  // Deletion is a request an agent executes, not a button that fires once: the
  // first press arms it, the second queues it, four seconds to change your mind.
  if (kind === "delete") {
    if (Date.now() > armedUntil) {
      armedUntil = Date.now() + 4000;
      el.act.delete.dataset.armed = "1";
      el.act.delete.querySelector(".act-label").textContent = "press again to queue";
      clearTimeout(armTimer);
      armTimer = setTimeout(() => {
        el.act.delete.dataset.armed = "";
        renderActions();
      }, 4000);
      return;
    }
    armedUntil = 0;
    el.act.delete.dataset.armed = "";
    clearTimeout(armTimer);
  }

  const instruction = kind === "hermes" ? el.instruction.value.trim() : "";
  if (kind === "hermes" && !instruction) {
    revealInstruction();
    return;
  }

  el.actState.textContent = "sending…";
  el.actState.classList.add("live");
  try {
    const rows = await postJSON(`${API}/atlas-act`, { messageId, kind, instruction });
    const row = Array.isArray(rows) ? rows[0] : rows;
    state.reader.actions = [
      ...state.reader.actions.filter((a) => a.kind !== kind),
      {
        kind,
        status: row?.status ?? "pending",
        instruction,
        requestedAt: row?.requestedAt ?? null,
      },
    ];
    if (kind === "hermes") {
      el.instruct.hidden = true;
      el.instruction.value = "";
    }
    renderActions();
    // The reader is about to close on a letter the list no longer holds.
    leaveWorkingSet(messageId);
  } catch (error) {
    console.error(error);
    el.actState.textContent = "the archive did not answer";
    el.actState.classList.remove("live");
  }
}

for (const [kind, button] of Object.entries(el.act)) {
  button.addEventListener("click", () => {
    if (kind === "hermes" && el.instruct.hidden) revealInstruction();
    else act(kind);
  });
}

el.instruct.addEventListener("submit", (event) => {
  event.preventDefault();
  act("hermes");
});

el.instruction.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    act("hermes");
  }
});

// A stored body is markdown flattened to text, and senders separate paragraphs
// three different ways: a blank line, one sentence per line, or a hard wrap at
// 72. The rule that reads all three — a line ends a paragraph when it ends in
// terminal punctuation or stands alone as a bullet; anything else is a wrapped
// continuation of the line above.
function bodyBlocks(text) {
  const blocks = [];
  let current = "";
  const flush = () => {
    if (current.trim()) blocks.push(current.trim());
    current = "";
  };
  for (const raw of String(text || "").replace(/\r\n?/g, "\n").split("\n")) {
    const line = raw.trim();
    if (!line) {
      flush();
      continue;
    }
    const bullet = /^(?:[>•*\-–—]|\d+[.)])\s/.test(line);
    if (bullet) flush();
    current = current ? `${current} ${line}` : line;
    if (bullet || /[.!?…:;]$/.test(line)) flush();
  }
  flush();
  return blocks;
}

// One <p> per block is the difference between a letter and a scrollbar of prose.
function renderBody(text) {
  el.readerBody.replaceChildren();
  const blocks = bodyBlocks(text).slice(0, 400);
  if (!blocks.length) {
    const empty = document.createElement("p");
    empty.textContent = "(no text body)";
    el.readerBody.append(empty);
    return;
  }
  for (const block of blocks) {
    const p = document.createElement("p");
    p.textContent = block;
    el.readerBody.append(p);
  }
}

async function openReader(id) {
  try {
    const rows = await getJSON(`${API}/atlas-message?id=${encodeURIComponent(id)}`);
    const mail = Array.isArray(rows) ? rows[0] : rows;
    if (!mail) return;
    const tags = toArray(mail.tags);
    state.reader = { messageId: mail.messageId, actions: toArray(mail.actions) };
    armedUntil = 0;
    el.act.delete.dataset.armed = "";
    el.instruct.hidden = true;
    el.instruction.value = "";
    renderActions();
    el.readerKicker.textContent = [
      "letter",
      when(mail.sentAt) || "undated",
      mail.box && mail.box !== "inbox" ? mail.box : "",
    ]
      .filter(Boolean)
      .join(" · ");
    el.readerSubject.textContent = plain(mail.subject) || "(no subject)";
    const trail = toArray(mail.boxHistory);
    el.readerMeta.innerHTML = [
      `<span>from <b>${esc(mail.sender || "unknown")}</b></span>`,
      tags.length ? `<span class="rtag">${tags.map((t) => `#${esc(t)}`).join(" ")}</span>` : "",
      mail.attachmentPath ? "<span>attachment</span>" : "",
      trail.length
        ? `<span class="rtrail">${trail
            .slice(-4)
            .map((move) => `${esc(move.box)} ${esc(since(move.at))}`)
            .join(" → ")}</span>`
        : "",
    ]
      .filter(Boolean)
      .join("");
    renderBody(plain(mail.bodyPlain ?? mail.body_plain ?? "", { lines: true }));
    el.reader.showModal();
  } catch (error) {
    console.error(error);
  }
}

document.getElementById("reader-close").addEventListener("click", () => el.reader.close());
el.reader.addEventListener("click", (event) => {
  if (event.target === el.reader) el.reader.close();
});

/* ------------------------------------------------------------------ */
/* keyboard + boot                                                     */
/* ------------------------------------------------------------------ */

el.form.addEventListener("submit", (event) => {
  event.preventDefault();
  runSearch({ inhale: true });
});

el.q.addEventListener(
  "input",
  debounce(() => {
    const point = searchPoint();
    if (qi) qi.caret(point.x, point.y);
    runSearch();
  }, 150),
);

document.addEventListener("keydown", (event) => {
  const typing = document.activeElement === el.q;

  // Inside the reader the letter keys are the decisions. Esc is left to the
  // dialog, which closes natively.
  if (el.reader.open) {
    if (document.activeElement === el.instruction) return;
    const kind = event.key === "a" ? "archive" : event.key === "x" ? "delete" : event.key === "h" ? "hermes" : null;
    if (kind) {
      event.preventDefault();
      if (kind === "hermes" && el.instruct.hidden) revealInstruction();
      else act(kind);
    }
    return;
  }

  if (event.key === "/" && !typing) {
    event.preventDefault();
    el.q.focus();
    el.q.select();
    return;
  }
  // `H` (shift-h) is the mailbox-wide command, `h` in the reader is the same
  // instruction scoped to one letter.
  if (event.key === "H" && !typing) {
    event.preventDefault();
    openCommand();
    return;
  }
  // Esc also disarms a half-pressed `x`, not just the marks: an armed bar that
  // survives the key that clears everything reads as a stuck state.
  if (event.key === "Escape" && (state.selected.size || Date.now() <= batchArmedUntil)) {
    resetBatch();
    renderResults();
    return;
  }
  if (event.key === "Escape" && typing) {
    el.q.value = "";
    runSearch({ inhale: true });
    el.q.blur();
    return;
  }
  if (!state.results.length) return;

  // The list is a workspace, not just an index: space marks, `a` archives,
  // `x` queues deletion (twice), and the marked set is what they apply to.
  if (event.key === " " && !typing) {
    event.preventDefault();
    toggleSelect(state.focus >= 0 ? state.focus : 0);
    return;
  }
  if ((event.key === "a" || event.key === "x") && !typing) {
    event.preventDefault();
    batch(event.key === "a" ? "archive" : "delete");
    return;
  }

  if (event.key === "ArrowDown" || (event.key === "j" && !typing)) {
    event.preventDefault();
    state.focus = Math.min(state.focus + 1, state.results.length - 1);
    renderResults();
    el.results.children[state.focus]?.scrollIntoView({ block: "nearest" });
    return;
  }
  if (event.key === "ArrowUp" || (event.key === "k" && !typing)) {
    event.preventDefault();
    state.focus = Math.max(state.focus - 1, 0);
    renderResults();
    el.results.children[state.focus]?.scrollIntoView({ block: "nearest" });
    return;
  }

  // Enter opens the focused letter even with the caret still in the search box
  // — but only while that box still holds the query the list was built from, so
  // Enter after typing a new word searches instead of opening a stale result.
  const focused = state.focus >= 0 && (!typing || el.q.value.trim() === state.q);
  if (event.key === "Enter" && focused) {
    event.preventDefault();
    openReader(state.results[state.focus].id);
  }
});

/* ------------------------------------------------------------------ */
/* the controls: boxes, the action bar, one command for Hermes         */
/* ------------------------------------------------------------------ */

el.more.addEventListener("click", () => runSearch({ append: true, updateURL: false }));

el.boxTabs.addEventListener("click", (event) => {
  const tab = event.target.closest("button[data-box]");
  if (tab) setBox(tab.dataset.box);
});

// Folding the field is a preference, not a route: it survives a reload and a
// search, and it is the difference between a decoration and a usable list on a
// small machine.
const workspace = document.querySelector(".workspace");
const fieldFold = document.getElementById("field-fold");

function setField(folded) {
  workspace.dataset.field = folded ? "folded" : "open";
  fieldFold.textContent = folded ? "unfold" : "fold";
  try {
    localStorage.setItem("atlas.field", folded ? "folded" : "open");
  } catch {
    /* a private window still folds */
  }
  if (!folded) requestAnimationFrame(() => field.resize());
}

fieldFold.addEventListener("click", () => {
  setField(workspace.dataset.field !== "folded");
});

for (const button of el.actionBar.querySelectorAll(".ab-actions button")) {
  button.addEventListener("click", () => {
    if (button.dataset.kind === "clear") {
      resetBatch();
      renderResults();
      return;
    }
    batch(button.dataset.kind);
  });
}

function openCommand() {
  el.commandState.textContent = "";
  el.commandState.classList.remove("live");
  el.command.showModal();
  el.commandText.focus();
}

el.hermesOpen.addEventListener("click", openCommand);
el.commandClose.addEventListener("click", () => el.command.close());

// The instruction is a sentence, so Enter is a newline; queueing is ⌘↵ (or the
// button), the same gesture as the per-letter instruction box.
el.commandText.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
    event.preventDefault();
    el.commandForm.requestSubmit();
  }
});

el.commandForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const instruction = el.commandText.value.trim();
  if (!instruction) {
    el.commandText.focus();
    return;
  }
  el.commandState.textContent = "queueing…";
  el.commandState.classList.add("live");
  try {
    await postJSON(`${API}/atlas-command`, { instruction });
    el.commandText.value = "";
    el.commandState.textContent = "";
    el.commandState.classList.remove("live");
    el.command.close();
    state.counts.commands = (state.counts.commands ?? 0) + 1;
    el.batchState.textContent = `${state.counts.commands} command${state.counts.commands === 1 ? "" : "s"} waiting for Hermes`;
    el.batchState.classList.add("live");
  } catch (error) {
    console.error(error);
    el.commandState.textContent = "the archive did not answer";
    el.commandState.classList.remove("live");
  }
});

field.onOpen(openReader);
field.onTag((tag) => {
  el.q.value = tag;
  runSearch({ inhale: true });
});
field.onCategory((cat) => setCategory(cat));

(async function boot() {
  qi = await startQiField(document.getElementById("qi-field"));
  document.addEventListener("click", (event) => {
    if (event.target.closest("a, button, input")) return;
    qi.burst(event.clientX, event.clientY, 11000);
  });

  const params = new URLSearchParams(location.search);
  state.cat = params.get("cat") || "";
  state.box = params.get("box") || "inbox";
  el.q.value = params.get("q") || "";

  try {
    const [taxonomy, stats] = await Promise.all([
      getJSON(`${API}/atlas-taxonomy`),
      getJSON(`${API}/atlas-stats`),
    ]);
    state.taxonomy = (Array.isArray(taxonomy) ? taxonomy : []).map((c) => ({
      ...c,
      tags: toArray(c.tags),
      mailCount: Number(c.mailCount || 0),
    }));
    for (const cat of state.taxonomy) state.glyphs[cat.id] = cat.glyph;
    // The graph labels draw gate glyphs on a canvas, which has no fallback
    // chain to lean on: wait for the subset before the first frame.
    try {
      await document.fonts.load('12px "Atlas Han"');
    } catch {
      /* the CSS fallback still renders */
    }
    const headline = Array.isArray(stats) ? stats[0] : stats;
    state.total = Number(headline?.letters || 0);
    el.letters.textContent = String(state.total);
    state.counts.inbox = Number(headline?.inbox ?? 0);
    state.counts.queued = Number(headline?.queued ?? 0);
    state.counts.commands = Number(headline?.commands ?? 0);
    renderCounts();
    renderBoxTabs();
    renderSelection();
    if (state.total) {
      el.hint.textContent = `${state.counts.inbox} in · ${state.counts.queued} queued · ↑↓ walk · ↵ read`;
    }
    el.dot.className = "dot live";
    el.link.textContent = "linked";
    renderCategories();
    renderChips([]);
    try {
      if (localStorage.getItem("atlas.field") === "folded") setField(true);
    } catch {
      /* no storage: the field stays open */
    }
    field.resize();
  } catch (error) {
    console.error(error);
    el.dot.className = "dot down";
    el.link.textContent = "unreachable";
  }

  await runSearch({ updateURL: false, inhale: true });
})();
