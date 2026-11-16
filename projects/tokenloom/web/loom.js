'use strict';

const WIRE = { INSERT: 1, DELETE: 2, MERGE: 3, SPLIT: 4, ANNOTATE: 5, CONSTRAINT: 6, TOGGLE: 7, RESYNC: 8 };
const FRAME = {
  ACK: 0x80, DIFF: 0x81, RAISE: 0x82, CLEAR: 0x83, SNAPSHOT: 0x84, METRICS: 0x85, CONSTRAINTS: 0x86,
};
const ROW_TOKENS = 16;
const ROW_H = 26;
const KIND = {
  1: 'boundary-instability',
  2: 'cross-vocab-divergence',
  3: 'constraint-violation',
  4: 'span-creep',
  5: 'merge-explosion',
  6: 'ripple-truncated',
};
const REACTORS = { 1: 'bpe-a', 2: 'bpe-b', 3: 'wordpiece', 4: 'regex-lexer', 5: 'constraint-check', 6: 'stability' };
const CONS_KIND = { 1: 'max-tokens', 2: 'no-crossing', 3: 'stable-boundary' };

const state = {
  tokens: [],
  revision: 0,
  seq: 1,
  warnings: new Map(),
  diffs: [],
  constraints: [],
  metrics: null,
  sel: { a: 0, b: 0 },
  ws: null,
};

const $ = (sel) => document.querySelector(sel);
const scroller = $('#scroller');
const spacer = $('#spacer');
const layer = $('#layer');
const decoder = new TextDecoder('utf-8');

class Writer {
  constructor(cap = 256) {
    this.buf = new Uint8Array(cap);
    this.v = new DataView(this.buf.buffer);
    this.p = 0;
  }
  need(n) {
    if (this.p + n <= this.buf.length) return;
    let cap = this.buf.length * 2;
    while (cap < this.p + n) cap *= 2;
    const next = new Uint8Array(cap);
    next.set(this.buf.subarray(0, this.p));
    this.buf = next;
    this.v = new DataView(next.buffer);
  }
  u8(x) { this.need(1); this.v.setUint8(this.p, x); this.p += 1; return this; }
  u16(x) { this.need(2); this.v.setUint16(this.p, x, true); this.p += 2; return this; }
  u32(x) { this.need(4); this.v.setUint32(this.p, x >>> 0, true); this.p += 4; return this; }
  u64(x) { this.need(8); this.v.setBigUint64(this.p, BigInt(x), true); this.p += 8; return this; }
  raw(bytes) { this.need(bytes.length); this.buf.set(bytes, this.p); this.p += bytes.length; return this; }
  done() { return this.buf.slice(0, this.p); }
}

class Reader {
  constructor(buf) {
    this.v = new DataView(buf);
    this.p = 0;
  }
  u8() { const x = this.v.getUint8(this.p); this.p += 1; return x; }
  u16() { const x = this.v.getUint16(this.p, true); this.p += 2; return x; }
  u32() { const x = this.v.getUint32(this.p, true); this.p += 4; return x; }
  u64() { const x = Number(this.v.getBigUint64(this.p, true)); this.p += 8; return x; }
  text(n) {
    const bytes = new Uint8Array(this.v.buffer, this.v.byteOffset + this.p, n);
    this.p += n;
    return decoder.decode(bytes);
  }
  oneToken() {
    const len = this.u16();
    const flags = this.u8();
    return { text: this.text(len), flags };
  }
}

function send(bytes) {
  if (state.ws && state.ws.readyState === 1) state.ws.send(bytes);
}

function opInsert(offset, words) {
  const tokens = words.map((w) => {
    const bytes = new TextEncoder().encode(w);
    const flags = /^[A-Za-z0-9_]+$/.test(w) ? 1 : 2;
    return { bytes, flags };
  });
  const w = new Writer().u8(WIRE.INSERT).u64(state.seq++).u32(offset).u16(tokens.length);
  for (const t of tokens) w.u16(t.bytes.length).u8(t.flags).raw(t.bytes);
  send(w.done());
}

function opDelete(offset, count) {
  send(new Writer().u8(WIRE.DELETE).u64(state.seq++).u32(offset).u16(count).done());
}

function opMerge(offset, count) {
  send(new Writer().u8(WIRE.MERGE).u64(state.seq++).u32(offset).u16(count).done());
}

function opSplit(offset, byteOff) {
  send(new Writer().u8(WIRE.SPLIT).u64(state.seq++).u32(offset).u16(byteOff).done());
}

function opAnnotate(offset, count, tag, bytes) {
  const w = new Writer().u8(WIRE.ANNOTATE).u64(state.seq++).u32(offset).u16(count).u16(tag).u16(bytes.length);
  send(w.raw(bytes).done());
}

