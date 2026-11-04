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

`-c copy` + `+faststart` means nothing is re-encoded and the moov atom sits at
the front, which is what makes seeking over Range work.

## Operations

- `yt-get [--height N] [--fps N] <url>` is the only command; there is no task.
- The cookie jar at `/var/lib/media-relay/cookies.txt` (0600, `devji`) is a
  hand-provisioned credential and never enters the store. Without it a
  datacenter IP is refused at the player API ("Sign in to confirm you're not a
  bot"), which looks like a network fault — so `yt-get` checks it and fails
  loudly instead. `requireCookies = false` is the deliberate override.
- `media-relay-prune` runs daily and deletes files untouched for
  `retentionDays` (14), then empties directories. The library is a cache, not an
  archive: anything worth keeping belongs on `/srv/data`.
