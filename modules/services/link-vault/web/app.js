const state = {
  links: [],
  collections: [],
  tags: [],
  stats: {}
};

const $ = (id) => document.getElementById(id);

function escapeHTML(value) {
  return String(value == null ? '' : value).replace(/[&<>'"]/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
  }[char]));
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { 'Accept': 'application/json', ...(options.body ? { 'Content-Type': 'application/json' } : {}) },
    ...options
  });
  const text = await response.text();
  let data = {};
  try { data = text ? JSON.parse(text) : {}; } catch (error) { data = { error: text || error.message }; }
  if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
  return data;
}

function metric(label, key) {
  return `<div class="metric"><strong>${escapeHTML(state.stats[key] || 0)}</strong><span>${escapeHTML(label)}</span></div>`;
}

function renderMetrics() {
  $('metrics').innerHTML = [
    metric('bookmarks', 'bookmarks'),
    metric('unread', 'unread'),
    metric('read', 'read'),
    metric('archived', 'archived'),
    metric('collections', 'collections'),
    metric('tags', 'tags'),
    metric('extracted', 'extracted')
  ].join('');
}

function renderFilters() {
  const collectionOptions = ['<option value="">all</option>'].concat(state.collections.map((collection) =>
    `<option value="${escapeHTML(collection.name)}">${escapeHTML(collection.name)} (${collection.links})</option>`)).join('');
  const currentCollection = $('collection-filter').value;
  $('collection-filter').innerHTML = collectionOptions;
  $('collection-filter').value = currentCollection;
  $('collection-list').innerHTML = state.collections.map((collection) => `<option value="${escapeHTML(collection.name)}">`).join('');

  const currentTag = $('tag-filter').value;
  $('tag-filter').innerHTML = ['<option value="">all</option>'].concat(state.tags.map((tag) =>
    `<option value="${escapeHTML(tag)}">${escapeHTML(tag)}</option>`)).join('');
  $('tag-filter').value = currentTag;
  $('tag-cloud').innerHTML = state.tags.slice(0, 28).map((tag) =>
    `<button class="tag" type="button" data-tag="${escapeHTML(tag)}">#${escapeHTML(tag)}</button>`).join('');
}

function stateActions(link) {
  const next = link.state === 'read' ? 'unread' : 'read';
  return `
    <button class="button small ghost" data-action="state" data-id="${link.id}" data-state="${next}">${next === 'read' ? 'Mark read' : 'Mark unread'}</button>
    <button class="button small ghost" data-action="state" data-id="${link.id}" data-state="archived">Archive</button>
    <button class="button small ghost" data-action="extract" data-id="${link.id}">Extract</button>
    <button class="button small ghost" data-action="delete" data-id="${link.id}">Delete</button>`;
}

function renderLinks() {
  $('result-count').textContent = `${state.links.length} link${state.links.length === 1 ? '' : 's'}`;
  if (!state.links.length) {
    $('links').innerHTML = '<p class="description">No links match this view yet.</p>';
    return;
  }
  $('links').innerHTML = state.links.map((link) => {
    const title = link.title || link.url;
    const tags = (link.tags || []).map((tag) => `<span class="tag">#${escapeHTML(tag)}</span>`).join('');
    const extraction = link.extraction_status === 'ok' ? ' · extracted' : '';
    return `<article class="card">
      <div class="meta"><span class="state ${escapeHTML(link.state)}">${escapeHTML(link.state)}</span> · ${escapeHTML(link.site_name || 'web')} · ${escapeHTML(link.source || 'manual')}${extraction}</div>
      <h3><a href="${escapeHTML(link.url)}" target="_blank" rel="noreferrer">${escapeHTML(title)}</a></h3>
      <p class="excerpt">${escapeHTML(link.excerpt || link.description || 'No extracted summary yet.')}</p>
      <div class="tag-cloud">${tags}</div>
      <p class="meta">${link.collection_name ? `collection ${escapeHTML(link.collection_name)} · ` : ''}updated ${escapeHTML((link.updated_at || '').slice(0, 10))}</p>
      <div class="card-actions">
        <button class="button small" data-action="detail" data-id="${link.id}">Read detail</button>
        <span>${stateActions(link)}</span>
      </div>
    </article>`;
  }).join('');
}

