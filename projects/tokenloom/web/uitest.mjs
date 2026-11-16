#!/usr/bin/env node
// Exercise the real page in headless chromium over the DevTools protocol.
//
// The rope view is virtualized and click-driven, so this checks what a
// screenshot cannot: selection, the diff lane, a warning raised by an edit, the
// reactor switch clearing it, and scrolling into a later window of the rope.
//
// usage: node web/uitest.mjs [http://127.0.0.1:8787/] [--shot out.png]
// env:   CDP_PORT (9222), NODE_PATH must resolve `ws`

import WebSocket from 'ws';
import { writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const base = args.find((a) => a.startsWith('http')) || 'http://127.0.0.1:8787/';
const shotIdx = args.indexOf('--shot');
const shot = shotIdx >= 0 ? args[shotIdx + 1] : null;
const cdpPort = Number(process.env.CDP_PORT || 9222);

const fail = (msg) => {
  console.error(`FAIL ${msg}`);
  process.exit(1);
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
    if (msg.error) reject(new Error(`${msg.error.message} (${JSON.stringify(msg.error.data ?? '')})`));
    else resolve(msg.result);
    return;
  }
  if (msg.method === 'Runtime.exceptionThrown') {
    pageErrors.push(msg.params.exceptionDetails?.exception?.description || msg.params.exceptionDetails?.text || 'exception');
  }
  if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') {
    pageErrors.push(msg.params.args.map((a) => a.value ?? a.description ?? '').join(' '));
  }
});

const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => {
      if (pending.delete(id)) reject(new Error(`${method} timed out`));
    }, 20000);
  });

const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (r.exceptionDetails) {
    fail(`evaluate threw: ${r.exceptionDetails.exception?.description || r.exceptionDetails.text}\n  ${expression.slice(0, 160)}`);
  }
  return r.result.value;
};

const frame = () => evaluate('new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => r(1))))');

async function waitFor(what, expr, timeoutMs = 8000) {
  const started = Date.now();
  const deadline = started + timeoutMs;
  while (Date.now() < deadline) {
    const v = await evaluate(expr);
    if (v) return v;
    await sleep(60);
  }
  fail(`timed out after ${timeoutMs}ms waiting for ${what}`);
}

const step = (msg) => console.log(`  ok   ${msg}`);

await new Promise((resolve, reject) => {
  ws.once('open', resolve);
  ws.once('error', reject);
});
await send('Page.enable');
await send('Runtime.enable');
await send('Page.navigate', { url: base });

await waitFor('the socket to report live', "document.querySelector('#conn')?.textContent === 'live'");
step('websocket connected, pill reads live');

const rows = await evaluate("document.querySelectorAll('.row').length");
const chips = await evaluate("document.querySelectorAll('.chip').length");
if (chips < 16) fail(`rope view rendered ${chips} chips in ${rows} rows`);
const rev0 = await evaluate("document.querySelector('#rev').textContent");
if (rev0 !== 'rev 0') fail(`expected rev 0 before any edit, got ${rev0}`);
step(`rope view rendered ${chips} chips over ${rows} rows at ${rev0}`);

// Selection: click a chip, then shift-click a later one. The view redraws on a
// frame, so each read waits for one.
await evaluate(
  "[...document.querySelectorAll('.chip')][0].dispatchEvent(new MouseEvent('click', { bubbles: true }))",
);
await frame();
const selOne = await evaluate("document.querySelector('#sel').textContent");
if (selOne !== 'token 0') fail(`single click should select token 0, showed '${selOne}'`);
await evaluate(
  "[...document.querySelectorAll('.chip')][5].dispatchEvent(new MouseEvent('click', { bubbles: true, shiftKey: true }))",
);
await frame();
const selRange = await evaluate("document.querySelector('#sel').textContent");
if (!/tokens 0\.\.5 \(6\)/.test(selRange)) fail(`shift-click should select 0..5, showed '${selRange}'`);
step(`selection: ${selOne} then ${selRange}`);