function opConstraint(start, len, kind, param) {
  send(new Writer().u8(WIRE.CONSTRAINT).u64(state.seq++).u32(start).u16(len).u8(kind).u32(param).done());
}

function opToggle(id, on) {
  send(new Writer().u8(WIRE.TOGGLE).u64(state.seq++).u8(id).u8(on ? 1 : 0).done());
}

function selRange() {
  const a = Math.min(state.sel.a, state.sel.b);
  const b = Math.max(state.sel.a, state.sel.b);
  return { start: a, end: b + 1, count: b - a + 1 };
}

function selected() {
  const r = selRange();
  return r;
}

/* ── incoming frames ─────────────────────────────────────────────── */

function onBinary(buf) {
  const r = new Reader(buf);
  switch (r.u8()) {
    case FRAME.ACK: {
      r.u64();
      state.revision = r.u64();
      $('#rev').textContent = `rev ${state.revision}`;
      return;
    }
    case FRAME.DIFF: {
      const revision = r.u64();
      const start = r.u32();
      const deleted = r.u16();
      const count = r.u16();
      const inserted = [];
      for (let i = 0; i < count; i++) inserted.push(r.oneToken());
      state.tokens.splice(start, deleted, ...inserted);
      state.revision = revision;
      state.diffs.unshift({ revision, start, deleted, inserted });
      if (state.diffs.length > 30) state.diffs.pop();
      $('#rev').textContent = `rev ${state.revision}`;
      renderDiffs();
      drawRope();
      return;
    }
    case FRAME.RAISE: {
      const w = {
        id: r.u32(),
        kind: r.u8(),
        reactor: r.u8(),
        severity: r.u8(),
        start: r.u32(),
        len: r.u16(),
        revision: r.u64(),
        message: r.text(r.u16()),
      };
      state.warnings.set(w.id, w);
      renderWarnings();
      return;
    }
    case FRAME.CLEAR: {
      const id = r.u32();
      r.u64();
      state.warnings.delete(id);
      renderWarnings();
      return;
    }
    case FRAME.SNAPSHOT: {
      const revision = r.u64();
      const reactors = r.u8();
      const n = r.u32();
      const tokens = [];
      for (let i = 0; i < n; i++) tokens.push(r.oneToken());
      state.tokens = tokens;
      state.revision = revision;
      state.diffs = [];
      state.warnings.clear();
      syncReactors(reactors);
      $('#rev').textContent = `rev ${state.revision}`;
      drawRope();
      renderDiffs();
      renderWarnings();
      return;
    }
    case FRAME.METRICS: {
      state.metrics = {
        p50: r.u32(), p99: r.u32(), retok: r.u32(), trunc: r.u32(), starved: r.u32(), win: r.u32(),
        reactors: r.u8(), constraints: r.u32(),
      };
      renderMetrics();
      return;
    }
    case FRAME.CONSTRAINTS: {
      r.u64();
      const n = r.u32();
      const items = [];
      for (let i = 0; i < n; i++) {
        items.push({ id: r.u32(), anchor: r.u32(), len: r.u16(), kind: r.u8(), param: r.u32() });
      }
      state.constraints = items;
      renderConstraints();
      return;
    }
  }
}

/* ── rendering ───────────────────────────────────────────────────── */

function display(text) {
  if (!text.length) return '∅';
  return text.replace(/ /g, '·').replace(/\t/g, '→').replace(/\n/g, '⏎');
}

function classOf(flags) {
  if (flags & 1) return 'word';
  if (flags & 4) return 'ws';
  return 'punct';
}

function inSel(i) {
  const { start, end } = selRange();
  return i >= start && i < end;
}

let renderQueued = false;
function drawRope() {
  if (renderQueued) return;
  renderQueued = true;
  requestAnimationFrame(() => {
    renderQueued = false;
    const total = state.tokens.length;
    const rows = Math.ceil(total / ROW_TOKENS);
    spacer.style.height = `${rows * ROW_H}px`;
    const first = Math.max(0, Math.floor(scroller.scrollTop / ROW_H) - 3);
    const visible = Math.ceil(scroller.clientHeight / ROW_H) + 7;
    const last = Math.min(rows, first + visible);
    layer.style.transform = `translateY(${first * ROW_H}px)`;
    const frag = document.createDocumentFragment();
    for (let row = first; row < last; row++) {
      const div = document.createElement('div');
      div.className = 'row';
      div.style.height = `${ROW_H}px`;
      const from = row * ROW_TOKENS;
      const to = Math.min(total, from + ROW_TOKENS);
      for (let i = from; i < to; i++) {
        const t = state.tokens[i];
        const chip = document.createElement('span');
        chip.className = `chip ${classOf(t.flags)}${inSel(i) ? ' sel' : ''}`;
        chip.textContent = display(t.text);
        chip.dataset.i = String(i);
        chip.title = `#${i} · ${t.text.length} bytes`;
        div.appendChild(chip);
      }
      frag.appendChild(div);
    }
    layer.replaceChildren(frag);
    const r = selRange();
    $('#sel').textContent = r.count > 1 ? `tokens ${r.start}..${r.end - 1} (${r.count})` : `token ${r.start}`;
  });
}

