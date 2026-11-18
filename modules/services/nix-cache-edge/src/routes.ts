// Path grammar and header arithmetic for the edge cache. Deliberately free of
// Cloudflare types: the Worker imports this, and `node --test` imports it too,
// so the routing rules can be proved without a bucket, a token or a deploy.
// Why the edge exists at all: docs/nix-cache-edge.md.

export type Route =
  | {kind: "cache-info"}
  | {kind: "narinfo"; hash: string; key: string}
  | {kind: "nar"; key: string}
  | {kind: "media"; key: string; contentType: string}
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
  const media = mediaRoute(pathname);
  if (media) return media;
  return {kind: "not-found"};
}

// The bucket is double-dipped: `media/` holds what the media relay fetched, and
// the same read path serves it. A video player needs exactly what a nix client
// needs here — a sized object, Range and a stable ETag — so the route only has
// to name the object and its type. Why the relay stores there: docs/media-relay.md.
const MEDIA_PREFIX = "/media/";

// Extension to type, because R2 objects written by rclone carry no useful
// Content-Type and a browser given application/octet-stream downloads the file
// instead of playing it. The list is the relay's own extension set.
const MEDIA_TYPES: Record<string, string> = {
  mp4: "video/mp4",
  m4v: "video/mp4",
  webm: "video/webm",
  mkv: "video/x-matroska",
  mov: "video/quicktime",
  avi: "video/x-msvideo",
  mpg: "video/mpeg",
  mpeg: "video/mpeg",
  ts: "video/mp2t",
  mp3: "audio/mpeg",
  m4a: "audio/mp4",
  aac: "audio/aac",
  ogg: "audio/ogg",
  opus: "audio/ogg",
  flac: "audio/flac",
  wav: "audio/wav",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  gif: "image/gif",
  avif: "image/avif",
  srt: "text/plain; charset=utf-8",
  vtt: "text/vtt; charset=utf-8",
};

export function mediaType(path: string): string {
  const dot = path.lastIndexOf(".");
  if (dot === -1 || dot < path.lastIndexOf("/")) return "application/octet-stream";
  return MEDIA_TYPES[path.slice(dot + 1).toLowerCase()] ?? "application/octet-stream";
}

// A percent-encoded key from a page link, decoded once and then checked. The
// decode happens before the checks so that `%2e%2e` cannot walk out of the
// prefix; a dotfile is refused whole, which also keeps a stray key from being
// listed by a future index route.
function mediaRoute(pathname: string): Route | null {
  if (!pathname.startsWith(MEDIA_PREFIX)) return null;
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname.slice(MEDIA_PREFIX.length));
  } catch {
    return {kind: "not-found"};
  }
  if (!decoded || decoded.length > 512) return {kind: "not-found"};
  if (/[\u0000-\u001f\\]/.test(decoded)) return {kind: "not-found"};
  const segments = decoded.split("/");
  if (segments.some((s) => s === "" || s.startsWith("."))) return {kind: "not-found"};
  return {kind: "media", key: `media/${decoded}`, contentType: mediaType(decoded)};
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
