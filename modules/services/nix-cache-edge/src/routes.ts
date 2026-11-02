// Path grammar and header arithmetic for the edge cache. Deliberately free of
// Cloudflare types: the Worker imports this, and `node --test` imports it too,
// so the routing rules can be proved without a bucket, a token or a deploy.
// Why the edge exists at all: docs/nix-cache-edge.md.

export type Route =
  | {kind: "cache-info"}
  | {kind: "narinfo"; hash: string; key: string}
  | {kind: "nar"; key: string}
  | {kind: "not-found"};

// A store path hash is 32 base32 characters (NOILU removed from the alphabet).
const NARINFO = /^\/([0-9a-df-np-sv-z]{32})\.narinfo$/;
// The nar file is `<narhash>.nar[.xz|.zst|.bz2|.br]` under /nar/; the hash is the
// flat (uncompressed) hash Nix computed, so the extension is the only variable.
const NAR = /^\/nar\/([0-9a-df-np-sv-z]{52}\.nar(?:\.(?:xz|zst|bz2|br))?)$/;

export function routeFor(pathname: string): Route {
  if (pathname === "/nix-cache-info") return {kind: "cache-info"};
  const narinfo = NARINFO.exec(pathname);
  if (narinfo) return {kind: "narinfo", hash: narinfo[1], key: `${narinfo[1]}.narinfo`};
  const nar = NAR.exec(pathname);
  if (nar) return {kind: "nar", key: `nar/${nar[1]}`};
  return {kind: "not-found"};
}

// Nix orders substitutes by Priority (lower wins). harmonia advertises 10 and is
// reachable only on the LAN; this cache sits behind it so a LAN build never
// leaves the house for something the NAS already serves.
export function cacheInfo(priority: number): string {
  return `StoreDir: /nix/store\nWantMassQuery: 1\nPriority: ${priority}\n`;
}

export type ByteRange = {offset: number; length?: number};

// `Range: bytes=0-99`, `bytes=100-`, `bytes=-500`. null means "no header", the
// string "invalid" means "416" — an unsatisfiable range must not be answered
// with a 200, because Nix would then treat a truncated nar as whole.
export function parseRange(header: string | null, size: number): ByteRange | null | "invalid" {
  if (!header) return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match) return "invalid";
  const [, rawStart, rawEnd] = match;
  if (rawStart === "" && rawEnd === "") return "invalid";

  if (rawStart === "") {
    const suffix = Number(rawEnd);
    if (suffix === 0) return "invalid";
    const length = Math.min(suffix, size);
    return {offset: size - length, length};
  }

  const offset = Number(rawStart);
  if (offset >= size) return "invalid";
  if (rawEnd === "") return {offset};
  const end = Number(rawEnd);
  if (end < offset) return "invalid";
  return {offset, length: Math.min(end, size - 1) - offset + 1};
}

// Nix sends HEAD before a GET to learn the nar size; a cache that answers HEAD
// with a body or a 405 costs an extra round trip per path.
export function isHead(method: string): boolean {
  return method === "HEAD";
}
