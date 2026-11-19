'use strict';
const $ = (id) => document.getElementById(id);
let tasks = [], sel = null, es = null;

// --- fuzzy: subsequence match, tighter + earlier = better --------------------
function score(q, s) {
  let i = 0, sc = 0, last = -1;
  for (const c of q) {
    const j = s.indexOf(c, i);
    if (j < 0) return -1;
    sc += j - last > 1 ? j - last : 0;
    i = j + 1;
    last = j;
  }
  return sc + s.length * 0.02;
}

function render() {
  const q = $('q').value.trim().toLowerCase();
  let list;
  if (!q) {
    list = tasks.slice(0, 80);
  } else {
    list = tasks
      .map(t => {
        const ns = score(q, t.name);
        const ds = score(q, t.desc);
        const s = ns >= 0 ? ns : ds >= 0 ? ds + 40 : -1;
        return [s, t];
      })
      .filter(x => x[0] >= 0)
      .sort((a, b) => a[0] - b[0])
      .slice(0, 80)
      .map(x => x[1]);
  }
  let html = '', ns = '';
  for (const t of list) {
    const g = t.name.split(':')[0];
    if (g !== ns) { ns = g; html += `<div class="ns">${g}</div>`; }
    const cls = sel === t.name ? 't sel' : 't';
    html += `<div class="${cls}" data-n="${t.name}"><b>${t.name}</b><span>${esc(t.desc)}</span></div>`;
  }
  $('tasks').innerHTML = html || '<div class="ns">no match</div>';
  for (const el of document.querySelectorAll('.t')) {
    el.onclick = () => pick(el.dataset.n);
  }
}

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function pick(name) {
  sel = name;
  $('selname').textContent = name;
  $('go').disabled = false;
  render();
}

// --- runs ------------------------------------------------------------------
function attach(id, label) {
  if (es) es.close();
  $('out').textContent = '';
  $('outtitle').textContent = label || 'output';
  es = new EventSource('/api/runs/' + id + '/events');
  es.onmessage = (e) => {
    $('out').textContent += JSON.parse(e.data);
    $('out').scrollTop = $('out').scrollHeight;
  };
  es.addEventListener('done', (e) => {
    const ex = JSON.parse(e.data).exit;
    $('out').textContent += `\n── exit ${ex} ──\n`;
    es.close();
    pollRuns();
  });
  es.onerror = () => {};
}

async function launch(path, body) {
  const r = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const j = await r.json();
  if (j.id) attach(j.id, body.task ? 'task ' + body.task : '$ ' + body.cmd);
  else $('out').textContent = 'error: ' + (j.error || r.status);
}

$('go').onclick = () => {
  if (!sel) return;
  const args = $('vars').value.trim().split(/\s+/).filter(Boolean);
  launch('/api/run', { task: sel, args });
};
$('shellbtn').onclick = () => $('shellbox').classList.toggle('hidden');
$('shellgo').onclick = () => {
  const c = $('shellcmd').value.trim();
  if (c) launch('/api/shell', { cmd: c });
};
$('shellcmd').addEventListener('keydown', e => { if (e.key === 'Enter') $('shellgo').click(); });
$('q').addEventListener('keydown', e => { if (e.key === 'Enter' && sel) $('go').click(); });
$('q').oninput = render;

async function pollRuns() {
  try {
    const j = await (await fetch('/api/runs')).json();
    $('runs').innerHTML = (j.runs || []).map(r => {
      const cls = r.done ? (r.exit === 0 ? 'ok' : 'bad') : 'run';
      const st = r.done ? 'exit ' + r.exit : 'running';
      return `<li data-id="${r.id}" data-cmd="${esc(r.cmd)}"><span class="${cls}">${st}</span><span class="cmd">${esc(r.cmd)}</span></li>`;
    }).join('') || '<li class="rc">none yet</li>';
    for (const el of document.querySelectorAll('#runs li[data-id]')) {
      el.onclick = () => attach(el.dataset.id, el.dataset.cmd);
    }
  } catch {}
}

async function pollDash() {
  try {
    const d = await (await fetch('/api/dash')).json();
    const st = d.state || '?';
    const cls = st === 'running' ? 'ok' : st === 'degraded' ? 'bad' : 'warn';
    const memPct = d.memTotal ? Math.round(100 * (1 - d.memAvail / d.memTotal)) : 0;
    const load = (d.load || []).slice(0, 3).join(' ');
    const up = d.uptime ? Math.round(d.uptime / 3600) + 'h' : '?';
    const gen = d.generation ? rel(d.generation) : '?';
    $('health').innerHTML =
      `<span class="badge ${cls}">${esc(st)}</span>` +
      `<span class="badge dim">load ${esc(load)}</span>` +
      `<span class="badge ${memPct > 90 ? 'bad' : memPct > 75 ? 'warn' : 'dim'}">mem ${memPct}%</span>` +
      `<span class="badge ${d.diskRoot > 90 ? 'bad' : d.diskRoot > 80 ? 'warn' : 'dim'}">disk ${Math.round(d.diskRoot)}%</span>` +
      `<span class="badge dim">gen ${esc(gen)}</span>` +
      `<span class="badge dim">up ${esc(up)}</span>`;
    $('lanesbody').textContent = d.lanes || 'no tmux lanes';
  } catch {}
}

function rel(iso) {
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 3600) return Math.round(s / 60) + 'm';
  if (s < 86400) return Math.round(s / 3600) + 'h';
  return Math.round(s / 86400) + 'd';
}

fetch('/api/tasks')
  .then(r => r.json())
  .then(j => { tasks = (j.tasks || []).map(t => ({ name: t.name, desc: t.desc || '' })); render(); })
  .catch(() => { $('tasks').innerHTML = '<div class="ns">task catalog failed</div>'; });

pollRuns();
pollDash();
setInterval(pollRuns, 4000);
setInterval(pollDash, 10000);
