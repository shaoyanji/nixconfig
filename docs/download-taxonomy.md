# Download & Storage Taxonomy

How downloaded content enters the fleet and where it is allowed to live on the
NAS data pool (`/srv/data` on `frieren`, mounted fleet-wide at `/Volumes/data`).

The rule of thumb: **download clients stage into one quarantined directory; a
human (or the sort step below) moves each finished item into the taxonomy folder
for its kind.** Nothing is downloaded straight into a media-scanner-indexed tree.

## 1. Ingest doors (staging)

| Client | Host | Staging path | Notes |
| :--- | :--- | :--- | :--- |
| `aria2` (RPC + AriaNg) | `frieren` | `/srv/data/downloads` | Mode `0775 aria2:users`. HTTP/FTP/magnet/metalink. |
| `transmission-daemon` | `frieren` | `/srv/data/downloads` | Leech-only (see `hosts/frieren/transmission.nix`); seeds nothing. |
| `transmission-daemon` | `BurgerNAS` (DS220j) | `/volume1/downloads/complete` | NAS-local pool; offloads bulk ISO/dataset torrents off frieren's SSD. |
| `aria2` (RPC + AriaNg) | `BurgerNAS` (DS220j) | `/volume1/downloads/complete` | Second ingest door on the NAS — aria2 RPC `:6800`, AriaNg UI at `/ariang/` (CORS enabled for the browser). |

`/srv/data/downloads` is deliberately **not** indexed by Jellyfin/Plex and
carries no `.nomedia` marker of its own; it is ephemeral and expected to be
empty once items are sorted.

## 2. Sort destinations

| Content kind | Destination | Scanner policy |
| :--- | :--- | :--- |
| Movies / TV series | `/srv/data/arr` | **Indexed** by Jellyfin & Plex — clean video containers only (`.mkv`, `.mp4`, `.srt`). No archives, ISOs or installers. |
| Music / general media | `/srv/data/media` | Legacy mirror library. |
| OS images & installers (Linux/BSD/Boot ISOs, Pi images) | `/srv/data/isos` | Unindexed. |
| Academic papers, books, comics | `/srv/data/books` | Unindexed by video servers; indexed by `qmd` (document search). |
| Software installers, desktop utilities, fonts, tools | `/srv/data/software` | Unindexed. Torrented software goes to `software/torrents/` (guarded by `.nomedia` + `.plexignore`). |
| Device firmware / recovery ROMs | `/srv/data/devices` | Unindexed. |
| Language-learning material | `/srv/data/german` | `books/`, `audio/`, `notes/`. |
| Git checkouts & source dumps | `/srv/data/projects` | Working trees, not archives. |
| Standalone binaries / scripts / AppImages | `/srv/data/bin-*`, `/srv/data/appimages` | Lazily served across the fleet. |
| Private archives | `/srv/data/p/zhuomin`, `/srv/data/p/ppp` | `0700 devji:users`, `.nomedia` + `.plexignore`. |

## 3. The probe-failure trap (why the split exists)

Jellyfin/Plex invoke `ffprobe` on every file inside an indexed tree. A single
non-media file (an ISO, a zip, a `.deb`) inside `arr/` crashes the scanner with
recurring probe exceptions. Hence:

1. Only **video/subtitle** files belong in `arr/`.
2. `software/torrents/`, `books/`, `isos/` and `downloads/` must never be added
   to a media library.
3. Any directory that should never be indexed carries `.nomedia` **and**
   `.plexignore` sentinels.

## 4. Torrent policy (both clients)

Both Transmission instances are **leech-only** and are not seedboxes:

- `ratio-limit = 0` + `ratio-limit-enabled = true` → stops the instant a
  download reaches 100%.
- Upload capped at 1 kB/s (the protocol floor; `0` means *unlimited*).
- DHT/PEX/LPD and UPnP/NAT-PMP off; peer port not forwarded → the client never
  advertises itself to the public swarm.
- Intended for **open-access** material: Linux/BSD ISOs, Internet Archive items,
  `academictorrents.com` datasets, Kiwix ZIMs, open movie/audio releases.

After a download completes, move it from the staging dir to the destination in
§2 (e.g. `... .iso` → `/srv/data/isos`, a paper → `/srv/data/books`).

## 5. Automation

- `task data:audit` verifies taxonomy, permissions and media hygiene.
- `task data:clean:downloads` clears orphaned control files / empty staging dirs.
- The `software/torrents/` guard is enforced by `task data:protect:private` and
  the sentinel files listed above.

See also: the canonical storage table in [`AGENTS.md`](../AGENTS.md) and the
per-service notes in `modules/services/aria2-daemon.nix` and
`hosts/frieren/transmission.nix`.
