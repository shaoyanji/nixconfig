// End-to-end smoke test against a running loom-srv.
//
//   node web/smoke.mjs        (LOOM_PORT, default 8787)
//
// Proves the parts the unit tests cannot: the socket upgrade, the coalescer, the
// reactor pool reaching a warning, and the static routes. Node's global
// WebSocket is what makes this dependency-free.

if (typeof WebSocket === 'undefined') {
  console.error('node has no global WebSocket; cannot smoke the wire');
  process.exit(2);
}

const PORT = process.env.LOOM_PORT || 8787;
const BASE = `http://127.0.0.1:${PORT}`;

class W {
  constructor(cap = 128) {
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

function decode(bytes) {
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const state = { p: 0 };
  const u8 = () => { const x = v.getUint8(state.p); state.p += 1; return x; };
  const u16 = () => { const x = v.getUint16(state.p, true); state.p += 2; return x; };
  const u32 = () => { const x = v.getUint32(state.p, true); state.p += 4; return x; };
  const u64 = () => { const x = Number(v.getBigUint64(state.p, true)); state.p += 8; return x; };
  const text = (n) => {
    const s = new TextDecoder().decode(new Uint8Array(bytes.buffer, bytes.byteOffset + state.p, n));
    state.p += n;
    return s;
  };
  const op = u8();
  if (op === 0x80) return { op, seq: u64(), revision: u64() };
  if (op === 0x81) {
    const revision = u64(), start = u32(), deleted = u16(), count = u16();
    const inserted = [];
    for (let i = 0; i < count; i++) {
      const len = u16(), flags = u8();
      inserted.push({ text: text(len), flags });
    }
    return { op, revision, start, deleted, inserted };
  }
  if (op === 0x82) {
    const w = {
      op, id: u32(), kind: u8(), reactor: u8(), severity: u8(),
      start: u32(), len: u16(), revision: u64(),
    };
    w.message = text(u16());
    return w;
  }
  if (op === 0x83) return { op, id: u32(), revision: u64() };
  if (op === 0x84) {
    const revision = u64(), reactors = u8(), n = u32();
    const tokens = [];
    for (let i = 0; i < n; i++) {
      const len = u16(), flags = u8();
      tokens.push({ text: text(len), flags });
    }
    return { op, revision, reactors, tokens };
  }
  if (op === 0x85) {
    return {
      op, p50: u32(), p99: u32(), retok: u32(), trunc: u32(), starved: u32(), win: u32(),
      reactors: u8(), constraints: u32(),
    };
  }
  if (op === 0x86) {
    const revision = u64(), n = u32();
    const items = [];
    for (let i = 0; i < n; i++) {
      items.push({ id: u32(), anchor: u32(), len: u16(), kind: u8(), param: u32() });
    }
    return { op, revision, items };
  }
  return { op };
}

const queue = [];
const waiters = [];
function push(frame) {
  const w = waiters.shift();
  if (w) w(frame);
  else queue.push(frame);
}
function next(timeoutMs = 5000) {
  if (queue.length) return Promise.resolve(queue.shift());
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout waiting for a frame')), timeoutMs);
    waiters.push((f) => { clearTimeout(timer); resolve(f); });
  });
}
async function scan(op, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const left = deadline - Date.now();
    if (left <= 0) throw new Error(`timeout waiting for op 0x${op.toString(16)}`);
    const f = await next(left);
    if (f.op === op) return f;
  }
}

async function scanWarning(kind, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const left = deadline - Date.now();
    if (left <= 0) throw new Error(`timeout waiting for warning kind ${kind}`);
    const f = await next(left);
    if (f.op === 0x82 && f.kind === kind) return f;
  }
}

async function scanClear(id, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const left = deadline - Date.now();
    if (left <= 0) throw new Error(`timeout waiting for clear of #${id}`);
    const f = await next(left);
    if (f.op === 0x83 && f.id === id) return f;
  }
}

function insert(seq, offset, words) {
  const w = new W().u8(0x01).u64(seq).u32(offset).u16(words.length);
  for (const word of words) {
    const bytes = new TextEncoder().encode(word);
    w.u16(bytes.length).u8(/^[A-Za-z0-9_]+$/.test(word) ? 1 : 2).raw(bytes);
  }
  return w.done();
}

