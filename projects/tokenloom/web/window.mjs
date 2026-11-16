// What the coalescing window costs an edit, and what it buys a burst — and the
// gate for the end-to-end target.
//
// One keystroke and a machine-speed burst are different loads: the first wants
// the window as short as it can be, the second is the reason the window exists.
// This script times both against the same server and fails when a single edit's
// p99 misses the target, so the number in the README is checked rather than
// remembered. The ack itself waits for the batch — the window is on the wire
// before the first frame — so the diff cannot be timed apart from it.
//
//   node web/window.mjs http://127.0.0.1:8787/
//
// env: WINDOW (label, ms), LOOM_PORT, N (60 single edits), BURST (10 ops sent in
// one turn), ROUNDS (10 bursts), KEYS (20 edits at TYPING_GAP ms apart),
// TARGET_MS (5 — the single-edit p99 the build promises)

if (typeof WebSocket === 'undefined') {
  console.error('node has no global WebSocket; cannot time the wire');
  process.exit(2);
}

const PORT = process.env.LOOM_PORT || 8787;
const BASE = (process.argv.slice(2).find((a) => a.startsWith('http')) || `http://127.0.0.1:${PORT}`).replace(
  /\/+$/,
  '',
);
const WINDOW = process.env.WINDOW || '?';
const N = Number(process.env.N || 60);
const BURST = Number(process.env.BURST || 10);
const ROUNDS = Number(process.env.ROUNDS || 10);
const KEYS = Number(process.env.KEYS || 20);
const TYPING_GAP = Number(process.env.TYPING_GAP || 100);
const SPREAD_MS = Number(process.env.SPREAD_MS || 4);
const TARGET_MS = Number(process.env.TARGET_MS || 5);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// setTimeout's floor is about a millisecond, which is coarser than the gaps
// between ops in a spread burst; a spin is what can actually hold the cadence.
const spin = (ms) => {
  const end = performance.now() + ms;
  while (performance.now() < end) {}
};

