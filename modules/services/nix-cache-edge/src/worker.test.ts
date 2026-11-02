import assert from "node:assert/strict";
import {test} from "node:test";

import worker from "./worker.ts";

const BASE32 = "0123456789abcdfghijklmnpqrsvwxyz";
const STORE_HASH = BASE32;
const NAR_HASH = (BASE32 + BASE32).slice(0, 52);

const NARINFO = [
  "StorePath: /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-probe-1.0",
  `URL: nar/${NAR_HASH}.nar`,
  "Compression: none",
  "FileHash: sha256:0000000000000000000000000000000000000000000000000000",
  "FileSize: 6",
  "NarHash: sha256:1111111111111111111111111111111111111111111111111111",
  "NarSize: 6",
  "Sig: probe-1:signature-placeholder",
  "",
].join("\n");

// Only the members the worker touches. A stub is the point: it pins the contract
// (which keys are requested, what HEAD returns) without a bucket or a token.
function stubBucket(objects: Record<string, string>) {
  const requested: {key: string; range?: {offset: number; length?: number}}[] = [];
  const encode = (body: string) => new Response(body).body;
  return {
    requested,
    async get(key: string, options?: {range?: {offset: number; length?: number}}) {
      requested.push({key, range: options?.range});
      const body = objects[key];
      if (body === undefined) return null;
      const bytes = body.length;
      const etag = `"etag-${key.replace(/[^a-z0-9]/gi, "")}"`;
      if (!options?.range) {
        return {size: bytes, httpEtag: etag, body: encode(body)};
      }
      const {offset, length} = options.range;
      const end = length === undefined ? bytes : Math.min(bytes, offset + length);
      if (offset >= bytes) return null;
      return {
        size: bytes,
        httpEtag: etag,
        range: {offset, length: end - offset},
        body: encode(body.slice(offset, end)),
      };
    },
    async head(key: string) {
      const body = objects[key];
      if (body === undefined) return null;
      return {size: body.length, httpEtag: `"etag-${key.replace(/[^a-z0-9]/gi, "")}"`};
    },
  };
}

function call(bucket: ReturnType<typeof stubBucket>, path: string, init?: RequestInit) {
  return worker.fetch(new Request(`https://cache.example${path}`, init), {
    BUCKET: bucket,
    PRIORITY: "30",
  });
}

test("nix-cache-info is served with the priority the var carries", async () => {
  const res = await call(stubBucket({}), "/nix-cache-info");
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-type"), "text/plain; charset=utf-8");
  assert.equal(await res.text(), "StoreDir: /nix/store\nWantMassQuery: 1\nPriority: 30\n");
});

test("a narinfo is served as text/x-nix-narinfo, immutable and ranged", async () => {
  const bucket = stubBucket({[`${STORE_HASH}.narinfo`]: NARINFO});
  const res = await call(bucket, `/${STORE_HASH}.narinfo`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-type"), "text/x-nix-narinfo");
  assert.match(res.headers.get("cache-control") ?? "", /immutable/);
  assert.equal(res.headers.get("accept-ranges"), "bytes");
  assert.equal(await res.text(), NARINFO);
});

test("HEAD answers with the length and no body", async () => {
  const bucket = stubBucket({[`${STORE_HASH}.narinfo`]: NARINFO});
  const res = await call(bucket, `/${STORE_HASH}.narinfo`, {method: "HEAD"});
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-length"), String(NARINFO.length));
  assert.equal(await res.text(), "");
});

test("a whole nar is binary and its range request is a 206", async () => {
  const bucket = stubBucket({[`nar/${NAR_HASH}.nar`]: "narbytes"});
  const whole = await call(bucket, `/nar/${NAR_HASH}.nar`);
  assert.equal(whole.status, 200);
  assert.equal(whole.headers.get("content-type"), "application/x-nix-nar");
  assert.equal(await whole.text(), "narbytes");

  const partial = await call(stubBucket({[`nar/${NAR_HASH}.nar`]: "narbytes"}), `/nar/${NAR_HASH}.nar`, {
    headers: {range: "bytes=0-2"},
  });
  assert.equal(partial.status, 206);
  assert.equal(partial.headers.get("content-range"), "bytes 0-2/8");
  assert.equal(await partial.text(), "nar");
});

test("a whole read is 200 even when the binding reports range metadata", async () => {
  // Miniflare (and R2 locally) populate `range` on every get, so the status has
  // to follow the request instead: a 206 here makes a client treat the whole nar
  // as a fragment.
  const key = `nar/${NAR_HASH}.nar`;
  const bucket = {
    async get() {
      return {
        size: 8,
        httpEtag: '"etag-whole"',
        range: {offset: 0, length: 8},
        body: new Response("narbytes").body,
      };
    },
    async head() {
      return {size: 8, httpEtag: '"etag-whole"'};
    },
  };
  const res = await worker.fetch(new Request(`https://cache.example/${key}`), {BUCKET: bucket});
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-length"), "8");
  assert.equal(res.headers.get("content-range"), null);
  assert.equal(await res.text(), "narbytes");
});

test("an unsatisfiable range is 416, never a 200 with the wrong bytes", async () => {
  const bucket = stubBucket({[`nar/${NAR_HASH}.nar`]: "narbytes"});
  const res = await call(bucket, `/nar/${NAR_HASH}.nar`, {headers: {range: "bytes=99-"}});
  assert.equal(res.status, 416);
  assert.equal(res.headers.get("content-range"), "bytes */8");
});

test("matching If-None-Match is a 304 with the etag", async () => {
  const key = `${STORE_HASH}.narinfo`;
  const bucket = stubBucket({[key]: NARINFO});
  const etag = (await bucket.head(key))!.httpEtag;
  const res = await call(bucket, `/${key}`, {headers: {"if-none-match": etag}});
  assert.equal(res.status, 304);
  assert.equal(res.headers.get("etag"), etag);
});

test("a miss is a 404 and a write is a 405 that names the real upload path", async () => {
  const missing = await call(stubBucket({}), `/${STORE_HASH}.narinfo`);
  assert.equal(missing.status, 404);

  const put = await call(stubBucket({}), `/${STORE_HASH}.narinfo`, {method: "PUT"});
  assert.equal(put.status, 405);
  assert.equal(put.headers.get("allow"), "GET, HEAD");
  assert.match(await put.text(), /S3 API/);
});

test("unknown paths never reach the bucket", async () => {
  const bucket = stubBucket({});
  for (const path of ["/", "/nix/store/abc", "/nar/../etc/passwd", "/nix-cache-info.json"]) {
    const res = await call(bucket, path);
    assert.equal(res.status, 404, path);
  }
  assert.deepEqual(
    bucket.requested.filter((r) => r.key !== "nix-cache-info"),
    [],
    "no object reads for a path outside the grammar",
  );
});
