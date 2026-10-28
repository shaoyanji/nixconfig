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
| DNS override | `hosts/frieren/dns.nix` — `address=/steamcontent.com/…` and `address=/steamcdn-a.akamaihd.net/…` |
| Health | gatus endpoint `steam cache` → `http://127.0.0.1:8081/__health` |

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
end-to-end proof. `BYPASS` means the front fell back to Valve — the backend is
down or the stick is missing.

## Limits worth knowing

- **70 GB cap** (`maxSize`): Dota 2 plus a season of deltas, and it leaves the
  tier's own scratch (`jellyfin-transcode`, `immich-thumbs`, `nix-eval`) room.
  When the cap is hit, least-recently-used objects are evicted.
- **Range responses are not cached** (no `slice` module): a client that asks for
  a byte range on a cold object is served from Valve. SteamPipe chunk fetches
  are whole objects, so this only costs the odd resume.
- **One resolver per client** matters: a machine with a second DNS server may
  get the public answer and silently skip the cache. The LAN hands out the VIP
  (`192.168.3.50`); the failover peer must carry the same `address=` lines or it
  answers with the public CDN (slower, still correct).
- **Prefilling needs no GUI.** The cache itself needs no login at all — clients
  log into Steam as usual. `pkgs.steam-lancache-prefill` (`steam-lancache-prefill
  login <user>`) prompts for the password and Steam Guard code in a terminal and
  caches the refresh token, so later runs are unattended; Dota 2 (570) is
  free-to-play and downloads anonymously, so a prefill normally needs no account.
