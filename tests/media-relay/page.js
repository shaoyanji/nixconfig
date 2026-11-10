// Row markup for the media library, run against the page's own functions.
//
// `lib/media-relay/index.html` carries the listing logic inline (no build step),
// so the only way to assert it is to lift the functions out of the file and run
// them. The slice is by function name, and a missing one is a failure rather
// than an empty test: a rename must break this, not silently pass it.
//
// Usage: node page.js <path to index.html>
'use strict';

const fs = require('fs');

const file = process.argv[2];
if (!file) {
  console.error('page.js: no page path');
  process.exit(2);
}
const src = fs.readFileSync(file, 'utf8');

const slice = (from, to) => {
  const start = src.indexOf(from);
  const end = src.indexOf(to);
  if (start === -1 || end === -1 || end <= start) {
    console.error(`page.js: cannot find ${from} .. ${to}`);
    process.exit(2);
  }
  return src.slice(start, end);
};

// The page touches the DOM at load time, so the harness needs the shape of it.
const stubEl = () => ({
  id: '', innerHTML: '', textContent: '', value: '',
  addEventListener() {}, append() {}, replaceChildren() {}, setAttribute() {},
  querySelectorAll: () => [], focus() {}, blur() {},
});
globalThis.document = {
  getElementById: () => stubEl(),
  createElement: () => stubEl(),
  addEventListener() {},
  body: stubEl(),
  execCommand: () => true,
};
globalThis.fetch = () => new Promise(() => {});
globalThis.location = { origin: 'https://delphi.example:8461' };

const body = slice("'use strict';", 'function selected');
const rows = slice('function selected', 'function markup');
const { selected, groupByDir, ytCard, fmtDur, shortcutFor } = new Function(
  `${body}\n${rows}\nreturn { selected, groupByDir, ytCard, fmtDur, shortcutFor };`,
)();

let pass = 0;
let fail = 0;
const ok = (name, cond) => {
  if (cond) {
    pass += 1;
    console.log(`ok   ${name}`);
  } else {
    fail += 1;
    console.log(`FAIL ${name}`);
  }
};

const video = {
  path: 'vidA/Big Buck Bunny.mp4', name: 'Big Buck Bunny.mp4', ext: 'mp4',
  size: 5000, mtime: 1000, poster: 'vidA/poster.jpg', html: 'Big Buck Bunny.mp4',
};
const plain = { path: 'vidB/clip.webm', name: 'clip.webm', ext: 'webm', size: 3000, mtime: 2000, html: 'clip.webm' };
const spaced = { path: 'a b/x y.mp4', name: 'x y.mp4', ext: 'mp4', size: 1, mtime: 3000, poster: 'a b/poster.jpg', html: 'x y.mp4' };

const row = selected(video);
ok('a poster puts a thumb on the row', row.includes('class="thumb"') && row.includes('class="poster"'));
ok('the thumb is a lazy 96x54 box', row.includes('width="96" height="54"') && row.includes('loading="lazy"'));
ok('the thumb is the manifest poster', row.includes('src="/vidA/poster.jpg"'));
ok('the name survives the thumb', row.includes('Big Buck Bunny.mp4'));
ok('a row without a poster has no thumb', !selected(plain).includes('thumb'));
ok('a row without a poster has no grid class', !selected(plain).includes('class="poster"'));
ok('paths are percent-encoded in the poster', selected(spaced).includes('src="/a%20b/poster.jpg"'));
ok('paths are percent-encoded in the link', selected(spaced).includes('href="/a%20b/x%20y.mp4"'));
ok('one image per row', (row.match(/<img/g) || []).length === 1);
ok('the thumb comes before the name', row.indexOf('thumb') < row.indexOf('class="n"'));
ok('every row offers copy', row.includes('<button class="cp"'));
ok('the button carries the encoded link', row.includes('data-href="/vidA/Big%20Buck%20Bunny.mp4"'));
ok('the button is outside the anchor', row.includes('</a><button'));
ok('the button names what it copies', row.includes('aria-label="Copy the link to Big Buck Bunny.mp4"'));

const groups = groupByDir([
  { path: 'old/a.mp4', mtime: 100 },
  { path: 'new/b.mp4', mtime: 900 },
  { path: 'new/c.mp4', mtime: 500 },
]);
ok('folders are newest first', groups.length === 2 && groups[0][0] === 'new' && groups[1][0] === 'old');
ok('files are newest first inside a folder', groups[0][1][0].path === 'new/b.mp4' && groups[0][1][1].path === 'new/c.mp4');
const tied = groupByDir([{ path: 'z/x.mp4', mtime: 7 }, { path: 'z/a.mp4', mtime: 7 }]);
ok('equal mtimes fall back to the name', tied.length === 1 && tied[0][1][0].path === 'z/a.mp4');

// The YouTube search card: the fetch button is a sibling of the link, so
// opening the video and pulling it onto delphi stay two different intents.
const hit = {
  id: 'vidA', title: 'Big Buck Bunny', channel: 'Blender', duration: 596,
  live: 'not_live', url: 'https://www.youtube.com/watch?v=vidA',
  thumb: 'https://i.ytimg.com/vi/vidA/mqdefault.jpg',
};
const card = ytCard(hit);
ok('a card carries the thumbnail', card.includes('src="https://i.ytimg.com/vi/vidA/mqdefault.jpg"'));
ok('the thumbnail is a wide lazy box', card.includes('class="thumb wide"') && card.includes('loading="lazy"'));
ok('the card links the video', card.includes('href="https://www.youtube.com/watch?v=vidA"'));
ok('the card names the channel and the length', card.includes('Blender \u00b7 9:56'));
ok('the fetch button is outside the link', card.includes('</a><button'));
ok('the fetch button carries the url and the title',
  card.includes('data-url="https://www.youtube.com/watch?v=vidA"')
  && card.includes('data-title="Big Buck Bunny"'));
ok('a title with markup is escaped', ytCard({ ...hit, title: '<b>x</b>' }).includes('&lt;b&gt;x&lt;/b&gt;'));
ok('a missing thumbnail falls back to the still',
  ytCard({ ...hit, thumb: '' }).includes('src="https://i.ytimg.com/vi/vidA/mqdefault.jpg"'));
ok('a live entry says live', ytCard({ ...hit, duration: null, live: 'is_live' }).includes('Blender \u00b7 live'));
// A live fetch records until the broadcast ends, so the card offers no button.
ok('a live result offers no fetch',
  !ytCard({ ...hit, live: 'is_live' }).includes('<button') && ytCard({ ...hit, live: 'is_live' }).includes('class="go off"'));
ok('an upcoming stream offers no fetch', !ytCard({ ...hit, live: 'is_upcoming' }).includes('<button'));
ok('a finished stream still fetches', ytCard({ ...hit, live: 'was_live' }).includes('<button class="go fet"'));
ok('durations are clock-shaped', fmtDur(59) === '0:59' && fmtDur(60) === '1:00' && fmtDur(3661) === '1:01:01');
ok('no duration prints nothing', fmtDur(null) === '' && fmtDur(undefined) === '');

// Shortcuts: one letter per field, matched to the field's name.
ok('l is the library filter', shortcutFor('l') === 'library');
ok('p is the paste-a-URL field', shortcutFor('p') === 'paste');
ok('y is the YouTube search', shortcutFor('y') === 'search');
ok('s is free text', shortcutFor('s') === null);
ok('a symbol is not a shortcut', shortcutFor('/') === null && shortcutFor('Enter') === null);

console.log(`page: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
