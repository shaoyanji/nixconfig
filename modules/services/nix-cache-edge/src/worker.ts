// The read-only edge of the fleet's Nix cache, served from R2.
//
// There is no signing here and no secret on this side: narinfo is signed by the
// writer (`nix copy --to s3://…` with `secret-key-files`), so the edge only ever
// reads objects a nix client already signed. Uploads therefore do not exist as a
// route — PUT is a 405 that says where to push instead.
//
// Cloudflare's types are not imported: `node --test` runs this file (Node 24
// strips types) and wrangler bundles it with no install step, so the whole
// project has zero npm dependencies. docs/nix-cache-edge.md.
import {cacheInfo, parseRange, routeFor} from "./routes.ts";

interface R2Range {
  offset: number;
  length?: number;
}

interface R2ObjectBody {
  size: number;
  httpEtag: string;
  range?: {offset: number; length: number};
  body: ReadableStream | null;
}

interface R2ObjectHead {
  size: number;
  httpEtag: string;
}

interface R2BucketLike {
  get(key: string, options?: {range?: R2Range}): Promise<R2ObjectBody | null>;
  head(key: string): Promise<R2ObjectHead | null>;
}

interface Env {
  BUCKET: R2BucketLike;
  PRIORITY?: string;
}

const IMMUTABLE = "public, max-age=31536000, immutable";
// nix-cache-info is small and changes only when PRIORITY does; the store paths it
// describes are immutable forever, so only this file wants a short TTL.
const SELF_DESCRIBING = "public, max-age=300";

function notFound(head: boolean): Response {
  return new Response(head ? null : "not found\n", {
    status: 404,
    headers: {"content-type": "text/plain; charset=utf-8", "cache-control": SELF_DESCRIBING},
  });
}

function readOnly(head: boolean): Response {
  const body =
    "this cache is read-only\n\n" +
    "uploads go to the R2 bucket through its S3 API, where nix signs the narinfo\n" +
    "it writes; see docs/nix-cache-edge.md\n";
  return new Response(head ? null : body, {
    status: 405,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      allow: "GET, HEAD",
      "cache-control": "no-store",
    },
  });
}

function unsatisfiable(size: number): Response {
  return new Response("range not satisfiable\n", {
    status: 416,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "content-range": `bytes */${size}`,
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const method = request.method.toUpperCase();
    const head = method === "HEAD";
    if (method !== "GET" && !head) return readOnly(head);

    const route = routeFor(new URL(request.url).pathname);
    if (route.kind === "not-found") return notFound(head);

    if (route.kind === "cache-info") {
      const configured = Number(env.PRIORITY ?? "");
      const priority = Number.isFinite(configured) ? configured : 30;
      return new Response(head ? null : cacheInfo(priority), {
        status: 200,
        headers: {"content-type": "text/plain; charset=utf-8", "cache-control": SELF_DESCRIBING},
      });
    }

    const contentType = route.kind === "narinfo" ? "text/x-nix-narinfo" : "application/x-nix-nar";
    const rangeHeader = request.headers.get("range");

    // A ranged request costs one metadata read before the body: the object size
    // decides both a suffix range's meaning and whether an offset is satisfiable,
    // and R2 answers a past-the-end offset with a miss rather than a 416 — which
    // would report an object that exists as `not in cache`. Nix rarely ranges a
    // nar, so the common path stays a single GET.
    let range: R2Range | undefined;
    if (rangeHeader) {
      const meta = await env.BUCKET.head(route.key);
      if (!meta) return notFound(head);
      const parsed = parseRange(rangeHeader, meta.size);
      if (parsed === "invalid") return unsatisfiable(meta.size);
      range = parsed ?? undefined;
    }

    const object = await env.BUCKET.get(route.key, range ? {range} : undefined);
    if (!object) return notFound(head);
    if (range && !object.range) return unsatisfiable(object.size);
    // R2 reports `range` metadata even for a whole-object read (Miniflare always
    // does), so the request — not the response — decides whether this is a 206.
    // Answering a plain GET with a partial status makes some clients treat the
    // body as a fragment.
    const partial = range !== undefined && object.range !== undefined;

    const etag = object.httpEtag;
    const inm = request.headers.get("if-none-match");
    if (inm && (inm.trim() === "*" || inm.split(",").some((tag) => tag.trim() === etag))) {
      return new Response(null, {status: 304, headers: {etag, "cache-control": IMMUTABLE}});
    }

    const length = partial ? object.range!.length : object.size;
    const headers = new Headers({
      "content-type": contentType,
      "cache-control": IMMUTABLE,
      "content-length": String(length),
      "accept-ranges": "bytes",
      etag,
    });
    if (partial) {
      const served = object.range!;
      headers.set(
        "content-range",
        `bytes ${served.offset}-${served.offset + served.length - 1}/${object.size}`,
      );
    }

    return new Response(head ? null : object.body, {
      status: partial ? 206 : 200,
      headers,
    });
  },
};
