import assert from "node:assert/strict";
import {test} from "node:test";

import {cacheInfo, mediaType, parseRange, routeFor} from "./routes.ts";

test("nix-cache-info advertises a store dir, mass query and a priority", () => {
  assert.equal(cacheInfo(30), "StoreDir: /nix/store\nWantMassQuery: 1\nPriority: 30\n");
});

// nix's base32 alphabet is exactly 32 characters: 0-9 a-z without e, o, u, t.
const BASE32 = "0123456789abcdfghijklmnpqrsvwxyz";
const NAR_HASH = (BASE32 + BASE32).slice(0, 52);

test("narinfo needs a 32-character base32 store hash and nothing else", () => {
  const hash = BASE32;
  assert.deepEqual(routeFor(`/${hash}.narinfo`), {
    kind: "narinfo",
    hash,
    key: `${hash}.narinfo`,
  });
  // 'o' is not in nix's base32 alphabet, and a path is not a store hash.
  assert.equal(routeFor(`/o${BASE32.slice(1)}.narinfo`).kind, "not-found");
  assert.equal(routeFor(`/${BASE32.slice(1)}.narinfo`).kind, "not-found");
  assert.equal(routeFor("/abc.narinfo").kind, "not-found");
  assert.equal(routeFor("/nix/store/abc.narinfo").kind, "not-found");
});

test("nar keys live under nar/ and keep their compression extension", () => {
  const hash = NAR_HASH;
  assert.deepEqual(routeFor(`/nar/${hash}.nar`), {kind: "nar", key: `nar/${hash}.nar`});
  assert.deepEqual(routeFor(`/nar/${hash}.nar.zst`), {kind: "nar", key: `nar/${hash}.nar.zst`});
  assert.equal(routeFor(`/nar/${hash}.nar.zip`).kind, "not-found");
  assert.equal(routeFor(`/nar/../${hash}.nar`).kind, "not-found");
});

test("the info endpoint is exact, not a prefix", () => {
  assert.deepEqual(routeFor("/nix-cache-info"), {kind: "cache-info"});
  assert.equal(routeFor("/nix-cache-info.json").kind, "not-found");
  assert.equal(routeFor("/").kind, "not-found");
});

test("media keys keep their prefix and take a type from the extension", () => {
  assert.deepEqual(routeFor("/media/dQw4w9WgXcQ/Title%20%5BdQw4w9WgXcQ%5D.mp4"), {
    kind: "media",
    key: "media/dQw4w9WgXcQ/Title [dQw4w9WgXcQ].mp4",
    contentType: "video/mp4",
  });
  assert.equal(routeFor("/media/vidA/poster.jpg").kind, "media");
  assert.equal(mediaType("a/b.jpg"), "image/jpeg");
  assert.equal(mediaType("a/b.MP4"), "video/mp4");
  // An unknown or absent extension is a download, not a broken player guess.
  assert.equal(mediaType("a/noext"), "application/octet-stream");
  assert.equal(mediaType("a.dir/noext"), "application/octet-stream");
});

test("a media key cannot escape its prefix", () => {
  for (const path of [
    "/media/",
    "/media/../secrets.yaml",
    "/media/vidA/%2e%2e/%2e%2e/x.mp4",
    "/media/a//b.mp4",
    "/media/vidA/.hidden.mp4",
    "/media/a%5Cb.mp4",
  ]) {
    assert.equal(routeFor(path).kind, "not-found", path);
  }
});

test("no range header is a whole-object read", () => {
  assert.equal(parseRange(null, 100), null);
});

test("offset and offset-end ranges", () => {
  assert.deepEqual(parseRange("bytes=0-99", 1000), {offset: 0, length: 100});
  assert.deepEqual(parseRange("bytes=100-", 1000), {offset: 100});
  // An end past the object is clamped to what exists, not rejected.
  assert.deepEqual(parseRange("bytes=900-9999", 1000), {offset: 900, length: 100});
});

test("suffix ranges are resolved against the size", () => {
  assert.deepEqual(parseRange("bytes=-100", 1000), {offset: 900, length: 100});
  assert.deepEqual(parseRange("bytes=-5000", 1000), {offset: 0, length: 1000});
  assert.equal(parseRange("bytes=-0", 1000), "invalid");
});

test("unsatisfiable and malformed ranges are 416, never a silent 200", () => {
  assert.equal(parseRange("bytes=1000-", 1000), "invalid");
  assert.equal(parseRange("bytes=5-4", 1000), "invalid");
  assert.equal(parseRange("bytes=", 1000), "invalid");
  assert.equal(parseRange("items=0-1", 1000), "invalid");
});
