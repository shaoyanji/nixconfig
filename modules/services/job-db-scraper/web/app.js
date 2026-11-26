const state = { q: '', source: '', location: '', company: '', companyLabel: '', lane: '', days: 7, remote: false, sort: 'latest', offset: 0, limit: 20, total: 0 };
const $ = (sel) => document.querySelector(sel);

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function fmtDate(value) {
  if (!value) return 'undated';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}
function age(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const hours = Math.max(0, Math.floor((Date.now() - d.getTime()) / 3600000));
  if (hours < 1) return 'just now';
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}
async function api(path, options) {
  const res = await fetch(path, options);
  if (!res.ok) {
    let message = `${res.status} ${res.statusText}`;
    try { message = (await res.json()).error || message; } catch {}
    throw new Error(message);
  }
  return res.json();
}
function params() {
  const p = new URLSearchParams();
  if (state.q) p.set('q', state.q);
  if (state.source) p.set('source', state.source);
  if (state.location) p.set('location', state.location);
  if (state.company) p.set('company', state.company);
  if (state.lane) p.set('lane', state.lane);
  if (state.days) p.set('days', state.days);
  if (state.remote) p.set('remote', '1');
  if (state.sort === 'score') p.set('sort', 'score');
  p.set('limit', state.limit);
  p.set('offset', state.offset);
  return p;
}
async function loadStats() {
  const stats = await api('/api/stats');
  $('#metric-jobs').textContent = stats.active_postings ?? 0;
  $('#metric-companies').textContent = stats.companies ?? 0;
  $('#metric-remote').textContent = stats.remote ?? 0;
  $('#metric-fresh').textContent = stats.last_7_days ?? 0;
}
function barRows(rows, value, detail, attribute) {
  if (!rows.length) return '<div class="empty">nothing indexed</div>';
  const max = Math.max(1, ...rows.map(value));
  return rows.map((row) => {
    const selected = attribute === 'data-company' ? state.company === row.key : attribute === 'data-lane' ? state.lane === row.name : false;
    const attrs = attribute === 'data-company'
      ? `data-company="${esc(row.key)}" data-label="${esc(row.name)}"`
      : attribute === 'data-lane' ? `data-lane="${esc(row.name)}"` : '';
    const tag = attribute ? 'button' : 'div';
    return `<${tag} class="bar-row${attribute ? ' clickable' : ''}${selected ? ' active' : ''}" ${attrs} type="button"><span><b>${esc(row.name)}</b><em>${esc(detail(row))}</em></span><span class="bar"><i style="width:${Math.max(4, value(row) / max * 100)}%"></i></span></${tag}>`;
  }).join('');
}
function bandRows(bands) {
  const max = Math.max(1, ...bands.map((band) => band.count));
  return bands.map((band) => `<div class="band-row"><span class="band-label">${band.band}</span><span class="bar"><i style="width:${Math.max(2, band.count / max * 100)}%"></i></span><em>${band.count}</em></div>`).join('');
}
async function loadAnalytics() {
  const report = await api('/api/analytics?limit=8');
  $('#analytics-scope').textContent = `${report.active} active · ⌀ score ${report.avg_score} · ${report.remote} remote · ${report.unscored} unscored`;
  $('#analytics-companies').innerHTML = barRows(report.companies || [], (row) => row.postings, (row) => `${row.postings} · ⌀ ${row.avg_score}`, 'data-company');
  $('#analytics-lanes').innerHTML = barRows(report.lanes || [], (row) => row.postings, (row) => `${row.postings} active · max ${row.max_score}`, 'data-lane');
  $('#analytics-locations').innerHTML = barRows(report.locations || [], (row) => row.count, (row) => `${row.count}`);
  $('#analytics-sources').innerHTML = barRows(report.sources || [], (row) => row.count, (row) => `${row.count}`);
  $('#analytics-bands').innerHTML = bandRows(report.score_bands || []);
  const chips = [
    state.company && `<button class="chip clear" type="button" data-clear="company">company: ${esc(state.companyLabel || state.company)} ✕</button>`,
    state.lane && `<button class="chip clear" type="button" data-clear="lane">lane: ${esc(state.lane)} ✕</button>`,
  ].filter(Boolean).join('');
  $('#analytics-filters').innerHTML = chips || '<span class="muted">click a company or a lane to filter the list</span>';
}
async function loadSources() {
  const payload = await api('/api/sources');
  const states = payload.states || [];
  const select = $('#source');
  const existing = select.value;
  select.innerHTML = '<option value="">all sources</option>' + (payload.configured || []).map((s) => `<option value="${esc(s)}">${esc(s)}</option>`).join('');
  select.value = existing;
  $('#source-list').innerHTML = states.map((s) => `
    <div class="source-row"><strong>${esc(s.source)}</strong><span>${s.postings} rows</span><span>${esc(s.last_status || 'new')}</span></div>
  `).join('') || '<div class="source-row">no scrape state yet</div>';
}
async function loadRuns() {
  const payload = await api('/api/runs?limit=8');
  $('#runs').innerHTML = (payload.runs || []).map((run) => `
    <div class="run-row"><strong>${esc(run.source)}</strong><span>${esc(run.status)} · +${run.inserted} / ~${run.updated} of ${run.fetched}</span><span>${age(run.started_at)}</span></div>
  `).join('') || '<div class="empty">The scrape ledger is empty.</div>';
}
function renderJobs(items) {
  if (!items.length) {
    $('#results').innerHTML = '<div class="empty">No postings match. Run a scrape or widen the filters.</div>';
    return;
  }
  $('#results').innerHTML = items.map((job) => `
    <article class="job">
      <div>
        <h2><button data-id="${job.id}">${esc(job.title)}</button></h2>
        <div class="meta">
          <strong>${esc(job.company)}</strong>
          <span>${esc(job.location || 'unspecified')}</span>
          ${job.score ? `<span class="badge score">score ${job.score}</span>` : ''}
          ${job.remote ? '<span class="badge">remote</span>' : ''}
          ${(job.lanes || []).slice(0, 5).map((lane) => `<span class="badge lane">${esc(lane)}</span>`).join('')}
          <span class="badge source">${esc(job.source)}</span>
          ${(job.tags || []).slice(0, 4).map((t) => `<span class="badge">${esc(t)}</span>`).join('')}
        </div>
        <p class="snippet">${job.snippet || esc((job.description || '').slice(0, 260))}${(job.description || '').length > 260 && !job.snippet ? '…' : ''}</p>
      </div>
      <div class="job-actions">
        <span class="age">${age(job.last_seen)}</span>
        <a class="open" href="${esc(job.url)}" target="_blank" rel="noreferrer">Open posting ↗</a>
      </div>
    </article>
  `).join('');
  document.querySelectorAll('.job h2 button').forEach((button) => button.addEventListener('click', () => showDetail(button.dataset.id)));
}
async function loadJobs() {
  const page = await api('/api/postings?' + params());
  state.total = page.total || 0;
  $('#result-count').textContent = state.total;
  const scoped = [
    state.q ? `FTS5: “${state.q}”` : (state.sort === 'score' ? 'best role match first' : 'latest first'),
    state.company && `company: ${state.companyLabel || state.company}`,
    state.lane && `lane: ${state.lane}`,
  ].filter(Boolean);
  $('#query-echo').textContent = scoped.join(' · ');
  renderJobs(page.items || []);
  const pageNo = Math.floor(state.offset / state.limit) + 1;
  $('#page-label').textContent = `page ${pageNo}`;
  $('#prev').disabled = state.offset === 0;
  $('#next').disabled = state.offset + state.limit >= state.total;
}
async function showDetail(id) {
  const payload = await api(`/api/postings/${id}`);
  const job = payload.posting;
  $('#detail-body').innerHTML = `
    <h2>${esc(job.title)}</h2>
    <div class="detail-meta">
      <span class="badge source">${esc(job.source)}</span><strong>${esc(job.company)}</strong><span>${esc(job.location || 'unspecified')}</span>
      ${job.score ? `<span class="badge score">role-match ${job.score}/100</span>` : ''}
      ${job.remote ? '<span class="badge">remote</span>' : ''}
      ${(job.lanes || []).map((lane) => `<span class="badge lane">${esc(lane)}</span>`).join('')}
      <span class="badge">seen ${job.seen_count}×</span><span>${fmtDate(job.posted_at)}</span>
    </div>
    <a class="open" href="${esc(job.url)}" target="_blank" rel="noreferrer">Open original posting ↗</a>
    <div class="description">${esc(job.description || 'No description captured yet.')}</div>
    <div class="similar"><div class="panel-heading">Similar rows</div>${(payload.similar || []).map((x) => `<a href="${esc(x.url)}" target="_blank" rel="noreferrer">${esc(x.title)} · ${esc(x.company)}</a>`).join('') || '<span class="muted">No close rows.</span>'}</div>
  `;
  $('#detail').showModal();
}
async function loadScrapeState() {
  const status = await api('/api/scrape');
  $('#scrape-state').textContent = status.running ? `running — ${status.message || 'working'}` : (status.message || 'idle');
  $('#scrape-button').disabled = !!status.running;
}
$('#analytics').addEventListener('click', (event) => {
  const button = event.target.closest('button');
  if (!button) return;
  if (button.dataset.company !== undefined) {
    state.company = button.dataset.company;
    state.companyLabel = button.dataset.label || '';
  } else if (button.dataset.lane !== undefined) {
    state.lane = button.dataset.lane;
  } else if (button.dataset.clear === 'company') {
    state.company = '';
    state.companyLabel = '';
  } else if (button.dataset.clear === 'lane') {
    state.lane = '';
  } else {
    return;
  }
  state.offset = 0;
  loadJobs();
  loadAnalytics();
});
async function refreshAll() {
  await Promise.allSettled([loadStats(), loadAnalytics(), loadSources(), loadJobs(), loadRuns(), loadScrapeState()]);
}
$('#search-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  state.q = $('#q').value.trim();
  state.offset = 0;
  loadJobs();
});
$('#source').addEventListener('change', () => { state.source = $('#source').value; state.offset = 0; loadJobs(); });
$('#location').addEventListener('input', () => { state.location = $('#location').value.trim(); state.offset = 0; clearTimeout(window.locTimer); window.locTimer = setTimeout(loadJobs, 250); });
$('#days').addEventListener('change', () => { state.days = Number($('#days').value); state.offset = 0; loadJobs(); });
$('#remote').addEventListener('change', () => { state.remote = $('#remote').checked; state.offset = 0; loadJobs(); });
$('#sort').addEventListener('change', (event) => { state.sort = event.target.value; state.offset = 0; loadJobs(); });
$('#reset').addEventListener('click', () => {
  state.q = ''; state.source = ''; state.location = ''; state.company = ''; state.companyLabel = ''; state.lane = ''; state.days = 7; state.remote = false; state.sort = 'latest'; state.offset = 0;
  $('#q').value = ''; $('#source').value = ''; $('#location').value = ''; $('#days').value = '7'; $('#remote').checked = false; $('#sort').value = 'latest';
  loadJobs();
  loadAnalytics();
});
$('#prev').addEventListener('click', () => { state.offset = Math.max(0, state.offset - state.limit); loadJobs(); });
$('#next').addEventListener('click', () => { state.offset += state.limit; loadJobs(); });
$('#scrape-button').addEventListener('click', async () => {
  try {
    await api('/api/scrape', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}' });
  } catch (err) {
    if (!String(err.message).includes('409')) alert(err.message);
  }
  loadScrapeState();
});
$('#close-detail').addEventListener('click', () => $('#detail').close());
(async function boot() {
  try {
    await api('/api/health');
    $('#health').innerHTML = '<span class="pulse"></span>online';
    $('#health').classList.add('ok');
  } catch {
    $('#health').textContent = 'offline';
  }
  await refreshAll();
  setInterval(() => { loadScrapeState(); loadRuns(); }, 10000);
})();
