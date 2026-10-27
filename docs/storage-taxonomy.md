# Storage Taxonomy

The persistent pool is `/srv/data` on `frieren`, mounted fleet-wide at
`/Volumes/data` by [`modules/profiles/nas-client.nix`](../modules/profiles/nas-client.nix).
This page is the only place the path table lives; the manual points here.

## Layout

| Path (`/srv/data/`)                       | Holds                                                | Indexing & access                                                                                      |
| :---------------------------------------- | :--------------------------------------------------- | :----------------------------------------------------------------------------------------------------- |
| `arr/`                                    | Movies and TV series                                 | **Indexed by Jellyfin & Plex.** Video containers only (`.mkv`, `.mp4`, subs).                          |
| `media/`                                  | Primary media library mirror                         | Legacy direct media; indexed where a library points at it.                                            |
| `software/`                               | Installers, desktop utilities, fonts, tools           | Unindexed. Torrented software lives in `software/torrents/`, shielded by sentinels.                    |
| `books/`                                  | Books, papers, theses, comics                        | Unindexed by video servers; indexed by `qmd`. `programming/ philosophy/ ai/ science/ comics/`.         |
| `isos/`                                   | OS images and installers                             | Linux, appliances (`opnsense`, `openwrt`), Raspberry Pi images. Unindexed.                              |
| `german/`                                 | Language learning                                    | `books/ audio/ notes/`.                                                                                |
| `devices/`                                | Device firmware and recovery ROMs                    | Hardware payloads (e.g. OnePlus 6 recovery tools).                                                     |
| `projects/`                               | Git checkouts and source dumps                       | Working trees, not archives (`nixconfig`, `bountystash-web`, `gpt2099.nu`).                            |
| `bin-x86/ bin-aarch64/ bin-script/`       | Standalone binaries and scripts                      | Served across the fleet over NFS/HTTP without a Nix derivation. Release builds are one table, not a pile of commands [[flake/policies.nix#library-table-generated]]; every row pins its asset per arch [[flake/policies.nix#library-row-pins-its-arch]]. |
| `appimages/`                              | Portable Linux applications                         | Lazily served across the network. The one library dir that accepts a dynamic binary, since an AppImage carries its payload. |
| `downloads/`                              | aria2 + transmission staging                         | `0775 aria2:users`, ephemeral, never indexed; sorted out after each download.                           |
| `p/zhuomin`                               | Private archives                                    | `0700 devji:users`, sentinel-shielded, kept for private review.                                        |
| `p/ppp`                                   | Private stash                                       | `0700 devji:users`, sentinel-shielded, never scanned.                                                  |
| `security/`                               | Credentials, recovery keys, certificates            | `0700 devji:users` (`0600` files). Never exposed to a network guest.                                   |
| `p/web`, `storage/`                       | Backward-compatibility symlinks                      | `p/web → projects/bountystash-web`; `storage → .` so `/Volumes/data/storage/...` resolves.              |

## Media scanner rules

Jellyfin and Plex run `ffprobe` on every file inside an indexed tree; one ISO,
zip or `.deb` in `arr/` crashes the scanner with recurring probe exceptions. So:

1. Only video and subtitle files belong in `arr/`.
2. `software/torrents/`, `books/`, `isos/` and `downloads/` are never added to a
   media library.
3. A directory that must never be indexed carries **both** `.nomedia` and
   `.plexignore`; a missing half is still a scan.
   [[flake/policies.nix#media-tree-isolation]]

## Permissions and privacy

`p/zhuomin`, `p/ppp` and `security/` are `0700 devji:users`, and only
`security/` holds private key material at `0600`. `task data:protect:private` is
the writer, `task data:audit` the check, and neither is advisory: a widened mode
is a finding, not a preference. [[flake/policies.nix#private-trees-restricted]]

Secrets themselves are **not** stored in the taxonomy. `modules/secrets.yaml`
(SOPS) is canonical; TOTP lives under `.cloak` (`task dev:cloak:*`); the master
key is `id_ed25519` at `0600` in `security/`, published encrypted as
`id_ed25519.age` to the fleet age keys. `security/gist.nu` is the universal
NuShell fallback: it finds `apikeys.yaml` in the standard workspaces and decrypts
with whichever age identity exists (`~/.config/sops/age/keys.txt`,
`~/.ssh/id_ed25519`, a local security key). Rekeying is
[`sops-rekey.md`](./sops-rekey.md).

## Ingest and sorting

Clients stage into one quarantined directory; a human or the sort step moves each
finished item into the folder for its kind. Nothing downloads straight into an
indexed tree.

| Client                | Host                 | Staging                          | Notes                                                  |
| :-------------------- | :------------------- | :------------------------------- | :----------------------------------------------------- |
| `aria2` (RPC, AriaNg) | `frieren`            | `/srv/data/downloads`            | HTTP/FTP/magnet/metalink; AriaNg UI via nginx.          |
| `transmission-daemon` | `frieren`            | `/srv/data/downloads`            | Leech-only (`hosts/frieren/transmission.nix`).          |
| `transmission-daemon` | `BurgerNAS` (DS220j) | `/volume1/downloads/complete`    | Offloads bulk ISO/dataset torrents off frieren's SSD.   |
| `aria2` (RPC, AriaNg) | `BurgerNAS` (DS220j) | `/volume1/downloads/complete`    | RPC `:6800`, AriaNg at `/ariang/` (CORS for browser).   |

Both transmission instances are leech-only, never seedboxes: `ratio-limit = 0`
with `ratio-limit-enabled = true` stops at 100 %, upload is capped at the 1 kB/s
floor (`0` would mean unlimited), DHT/PEX/LPD and UPnP/NAT-PMP are off, and the
peer port is not forwarded. Intended material is open-access: Linux/BSD ISOs,
Internet Archive items, `academictorrents.com` datasets, Kiwix ZIMs, open
movie/audio releases.

## Automation

| Task                      | What                                                                   |
| :------------------------ | :--------------------------------------------------------------------- |
| `task data:audit`         | taxonomy, permissions, `arr/` hygiene, sentinels, metadata noise        |
| `task data:sort`          | sort finished staging items into their kind's tree (dry-run unless `--apply`; `--classify` asks a model when the rules cannot place an item) |
| `task data:protect:private` | writes `0700` and plants `.nomedia` + `.plexignore`                  |
| `task data:clean:downloads` | orphaned control files and empty staging directories                 |
| `task data:clean:metadata`  | `._*`, `.DS_Store`, `@eaDir`                                          |
| `task data:status`        | audit + index refresh summary                                          |

The scripts behind them (`scripts/task/data-ops.sh`) are the enforcement, so the
table above is a description, not a second source of truth:
[[flake/policies.nix#taxonomy-one-home]].
