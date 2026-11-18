// The log as a graph: time runs left to right because the ledger is append-only,
// agents get a lane each so a handoff is a line that changes height, and two
// turns are joined when they share a SUBJECT (solid) or a CLAIM (faint). Claims
// are the interesting edges — that is where two agents' work touches the same
// files without either of them naming the other.
//
// No layout library: a force simulation would say "these are near" without
// saying why, and this graph has one defensible axis, which is time.

const cvs = document.getElementById("graph");
const ctx = cvs.getContext("2d");
const tip = document.getElementById("tip");
const stat = document.getElementById("stat");

const COLOR = {done: "#3ef2a6", wait: "#14e0c8", bad: "#ff4f7d"};
const dim = (hex, a) => hex + Math.round(a * 255).toString(16).padStart(2, "0");
const PAD = {l: 104, r: 32, t: 104, b: 60};

let turns = []; // chronological, oldest first
let lanes = []; // source names, stable order
let domain = {lo: 0, hi: 1}; // milliseconds
let span = {lo: 0, hi: 1}; // the full log, for esc
let edges = []; // {a, b, kind}
let hover = null;
let drag = null;

const classOf = (o) =>
  o === "done" ? "done" : o === "in_progress" || o.startsWith("blocked") ? "wait" : "bad";

function fit() {
  const dpr = window.devicePixelRatio || 1;
  cvs.width = Math.round(cvs.clientWidth * dpr);
  cvs.height = Math.round(cvs.clientHeight * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

const plot = () => ({
  w: cvs.clientWidth - PAD.l - PAD.r,
  h: cvs.clientHeight - PAD.t - PAD.b,
});

const xOf = (t) => {
  const {w} = plot();
  return PAD.l + ((t - domain.lo) / (domain.hi - domain.lo || 1)) * w;
};
const laneY = (src) => {
  const {h} = plot();
  const i = Math.max(0, lanes.indexOf(src));
  return PAD.t + (laneCount() === 1 ? h / 2 : (i / (laneCount() - 1)) * h);
};
const laneCount = () => Math.max(1, lanes.length);
const tOf = (i) => Number(turns[i].ts) || i * 60000;

function build() {
  // A turn without a parseable ts would otherwise collapse onto 1970: give it
  // the previous turn's time, which is what its position in the log means.
  let last = 0;
  for (const t of turns) {
    const ms = Date.parse(t.ts);
    t.ms = Number.isFinite(ms) ? ms : last;
    last = t.ms;
  }
  turns.sort((a, b) => a.ms - b.ms);
  lanes = [...new Set(turns.map((t) => t.source || "?"))].sort();

  const lastOf = new Map();
  edges = [];
  const add = (key, kind, t) => {
    const prev = lastOf.get(key);
    if (prev) edges.push({a: prev, b: t, kind});
    lastOf.set(key, t);
  };
  for (const t of turns) {
    if (t.subject) add("s:" + t.subject, "subject", t);
    for (const c of t.claims ?? []) add("c:" + c, "claim", t);
  }

  span = {lo: turns[0]?.ms ?? 0, hi: turns.at(-1)?.ms ?? 1};
  if (span.hi === span.lo) span.hi = span.lo + 60000;
  domain = {...span};
  stat.textContent = `${turns.length} turns · ${edges.length} edges`;
}

function draw() {
  const {w, h} = plot();
  ctx.clearRect(0, 0, cvs.clientWidth, cvs.clientHeight);

  // Lanes and their names: the y axis is who, and it never reorders — a lane
  // that jumped when a new agent appeared would make yesterday's graph a lie.
  ctx.font = '11px "Iosevka Term", ui-monospace, monospace';
  ctx.textBaseline = "middle";
  for (const src of lanes) {
    const y = laneY(src);
    ctx.strokeStyle = "rgba(20,224,200,0.07)";
    ctx.beginPath();
    ctx.moveTo(PAD.l, y);
    ctx.lineTo(PAD.l + w, y);
    ctx.stroke();
    ctx.fillStyle = "#5f8f88";
    ctx.textAlign = "right";
    ctx.fillText(src, PAD.l - 12, y);
  }

  // Date ticks: the axis label is what makes this a timeline and not a cloud.
  const ticks = 6;
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  for (let i = 0; i <= ticks; i++) {
    const ms = domain.lo + ((domain.hi - domain.lo) * i) / ticks;
    const x = xOf(ms);
    ctx.strokeStyle = "rgba(20,224,200,0.10)";
    ctx.beginPath();
    ctx.moveTo(x, PAD.t - 6);
    ctx.lineTo(x, PAD.t + h);
    ctx.stroke();
    ctx.fillStyle = "#5f8f88";
    ctx.fillText(new Date(ms).toISOString().slice(5, 16).replace("T", " "), x, PAD.t + h + 10);
  }

  const visible = new Set();
  for (const t of turns) if (t.ms >= domain.lo && t.ms <= domain.hi) visible.add(t);

  // Claim edges first: they are context, and a solid subject edge drawn under
  // one would read as the weaker relation.
  for (const kind of ["claim", "subject"]) {
    ctx.lineWidth = kind === "claim" ? 1 : 1.6;
    for (const e of edges) {
      if (e.kind !== kind || !visible.has(e.a) || !visible.has(e.b)) continue;
      const x1 = xOf(e.a.ms);
      const x2 = xOf(e.b.ms);
      const y1 = laneY(e.a.source);
      const y2 = laneY(e.b.source);
      const mid = (x1 + x2) / 2;
      ctx.strokeStyle =
        kind === "claim" ? "rgba(20,224,200,0.16)" : "rgba(62,242,166,0.42)";
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.bezierCurveTo(mid, y1, mid, y2, x2, y2);
      ctx.stroke();
    }
  }

  for (const t of turns) {
    if (!visible.has(t)) continue;
    const x = xOf(t.ms);
    const y = laneY(t.source);
    const r = 4.5;
    const c = COLOR[classOf(t.outcome)] ?? COLOR.wait;
    ctx.fillStyle = t === hover ? "#cdf7ea" : c;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
    if (t === hover) {
      ctx.strokeStyle = dim(c, 0.9);
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(x, y, r + 4, 0, Math.PI * 2);
      ctx.stroke();
    }
  }
  ctx.textBaseline = "alphabetic";
}

function nearest(mx, my) {
  let best = null;
  let bestD = 14;
  for (const t of turns) {
    if (t.ms < domain.lo || t.ms > domain.hi) continue;
    const d = Math.hypot(xOf(t.ms) - mx, laneY(t.source) - my);
    if (d < bestD) {
      bestD = d;
      best = t;
    }
  }
  return best;
}

function showTip(t, mx, my) {
  if (!t) {
    tip.hidden = true;
    return;
  }
  tip.innerHTML = "";
  const add = (tag, cls, text) => {
    const el = document.createElement(tag);
    el.className = cls;
    el.textContent = text;
    tip.append(el);
  };
  add("div", "t-meta", `${t.source} · ${t.outcome} · ${new Date(t.ms).toISOString().slice(0, 16).replace("T", " ")}`);
  add("div", "t-sub", t.subject ?? "—");
  add("div", "", t.action ?? "");
  tip.hidden = false;
  const box = tip.getBoundingClientRect();
  tip.style.left = Math.min(mx + 16, cvs.clientWidth - box.width - 12) + "px";
  tip.style.top = Math.min(my + 16, cvs.clientHeight - box.height - 12) + "px";
}

// --- interaction -----------------------------------------------------------

const local = (e) => {
  const r = cvs.getBoundingClientRect();
  return {x: e.clientX - r.left, y: e.clientY - r.top};
};

cvs.addEventListener("wheel", (e) => {
  e.preventDefault();
  const {x} = local(e);
  const at = domain.lo + ((x - PAD.l) / plot().w) * (domain.hi - domain.lo);
  const k = e.deltaY > 0 ? 1.25 : 0.8; // out / in
  const lo = at - (at - domain.lo) * k;
  const hi = at + (domain.hi - at) * k;
  if (hi - lo < 60_000) return; // a minute wide is the floor; below that, nothing to see
  domain = {lo, hi};
  draw();
}, {passive: false});

cvs.addEventListener("pointerdown", (e) => {
  drag = {x: e.clientX, lo: domain.lo, hi: domain.hi, moved: false};
  cvs.setPointerCapture(e.pointerId);
});

cvs.addEventListener("pointermove", (e) => {
  const {x, y} = local(e);
  if (drag) {
    const dx = e.clientX - drag.x;
    if (Math.abs(dx) > 2) drag.moved = true;
    const perPx = (drag.hi - drag.lo) / plot().w;
    domain = {lo: drag.lo - dx * perPx, hi: drag.hi - dx * perPx};
    draw();
    return;
  }
  const t = nearest(x, y);
  if (t !== hover) {
    hover = t;
    draw();
  }
  showTip(t, x, y);
});

cvs.addEventListener("pointerup", (e) => {
  const moved = drag?.moved;
  drag = null;
  if (moved) return;
  const {x, y} = local(e);
  const t = nearest(x, y);
  if (t) location.href = `index.html#turn-${t.id}`;
});

cvs.addEventListener("pointerleave", () => {
  hover = null;
  tip.hidden = true;
  draw();
});

addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  domain = {...span};
  draw();
});

addEventListener("resize", () => {
  fit();
  draw();
});

// --- data ------------------------------------------------------------------
// The server already holds the log for the reader; /api/turns.json is that same
// snapshot as JSON. A frame on the stream means "the log changed", so the page
// refetches instead of parsing patches it cannot use.

let pending = 0;
async function load() {
  try {
    const r = await fetch("api/turns.json", {cache: "no-store"});
    if (!r.ok) throw new Error(String(r.status));
    const body = await r.json();
    turns = body.events ?? [];
    build();
    if (!drag) draw();
    document.body.dataset.stream = "live";
  } catch {
    stat.textContent = "no data";
    document.body.dataset.stream = "retrying";
  }
}

function reload() {
  clearTimeout(pending);
  pending = setTimeout(load, 400); // a burst of turns is one redraw
}

fit();
load();
const stream = new EventSource("api/stream");
stream.onmessage = reload;
stream.addEventListener("patch", reload);
stream.onopen = () => (document.body.dataset.stream = "live");
stream.onerror = () => (document.body.dataset.stream = "retrying");