function renderDiffs() {
  const list = $('#diffs');
  $('#diffCount').textContent = String(state.diffs.length);
  if (!state.diffs.length) {
    list.innerHTML = '<li class="empty">no diffs yet</li>';
    return;
  }
  list.replaceChildren(
    ...state.diffs.map((d) => {
      const li = document.createElement('li');
      const head = document.createElement('span');
      head.className = 'n';
      head.textContent = `rev ${d.revision}`;
      const body = document.createElement('span');
      const text = d.inserted.map((t) => display(t.text)).join(' ');
      // A separator before the offset: the lane is two spans, and without it a
      // revision of 1 landing at offset 0 reads as revision 10.
      body.textContent = ` · ${d.start} −${d.deleted} +${d.inserted.length}${text ? `  ${text.slice(0, 60)}` : ''}`;
      li.append(head, body);
      return li;
    }),
  );
}

function renderWarnings() {
  const list = $('#warnings');
  const items = [...state.warnings.values()].sort((a, b) => a.id - b.id);
  $('#warnCount').textContent = String(items.length);
  if (!items.length) {
    list.innerHTML = '<li class="empty">quiet</li>';
    return;
  }
  list.replaceChildren(
    ...items.map((w) => {
      const li = document.createElement('li');
      li.className = `sev-${w.severity}`;
      const kind = document.createElement('span');
      kind.className = 'kind';
      kind.textContent = KIND[w.kind] || `kind ${w.kind}`;
      const msg = document.createElement('span');
      msg.className = 'msg';
      msg.textContent = `#${w.reactor} ${w.message}`;
      li.append(kind, msg);
      li.onclick = () => {
        state.sel.a = w.start;
        state.sel.b = w.start + Math.max(0, w.len - 1);
        drawRope();
        scroller.scrollTop = Math.floor(w.start / ROW_TOKENS) * ROW_H;
      };
      return li;
    }),
  );
}

function describeConstraint(c) {
  if (c.kind === 1) return `≤ ${c.param} tokens`;
  if (c.kind === 2) return `no token crosses '${String.fromCharCode(c.param)}'`;
  if (c.kind === 3) return 'stable boundary';
  return `kind ${c.kind}`;
}

// The panel speaks bytes because that is what the index keeps; the rope speaks
// tokens. Walk the token texts once to find the one that covers the anchor.
function tokenAtByte(byte) {
  const enc = new TextEncoder();
  let at = 0;
  for (let i = 0; i < state.tokens.length; i++) {
    const len = enc.encode(state.tokens[i].text).length;
    if (at + len > byte) return i;
    at += len;
  }
  return 0;
}

function renderConstraints() {
  const list = $('#constraints');
  $('#consCount').textContent = String(state.constraints.length);
  if (!state.constraints.length) {
    list.innerHTML = '<li class="empty">none planted</li>';
    return;
  }
  list.replaceChildren(
    ...state.constraints.map((c) => {
      const li = document.createElement('li');
      const kind = document.createElement('span');
      kind.className = 'k';
      kind.textContent = `#${c.id} ${CONS_KIND[c.kind] || `kind ${c.kind}`}`;
      const msg = document.createElement('span');
      msg.className = 'msg';
      msg.textContent = `${describeConstraint(c)} · ${c.len}t @ ${c.anchor}b`;
      li.append(kind, msg);
      li.onclick = () => {
        const start = tokenAtByte(c.anchor);
        state.sel = { a: start, b: start + Math.max(0, c.len - 1) };
        drawRope();
        scroller.scrollTop = Math.floor(start / ROW_TOKENS) * ROW_H;
      };
      return li;
    }),
  );
}

