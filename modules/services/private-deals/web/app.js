const $ = (sel, root=document) => root.querySelector(sel);
const $$ = (sel, root=document) => [...root.querySelectorAll(sel)];
const state = { deals: [], products: [], watchlists: [] };

async function api(path, opts={}) {
  const res = await fetch(path, opts);
  const type = res.headers.get('content-type') || '';
  const body = type.includes('json') ? await res.json() : await res.text();
  if (!res.ok) throw new Error(body.error || res.statusText);
  return body;
}
const money = (value, currency='EUR') => value == null ? '' : new Intl.NumberFormat(undefined,{style:'currency',currency}).format(value);
const esc = value => String(value ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function toast(message) {
  const el = $('#toast'); el.textContent = message; el.classList.add('show');
  clearTimeout(el.timer); el.timer = setTimeout(() => el.classList.remove('show'), 3200);
}
async function refreshStats() {
  const stats = await api('/api/stats');
  $('#stats').innerHTML = [
    ['deals','Active deals'],['products','Tracked products'],['price_points','Price points'],['discount_max','Best discount %']
  ].map(([key,label]) => `<div class="stat"><strong>${esc(stats[key] ?? 0)}${key==='discount_max'?'%':''}</strong><span>${label}</span></div>`).join('');
}
function filterParams() {
  const data = new FormData($('#filters'));
  const params = new URLSearchParams({limit:'60'});
  for (const [key,value] of data.entries()) if (String(value).trim()) params.set(key,value);
  return params;
}
async function loadDeals() {
  const page = await api('/api/deals?' + filterParams());
  state.deals = page.items || [];
  $('#dealCount').textContent = `${page.total} indexed`;
  $('#deals').innerHTML = state.deals.map(card).join('') || `<p class="muted">No deals match. Run ingestion or add one manually.</p>`;
  $$('.detail-button').forEach(btn => btn.onclick = () => showDeal(btn.dataset.id));
}
function card(deal) {
  const price = deal.price != null ? `<span class="price">${money(deal.price,deal.currency)}</span>` : '<span class="missing">price unseen</span>';
  const list = deal.list_price != null ? `<span class="list">${money(deal.list_price,deal.currency)}</span>` : '';
  const discount = deal.discount_pct ? `<span class="discount">−${deal.discount_pct}%</span>` : '';
  const snippet = deal.snippet || deal.description || '';
  return `<article class="deal">
    <div class="dealheader"><span class="merchant">${esc(deal.merchant || deal.source)}</span>${discount}</div>
    <h3 class="title">${esc(deal.title)}</h3>
    <p class="snippet">${snippet.includes('<mark>') ? snippet : esc(snippet)}</p>
    <div class="priceblock">${price}${list}</div>
    <div class="meta"><span class="chip">${esc(deal.category || 'uncategorised')}</span><span class="chip">${esc(deal.source)}</span>${deal.coupon_code?`<span class="chip">code ${esc(deal.coupon_code)}</span>`:''}</div>
    <div class="actions"><button class="detail-button" data-id="${deal.id}">Details</button>${deal.url?`<a class="ghost" target="_blank" rel="noreferrer" href="${esc(deal.url)}">Open</a>`:''}</div>
  </article>`;
}
async function showDeal(id) {
  const payload = await api(`/api/deals/${id}`);
  const deal = payload.deal;
  const history = payload.price_history || [];
  const prices = history.filter(p => p.price != null).slice().reverse();
  const max = Math.max(...prices.map(p => p.price), 1);
  const bars = prices.map(p => `<span class="bar" title="${money(p.price,p.currency)} · ${new Date(p.captured_at).toLocaleString()}" style="height:${Math.max(8,(p.price/max)*100)}%"></span>`).join('');
  $('#detail').innerHTML = `<p class="eyebrow">${esc(deal.merchant || deal.source)}</p><h2>${esc(deal.title)}</h2>
    <div class="priceblock">${deal.price!=null?`<span class="price">${money(deal.price,deal.currency)}</span>`:''}${deal.list_price!=null?`<span class="list">${money(deal.list_price,deal.currency)}</span>`:''}${deal.discount_pct?`<span class="discount">−${deal.discount_pct}%</span>`:''}</div>
    <p>${esc(deal.description || 'No description indexed.')}</p>
    <div class="meta"><span class="chip">seen ${deal.seen_count}×</span><span class="chip">last ${new Date(deal.last_seen).toLocaleString()}</span>${deal.expires_at?`<span class="chip">expires ${esc(deal.expires_at)}</span>`:''}</div>
    <h3>Price history</h3><div class="history">${bars || '<span class="muted">no price points yet</span>'}</div>
    ${deal.url?`<a class="primary ghost" target="_blank" rel="noreferrer" href="${esc(deal.url)}">Open source</a>`:''}`;
  $('#detailDialog').showModal();
}
async function loadProducts() {
  const page = await api('/api/products?limit=12');
  state.products = page.items || [];
  $('#productCount').textContent = page.total;
  $('#products').innerHTML = state.products.map(p => `<div class="product"><button class="tiny add-product" data-id="${p.id}">+ list</button><b>${esc(p.name)}</b><span class="small">${esc(p.merchant || 'unknown')} · ${p.current_price!=null?money(p.current_price,p.currency):'no price'}${p.target_price!=null?' · target '+money(p.target_price,p.currency):''}</span></div>`).join('') || '<p class="muted">No tracked products yet.</p>';
  $$('.add-product').forEach(btn => btn.onclick = () => addProductToList(btn.dataset.id));
}
async function loadWatchlists() {
  const page = await api('/api/watchlists');
  state.watchlists = page.items || [];
  $('#watchlistPicker').innerHTML = state.watchlists.map(w => `<option value="${w.id}">${esc(w.name)}</option>`).join('') || '<option value="">no watchlist</option>';
  $('#watchlists').innerHTML = state.watchlists.map(w => `<div class="watchlist"><button class="tiny" data-list="${w.id}">items</button><b>${esc(w.name)}</b><span class="small">${w.item_count} product(s)</span></div>`).join('') || '<p class="muted">No watchlists yet.</p>';
  $$('#watchlists button').forEach(btn => btn.onclick = () => showWatchlist(btn.dataset.list));
}
async function addProductToList(productID) {
  const watchlistID = $('#watchlistPicker').value;
  if (!watchlistID) { toast('Create a watchlist first'); return; }
  try {
    await api(`/api/watchlists/${watchlistID}/items`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({product_id:Number(productID)})});
    toast('Product added to watchlist'); loadWatchlists();
  } catch(err) { toast(err.message); }
}

