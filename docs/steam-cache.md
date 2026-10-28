# Steam content cache

Frieren serves SteamPipe content to the LAN, so a game update or install is
fetched from the NAS instead of the internet. Steam supports this natively: it
resolves `lancache.steamcontent.com`, and when the answer is the cache it
downloads from the CDN hostname it is handed **over plain HTTP** — no
certificate, no client configuration.

## Layout

| Piece | Where |
| :--- | :--- |
| Front vhost (`:80`, always on) | `services.nginx.virtualHosts.steam-cache` — `modules/services/steam-cache.nix` |
| Cache process (`127.0.0.1:8081`) | `systemd.services.steam-cache`, cache root `/mnt/flash-cache/steam-cache` |
| DNS override (**off**) | `hosts/frieren/dns.nix`, gated on `services.steamCache.dnsOverride` |
| Health | gatus endpoint `steam cache` → `http://127.0.0.1:8081/__health` |

## The override is off, and why

Steam's client resolves `lancache.steamcontent.com` to detect a cache, then
fetches depots from the CDN hostname it is handed — all inside
`steamcontent.com`. So making downloads cache requires an `address=` record for
the **whole zone**, not just the detection name, and that zone is not
cache-only traffic: with it on, a Dota 2 client could not complete a match
accept (2026-10-28). There is no narrower record that keeps downloads cached.

So `dnsOverride` defaults to `false` and the cache is inert for clients:
frieren still answers any request that asks for the front by name, but nothing
is steered to it. Re-enabling is a decision about the whole zone, not a
performance tweak — and if a game is being played on the LAN while it is on,
that game is the experiment.

The split is deliberate. The cache lives on the **removable** USB flash tier
(`nofail`), so its unit is gated on `ConditionPathIsMountPoint` and nothing else
depends on it: when the stick is out the backend is simply not running, the
front answers 502, and its `error_page 502 504 = @valve` re-fetches the object
from Valve. A pulled drive costs the cache, never the LAN's downloads.

## Why the flash tier

Measured on frieren, 2026-10-27:

| | sequential read | 8 concurrent readers | per stream |
| :--- | ---: | ---: | ---: |
| USB flash (F2FS) | 331 MB/s | 236 MB/s | 29 MB/s |
| `/srv/data` (ST2000LX001 + zstd) | 76 MB/s | 67 MB/s | 8.3 MB/s |
| WAN (Hetzner / OVH 100 MB) | 5–7 MB/s | — | — |

The tier serves reads an order of magnitude faster than the internet and 3.5×
faster than the spindle, and it keeps cache traffic off the disk that answers
Jellyfin, Immich and the nightly restic push. Its write path is the weak point
(8–10 MB/s), which bounds a fill from the LAN but not one from the WAN.

## Operating it

```bash
# is the cache alive, and is it serving from cache?
curl -s http://127.0.0.1:8081/__health
curl -sI -H 'Host: steamcdn-a.akamaihd.net' \
  http://127.0.0.1/client/installer/steamcmd_linux.tar.gz | grep -i x-steam-cache

# how much is cached
du -sh /mnt/flash-cache/steam-cache; systemctl status steam-cache

# take the cache out of the path without touching the cache host
#   comment the two `address=` lines in hosts/frieren/dns.nix and switch
```

`X-Steam-Cache: MISS` on the first request and `HIT` on the second is the
end-to-end proof. A response with **no** `X-Steam-Cache` header at all came from
the `@valve` fallback — the backend is down or the stick is missing, and the
client still gets its bytes.

## Limits worth knowing

- **No login is involved anywhere in the cache.** It caches CDN responses; the
  Steam account only matters to the client. Prefill is the sole exception (see
  below), and it is optional.
- **100 GB cap** (`maxSize`) on the 118.5 GB tier, leaving ~18 GB for its own
  scratch (`jellyfin-transcode`, `immich-thumbs`, `nix-eval`). The cap has to
  sit **above the largest single install**, not just near it: below that, LRU
  eviction removes chunks of the build a client is still downloading and it
  re-fetches what it just fetched. Dota 2 is over 70 GB, so 70 GB was wrong.
- **Range responses are not cached** (no `slice` module): a client that asks for
  a byte range on a cold object is served from Valve. SteamPipe chunk fetches
  are whole objects, so this only costs the odd resume.
- **One resolver per client** matters: a machine with a second DNS server may
  get the public answer and silently skip the cache. The LAN hands out the VIP
  (`192.168.3.50`); the failover peer must carry the same `address=` lines or it
  answers with the public CDN (slower, still correct).

## Nightly prefill (optional, off by default)

The cache fills **on demand**, so a title nobody has asked for yet is empty when
the first client wants it. `services.steamCache.prefill` adds a `02:00` run of
[SteamPrefill](https://github.com/tpill90/steam-lancache-prefill) that fetches the
selected apps *through this cache*, spending the idle line instead of the
evening's.

| Piece | Where |
| :--- | :--- |
| `steam-prefill.service` | `oneshot`, `User` from `prefill.user`, `WorkingDirectory` `prefill.stateDir` |
| `steam-prefill.timer` | `OnCalendar` `prefill.calendar` (`02:00` on frieren), **not** persistent |
| App list + Steam token | `/var/lib/steam-prefill/Config/` (`selectedAppsToPrefill.json`, `account.config`) |

Gates, in order: the flash mount must be mounted, the app list must exist, and
`127.0.0.1:8081/__health` must answer. Without the last two, a prefill through a
dead cache would download from Valve at full speed, store nothing, and look
successful — the front falls back by design. The run is capped by
`prefill.maxRuntime`; prefill resumes where it stopped, so a closed window costs
time, not progress.

### One-time setup (needs a terminal, no GUI)

Steam will only hand out depots to an **authenticated account that owns the app**
— anonymity is not enough, even for free-to-play titles like Dota 2 (add it to
the library first). The selection itself is interactive, so it is done once by
hand:

```bash
# as devji, from the state dir — nixpkgs' build keeps `Config/` in the CWD,
# so the directory matters: it is where the token and the app list are saved.
cd /var/lib/steam-prefill
nix run nixpkgs#steam-lancache-prefill -- select-apps          # login, then space+enter to save
nix run nixpkgs#steam-lancache-prefill -- select-apps status   # total size of the selection
```

A scheduled run fills nothing until that file exists — it is the timer's
`ConditionPathExists`, and it is also the only way to know a login succeeded.

The token and the selection live in `Config/` beside that working directory, so
later runs need nothing: the timer prefills what was selected, skips apps that
are already current, and pulls only deltas afterwards (`--force` is never used
here).

### What a run costs

At 02:00 the WAN is 5–7 MB/s, so 100 GB would take ~4–5 h; the timer caps the run
at 3 h on frieren and the next night continues. Each completed title leaves the
stick write path (8–10 MB/s) as the LAN's ceiling, not the internet.
