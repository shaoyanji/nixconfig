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

## Prefill without touching LAN DNS

SteamPrefill refuses to run unless `lancache.steamcontent.com` resolves to an
RFC1918 address (exit 1, `LancacheNotFoundException`). The LAN must keep
resolving that name publicly — the `address=` override is what broke Dota 2
matchmaking — so the pin is given to **the prefill process only**, inside a
private mount namespace. Measured working on frieren 2026-10-28; the fill then
writes into the cache like any LAN client, with LAN DNS untouched throughout.

The pin is five `BindReadOnlyPaths` in `modules/services/steam-cache.nix` —
store paths in the closure, not files a script writes. Four of them are traps,
each verified by removing it and watching the fill fail:

1. **`/etc/nsswitch.conf` → `hosts: files dns`.** The host lists
   `mymachines mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files …`,
   so a hosts entry is consulted *after* systemd-resolved.
2. **`/etc/host.conf` → `multi off`.** With `multi on` glibc merges the public
   AAAA/A that DNS returns with the pinned IPv4, and the client may connect to
   the public one — a 33 GiB download that stores nothing.
3. **`/var/run/nscd` masked by an empty directory.** `nscd.service` (nsncd) is
   live on this host and answers from its own cache, so `/etc/hosts` is never
   read at all. This is the layer that made earlier attempts fail while every
   file looked correct.
4. **`X-LanCache-Processed-By` on `/lancache-heartbeat`.** Detection is not
   satisfied by a 200: the front (and the default vhost, because the probe sends
   the bare LAN IP as `Host:`) must return that header.

`resolv.conf` points at the fleet resolver, not `1.1.1.1`: detection reverse-
resolves the cache address, and the public resolver NXDOMAINs a LAN PTR.
`prefill.pinAddress` defaults to the host's `lan_ip` from the compiled
inventory, so the prefill lands on the same front a LAN client does.

Verifying the split takes one command — `getaddrinfo` is the API .NET uses:

```bash
systemctl show steam-prefill -p BindReadOnlyPaths --value   # the five mounts
systemd-run --pipe -p PrivateMounts=yes \
  -p "BindReadOnlyPaths=$(systemctl show steam-prefill -p BindReadOnlyPaths --value)" \
  python3 -c 'import socket; print(socket.getaddrinfo("lancache.steamcontent.com", 80)[0][4])'
```

Inside that namespace the name answers `192.168.3.25` and nothing else; on the
host the same call returns Valve's public addresses. `getent hosts` is *not* a
good probe here — with `multi off` it still prints the DNS AAAA while
`getaddrinfo`, which is what the client calls, returns only the pin.

The service-level gates still apply if the unit is ever enabled:
`ConditionPathExists` on the selected-apps file, `ExecCondition` on the backend's
`/__health`, and `TimeoutStartSec` (not `RuntimeMaxSec`, which a oneshot ignores)
as the bound.

One cosmetic wrinkle: detection reports `localhost [127.0.0.1]` rather than the
LAN address, because the probe sends the bare IP as `Host:` and the **atuin**
vhost claims `192.168.3.25` in `server_name`, so that request lands on atuin and
404s. The bytes still flow through this front, so the fill is correct; the
conflicting vhost is separate open work (`nginx -t` does not flag it — the first
block simply wins).

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

## Nightly prefill (unit always present; armed on frieren)

The cache fills **on demand**, so a title nobody has asked for yet is empty when
the first client wants it. `services.steamCache.prefill` adds a `02:00` run of
[SteamPrefill](https://github.com/tpill90/steam-lancache-prefill) that fetches the
selected apps *through this cache*, spending the idle line instead of the
evening's.

The unit exists whenever the cache does, and `prefill.enable` only arms the
timer — armed on frieren since 2026-10-28 (next elapse `02:00` + up to 5 min of
jitter). That split is what makes an ad-hoc fill one command: it runs the same
recipe the timer would, so there is no second, unreviewed copy to drift.

```bash
sudo systemctl start steam-prefill     # one fill now; the timer stays parked
```

| Piece | Where |
| :--- | :--- |
| `steam-prefill.service` | `oneshot`, `User` from `prefill.user`, `WorkingDirectory` `prefill.stateDir`, present whenever `steamCache.enable` |
| `steam-prefill.timer` | `OnCalendar` `prefill.calendar` (`02:00` on frieren), **not** persistent, only when `prefill.enable` |
| DNS pin | `prefill.pin` (`BindReadOnlyPaths` over `nsswitch.conf`, `host.conf`, `hosts`, `resolv.conf` + an empty `/var/run/nscd`), store paths in the closure |
| App list + Steam token | `/var/lib/steam-prefill/Config/` (`selectedAppsToPrefill.json`, `account.config`) |

Gates, in order: the flash mount must be mounted, the app list must exist, and
`127.0.0.1:8081/__health` must answer. Without the last two, a prefill through a
dead cache would download from Valve at full speed, store nothing, and look
successful — the front falls back by design. The run is capped by
`prefill.maxRuntime`; prefill resumes where it stopped, so a closed window costs
time, not progress.

### Run it when nobody is streaming, because it cannot be throttled

SteamPrefill has no rate-limit flag (checked against 3.6.1's `prefill --help`) and
takes the whole line:

| measured 2026-10-28 | while filling | after `SIGSTOP` |
| :--- | :--- | :--- |
| LAN `rx` on `enp1s0` | 5099 KiB/s (≈ 40 Mbit, pinned) | 31 KiB/s |
| `ping 1.1.1.1` | 33 % loss, 49 ms | 0 % loss, 12 ms |
| a house device resolving a cold name | reads as "the DNS is down" | fine |

The failure mode is worth naming because it does not look like bandwidth: the
fill eats the upstream, un-cached lookups time out **upstream**, and a TV
upstairs reports no internet while `dig @192.168.3.25 crunchyroll.com` answers
normally on the box. Stopping the run gives the line back in two seconds and
costs nothing — `SIGINT` to the SteamPrefill pid, then start it again; it skips
what is cached. Do **not** use `SIGSTOP` as a throttle: measured 2026-10-28, a
SIGSTOP/SIGCONT duty cycle left throughput unchanged at 3.3 MB/s and the process
never showed `T`, while `SIGINT` dropped the line to 8 KiB/s in 2 s. A signal
that cannot stop it cannot pace it.

State 2026-10-28 22:20: **complete.** Dota 2 linux depots, `Prefilled 1 apps
totaling 33.42 GiB in 35:27.37`, cache `40 → 45 GB` on a 100 GB cap with 74 GB
free on the tier. A run costs what it costs because it skips what the cache
already holds: the first 88 % came off the LAN at ~168 MB/min, and only the tail
fetched from Valve. Nothing needs to run again until the LRU evicts it.

State 2026-10-28 23:20: the same fill through the **unit** reports
`Updated 0 │ Up To Date 1` in 5.9 s — the depots it prefill already carries are
recognised, and the recipe that got there now lives in the module rather than in
`/var/lib/steam-prefill/pf-dota.sh` (deleted).

What a delta-only run costs, measured through the unit 2026-10-28 23:31 with the
cache warm: `Prefilled 1 apps totaling 0 b`, **77.4 KB in / 13.6 KB out** over
6.4 s. That is the number to expect at 02:00 whenever nothing on Valve's side has
rolled — a login, a manifest comparison, and no depot bytes.

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