async function showWatchlist(id) {
  const page = await api(`/api/watchlists/${id}/items`);
  $('#detail').innerHTML = `<p class="eyebrow">watchlist</p><h2>${page.total} tracked product(s)</h2>` + (page.items || []).map(item => `<div class="product"><b>${esc(item.product.name)}</b><span class="small">${esc(item.product.merchant)} · ${item.product.current_price!=null?money(item.product.current_price,item.product.currency):'no price'}</span><p>${esc(item.notes || '')}</p></div>`).join('');
  $('#detailDialog').showModal();
}
async function loadSources() {
  const payload = await api('/api/sources');
  const states = payload.states || [];
  $('#sources').innerHTML = defaultSourceRows(payload.configured, states).map(row => `<div class="source"><b>${esc(row.name)}</b><span class="small">${esc(row.last_status || 'never run')} · ${row.total_fetched || 0} fetched</span></div>`).join('');
}
function defaultSourceRows(configured, states) {
  return (configured || []).map(name => ({name, ...(states.find(s => s.name === name) || {})}));
}
async function pollIngest() {
  const status = await api('/api/ingest');
  $('#ingestState').textContent = status.running ? 'running' : 'idle';
  if (status.running) setTimeout(pollIngest, 1200);
  else { refreshStats(); loadDeals(); loadSources(); }
}
function formNumbers(form, keys) {
  const out = {};
  for (const key of keys) {
    const raw = form[key]?.value;
    if (raw !== undefined && raw !== '') out[key] = Number(raw);
  }
  return out;
}
$('#filters').addEventListener('submit', event => { event.preventDefault(); loadDeals().catch(err => toast(err.message)); });
$('#filters').q.addEventListener('input', () => { clearTimeout(window.searchTimer); window.searchTimer = setTimeout(() => loadDeals(), 250); });
$('#ingestButton').onclick = async () => {
  try { await api('/api/ingest',{method:'POST',headers:{'content-type':'application/json'},body:'{}'}); toast('Ingestion started'); pollIngest(); }
  catch(err) { toast(err.message); }
};
$('#dealForm').addEventListener('submit', async event => {
  event.preventDefault();
  const f = event.target;
  const body = {title:f.title.value,url:f.url.value,merchant:f.merchant.value,coupon_code:f.coupon_code.value,description:f.description.value,source:'manual',...formNumbers(f,['price','list_price'])};
  try { await api('/api/deals',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)}); f.reset(); toast('Deal saved'); refreshStats(); loadDeals(); }
  catch(err) { toast(err.message); }
});
$('#productForm').addEventListener('submit', async event => {
  event.preventDefault();
  const f = event.target;
  const body = {name:f.name.value,url:f.url.value,merchant:f.merchant.value,brand:f.brand.value,category:f.category.value,source:'manual',...formNumbers(f,['current_price','target_price'])};
  try { await api('/api/products',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)}); f.reset(); toast('Product tracked'); refreshStats(); loadProducts(); }
  catch(err) { toast(err.message); }
});
$('#newListButton').onclick = () => $('#watchlistForm').classList.toggle('hidden');
$('#watchlistForm').addEventListener('submit', async event => {
  event.preventDefault();
  try { await api('/api/watchlists',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({name:event.target.name.value})}); event.target.reset(); loadWatchlists(); }
  catch(err) { toast(err.message); }
});
Promise.all([refreshStats(),loadDeals(),loadProducts(),loadWatchlists(),loadSources()]).catch(err => toast(err.message));