class W {
  constructor(cap = 64) {
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

// One frame at the head of the message, with the bytes it used: the server packs
// the frames it wrote in the same instant, so a message can hold several.
function decodeAt(bytes) {
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const p = { at: 0 };
  const u8 = () => { const x = v.getUint8(p.at); p.at += 1; return x; };
  const u16 = () => { const x = v.getUint16(p.at, true); p.at += 2; return x; };
  const u32 = () => { const x = v.getUint32(p.at, true); p.at += 4; return x; };
  const u64 = () => { const x = Number(v.getBigUint64(p.at, true)); p.at += 8; return x; };
  const op = u8();
  if (op === 0x80) return [{ op, seq: u64(), revision: u64() }, p.at];
  if (op === 0x81) {
    const revision = u64(), start = u32(), deleted = u16(), count = u16();
    for (let i = 0; i < count; i++) { const len = u16(); u8(); p.at += len; }
    return [{ op, revision, start, deleted, count }, p.at];
  }
  if (op === 0x84) {
    const revision = u64(), reactors = u8(), count = u32();
    for (let i = 0; i < count; i++) { const len = u16(); u8(); p.at += len; }
    return [{ op, revision, reactors, tokens: count }, p.at];
  }
  // metrics: six u32, a reactor bitfield, a constraint count
  if (op === 0x85) { p.at += 6 * 4 + 1 + 4; return [{ op }, p.at]; }
  if (op === 0x86) { u64(); const n = u32(); p.at += n * 19; return [{ op }, p.at]; }
  // raise: id, kind, reactor, severity, start, len, revision, then the message
  if (op === 0x82) { p.at += 4 + 1 + 1 + 1 + 4 + 2 + 8; const len = u16(); p.at += len; return [{ op }, p.at]; }
  if (op === 0x83) { p.at += 4 + 8; return [{ op }, p.at]; }
  throw new Error(`unknown frame opcode 0x${op.toString(16)}`);
}

function decodeAll(bytes) {
  const out = [];
  let at = 0;
  while (at < bytes.length) {
    const [frame, used] = decodeAt(bytes.subarray(at));
    out.push(frame);
    at += used;
  }
  return out;
}

function insert(seq, offset, words) {
  const w = new W().u8(0x01).u64(seq).u32(offset).u16(words.length);
  for (const word of words) {
    const bytes = new TextEncoder().encode(word);
    w.u16(bytes.length).u8(1).raw(bytes);
  }
  return w.done();
}

const ws = new WebSocket(`ws://127.0.0.1:${PORT}/ws`);
ws.binaryType = 'arraybuffer';
const opened = new Promise((resolve, reject) => {
  ws.onopen = resolve;
  ws.onerror = () => reject(new Error('websocket failed to open'));
});

// Every frame is stamped when its event fires; the waits below only pick the
// stamp up. A timer would measure its own interval instead of the path. Frames
// packed into one message share the event's stamp, which is the point: they
// arrived together.
const arrivals = [];
let diffsSeen = 0;
let maxPacked = 0;
ws.onmessage = (ev) => {
  const t = performance.now();
  const frames = decodeAll(new Uint8Array(ev.data));
  maxPacked = Math.max(maxPacked, frames.length);
  for (const f of frames) {
    f.t = t;
    if (f.op === 0x81) diffsSeen += 1;
    arrivals.push(f);
  }
};

const take = async (pred, timeoutMs = 5000) => {
  const deadline = performance.now() + timeoutMs;
  for (;;) {
    const i = arrivals.findIndex(pred);
    if (i >= 0) return arrivals.splice(i, 1)[0];
    if (performance.now() > deadline) throw new Error('timeout waiting for a frame');
    await sleep(1);
  }
};

const quiet = async (ms = 60) => {
  let seen = diffsSeen;
  let stamp = performance.now();
  for (;;) {
    await sleep(5);
    if (diffsSeen !== seen) {
      seen = diffsSeen;
      stamp = performance.now();
    } else if (performance.now() - stamp > ms) {
      return;
    }
  }
};

async function main() {
  const health = await fetch(`${BASE}/health`);
  if ((await health.text()).trim() !== 'ok') throw new Error('health is not ok');
  await opened;
  const snap = await take((f) => f.op === 0x84);
  let at = snap.tokens;
  let seq = 1;

  const single = [];
  let shared = 0;
  for (let i = 0; i < N; i++) {
    const t0 = performance.now();
    const mine = seq++;
    ws.send(insert(mine, at++, ['z']));
    const ack = await take((f) => f.op === 0x80 && f.seq === mine);
    const diff = await take((f) => f.op === 0x81);
    if (ack.t === diff.t) shared += 1;
    single.push({ ack: ack.t - t0, diff: diff.t - t0 });
  }

  const merged = [];
  for (let r = 0; r < ROUNDS; r++) {
    const before = diffsSeen;
    for (let i = 0; i < BURST; i++) ws.send(insert(seq++, at++, ['z']));
    await quiet();
    const batches = diffsSeen - before;
    merged.push(batches ? BURST / batches : BURST);
  }

  const spread = [];
  for (let r = 0; r < ROUNDS; r++) {
    const before = diffsSeen;
    for (let i = 0; i < BURST; i++) {
      ws.send(insert(seq++, at++, ['z']));
      if (i + 1 < BURST) spin(SPREAD_MS / BURST);
    }
    await quiet();
    const batches = diffsSeen - before;
    spread.push(batches ? BURST / batches : BURST);
  }

  const typingBefore = diffsSeen;
  for (let i = 0; i < KEYS; i++) {
    ws.send(insert(seq++, at++, ['z']));
    if (i + 1 < KEYS) await sleep(TYPING_GAP);
  }
  await quiet();
  const typedBatches = diffsSeen - typingBefore;

  const pct = (pick) => {
    const s = single.map(pick).sort((a, b) => a - b);
    const at = (q) => s[Math.min(s.length - 1, Math.round((s.length - 1) * q))];
    return { p50: at(0.5), p99: at(0.99), max: s[s.length - 1] };
  };
  const show = (x) => `p50 ${x.p50.toFixed(2)} · p99 ${x.p99.toFixed(2)} · max ${x.max.toFixed(2)} ms`;
  const perBatch = merged.reduce((a, b) => a + b, 0) / merged.length;
  const ack = pct((s) => s.ack);
  const diff = pct((s) => s.diff);

  console.log(`window ${WINDOW} ms`);
  console.log(`  single edit → ack    ${show(ack)}`);
  console.log(`  single edit → diff   ${show(diff)}  (n=${N})`);
  console.log(
    `  burst of ${BURST} in one turn: ${(BURST / perBatch).toFixed(2)} batches → ${perBatch.toFixed(1)} ops merged per batch (n=${ROUNDS})`,
  );
  const spreadPerBatch = spread.reduce((a, b) => a + b, 0) / spread.length;
  console.log(
    `  burst of ${BURST} spread over ~${SPREAD_MS} ms: ${(BURST / spreadPerBatch).toFixed(2)} batches → ${spreadPerBatch.toFixed(1)} ops merged per batch`,
  );
  console.log(
    `  ${KEYS} edits ${TYPING_GAP} ms apart: ${typedBatches} batches — a keystroke cadence merges ${KEYS - typedBatches}`,
  );
  console.log(`  frames per message: max ${maxPacked}`);
  ws.close();

  const ok = diff.p99 <= TARGET_MS;
  console.log(
    `edit → diff p99 ${diff.p99.toFixed(2)} ms vs target ${TARGET_MS.toFixed(2)} ms: ${ok ? 'PASS' : 'FAIL'}`,
  );
  console.log(`  the diff shared the ack's message in ${shared}/${N} edits`);
  if (!ok) {
    console.error(`FAIL: single-edit p99 is ${diff.p99.toFixed(2)} ms, over the ${TARGET_MS} ms target`);
    process.exit(1);
  }
  console.log('PASS');
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error(`FAIL: ${e.message}`);
    process.exit(1);
  },
);
