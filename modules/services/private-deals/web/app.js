const $ = (sel, root=document) => root.querySelector(sel);
const $$ = (sel, root=document) => [...root.querySelectorAll(sel)];
const state = { deals: [], products: [], watchlists: [], analytics: null };

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
    ['deals','Active deals'],['products','Tracked products'],['price_points','Price points'],['alerts_sent','Alerts sent']
  ].map(([key,label]) => `<div class="stat"><strong>${esc(stats[key] ?? 0)}</strong><span>${label}</span></div>`).join('');
}
function sparkline(days, currency, width = 240) {
  const points = (days || []).filter(day => day.min_price != null);
  if (points.length < 2) return '';
  const height = 46, pad = 4;
  const values = points.map(day => day.min_price);
  const low = Math.min(...values), high = Math.max(...values), span = high - low || 1;
  const step = (width - pad * 2) / (points.length - 1);
  const coords = values.map((value, i) => [pad + i * step, height - pad - ((value - low) / span) * (height - pad * 2)]);
  const line = coords.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
  const area = `${line} L${(width - pad).toFixed(1)} ${height} L${pad} ${height} Z`;
  const [lastX, lastY] = coords[coords.length - 1];
  const label = `lowest price per day: ${money(low, currency)} to ${money(high, currency)}`;
  return `<svg class="spark" viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(label)}"><title>${esc(label)}</title><path class="spark-area" d="${area}"></path><path class="spark-line" d="${line}"></path><circle class="spark-dot" cx="${lastX.toFixed(1)}" cy="${lastY.toFixed(1)}" r="2.6"></circle></svg>`;
}
async function loadAnalytics() {
  const report = await api('/api/analytics?window=30&limit=5');
  state.analytics = report;
  const history = report.history || {};
  const currency = history.currency || 'EUR';
  const drop = (report.biggest_drops || [])[0];
  const figure = (value, label) => `<div><strong>${esc(value)}</strong><span>${esc(label)}</span></div>`;
  const plural = (count, one, many) => `${count} ${count === 1 ? one : many}`;
  const figures = [
    figure(`${history.points || 0}`, `${history.points === 1 ? 'price point' : 'price points'} · ${report.window_days || 30} d`),
    figure(plural(history.fell || 0, 'product', 'products'), 'falling'),
    figure(plural(history.rose || 0, 'product', 'products'), 'rising'),
    figure(drop ? `−${drop.drop_pct}%` : '—', drop ? drop.name : 'no drop yet'),
  ].join('');
  const rows = (items, detail) => items.length ? items.map(item => `<div class="analytics-row"><b>${esc(item.name || item.title)}</b><span>${detail(item)}</span></div>`).join('') : '<p class="muted">nothing yet</p>';
  const lists = [
    ['Top discounts', rows(report.top_discounts || [], deal => `−${deal.discount_pct}%${deal.price != null ? ' · ' + money(deal.price, deal.currency) : ''}`)],
    ['Merchants', rows(report.merchants || [], row => `${plural(row.deals, 'deal', 'deals')} · ⌀−${row.avg_discount}%`)],
    ['Categories', rows(report.categories || [], row => `${plural(row.deals, 'deal', 'deals')} · max −${row.max_discount}%`)],
  ].map(([title, body]) => `<div><h4>${title}</h4>${body}</div>`).join('');
  $('#analyticsWindow').textContent = `last ${report.window_days || 30} days · avg ${history.avg_price != null ? money(history.avg_price, currency) : '—'}`;
  // The sparkline is drawn in the panel's own pixels: a fixed viewBox inside a
  // wider box letterboxes the line into the middle third of the column.
  const sparkWidth = Math.max(240, Math.round($('#analytics').clientWidth || 240));
  $('#analytics').innerHTML = `<div class="analytics-figures">${figures}</div>${sparkline(history.daily, currency, sparkWidth)}` +
    (drop ? `<p class="muted">${esc(drop.name)} ${money(drop.from, drop.currency)} → ${money(drop.to, drop.currency)} over ${plural(drop.points, 'point', 'points')}</p>` : '') +
    `<div class="analytics-lists">${lists}</div>`;
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
  const first = prices[0], latest = prices[prices.length-1];
  const change = first && latest ? latest.price - first.price : 0;
  const trendClass = change < 0 ? 'down' : change > 0 ? 'up' : 'flat';
  const trend = prices.length > 1 ? `<span class="chip trend ${trendClass}">${change<0?'▼':change>0?'▲':'■'} ${money(Math.abs(change),latest.currency)} since first point</span>` : '';
  const low = prices.length ? Math.min(...prices.map(p => p.price)) : null;
  const high = prices.length ? Math.max(...prices.map(p => p.price)) : null;
  const range = prices.length ? `<div class="trendline"><span>low ${money(low,latest.currency)}</span><span>latest ${money(latest.price,latest.currency)}</span><span>high ${money(high,latest.currency)}</span></div>` : '';
  $('#detail').innerHTML = `<p class="eyebrow">${esc(deal.merchant || deal.source)}</p><h2>${esc(deal.title)}</h2>
    <div class="priceblock">${deal.price!=null?`<span class="price">${money(deal.price,deal.currency)}</span>`:''}${deal.list_price!=null?`<span class="list">${money(deal.list_price,deal.currency)}</span>`:''}${deal.discount_pct?`<span class="discount">−${deal.discount_pct}%</span>`:''}${trend}</div>
    <p>${esc(deal.description || 'No description indexed.')}</p>
    <div class="meta"><span class="chip">seen ${deal.seen_count}×</span><span class="chip">last ${new Date(deal.last_seen).toLocaleString()}</span>${deal.expires_at?`<span class="chip">expires ${esc(deal.expires_at)}</span>`:''}</div>
    <h3>Price history</h3><div class="history">${bars || '<span class="muted">no price points yet</span>'}</div>${range}
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
  $('#watchlists').innerHTML = state.watchlists.map(w => `<div class="watchlist"><div class="watch-actions"><button class="tiny" data-list="${w.id}">items</button><button class="tiny poll-list" data-list="${w.id}">poll</button></div><b>${esc(w.name)}</b><span class="small">${w.item_count} product(s)</span></div>`).join('') || '<p class="muted">No watchlists yet.</p>';
  $$('#watchlists button:not(.poll-list)').forEach(btn => btn.onclick = () => showWatchlist(btn.dataset.list));
  $$('#watchlists .poll-list').forEach(btn => btn.onclick = () => pollWatchlist(btn.dataset.list));
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

async function pollWatchlist(id) {
  const path = id ? `/api/watchlists/${id}/poll` : '/api/watchlists/poll';
  try {
    const result = await api(path,{method:'POST',headers:{'content-type':'application/json'},body:'{}'});
    toast(result.accepted ? 'Watchlist poll started' : 'Watchlist poll already running');
    pollIngest();
  } catch(err) { toast(err.message); }
}
async function loadPriceEvents() {
  const page = await api('/api/price-events?kind=price-drop&limit=8');
  const events = page.items || [];
  state.priceEvents = events;
  $('#priceEvents').innerHTML = events.map(event => `<div class="alert price-drop"><span class="status sent">drop</span><b>${money(event.previous_price,event.currency)} → ${money(event.price,event.currency)}</b><span class="small">${esc(event.message)}</span><span class="small">${new Date(event.created_at).toLocaleString()}</span></div>`).join('') || '<p class="muted">No recorded price drops yet.</p>';
}

async function loadAlerts() {
  const page = await api('/api/alerts?limit=8');
  const alerts = page.items || [];
  $('#alerts').innerHTML = alerts.map(alert => `<button class="alert detail-button" data-id="${alert.deal_id}"><span class="status ${esc(alert.status)}">${esc(alert.status)}</span><b>${esc(alert.product_name || alert.title)}</b><span class="small">${money(alert.price,alert.currency)} · ${esc(alert.reason)} · ${esc(alert.watchlist)}</span><span class="small">${alert.attempts} attempt(s)${alert.notify_error?' · '+esc(alert.notify_error):''}</span></button>`).join('') || '<p class="muted">No watchlist alerts yet.</p>';
  $$('#alerts .detail-button').forEach(btn => btn.onclick = () => showDeal(btn.dataset.id));
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
  else { refreshStats(); loadAnalytics(); loadDeals(); loadSources(); loadPriceEvents(); }
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
$('#evaluateAlerts').onclick = async () => {
  try { const result = await api('/api/alerts/evaluate',{method:'POST',headers:{'content-type':'application/json'},body:'{}'}); toast(`Alerts: ${result.created} new, ${result.notified} sent, ${result.failed} failed`); loadAlerts(); }
  catch(err) { toast(err.message); }
};
$('#pollWatchlists').onclick = () => pollWatchlist();
$('#newListButton').onclick = () => $('#watchlistForm').classList.toggle('hidden');
$('#watchlistForm').addEventListener('submit', async event => {
  event.preventDefault();
  try { await api('/api/watchlists',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({name:event.target.name.value})}); event.target.reset(); loadWatchlists(); }
  catch(err) { toast(err.message); }
});
Promise.all([refreshStats(),loadAnalytics(),loadDeals(),loadProducts(),loadWatchlists(),loadSources(),loadAlerts(),loadPriceEvents()]).catch(err => toast(err.message));
