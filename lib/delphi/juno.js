/* juno.js — the only script on either delphi surface.
 *
 * Three jobs, all optional: remember an explicit theme choice, filter the
 * console's service cards, and decorate the portfolio-service cards with the
 * loopback telemetry aggregate. The documents are complete and readable with
 * this file absent; telemetry failure removes decoration, never content.
 */
(() => {
  const root = document.documentElement;
  const STORE = 'juno-theme';
  const MODES = ['auto', 'light', 'dark'];

  const read = () => {
    try { return localStorage.getItem(STORE); } catch (e) { return null; }
  };
  const write = (mode) => {
    try { localStorage.setItem(STORE, mode); } catch (e) { /* private mode */ }
  };

  let mode = read();
  if (!MODES.includes(mode)) mode = 'auto';

  const button = document.getElementById('juno-theme');
  const paint = () => {
    if (mode === 'auto') delete root.dataset.theme;
    else root.dataset.theme = mode;
    if (button) button.textContent = mode;
  };
  paint();

  if (button) {
    button.addEventListener('click', () => {
      mode = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
      paint();
      write(mode);
    });
  }

  const liveSlots = Array.from(document.querySelectorAll('[data-live-for]'));

  const formatMetricValue = (value) => {
    if (typeof value === 'number') return Number.isInteger(value) ? String(value) : value.toFixed(1);
    if (typeof value === 'boolean') return value ? 'yes' : 'no';
    return String(value ?? '—');
  };

  const renderLiveState = (slot, state) => {
    slot.textContent = '';
    slot.hidden = false;
    slot.dataset.telemetryActive = '1';
    slot.classList.remove('live-online', 'live-degraded', 'live-offline', 'live-unknown');
    slot.classList.add('live-' + (state.status || 'unknown'));

    const dot = document.createElement('span');
    dot.className = 'live-dot';
    dot.setAttribute('aria-hidden', 'true');
    slot.appendChild(dot);

    const status = document.createElement('span');
    status.className = 'live-status';
    status.textContent = state.status || 'unknown';
    slot.appendChild(status);

    (state.metrics || []).slice(0, 3).forEach((metric) => {
      const item = document.createElement('span');
      item.className = 'live-metric';
      item.textContent = formatMetricValue(metric.value) + ' ' + (metric.label || metric.key || 'metric');
      slot.appendChild(item);
    });

    const checked = state.checked_at ? new Date(state.checked_at) : null;
    slot.title = state.error || (checked && !Number.isNaN(checked.valueOf())
      ? 'checked ' + checked.toLocaleTimeString()
      : 'live service telemetry');
  };

  const renderTelemetryFailure = (slot) => {
    if (slot.dataset.telemetryActive !== '1') return;
    slot.textContent = '';
    slot.hidden = false;
    slot.classList.remove('live-online', 'live-degraded', 'live-offline');
    slot.classList.add('live-unknown');
    const status = document.createElement('span');
    status.className = 'live-status';
    status.textContent = 'telemetry unavailable';
    slot.appendChild(status);
    slot.title = 'the telemetry aggregate did not answer; structure above is still compiled truth';
  };

  const loadTelemetry = async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 1800);
    try {
      const response = await fetch('/api/telemetry', {
        headers: {Accept: 'application/json'},
        cache: 'no-store',
        signal: controller.signal
      });
      if (!response.ok) throw new Error('telemetry HTTP ' + response.status);
      const payload = await response.json();
      const services = payload.services || {};
      liveSlots.forEach((slot) => {
        const state = services[slot.dataset.liveFor];
        if (!state) {
          slot.hidden = true;
          delete slot.dataset.telemetryActive;
          return;
        }
        renderLiveState(slot, state);
      });
    } catch (error) {
      liveSlots.forEach(renderTelemetryFailure);
    } finally {
      clearTimeout(timer);
    }
  };

  if (liveSlots.length) {
    loadTelemetry();
    setInterval(loadTelemetry, 15000);
  }

  const input = document.getElementById('svc-filter');
  if (!input) return;

  const cards = Array.from(document.querySelectorAll('.svc'));
  const grids = Array.from(document.querySelectorAll('.svc-grid'));
  const counter = document.getElementById('svc-count');
  const total = cards.length;
  const noun = (n) => (n === 1 ? 'service' : 'services');

  const run = () => {
    const query = input.value.trim().toLowerCase();
    let shown = 0;
    cards.forEach((card) => {
      const haystack = (card.dataset.title || '') + ' ' + card.textContent.toLowerCase();
      const hit = query === '' || haystack.includes(query);
      card.hidden = !hit;
      if (hit) shown += 1;
    });
    // A heading over an empty grid reads as a broken section, so the heading and
    // its grid leave together.
    grids.forEach((grid) => {
      const empty = !Array.from(grid.children).some((child) => !child.hidden);
      grid.hidden = empty;
      const heading = grid.previousElementSibling;
      if (heading && heading.classList.contains('svc-group')) heading.hidden = empty;
    });
    if (counter) counter.textContent = shown + ' of ' + total + ' ' + noun(total);
  };

  input.addEventListener('input', run);
  document.addEventListener('keydown', (event) => {
    if (event.key !== '/' || event.ctrlKey || event.metaKey || event.altKey) return;
    if (document.activeElement === input) return;
    event.preventDefault();
    input.focus();
    input.select();
  });
  if (input.value !== '') run();
})();