// Insert a word at the selection.
const before = await evaluate("document.querySelectorAll('.chip').length");
await evaluate("document.querySelector('[data-act=insert]').click()");
await waitFor('rev 1 after insert', "document.querySelector('#rev').textContent === 'rev 1'");
await frame();
// The word arrives as whatever the tokenizer makes of it, so check the text the
// first chips spell, not one chip.
const head = await evaluate(
  "[...document.querySelectorAll('.chip')].slice(0, 6).map(c => (c.textContent === '·' ? ' ' : c.textContent)).join('')",
);
if (head !== 'ripple') fail(`the inserted word should start the rope, first chips spell '${head}'`);
// Read the revision and the span separately: the lane is two spans, and a
// concatenated read of "rev 1" plus offset 0 reads as "rev 10".
const diffHead = await evaluate(`(() => {
  const li = document.querySelector('#diffs li');
  if (!li) return { rev: '', body: '' };
  return {
    rev: li.querySelector('.n').textContent.trim(),
    body: li.querySelector('span:not(.n)').textContent.trim(),
  };
})()`);
if (diffHead.rev !== 'rev 1') fail(`diff lane did not record rev 1, has '${diffHead.rev}'`);
if (!/\+[1-9]/.test(diffHead.body)) fail(`diff lane entry has no inserted count: '${diffHead.body}'`);
step(`insert → ${diffHead.rev} ${diffHead.body} (chips ${before} → ${await evaluate("document.querySelectorAll('.chip').length")})`);

// The header pill reports the batch window and the starve count, so a shard
// that fell back to a keyframe is visible without reading the server's log.
const pill = await waitFor(
  'the metrics pill to report a window, starvations, the bank and the constraints',
  `(() => {
     const t = document.querySelector('#metrics').textContent;
     return /win \\d+t/.test(t) && /starved \\d+/.test(t) && t.includes('bank 6/6') && /cons \\d+/.test(t)
       ? t
       : '';
   })()`,
  4000,
);
if (!/p50 /.test(pill)) fail(`metrics pill has no latency: '${pill}'`);
if (!/cons 0/.test(pill)) fail(`no constraint is planted yet, pill shows '${pill}'`);
step(`metrics pill: ${pill}`);

// Plant a "≤ 4 tokens" constraint on the six selected tokens and then grow it.
// Other reactors have opinions about this text too, so find the warning by kind.
const findViolation = `
  (() => {
    const li = [...document.querySelectorAll('#warnings li')].find(
      (n) => n.querySelector('.kind')?.textContent === 'constraint-violation',
    );
    return li ? { cls: li.className, msg: li.querySelector('.msg').textContent } : null;
  })()
`;
await evaluate("document.querySelector('[data-constraint=max]').click()");
await evaluate("document.querySelector('[data-act=insert]').click()");
const violation = await waitFor('a constraint warning', findViolation);
if (!violation.cls.includes('sev-3')) fail(`constraint violation should be severity 3, class '${violation.cls}'`);
if (!/holds \d+ tokens/.test(violation.msg)) fail(`unexpected constraint message: '${violation.msg}'`);
step(`warning: constraint-violation [${violation.cls}] ${violation.msg}`);

// Clicking a warning jumps the rope view to the span it names.
await evaluate(`
  [...document.querySelectorAll('#warnings li')]
    .find((n) => n.querySelector('.kind')?.textContent === 'constraint-violation')
    .click()
`);
await frame();
const jumped = await evaluate("document.querySelector('#sel').textContent");
if (!/tokens \d+\.\.\d+ \(\d+\)/.test(jumped)) fail(`clicking a warning should select its span, showed '${jumped}'`);
if (jumped === 'token 0') fail(`warning selection did not move off token 0: '${jumped}'`);
step(`warning click selects its span: ${jumped}`);

// Disabling a reactor clears its own warnings — and only its own.
await evaluate("document.querySelectorAll('#reactors input')[4].click()");
await waitFor(
  'the constraint warning to clear with its reactor off',
  "[...document.querySelectorAll('#warnings li .kind')].every((n) => n.textContent !== 'constraint-violation')",
  4000,
);
step('reactor switch off → its constraint warning cleared');

// The pill is pushed on a clock as well as on a batch, so the switch thrown
// above has to reach it with no edit of ours to carry it — and the count has to
// show the span planted above even though the warning it raised has cleared.
const banked = await waitFor(
  'the clock-driven pill to show the bank minus the switched-off reactor and one constraint',
  `(() => {
     const t = document.querySelector('#metrics').textContent;
     return t.includes('bank 5/6') && t.includes('cons 1') ? t : '';
   })()`,
  4000,
);
step(`pill after the switch, no edit of ours: ${banked}`);