function constraint(seq, start, len, kind, param) {
  return new W().u8(0x06).u64(seq).u32(start).u16(len).u8(kind).u32(param).done();
}

function toggle(seq, reactor, on) {
  return new W().u8(0x07).u64(seq).u8(reactor).u8(on ? 1 : 0).done();
}

function resync(seq) {
  return new W().u8(0x08).u64(seq).done();
}

function assert(ok, message) {
  if (!ok) throw new Error(message);
}

async function main() {
  const index = await fetch(`${BASE}/`);
  assert(index.ok, `GET / -> ${index.status}`);
  const html = await index.text();
  assert(html.includes('token loom'), 'index page is not the loom page');
  const health = await fetch(`${BASE}/health`);
  assert((await health.text()).trim() === 'ok', 'health is not ok');
  const js = await fetch(`${BASE}/loom.js`);
  assert(js.ok, `GET /loom.js -> ${js.status}`);
  console.log(`http: / + /loom.js + /health ok (${html.length} bytes of html)`);

  const ws = new WebSocket(`ws://127.0.0.1:${PORT}/ws`);
  ws.binaryType = 'arraybuffer';
  const opened = new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = () => reject(new Error('websocket failed to open'));
  });
  ws.onmessage = (ev) => push(decode(new Uint8Array(ev.data)));
  await opened;

  let seq = 1;
  const send = (bytes) => ws.send(bytes);

  const snap = await next();
  assert(snap.op === 0x84, `first frame should be SNAPSHOT, got 0x${snap.op.toString(16)}`);
  assert(snap.tokens.length > 0, 'snapshot has no tokens');
  console.log(`snapshot: rev ${snap.revision}, ${snap.tokens.length} tokens`);

  send(insert(seq++, 0, ['ripple']));
  const ack = await scan(0x80);
  assert(ack.seq === 1, `ack for seq 1, got ${ack.seq}`);
  const diff = await scan(0x81);
  const text = diff.inserted.map((t) => t.text).join('');
  assert(text === 'ripple', `diff inserted "${text}", expected "ripple"`);
  assert(diff.start === 0, `diff start ${diff.start}`);
  console.log(`diff: rev ${diff.revision} start ${diff.start} -${diff.deleted} +${diff.inserted.length} "${text}"`);

  // A constraint over the first three tokens that permits one token: the next
  // edit inside it must make the constraint reactor speak.
  send(constraint(seq++, 0, 3, 1, 1));
  send(insert(seq++, 1, ['x']));
  const raise = await scanWarning(3);
  assert(raise.severity === 3, `severity ${raise.severity}`);
  console.log(`warning: #${raise.id} kind ${raise.kind} reactor ${raise.reactor} sev ${raise.severity} "${raise.message}"`);

  // Disabling that reactor must let the warning clear.
  send(toggle(seq++, raise.reactor, false));
  const cleared = await scanClear(raise.id);
  console.log(`clear: #${cleared.id} at rev ${cleared.revision}`);

  send(resync(seq++));
  const again = await scan(0x84);
  assert(again.tokens.length > 0, 'resync snapshot has no tokens');
  // The snapshot carries the bank, so the switch thrown above has to be in the
  // bits rather than forgotten with the socket's own copy of it.
  assert(
    (again.reactors & (1 << raise.reactor)) === 0,
    `resync snapshot has reactor ${raise.reactor} on (bank 0b${again.reactors.toString(2)})`,
  );
  console.log(
    `resync: rev ${again.revision}, ${again.tokens.length} tokens, reactors 0b${again.reactors.toString(2)}`,
  );

  // The sidebar lists the spans, and the page keeps no index of its own, so the
  // list has to ride the resync beside the tokens.
  const listed = await scan(0x86);
  const span = listed.items.find((c) => c.kind === 1 && c.len === 3);
  assert(span, `resync carried no max-tokens span (${JSON.stringify(listed.items)})`);
  console.log(
    `constraints: ${listed.items.length} listed, #${span.id} kind ${span.kind} len ${span.len} param ${span.param} @ ${span.anchor}b`,
  );

  ws.close();
  console.log('PASS');
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error(`FAIL: ${e.message}`);
    process.exit(1);
  },
);
