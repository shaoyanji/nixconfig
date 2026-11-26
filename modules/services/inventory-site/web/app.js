const $ = (sel, root=document) => root.querySelector(sel);
const $$ = (sel, root=document) => [...root.querySelectorAll(sel)];
const state = { items: [], meta: {categories: [], locations: [], tags: []} };

async function api(path, opts={}) {
  const res = await fetch(path, opts);
  const type = res.headers.get('content-type') || '';
  const body = type.includes('json') ? await res.json() : await res.text();
  if (!res.ok) throw new Error((body && body.error) || res.statusText);
  return body;
}
const esc = value => String(value ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const cents = (value, currency='EUR') => new Intl.NumberFormat(undefined,{style:'currency',currency:currency||'EUR'}).format((value||0)/100);
const dateText = value => value ? new Date(value+'T00:00:00Z').toLocaleDateString() : '—';
function toast(message) {
  const el = $('#toast'); el.textContent = message; el.classList.add('show');
  clearTimeout(el.timer); el.timer = setTimeout(() => el.classList.remove('show'), 3400);
}
function marked(snippet) {
  return esc(snippet).replaceAll('&lt;mark&gt;','<mark>').replaceAll('&lt;/mark&gt;','</mark>');
}
function warrantyState(item) {
  if (!item.warranty_until) return ['none','no warranty'];
  const today = new Date(); today.setHours(0,0,0,0);
  const end = new Date(item.warranty_until+'T00:00:00');
  const days = Math.ceil((end-today)/86400000);
  if (days < 0) return ['bad','expired'];
  if (days <= 90) return ['warn',days+'d left'];
  return ['good',days+'d left'];
}
async function refreshStats() {
  const stats = await api('/api/stats');
  $('#stats').innerHTML = [
    ['items','Assets'], ['quantity','Units'], ['value_cents','Tracked value'], ['warranty_expiring_90d','Warranty ≤90d']
  ].map(([key,label]) => `<div class="stat"><strong>${key==='value_cents'?cents(stats[key]||0):esc(stats[key] ?? 0)}</strong><span>${label}</span></div>`).join('');
}
function filterParams() {
  const data = new FormData($('#filters'));
  const params = new URLSearchParams({limit:'72'});
  for (const [key,value] of data.entries()) {
    if (key === 'include_archived') continue;
    if (String(value).trim()) params.set(key,value);
  }
  if (data.get('include_archived')) params.set('include_archived','1');
  return params;
}
async function loadItems() {
  const page = await api('/api/items?' + filterParams());
  state.items = page.items || [];
  $('#assetCount').textContent = `${page.total} indexed`;
  $('#items').innerHTML = state.items.map(card).join('') || `<p class="muted">No assets match. Add one or import an inventory seed.</p>`;
  $$('.detail-button').forEach(btn => btn.onclick = () => showItem(btn.dataset.id));
  $$('.edit-button').forEach(btn => btn.onclick = () => editItem(btn.dataset.id));
}
function card(item) {
  const [wclass,wtext] = warrantyState(item);
  const snippet = item.snippet || item.description || item.notes || '';
  return `<article class="deal assetcard">
    <div class="dealheader"><span class="merchant">${esc(item.location || 'unplaced')}</span><span class="discount ${item.archived?'':'warranty-'+wclass}">${item.archived?'archived':esc(wtext)}</span></div>
    <h3 class="title">${esc(item.name)}</h3>
    <p class="snippet">${snippet.includes('<mark>') ? marked(snippet) : esc(snippet).slice(0,180)}</p>
    <div class="assetvalue"><strong>${item.value_cents?cents(item.value_cents,item.currency):'—'}</strong><span class="muted">× ${item.quantity || 1}</span></div>
    <div class="meta"><span class="chip">${esc(item.category || 'uncategorised')}</span>${(item.tags||[]).slice(0,3).map(t=>`<span class="chip">#${esc(t)}</span>`).join('')}</div>
    ${item.serial?`<p class="serial">SN ${esc(item.serial)}</p>`:''}
    <div class="actions"><button class="detail-button" data-id="${item.id}">Details</button><button class="edit-button" data-id="${item.id}">Edit</button>${item.url?`<a class="ghost" target="_blank" rel="noreferrer" href="${esc(item.url)}">Open</a>`:''}</div>
  </article>`;
}
async function showItem(id) {
  const item = await api(`/api/items/${id}`);
  const [wclass,wtext] = warrantyState(item);
  $('#detail').innerHTML = `<p class="eyebrow">${esc(item.category || 'asset')}</p><h2>${esc(item.name)}</h2>
    <p>${esc(item.description || 'No description recorded.')}</p>
    <div class="detail-specs">
      <div><span>location</span><b>${esc(item.location || '—')}</b></div>
      <div><span>value</span><b>${cents(item.value_cents,item.currency)} × ${item.quantity || 1}</b></div>
      <div><span>manufacturer / model</span><b>${esc([item.manufacturer,item.model].filter(Boolean).join(' ') || '—')}</b></div>
      <div><span>serial</span><b class="serial">${esc(item.serial || '—')}</b></div>
      <div><span>purchase</span><b>${dateText(item.purchase_date)}</b></div>
      <div><span>warranty</span><b class="warranty-${wclass}">${dateText(item.warranty_until)} · ${esc(wtext)}</b></div>
    </div>
    <div class="meta">${(item.tags||[]).map(t=>`<span class="chip">#${esc(t)}</span>`).join('')}<span class="chip">${esc(item.source)}</span>${item.archived?'<span class="chip">archived</span>':''}</div>
    ${item.notes?`<h3>Notes</h3><p>${esc(item.notes).replaceAll('\n','<br>')}</p>`:''}
    ${item.url?`<a class="primary ghost" target="_blank" rel="noreferrer" href="${esc(item.url)}">Open linked record</a>`:''}`;
  $('#detailDialog').showModal();
}
function fillForm(item={}) {
  const f = $('#itemForm');
  f.reset();
  f.id.value = item.id || '';
  f.source.value = item.source || 'manual';
  f.source_key.value = item.source_key || '';
  for (const key of ['name','category','location','manufacturer','model','serial','purchase_date','warranty_until','url','description','notes']) f[key].value = item[key] || '';
  f.value.value = item.value_cents ? (item.value_cents/100).toFixed(2) : '';
  f.quantity.value = item.quantity || 1;
  f.tags.value = (item.tags || []).join(', ');
  f.archived.checked = !!item.archived;
  $('#editorTitle').textContent = item.id ? `Edit ${item.name}` : 'Add an asset';
  $('#editorPanel').open = true;
  f.name.focus();
}
async function editItem(id) {
  try { fillForm(await api(`/api/items/${id}`)); } catch(err) { toast(err.message); }
}
async function saveItem(event) {
  event.preventDefault();
  const f = event.target;
  const body = {
    source:f.source.value || 'manual', source_key:f.source_key.value, name:f.name.value, category:f.category.value, location:f.location.value,
    manufacturer:f.manufacturer.value, model:f.model.value, serial:f.serial.value,
    purchase_date:f.purchase_date.value, warranty_until:f.warranty_until.value,
    value_cents:Math.round(Number(f.value.value || 0)*100), quantity:Number(f.quantity.value || 1),
    url:f.url.value, tags:f.tags.value.split(','), description:f.description.value, notes:f.notes.value,
    archived:f.archived.checked
  };
  const id = f.id.value;
  try {
    await api(id ? `/api/items/${id}` : '/api/items', {method:id?'PUT':'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
    toast(id?'Asset updated':'Asset saved'); fillForm(); await refreshAll();
  } catch(err) { toast(err.message); }
}
async function loadMeta() {
  for (const kind of ['categories','locations','tags']) {
    const payload = await api(`/api/meta/${kind}`);
    state.meta[kind] = payload.items || [];
    const singular = {categories:'category',locations:'location',tags:'tag'}[kind];
    $(`#${kind}`).innerHTML = state.meta[kind].map(entry => `<button class="chip" data-kind="${singular}" data-name="${esc(entry.name)}">${esc(entry.name)} <span class="muted">${entry.item_count}</span></button>`).join('') || '<span class="muted">none yet</span>';
    const countKey = singular + 'Count';
    if ($('#'+countKey)) $('#'+countKey).textContent = payload.total;
    const select = $(`select[data-meta="${kind}"]`);
    if (select) {
      const current = select.value;
      select.innerHTML = '<option value="">All</option>' + state.meta[kind].map(entry => `<option>${esc(entry.name)}</option>`).join('');
      select.value = current;
    }
  }
  $('#categoryList').innerHTML = state.meta.categories.map(x=>`<option value="${esc(x.name)}">`).join('');
  $('#locationList').innerHTML = state.meta.locations.map(x=>`<option value="${esc(x.name)}">`).join('');
  $$('.chiplist .chip').forEach(btn => btn.onclick = () => {
    const key = btn.dataset.kind === 'tag' ? 'tag' : btn.dataset.kind;
    const select = $(`#filters [name="${key}"]`);
    if (select) { select.value = btn.dataset.name; loadItems().catch(err => toast(err.message)); }
  });
}
async function refreshAll() {
  await Promise.all([refreshStats(), loadItems(), loadMeta()]);
}
async function importFile(input, path, type) {
  const file = input.files && input.files[0];
  if (!file) return;
  try {
    const text = await file.text();
    const result = await api(path,{method:'POST',headers:{'content-type':type},body:text});
    $('#importResult').innerHTML = `<span class="warranty-good">inserted ${result.inserted}, updated ${result.updated}, skipped ${result.skipped}</span>${(result.warnings||[]).slice(0,3).map(w=>`<br><span class="warranty-warn">${esc(w)}</span>`).join('')}`;
    toast('Import finished'); input.value=''; await refreshAll();
  } catch(err) { toast(err.message); }
}
$('#filters').addEventListener('submit', event => { event.preventDefault(); loadItems().catch(err => toast(err.message)); });
$('#filters').q.addEventListener('input', () => { clearTimeout(window.searchTimer); window.searchTimer = setTimeout(() => loadItems().catch(err => toast(err.message)), 240); });
$('#itemForm').addEventListener('submit', saveItem);
$('#resetEditor').onclick = () => fillForm();
$('#newItemButton').onclick = () => fillForm();
$('#jsonImport').addEventListener('change', event => importFile(event.target,'/api/import/json','application/json'));
$('#csvImport').addEventListener('change', event => importFile(event.target,'/api/import/csv','text/csv'));
$('#tomlImport').addEventListener('change', event => importFile(event.target,'/api/import/inventory-toml','application/toml'));
refreshAll().catch(err => toast(err.message));