// The sidebar lists the spans themselves, not just their number.
const listed = await evaluate(`(() => {
  const items = [...document.querySelectorAll('#constraints li')];
  return items.map((li) => ({
    k: li.querySelector('.k')?.textContent || '',
    msg: li.querySelector('.msg')?.textContent || '',
    empty: li.classList.contains('empty'),
  }));
})()`);
if (listed.length !== 1 || listed[0].empty) fail(`constraints panel should list one span, has ${JSON.stringify(listed)}`);
if (!listed[0].k.includes('max-tokens')) fail(`constraints panel entry has the wrong kind: '${listed[0].k}'`);
if (!listed[0].msg.includes('≤ 4 tokens')) fail(`constraints panel entry has the wrong rule: '${listed[0].msg}'`);
if (!/@ \d+b/.test(listed[0].msg)) fail(`constraints panel entry has no byte anchor: '${listed[0].msg}'`);
step(`constraints panel: ${listed[0].k} ${listed[0].msg}`);

// Clicking an entry selects the tokens its anchor now covers.
await evaluate("document.querySelector('#constraints li').click()");
await frame();
const consSel = await evaluate("document.querySelector('#sel').textContent");
if (!/tokens \d+\.\.\d+ \(\d+\)/.test(consSel)) fail(`clicking a constraint should select its span, showed '${consSel}'`);
step(`constraint click selects its span: ${consSel}`);

// The span stays marked after the click, so the rule being watched and the
// chips it covers are on screen together.
const marked = await evaluate(`(() => {
  const chips = [...document.querySelectorAll('.chip.cons')];
  return {
    n: chips.length,
    first: chips.length ? Number(chips[0].dataset.i) : -1,
    on: !!document.querySelector('#constraints li.on'),
  };
})()`);
if (marked.n < 2) fail(`the clicked constraint's span should be marked in the rope, ${marked.n} chips carry .cons`);
if (!marked.on) fail('the clicked constraint should stay marked in the panel');
step(`constraint span marked in the rope: ${marked.n} chips from #${marked.first}`);

await evaluate("document.querySelectorAll('#reactors input')[4].click()");

// The server keeps the reactor bank and the snapshot frame hands it back, so a
// reload has to come up with the switch still off rather than defaulting on.
// Wait for the server, not the checkbox: the box flips locally the moment it is
// clicked, so reloading on that signal would race the batch it just sent.
const revBeforeToggle = await evaluate("document.querySelector('#rev').textContent");
await evaluate("document.querySelectorAll('#reactors input')[4].click()");
await waitFor(
  'the server to acknowledge the switch',
  `document.querySelector('#rev').textContent !== ${JSON.stringify(revBeforeToggle)} ? document.querySelector('#rev').textContent : ''`,
  4000,
);
await send('Page.reload');
await waitFor(
  'a fresh document with the rope drawn and the constraint list back',
  `document.querySelector('#diffs li')?.classList.contains('empty')
   && document.querySelectorAll('.chip').length > 16
   && document.querySelector('#constraints li .k')`,
);
await frame();
const restoredOff = await evaluate("document.querySelectorAll('#reactors input')[4].checked");
if (restoredOff !== false) fail('a reload should restore reactor 5 as off from the snapshot');
const relisted = await evaluate("document.querySelector('#constraints li .k').textContent");
if (!relisted.includes('max-tokens')) fail(`a reload should replay the constraint list, shows '${relisted}'`);
step(`reload → reactor 5 still off, constraint list back: ${relisted}`);
await evaluate("document.querySelectorAll('#reactors input')[4].click()");
await waitFor(
  'reactor 5 back on after the reload',
  "document.querySelectorAll('#reactors input')[4].checked === true",
  4000,
);

