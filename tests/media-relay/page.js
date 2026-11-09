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
const { selected, groupByDir } = new Function(`${body}\n${rows}\nreturn { selected, groupByDir };`)();

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

console.log(`page: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