function renderMetrics() {
  const m = state.metrics;
  if (!m) return;
  const pill = $('#metrics');
  let on = 0;
  for (const id of Object.keys(REACTORS)) if (m.reactors & (1 << Number(id))) on++;
  // The bank and the constraint count come from the server with every metrics
  // frame: a switch thrown in another tab, and a plant that raised nothing,
  // both show up here rather than only in the snapshot on reload.
  pill.textContent =
    `p50 ${(m.p50 / 1000).toFixed(2)}ms · p99 ${(m.p99 / 1000).toFixed(2)}ms · retok ${(m.retok / 100).toFixed(2)}% · trunc ${m.trunc} · win ${m.win}t · starved ${m.starved} · bank ${on}/6 · cons ${m.constraints}`;
  // A starved shard means a reactor missed a diff and fell back to a keyframe:
  // the feed is still right, it just took the expensive path. That should be
  // visible here rather than only in the server's log.
  pill.className = m.starved > 0 ? 'pill warn' : 'pill';
}

/* ── actions ─────────────────────────────────────────────────────── */

function act(name) {
  const r = selected();
  if (name === 'insert') {
    opInsert(r.start, [$('#word').value || 'word']);
  } else if (name === 'split') {
    const t = state.tokens[r.start];
    const off = t && t.text.length > 1 ? 1 : 0;
    if (off) opSplit(r.start, off);
  } else if (name === 'merge') {
    if (r.count >= 2) opMerge(r.start, r.count);
  } else if (name === 'delete') {
    opDelete(r.start, r.count);
  } else if (name === 'annotate') {
    opAnnotate(r.start, r.count, 7, new TextEncoder().encode('✳'));
  }
}

document.querySelectorAll('[data-act]').forEach((b) => {
  b.addEventListener('click', () => act(b.dataset.act));
});

document.querySelectorAll('[data-constraint]').forEach((b) => {
  b.addEventListener('click', () => {
    const r = selected();
    if (b.dataset.constraint === 'max') opConstraint(r.start, r.count, 1, 4);
    if (b.dataset.constraint === 'delim') opConstraint(r.start, r.count, 2, 32);
    if (b.dataset.constraint === 'stable') opConstraint(r.start, 1, 3, r.start);
  });
});

const boxes = new Map();
const reactors = $('#reactors');
for (const [id, name] of Object.entries(REACTORS)) {
  const label = document.createElement('label');
  const box = document.createElement('input');
  box.type = 'checkbox';
  box.checked = true;
  box.addEventListener('change', () => opToggle(Number(id), box.checked));
  label.append(box, document.createTextNode(name));
  reactors.appendChild(label);
  boxes.set(Number(id), box);
}

// The server owns the bank: the snapshot frame carries which reactors are on, so
// a reload after switching one off does not draw every box checked again.
function syncReactors(bits) {
  // Reactor ids are 1-based on the wire, so the bit for reactor 5 is bit 5.
  for (const [id, box] of boxes) box.checked = (bits & (1 << id)) !== 0;
}

layer.addEventListener('click', (e) => {
  const chip = e.target.closest('.chip');
  if (!chip) return;
  const i = Number(chip.dataset.i);
  if (e.shiftKey) state.sel.b = i;
  else state.sel = { a: i, b: i };
  drawRope();
});

let dragging = false;
layer.addEventListener('mousedown', (e) => {
  const chip = e.target.closest('.chip');
  if (!chip) return;
  const i = Number(chip.dataset.i);
  if (!e.shiftKey) state.sel = { a: i, b: i };
  dragging = true;
  drawRope();
  e.preventDefault();
});

layer.addEventListener('mouseover', (e) => {
  if (!dragging) return;
  const chip = e.target.closest('.chip');
  if (!chip) return;
  state.sel.b = Number(chip.dataset.i);
  drawRope();
});

document.addEventListener('mouseup', () => { dragging = false; });
scroller.addEventListener('scroll', drawRope);

document.addEventListener('keydown', (e) => {
  if (e.target.tagName === 'INPUT') return;
  if (e.key === 'Enter') { act('split'); e.preventDefault(); }
  else if (e.key === 'm' || e.key === 'M') { act('merge'); e.preventDefault(); }
  else if (e.key === 'Backspace' || e.key === 'Delete') { act('delete'); e.preventDefault(); }
});

/* ── connection ──────────────────────────────────────────────────── */

function connect() {
  const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const ws = new WebSocket(`${proto}//${location.host}/ws`);
  ws.binaryType = 'arraybuffer';
  state.ws = ws;

  ws.onopen = () => {
    const pill = $('#conn');
    pill.textContent = 'live';
    pill.className = 'pill ok';
  };
  ws.onmessage = (ev) => {
    if (ev.data instanceof ArrayBuffer) onBinary(ev.data);
  };
  ws.onclose = () => {
    const pill = $('#conn');
    pill.textContent = 'reconnecting';
    pill.className = 'pill warn';
    setTimeout(connect, 900);
  };
  ws.onerror = () => ws.close();
}

drawRope();
connect();
