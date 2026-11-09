# media-relay — fetch where the peering is good

delphi pulls a YouTube video on its own uplink and serves it back as an
H.264/AAC MP4 with HTTP Range, so a client on the LAN or the tailnet streams
from `http://delphi:8094` instead of from Googlevideo. delphi is the only host
this is enabled on (`services.media-relay.enable`, `hosts/delphi/configuration.nix`);
nothing opens the port in the firewall, so it is tailnet-only.

## The throughput claim is not proven

Measured: a 10-minute 1080p fetch on delphi took 12.4 s (a gigabit line), and
serving it back crossed WireGuard at 11.4 Mbit.

That is the relay working, not the relay *winning*. Every home-side number taken
on 2026-11-04 ran while a 20 GB download held the uplink at ~19–21 Mbit, so
"Google gives this house 1.5–2.3 Mbit" was really "the line was full" — a
contaminated measurement, and the number the delphi comment used to carry.

The decisive experiment is one `curl` against a Googlevideo URL and one against
this relay on a quiet line. Until that exists, treat the throughput case as
**open**, and the relay's value as packaging: one bookmarkable URL, plus the
format rules below, which are constraints rather than preferences.

## The format string encodes three rules

| Rule | Why |
| :--- | :--- |
| `vcodec^=avc1` — H.264 | An iPad Air 1 on iOS 12 decodes nothing else, and the netbook's Gen8 iGPU has no VP9/AV1 engine. |
| `acodec^=mp4a` — AAC | Opus (format 251) is `bestaudio`'s default and cannot play in an old Safari `<video>`. |
| frame rate ≤ 30 | Measured on the netbook (Celeron N3060, Gen8 iGPU): 8 s of 1080p60 dropped 273 frames, 64 with `profile=fast`, 100 with bilinear scaling — the box renders below 60 fps whatever the shader costs. The same 1080p at 30 fps dropped 9. |

Height and rate are **ceilings, not targets**: `--height`/`--fps` raise them per
fetch when the client is a TV, and the fps filter falls back to the uncapped
chain rather than failing when a video has no ≤30 fps format.

The three rules are enforced, not preferred: there is no `best` fallback at the
end of the format chain. A video with no `avc1`/`mp4a` stream below the ceiling
fails the fetch and says so, because the alternative is storing VP9 or AV1 in an
mp4 and discovering it cannot play on the client days later.

`-c copy` + `+faststart` means nothing is re-encoded and the moov atom sits at
the front, which is what makes seeking over Range work.

## Browsing

`http://delphi:8461/` (tailnet `tailscale-serve-media`) serves a browse page over
the library, not an nginx directory listing: every file, grouped by the fetch
folder it came from — newest fetch first, newest file first inside a folder —
with a fuzzy search over name, folder and extension, and a copy button on every
row for the absolute URL of the host it is being read on. The
page is one static HTML file with inline CSS and JS — no build step, no
framework, no network fetch beyond the manifest — because it has to work on an
iPad's Safari as well as the netbook.

- `/index.json` is the manifest: `path`, `name`, `dir`, `ext`, `kind`, `size`,
  `mtime` per file, plus `poster` on a video that has one, and `count` and
  `bytes`. The page never walks directories (that is one request per folder).
- A poster is one image per fetch folder, written to `poster.jpg` beside the
  video. `yt-get` asks for YouTube's own thumbnail first (one metadata call, no
  decode) and falls back to a frame at 3 s, or 0 s when the video is shorter,
  scaled to 480 px wide; `media-relay-posters` fills in the ones already in the
  library at boot. The name is the contract — the index reads `poster.jpg` as
  metadata for that folder's video, so it is never listed as an image and never
  counted in `bytes`. A video with no poster keeps the filename row, and its
  folder still lists every file.
- `media-relay-index` writes it from `find` every five minutes and at boot, and
  `yt-get` refreshes it at the end of a fetch, so a new download is listed
  immediately rather than at the next tick.
- The extension set is the index's filter, not the page's: mp4/m4v/webm/mkv/mov/
avi/mpg/mpeg/ts (video), mp3/m4a/aac/ogg/opus/flac/wav (audio),
jpg/jpeg/png/webp/gif/avif (image), srt/vtt (subtitle). Anything else is left out
of the listing and still served at its path.
- A directory URL (`/dQw4w9WgXcQ/`) keeps the plain nginx listing, so a bookmark
from before the page existed still opens.

## Operations

- `yt-get [--height N] [--fps N] <url>` is the only command; there is no task.
- The cookie jar at `/var/lib/media-relay/cookies.txt` (0600, `devji`) is a
  hand-provisioned credential and never enters the store. Without it a
  datacenter IP is refused at the player API ("Sign in to confirm you're not a
  bot"), which looks like a network fault — so `yt-get` checks it and fails
  loudly instead. `requireCookies = false` is the deliberate override.
- `media-relay-posters` is a boot oneshot for files that did not arrive through
  `yt-get` (a hand-copied file, or one fetched before posters existed). It
  skips a folder whose poster is already there, so a second run is a `find`.
- `media-relay-prune` runs daily and deletes files untouched for
  `retentionDays` (14), then empties directories. The library is a cache, not an
  archive: anything worth keeping belongs on `/srv/data`.