// A marked entry is retuned where it sits: same id, new rule, same count. The
// panel is the proof that the retune reached the server.
await evaluate("document.querySelector('#constraints li').click()");
await frame();
await evaluate("document.querySelector('[data-constraint=delim]').click()");
const retuned = await waitFor(
  'the marked entry to report its new rule',
  `(() => {
     const li = document.querySelector('#constraints li');
     const k = li?.querySelector('.k')?.textContent || '';
     const m = li?.querySelector('.msg')?.textContent || '';
     return k.startsWith('#0 ') && k.includes('no-crossing') ? { k, m } : null;
   })()`,
  4000,
);
if (!retuned.m.includes("no token crosses ' '")) fail(`retuned entry has the wrong rule: '${retuned.m}'`);
step(`constraint retuned in place: ${retuned.k} ${retuned.m}`);

// The panel can take a span back out again, and the removal reaches the pill on
// the same clock a plant does — no edit of ours to carry it.
await evaluate("document.querySelector('#constraints li .rm').click()");
const removedPill = await waitFor(
  'the constraint panel to empty and the pill to count zero',
  `(() => {
     const empty = document.querySelector('#constraints li')?.classList.contains('empty');
     const t = document.querySelector('#metrics').textContent;
     return empty && t.includes('cons 0') ? t : '';
   })()`,
  4000,
);
step(`constraint removed: panel empty, ${removedPill}`);

// Split, merge and delete through the buttons. Split needs a token wider than
// one byte, so pick one instead of assuming chip 2.
const ops = [];
async function clickAndWait(label, selectExpr, actName) {
  const revBefore = await evaluate("document.querySelector('#rev').textContent");
  await evaluate(selectExpr);
  await frame();
  await evaluate(`document.querySelector('[data-act=${actName}]').click()`);
  const revAfter = await waitFor(
    `${label} to land`,
    `document.querySelector('#rev').textContent !== ${JSON.stringify(revBefore)} ? document.querySelector('#rev').textContent : ''`,
    4000,
  );
  ops.push(`${label} ${revBefore}→${revAfter}`);
}

await clickAndWait(
  'split',
  `(() => {
     const c = [...document.querySelectorAll('.chip')].find((n) => n.textContent.length > 1 && n.textContent !== '·');
     c.click();
   })()`,
  'split',
);
await clickAndWait(
  'merge',
  `(() => {
     const chips = [...document.querySelectorAll('.chip')];
     chips[8].dispatchEvent(new MouseEvent('click', { bubbles: true }));
     chips[9].dispatchEvent(new MouseEvent('click', { bubbles: true, shiftKey: true }));
   })()`,
  'merge',
);
await clickAndWait('delete', "[...document.querySelectorAll('.chip')][3].click()", 'delete');
step(`tools: ${ops.join(', ')}`);

// Scroll into the middle of the rope: the window re-renders around the scroll.
// A short viewport is what makes the rope longer than the pane; at 900px tall a
// 300-token document fits and there is nothing to scroll.
await send('Emulation.setDeviceMetricsOverride', {
  width: 1000,
  height: 320,
  deviceScaleFactor: 1,
  mobile: false,
});
await sleep(200);
const scrolled = await evaluate(`
  new Promise((resolve) => {
    const scroller = document.querySelector('#scroller');
    scroller.scrollTop = 400;
    scroller.dispatchEvent(new Event('scroll'));
    requestAnimationFrame(() => requestAnimationFrame(() => {
      const first = document.querySelector('.chip');
      resolve({
        index: first ? Number(first.dataset.i) : -1,
        rows: document.querySelectorAll('.row').length,
        chips: document.querySelectorAll('.chip').length,
      });
    }));
  })
`);
if (scrolled.index < 100) fail(`scrolling to 400px should start rendering past token 100, got ${scrolled.index}`);
if (scrolled.chips > 400) fail(`virtualized view rendered ${scrolled.chips} chips, it should stay window-sized`);
step(`scroll 400px → first chip #${scrolled.index}, ${scrolled.chips} chips in ${scrolled.rows} rows`);

if (pageErrors.length) fail(`page raised errors:\n  ${pageErrors.join('\n  ')}`);
step('no page exceptions during the run');

if (shot) {
  await send('Emulation.clearDeviceMetricsOverride');
  await sleep(250);
  const png = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  writeFileSync(shot, Buffer.from(png.data, 'base64'));
  console.log(`  shot ${shot}`);
}

console.log('PASS');
ws.close();
process.exit(0);
