#!/usr/bin/env node
// What marking a constraint costs the rope view, measured on a ten-thousand-token
// page: the body of `drawRope` on the frame it was scheduled for, unmarked
// against marked, at the top of the rope and in the middle, plus the per-diff
// shift the list costs once a span is marked.
//
// usage: node web/redraw.mjs [http://127.0.0.1:8787/]
// env:   CDP_PORT (9222), NODE_PATH must resolve `ws`

import WebSocket from 'ws';

const base = process.argv.slice(2).find((a) => a.startsWith('http')) || 'http://127.0.0.1:8787/';
const cdpPort = Number(process.env.CDP_PORT || 9222);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const fail = (msg) => {
  console.error(`FAIL ${msg}`);
  process.exit(1);
};

async function pageTarget() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${cdpPort}/json/list`);
      const list = await res.json();
      const page = list.find((t) => t.type === 'page');
      if (page && page.webSocketDebuggerUrl) return page;
    } catch {}
    await sleep(250);
  }
  fail(`no page target on 127.0.0.1:${cdpPort}`);
}

const target = await pageTarget();
const ws = new WebSocket(target.webSocketDebuggerUrl, {
  perMessageDeflate: false,
  maxPayload: 64 * 1024 * 1024,
});

let nextId = 1;
const pending = new Map();
const pageErrors = [];

ws.on('message', (raw) => {
  const msg = JSON.parse(raw.toString());
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(msg.error.message));
    else resolve(msg.result);
    return;
  }
  if (msg.method === 'Runtime.exceptionThrown') {
    pageErrors.push(
      msg.params.exceptionDetails?.exception?.description || msg.params.exceptionDetails?.text || 'exception',
    );
  }
});

const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => {
      if (pending.delete(id)) reject(new Error(`${method} timed out`));
    }, 60000);
  });

const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) {
    fail(`evaluate threw: ${r.exceptionDetails.exception?.description || r.exceptionDetails.text}`);
  }
  return r.result.value;
};

async function waitFor(what, expr, timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const v = await evaluate(expr);
    if (v) return v;
    await sleep(60);
  }
  fail(`timed out after ${timeoutMs}ms waiting for ${what}`);
}

await new Promise((resolve, reject) => {
  ws.once('open', resolve);
  ws.once('error', reject);
});
await send('Page.enable');
await send('Runtime.enable');
await send('Page.navigate', { url: base });
await waitFor('the socket to report live', "document.querySelector('#conn')?.textContent === 'live'");

// Ten thousand words in one op. They tokenize to a real rope, and the page takes
// the diff and shifts its anchors exactly as it does for any other edit.
await evaluate(
  "(() => { opInsert(state.tokens.length, Array.from({ length: 10000 }, () => 'alpha')); return 1; })()",
);
const tokens = await waitFor(
  'the rope to pass ten thousand tokens',
  'state.tokens.length >= 10000 ? state.tokens.length : 0',
);

const pct = (samples) => {
  const s = [...samples].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.round((s.length - 1) * q))];
  return { p50: at(0.5), p99: at(0.99), max: s[s.length - 1] };
};
const show = (r) => `p50 ${r.p50.toFixed(3)} ms · p99 ${r.p99.toFixed(3)} ms · max ${r.max.toFixed(3)} ms`;

// What a diff costs the list once it is full: the index caps at 256 spans, and
// each one is a comparison against the edit.
const shiftUs = await evaluate(`(() => {
  const keep = state.constraints;
  state.constraints = Array.from({ length: 256 }, (_, i) => ({
    id: i, anchor: 0, token: i, len: 4, kind: 1, param: 4,
  }));
  shiftConstraints(0, 0, 0);
  const t0 = performance.now();
  for (let i = 0; i < 2000; i++) shiftConstraints(0, 1, 1);
  const us = ((performance.now() - t0) * 1000) / 2000;
  state.constraints = keep;
  return us;
})()`);

// The mark is page state here rather than a server plant: what is being timed is
// the draw, and a span over the whole rope is the widest it can be.
await evaluate(`(() => {
  state.constraints = [{ id: 0, anchor: 0, token: 0, len: ${tokens}, kind: 1, param: 4 }];
  state.consSel = null;
  renderConstraints();
  return 1;
})()`);

const rows = Math.ceil(tokens / 16);
async function phase(marked, scrollTop, n = 200) {
  return evaluate(`(async (n) => {
    state.consSel = ${marked ? 0 : null};
    document.querySelector('#scroller').scrollTop = ${scrollTop};
    drawRope();
    await new Promise((r) => requestAnimationFrame(() => r()));
    const samples = [];
    const realRaf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (cb) => realRaf((ts) => {
      const t0 = performance.now();
      cb(ts);
      samples.push(performance.now() - t0);
    });
    const tick = () => new Promise((r) => realRaf(() => r()));
    for (let i = 0; i < n; i++) {
      drawRope();
      await tick();
    }
    window.requestAnimationFrame = realRaf;
    return {
      samples,
      chips: document.querySelectorAll('.chip').length,
      marked: document.querySelectorAll('.chip.cons').length,
      rows: document.querySelectorAll('.row').length,
    };
  })(${n})`);
}

const mid = Math.round((rows / 2) * 26);
const topPlain = await phase(false, 0);
const topMarked = await phase(true, 0);
const midPlain = await phase(false, mid);
const midMarked = await phase(true, mid);

if (topPlain.marked !== 0 || midPlain.marked !== 0) fail('an unmarked phase still marked chips');
if (topMarked.marked < 1 || midMarked.marked < 1) {
  fail('the marked phases marked no chips, so they would measure nothing');
}

console.log(`rope: ${tokens} tokens · ${topPlain.rows} rows rendered · ${topPlain.chips} chips visible`);
console.log(`diff shift over 256 spans: ${shiftUs.toFixed(2)} µs per edit`);
console.log(`drawRope unmarked @top: ${show(pct(topPlain.samples))}`);
console.log(`drawRope marked   @top: ${show(pct(topMarked.samples))} · ${topMarked.marked} chips marked`);
console.log(`drawRope unmarked @mid: ${show(pct(midPlain.samples))}`);
console.log(`drawRope marked   @mid: ${show(pct(midMarked.samples))} · ${midMarked.marked} chips marked`);

if (pageErrors.length) fail(`page raised errors:\n  ${pageErrors.join('\n  ')}`);
console.log('PASS');
ws.close();
process.exit(0);
