#!/usr/bin/env node
// What a retune costs end to end, and whether the span keeps its identity
// through it: the rule button is clicked, the op goes over the socket, the
// server retunes the span it already has and rebroadcasts the list, and the
// panel updates. The clock runs from the click to the frame that shows the new
// rule, so it covers the whole round trip rather than one layer of it.
//
// Identity is checked in the three places it could break: the id the panel
// shows, the row element itself (which a rebuild would replace), and the id the
// next plant takes (a retune that renumbered would hand out #0 twice).
//
// usage: node web/retune.mjs [http://127.0.0.1:8787/]
// env:   CDP_PORT (9222), NODE_PATH must resolve `ws`, ROUNDS (default 60)

import WebSocket from 'ws';

const base = process.argv.slice(2).find((a) => a.startsWith('http')) || 'http://127.0.0.1:8787/';
const cdpPort = Number(process.env.CDP_PORT || 9222);
const rounds = Number(process.env.ROUNDS || 60);
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

// Plant on the first tokens of whatever the session holds, so the anchor is the
// same byte the panel will report back.
await evaluate(
  "(() => { if (state.tokens.length < 8) opInsert(0, Array.from({ length: 16 }, () => 'alpha')); return 1; })()",
);
await waitFor('a rope to plant on', 'state.tokens.length >= 8');

const planted = await evaluate(`(async () => {
  opConstraint(0, 3, 1, 4);
  for (let i = 0; i < 200; i++) {
    const li = document.querySelector('#constraints li');
    if (li?.dataset?.id === '0') return { k: li.querySelector('.k').textContent, m: li.querySelector('.msg').textContent };
    await new Promise((r) => requestAnimationFrame(() => r()));
  }
  return null;
})()`);
if (!planted) fail('the plant never reached the panel');

const result = await evaluate(`(async (rounds) => {
  const liNow = () => document.querySelector('#constraints li');
  const msgNow = () => liNow()?.querySelector('.msg')?.textContent || '';
  const buttons = document.querySelectorAll('[data-constraint]');
  const max = buttons[0];
  const delim = buttons[1];
  const notes = { replacement: 0, focusedBefore: false, focusedThrough: 0, wrongId: 0 };

  liNow().click();
  if (!liNow().classList.contains('on')) return { failed: 'the row did not take the mark' };
  const first = liNow();
  first.__witness = 'kept';
  const rm = first.querySelector('.rm');
  rm.focus();
  notes.focusedBefore = document.activeElement === rm;

  // The row is repainted inside the socket handler, so the time to the new rule
  // is socket + server + decode + render; the time to a painted frame adds one
  // animation frame and is reported apart, because that is the measurement's
  // own granularity rather than the path's cost.
  const list = document.querySelector('#constraints');
  const spans = new Set();
  const samples = [];
  const origRender = window.renderConstraints;
  let renderedAt = 0;
  window.renderConstraints = function (...args) {
    renderedAt = performance.now();
    return origRender.apply(this, args);
  };
  // Frame arrivals and the mutation that shows the rule are stamped by the
  // events themselves. A polling loop here would measure its own interval, and
  // would say a 1 ms path took as long as the timer it was watching with.
  const arrivals = [];
  // A message can hold several frames: the server packs what it wrote in one
  // instant, so the ack and the list it caused share an arrival. Walk the
  // message and stamp every frame it holds, or the list would read as missing.
  const ops = (bytes) => {
    const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const seen = [];
    let at = 0;
    while (at < bytes.length) {
      const op = v.getUint8(at);
      at += 1;
      if (op === 0x80) at += 16;
      else if (op === 0x81) {
        at += 8 + 4 + 2;
        const count = v.getUint16(at, true); at += 2;
        for (let i = 0; i < count; i++) { const len = v.getUint16(at, true); at += 2 + 1 + len; }
      } else if (op === 0x84) {
        at += 9;
        const count = v.getUint32(at, true); at += 4;
        for (let i = 0; i < count; i++) { const len = v.getUint16(at, true); at += 2 + 1 + len; }
      } else if (op === 0x85) at += 29;
      else if (op === 0x86) { at += 8; const n = v.getUint32(at, true); at += 4 + n * 19; }
      else if (op === 0x82) { at += 21; const len = v.getUint16(at, true); at += 2 + len; }
      else if (op === 0x83) at += 12;
      else break;
      seen.push(op);
    }
    return seen;
  };
  const prevMessage = state.ws.onmessage;
  state.ws.onmessage = (ev) => {
    if (ev.data instanceof ArrayBuffer) {
      const t = performance.now();
      for (const op of ops(new Uint8Array(ev.data))) arrivals.push({ t, op });
    }
    prevMessage(ev);
  };
  let changedAt = 0;
  const obs = new MutationObserver(() => {
    changedAt = performance.now();
  });
  obs.observe(list, { subtree: true, childList: true, characterData: true });

  const waitRule = (want) =>
    new Promise((resolve, reject) => {
      const deadline = performance.now() + 5000;
      const tick = () => {
        if (msgNow().includes(want)) {
          clearInterval(poll);
          resolve(changedAt || performance.now());
        } else if (performance.now() > deadline) {
          clearInterval(poll);
          reject(new Error('the retune never showed: want ' + want + ', have ' + msgNow()));
        }
      };
      const poll = setInterval(tick, 4);
      tick();
    });

  let trace = null;
  for (let i = 0; i < rounds; i++) {
    const toDelim = i % 2 === 0;
    const button = toDelim ? delim : max;
    const want = toDelim ? "no token crosses ' '" : '≤ 4 tokens';
    renderedAt = 0;
    changedAt = 0;
    arrivals.length = 0;
    const t0 = performance.now();
    button.click();
    const sent = performance.now() - t0;
    let dom;
    try {
      dom = await waitRule(want);
    } catch (e) {
      return { failed: e.message };
    }
    const at = (op) => arrivals.find((a) => a.op === op)?.t ?? 0;
    const sample = {
      sent,
      ack: at(FRAME.ACK) ? at(FRAME.ACK) - t0 : 0,
      cons: at(FRAME.CONSTRAINTS) ? at(FRAME.CONSTRAINTS) - t0 : 0,
      rendered: renderedAt ? renderedAt - t0 : 0,
      dom: dom - t0,
    };
    await new Promise((r) => requestAnimationFrame(() => r()));
    sample.painted = performance.now() - t0;
    samples.push(sample);
    if (i === 0) trace = arrivals.map((a) => a.op + '@' + (a.t - t0).toFixed(1));

    const li = liNow();
    if (li !== first) notes.replacement++;
    if (li.querySelector('.k').textContent.split(' ')[0] !== '#0') notes.wrongId++;
    if (document.activeElement === rm) notes.focusedThrough++;
    spans.add(li.querySelector('.msg').textContent.split(' · ')[1]);
  }

  state.ws.onmessage = prevMessage;
  obs.disconnect();
  window.renderConstraints = origRender;

  // A retune that renumbered would hand the next plant the id it just used.
  opConstraint(4, 2, 1, 4);
  for (let i = 0; i < 200; i++) {
    if (document.querySelectorAll('#constraints li').length === 2) break;
    await new Promise((r) => requestAnimationFrame(() => r()));
  }
  const ids = [...document.querySelectorAll('#constraints li')].map((li) => li.dataset.id);
  return {
    samples,
    trace,
    witness: first.__witness || 'lost',
    focusHeld: document.activeElement === rm,
    rows: document.querySelectorAll('#constraints li').length,
    ids,
    count: document.querySelector('#consCount').textContent,
    spans: [...spans],
    notes,
  };
})(${rounds})`);

