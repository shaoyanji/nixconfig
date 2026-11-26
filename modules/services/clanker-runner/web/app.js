const state = { q: '', status: '', kind: '', offset: 0, limit: 15, total: 0 };
const $ = (sel) => document.querySelector(sel);
function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function snippetHtml(value) {
  return esc(value).replaceAll('&lt;mark&gt;', '<mark>').replaceAll('&lt;/mark&gt;', '</mark>');
}
function age(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const seconds = Math.max(0, Math.floor((Date.now() - d.getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
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
  if (state.status) p.set('status', state.status);
  if (state.kind) p.set('kind', state.kind);
  p.set('limit', state.limit);
  p.set('offset', state.offset);
  return p;
}
async function loadStats() {
  const stats = await api('/api/stats');
  $('#metric-total').textContent = stats.total_jobs ?? 0;
  $('#metric-running').textContent = stats.running_jobs ?? 0;
  $('#metric-success').textContent = stats.successful_jobs ?? 0;
  $('#metric-failed').textContent = stats.failed_jobs ?? 0;
}
async function loadMachines() {
  const target = $('#machines');
  try {
    const payload = await api('/api/machines');
    target.innerHTML = (payload.items || []).map((machine) => `
      <article class="machine ${esc(machine.state)}">
        <div><strong>${esc(machine.name)}</strong><span>${esc(machine.id)}</span></div>
        <div class="machine-meta"><span class="badge state">${esc(machine.state)}</span><span>${machine.vcpus || '—'} vCPU</span><span>${Math.floor((machine.mem_mib || 0) / 1024) || '—'} GiB</span></div>
        <div class="machine-actions"><button data-wake="${esc(machine.name)}">Wake</button><button data-exec="${esc(machine.name)}">uname</button></div>
      </article>`).join('') || '<div class="empty small">No machines in this workspace.</div>';
    document.querySelectorAll('[data-wake]').forEach((button) => button.addEventListener('click', () => wake(button.dataset.wake)));
    document.querySelectorAll('[data-exec]').forEach((button) => button.addEventListener('click', () => quickExec(button.dataset.exec)));
  } catch (err) {
    target.innerHTML = `<div class="empty small">${esc(err.message)}</div>`;
  }
}
async function wake(machine) {
  try {
    await api(`/api/machines/${encodeURIComponent(machine)}/wake`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'});
  } catch (err) { alert(err.message); }
  loadMachines();
}
async function quickExec(machine) {
  try {
    const result = await api(`/api/machines/${encodeURIComponent(machine)}/exec`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({command: 'uname -a && nproc && df -h /data 2>/dev/null | tail -1'})});
    alert(result.stdout || result.stderr || `exit ${result.exitCode}`);
  } catch (err) { alert(err.message); }
}
function renderJobs(items) {
  if (!items.length) {
    $('#jobs').innerHTML = '<div class="empty">No jobs match. Queue one above or widen the filters.</div>';
    return;
  }
  $('#jobs').innerHTML = items.map((job) => `
    <article class="job ${esc(job.status)}">
      <button class="job-main" data-id="${esc(job.id)}">
        <span class="job-title"><b>${esc(job.kind)}</b><span class="badge ${esc(job.status)}">${esc(job.status)}</span><span>${esc(job.machine)}</span></span>
        <code>${esc(job.command)}</code>
        ${job.snippet ? `<span class="snippet">${snippetHtml(job.snippet)}</span>` : ''}
      </button>
      <span class="job-side"><em>${age(job.created_at)}</em>${job.exit_code !== undefined && job.exit_code !== null ? `<i>exit ${job.exit_code}</i>` : ''}</span>
    </article>`).join('');
  document.querySelectorAll('.job-main').forEach((button) => button.addEventListener('click', () => showDetail(button.dataset.id)));
}
async function loadJobs() {
  const page = await api('/api/jobs?' + params());
  state.total = page.total || 0;
  $('#job-count').textContent = state.total;
  $('#query-echo').textContent = state.q ? `FTS5: “${state.q}”` : 'latest first';
  renderJobs(page.items || []);
  const pageNo = Math.floor(state.offset / state.limit) + 1;
  $('#page-label').textContent = `page ${pageNo}`;
  $('#prev').disabled = state.offset === 0;
  $('#next').disabled = state.offset + state.limit >= state.total;
}
async function showDetail(id) {
  const payload = await api(`/api/jobs/${encodeURIComponent(id)}`);
  const artifactsPayload = await api(`/api/jobs/${encodeURIComponent(id)}/artifacts`).catch(() => ({items: []}));
  const artifacts = artifactsPayload.items || [];
  const job = payload.job;
  const logs = payload.logs || [];
  $('#detail-body').innerHTML = `
    <h2>${esc(job.kind)} on ${esc(job.machine)}</h2>
    <div class="detail-meta"><span class="badge ${esc(job.status)}">${esc(job.status)}</span><span>${esc(job.id)}</span><span>${age(job.created_at)}</span>${job.exit_code !== undefined && job.exit_code !== null ? `<span>exit ${job.exit_code}</span>` : ''}</div>
    <div class="panel-heading">Command</div><pre class="command">${esc(job.command)}</pre>
    ${job.error ? `<div class="panel-heading">Error</div><pre class="error">${esc(job.error)}</pre>` : ''}
    <div class="panel-heading">Artifacts</div>
    <div class="artifacts">${artifacts.map((artifact) => `<a class="artifact" href="/api/jobs/${encodeURIComponent(id)}/artifacts/${artifact.id}${artifact.mime.startsWith('text/') ? '?preview=1' : ''}" target="_blank" rel="noreferrer"><b>${esc(artifact.name)}</b><span>${esc(artifact.kind)} · ${artifact.size} bytes</span><code>${esc(artifact.sha256.slice(0, 16))}</code>${artifact.excerpt ? `<small>${esc(artifact.excerpt)}</small>` : ''}</a>`).join('') || '<span class="muted">No artifacts captured yet.</span>'}</div>
    <div class="panel-heading">Persisted log</div>
    <div class="log">${logs.map((line) => `<div><span>${esc(line.stream)}</span><code>${esc(line.line)}</code></div>`).join('') || '<span class="muted">No log rows yet.</span>'}</div>
    <div class="output-grid"><section><div class="panel-heading">stdout</div><pre>${esc(job.stdout || '—')}</pre></section><section><div class="panel-heading">stderr</div><pre>${esc(job.stderr || '—')}</pre></section></div>`;
  $('#detail').showModal();
}
function syncKindInputs() {
  const kind = $('#kind').value;
  $('#command-label').classList.toggle('hidden', kind !== 'shell');
  $('#attr-label').classList.toggle('hidden', kind !== 'nix');
  $('#args-label').classList.toggle('hidden', kind === 'shell');
}
function presetParams() {
  return {
    url: $('#preset-url').value.trim(),
    selector: $('#preset-selector').value.trim(),
    package: $('#preset-package').value.trim(),
    args: $('#preset-args').value.trim(),
    flake: $('#preset-flake').value.trim(),
    dir: $('#preset-dir').value.trim(),
    target: $('#preset-target').value.trim(),
    attr: $('#preset-target').value.trim()
  };
}
async function runPreset(id) {
  try {
    await api(`/api/presets/${encodeURIComponent(id)}/run`, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({machine:'clanker',...presetParams()})});
    await refreshAll();
  } catch (err) { alert(err.message); }
}
async function loadPresets() {
  const payload = await api('/api/presets');
  const items = payload.items || [];
  $('#presets').innerHTML = items.map((preset) => `<article class="preset"><strong>${esc(preset.name)}</strong><p>${esc(preset.description)}</p><p><code>${esc(preset.id)}</code></p>${preset.params?.length?`<div class="param-list">${preset.params.map((param) => `<span>${esc(param.name)}<small>${esc(param.type)}${param.required ? ' · required' : ''}</small></span>`).join('')}</div>`:''}<div class="preset-actions"><button data-preset="${esc(preset.id)}">Run</button>${preset.required?.length?`<small>needs ${esc(preset.required.join(', '))}</small>`:''}</div></article>`).join('');
  const select = $('#schedule-preset');
  const current = select.value;
  select.innerHTML = items.map((preset) => `<option value="${esc(preset.id)}">${esc(preset.name)}</option>`).join('');
  select.value = current || items[0]?.id || '';
  document.querySelectorAll('[data-preset]').forEach((button) => button.addEventListener('click', () => runPreset(button.dataset.preset)));
}
function scheduleParamsFor(presetID) {
  const values = presetParams();
  const params = {};
  for (const key of ['url', 'selector', 'package', 'args', 'flake', 'dir', 'target']) {
    if (values[key]) params[key] = values[key];
  }
  if (presetID === 'nix-flake-build' && values.target) params.attr = values.target;
  return params;
}
async function loadSchedules() {
  const payload = await api('/api/schedules');
  const items = payload.items || [];
  $('#schedules').innerHTML = items.map((schedule) => `<article class="schedule"><strong>${esc(schedule.name)}</strong><p><code>${esc(schedule.preset_id)}</code> on ${esc(schedule.machine)} every ${schedule.interval_seconds}s</p><small>next ${new Date(schedule.next_run_at).toLocaleString()}${schedule.last_job_id?` · last ${esc(schedule.last_job_id)}`:''}</small>${schedule.last_error?`<small class="error-text">${esc(schedule.last_error)}</small>`:''}<div class="schedule-actions"><button class="ghost" data-delete-schedule="${schedule.id}">Delete</button><span class="badge ${schedule.enabled?'finished':'failed'}">${schedule.enabled?'enabled':'disabled'}</span></div></article>`).join('') || '<div class="empty small">No recurring schedules yet.</div>';
  document.querySelectorAll('[data-delete-schedule]').forEach((button) => button.addEventListener('click', () => deleteSchedule(button.dataset.deleteSchedule)));
}
async function deleteSchedule(id) {
  try {
    await api(`/api/schedules/${encodeURIComponent(id)}`, {method:'DELETE'});
    await loadSchedules();
  } catch (err) { alert(err.message); }
}
async function createSchedule(event) {
  event.preventDefault();
  const presetID = $('#schedule-preset').value;
  const body = {
    preset_id: presetID,
    machine: $('#schedule-machine').value.trim() || 'clanker',
    interval_seconds: Number($('#schedule-interval').value || 3600),
    start_immediately: $('#schedule-start').checked,
    params: scheduleParamsFor(presetID)
  };
  try {
    await api('/api/schedules', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
    await loadSchedules();
  } catch (err) { alert(err.message); }
}
async function refreshAll() { await Promise.allSettled([loadStats(), loadMachines(), loadJobs(), loadPresets(), loadSchedules()]); }
$('#job-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const kind = $('#kind').value;
  const body = {machine: $('#machine').value.trim(), kind};
  if (kind === 'shell') body.command = $('#command').value;
  if (kind === 'nix') { body.attr = $('#attr').value; body.args = $('#args').value; }
  if (kind === 'agent-browser') { body.args = $('#args').value || $('#command').value; }
  try {
    await api('/api/jobs', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    $('#command').value = ''; $('#attr').value = ''; $('#args').value = '';
  } catch (err) { alert(err.message); }
  refreshAll();
});
$('#kind').addEventListener('change', syncKindInputs);
$('#q').addEventListener('input', () => { state.q = $('#q').value.trim(); state.offset = 0; clearTimeout(window.qTimer); window.qTimer = setTimeout(loadJobs, 240); });
$('#status').addEventListener('change', () => { state.status = $('#status').value; state.offset = 0; loadJobs(); });
$('#kind-filter').addEventListener('change', () => { state.kind = $('#kind-filter').value; state.offset = 0; loadJobs(); });
$('#reset').addEventListener('click', () => {
  state.q = ''; state.status = ''; state.kind = ''; state.offset = 0;
  $('#q').value = ''; $('#status').value = ''; $('#kind-filter').value = '';
  loadJobs();
});
$('#prev').addEventListener('click', () => { state.offset = Math.max(0, state.offset - state.limit); loadJobs(); });
$('#next').addEventListener('click', () => { state.offset += state.limit; loadJobs(); });
$('#schedule-form').addEventListener('submit', createSchedule);
$('#close-detail').addEventListener('click', () => $('#detail').close());
(async function boot() {
  syncKindInputs();
  try {
    const health = await api('/api/health');
    $('#health').innerHTML = `<span class="pulse"></span>${health.instabox_configured ? 'online' : 'no api key'}`;
    $('#health').classList.add('ok');
  } catch { $('#health').textContent = 'offline'; }
  await refreshAll();
  setInterval(refreshAll, 10000);
})();
