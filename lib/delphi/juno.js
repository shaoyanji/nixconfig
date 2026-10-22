/* juno.js — the only script on either delphi surface.
 *
 * Two jobs, both optional: remember an explicit theme choice, and filter the
 * console's service cards. The documents are complete and readable with this
 * file absent; nothing below builds content, and nothing below fetches anything.
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