if (result.failed) fail(result.failed);
if (result.witness !== 'kept') fail('the row was replaced: the retune rebuilt the list instead of updating it');
if (result.notes.replacement) fail(`${result.notes.replacement} retune(s) replaced the row element`);
if (result.notes.wrongId) fail(`${result.notes.wrongId} retune(s) changed the id the panel shows`);
if (result.spans.length !== 1) fail(`the span moved while it was retuned: ${result.spans.join(', ')}`);
if (result.count !== '2') fail(`the count is '${result.count}' where two spans are planted`);
if (result.ids.join(',') !== '0,1') fail(`the next plant took id ${result.ids.join(',')}, not 0,1`);

const pct = (pick) => {
  const s = result.samples.map(pick).sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.round((s.length - 1) * q))];
  return { p50: at(0.5), p99: at(0.99), max: s[s.length - 1] };
};
const show = (x) => `p50 ${x.p50.toFixed(2)} ms · p99 ${x.p99.toFixed(2)} ms · max ${x.max.toFixed(2)} ms`;

console.log(`planted: #0 ${planted.k.replace(/^#0 /, '')} · ${planted.m}`);
const step = (label, key) => console.log(`${label} ${show(pct((s) => s[key]))}`);
console.log(`retune, ${rounds} rounds, each step timed from the click:`);
step('  op on the wire                            ', 'sent');
step('  ack back from the server                 ', 'ack');
step('  list frame with the new rule             ', 'cons');
step('  row repainted                            ', 'rendered');
step('  panel shows the rule                     ', 'dom');
step('  one painted frame later                  ', 'painted');
console.log(`span across every retune: ${result.spans[0]} (anchor and length unchanged)`);
console.log(
  `identity: row element kept in ${rounds - result.notes.replacement}/${rounds}, id unchanged in ${rounds - result.notes.wrongId}/${rounds}, focus held in ${result.notes.focusedThrough}/${rounds}`,
);
console.log(`next plant took ids ${result.ids.join(', ')} — a retune renumbers nothing`);
if (process.env.TRACE && result.trace) console.log(`round 0 frames: ${result.trace.join(' · ')}`);
if (pageErrors.length) fail(`page raised errors:\n  ${pageErrors.join('\n  ')}`);
console.log('PASS');
ws.close();
process.exit(0);