async function loadStats() {
  const data = await api('/api/stats');
  state.stats = data.stats || data;
  renderMetrics();
  const providers = data.providers || {};
  $('provider-summary').textContent = `http + ${['firecrawl', 'tavily', 'context'].filter((name) => providers[name]).join(' + ') || 'no provider keys'}`;
}

async function loadFacets() {
  const [collections, tags] = await Promise.all([api('/api/collections'), api('/api/tags')]);
  state.collections = collections.collections || [];
  state.tags = tags.tags || [];
  renderFilters();
}

function queryString() {
  const params = new URLSearchParams();
  if ($('q').value.trim()) params.set('q', $('q').value.trim());
  if ($('state').value !== 'all') params.set('state', $('state').value);
  if ($('collection-filter').value) params.set('collection', $('collection-filter').value);
  if ($('tag-filter').value) params.set('tag', $('tag-filter').value);
  params.set('limit', '100');
  return params.toString();
}

async function loadLinks() {
  const data = await api(`/api/links?${queryString()}`);
  state.links = data.links || [];
  renderLinks();
}

async function refreshAll() {
  await Promise.all([loadStats(), loadFacets(), loadLinks()]);
}

function formMessage(text, isError = false) {
  $('form-message').textContent = text;
  $('form-message').classList.toggle('error', isError);
}

async function submitLink(event) {
  event.preventDefault();
  const input = {
    url: $('url').value.trim(),
    title: $('title').value.trim(),
    collection: $('collection').value.trim(),
    tags: $('tags').value.split(',').map((tag) => tag.trim()).filter(Boolean),
    provider: $('provider').value,
    extract: $('extract').checked
  };
  try {
    const result = await api('/api/links', { method: 'POST', body: JSON.stringify(input) });
    formMessage(result.created ? 'Link archived.' : 'Existing link updated.');
    $('link-form').reset();
    $('extract').checked = true;
    await refreshAll();
  } catch (error) {
    formMessage(error.message, true);
  }
}

function showDetail(link) {
  $('detail-meta').textContent = `${link.state} · ${link.site_name || 'web'} · ${link.source || 'manual'}`;
  $('detail-title').textContent = link.title || link.url;
  $('detail-url').href = link.url;
  $('detail-url').textContent = link.url;
  $('detail-tags').innerHTML = (link.tags || []).map((tag) => `<span class="tag">#${escapeHTML(tag)}</span>`).join('');
  $('detail-description').textContent = link.description || link.excerpt || '';
  $('detail-content').textContent = link.content || 'No extracted page text yet. Use Extract to capture it.';
  $('detail').showModal();
}

async function cardAction(button) {
  const id = button.dataset.id;
  const action = button.dataset.action;
  try {
    if (action === 'detail') {
      const link = await api(`/api/links/${id}`);
      showDetail(link);
      return;
    }
    if (action === 'state') {
      await api(`/api/links/${id}/state`, { method: 'POST', body: JSON.stringify({ state: button.dataset.state }) });
    } else if (action === 'extract') {
      await api(`/api/links/${id}/extract`, { method: 'POST', body: '{}' });
    } else if (action === 'delete') {
      if (!confirm('Delete this link from the archive?')) return;
      await api(`/api/links/${id}`, { method: 'DELETE' });
    }
    await refreshAll();
  } catch (error) {
    alert(error.message);
  }
}

function bind() {
  $('link-form').addEventListener('submit', submitLink);
  $('refresh').addEventListener('click', refreshAll);
  for (const id of ['q', 'state', 'collection-filter', 'tag-filter']) {
    $(id).addEventListener(id === 'q' ? 'input' : 'change', () => {
      clearTimeout(window.linkVaultTimer);
      window.linkVaultTimer = setTimeout(loadLinks, id === 'q' ? 250 : 0);
    });
  }
  $('links').addEventListener('click', (event) => {
    const button = event.target.closest('button[data-action]');
    if (button) cardAction(button);
  });
  $('tag-cloud').addEventListener('click', (event) => {
    const button = event.target.closest('button[data-tag]');
    if (!button) return;
    $('tag-filter').value = button.dataset.tag;
    loadLinks();
  });
  document.querySelector('[data-close]').addEventListener('click', () => $('detail').close());
}

bind();
refreshAll().catch((error) => formMessage(error.message, true));
