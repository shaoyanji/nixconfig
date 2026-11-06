# Offloading a service off frieren

frieren is a laptop standing in for a server: 4c/8t, 11 GiB, and a 2 TB spindle
that everything media-shaped already competes for. delphi is a 2-OCPU/11 GiB
aarch64 VM that is idle most of the day. Moving *compute* there is cheap. Moving
`/srv/data` there is not, and never will be.

So "offload" has one meaning in this tree:

> the process and its state move; the NAS keeps the **name** and the **copy**.

That is what makes the move reversible. A service that leaves without a name
stranded on frieren is a service whose clients have to be re-taught; a service
that leaves without a copy is one whose only instance is in a datacentre.

## What the declaration buys

One block on the receiving host (`services.offloadBridge`, `modules/services/offload-bridge.nix`)
supplies all three halves:

| | |
| --- | --- |
| `sets` | every tree is mirrored nightly to `<root>/<set>/` on frieren (default `/srv/backup/offload`), with each SQLite database replaced by a `sqlite3 .backup` snapshot. frieren's restic window picks the mirror up at 03:28/03:30, so the off-box copy chain is unchanged. |
| `ingest` | a drop folder the service no longer hosts (the scanner's `consume`) is pulled here every 10 min. The humans' habit keeps working. |
| `migrate` | which units to stop on each side, the row count that proves the archive matches, and the URL that proves the service came back. |

Push: `bash scripts/task/offload-bridge.sh push`. Ingest:
`bash scripts/task/offload-bridge.sh ingest`. Both read
`/etc/offload-bridge/config.json`, generated from the module — a hand run and the
timer cannot disagree about where state goes.

Migration: `bash scripts/task/offload-migrate.sh <set> [--dry-run]`. It takes a
lock (`/run/lock/nixconfig-offload-migrate.lock`, non-blocking) so two cutovers
cannot interleave, records a manifest so a second run is a no-op instead of a
second copy, and refuses to announce success until `integrity_check` is `ok`, the
row count matches the source, and the service answers.

## The candidate ladder

Ask in this order; the first "no" usually decides.

1. **Does it own data that lives in `/srv/data`?** Then it stays. A 1.5 TB library
   over a tailnet is not a service move, it is a slow outage. *(immich, jellyfin,
   plex, kiwix, transmission, the \*arr stack)*
2. **Does it need a device on the NAS?** Zigbee radio, SMART data, the Steam flash
   tier. *(home-assistant, scrutiny, influxdb2, steam-cache)*
3. **Is there a single-writer credential?** A Telegram bot token cannot be polled
   by two hosts, so the order is copy → enable → stop → measure, in one window.
   *(hermes)*
4. **Is the closure buildable here?** Check before promising:
   `nix build --dry-run … .paperless-ngx` on delphi printed *20 derivations to
   build* (all pure Python) and 559 MiB to fetch. An uncached Rust/LLVM closure is
   a different answer — that is why stirling's first aarch64 build ran 40 min.
5. **Is it worth it?** 4 MiB and 36 MiB resident (vaultwarden) moves because it is
   the fleet's only other password-manager host, not because it saves RAM.

### Measured candidates (2026-11-02)

| Service | RSS | State | Verdict |
| --- | --- | --- | --- |
| paperless-ngx (+tika+gotenberg) | ~520 MiB | 722 MB SQLite+media, 455 documents | **moved** |
| vaultwarden | 36 MiB | 4.2 MB SQLite | **moved** |
| anki-sync-server | 430 MiB | 4 KB, placeholder user | **moved** — the best ratio in the fleet |
| hermes | 340 MiB | `~/.hermes` 226 MiB | waits on a bot-token window |
| immich | 337 MiB | 1.4 TB media + 155 MB pg | stays: family users, media on the NAS |
| jellyfin / plex | 111 MiB | media on the NAS | stays: iGPU transcode is on frieren |
| home-assistant | 117 MiB | Zigbee radio | stays: the USB stick is in the NAS |
| influxdb2 / scrutiny | 77 MiB | SMART + local history | stays: the data is the NAS's own disks |
| gatus | 24 MiB | 10 endpoint definitions | **moved** — the checks are delphi's `services.fleetMonitors` since 2026-11-04; frieren keeps only the alert bridge |
| uptime-kuma | 37 MiB | zero monitors on **either** host | **retired** on frieren 2026-11-04 — an empty dashboard, not a monitoring service |

## Cutover, in order

```bash
# 1. On the receiver: a build, not a promise. (delphi only — never compile on frieren.)
nix build ".#nixosConfigurations.delphi.config.system.build.toplevel?submodules=1"
# 2. Switch. The services come up empty; the dataset is still on the NAS.
sudo nixos-rebuild switch --flake .#delphi
# 3. Free the source's name and ports. Nothing on the receiver to restart: the
#    vhost on the NAS names this host's tailnet address directly.
ssh frieren 'sudo systemctl stop paperless-web paperless-task-queue paperless-consumer \
             paperless-scheduler vaultwarden anki-sync-server'
# 4. Move the state, twice. The second run proves idempotency.
sudo bash scripts/task/offload-migrate.sh paperless
sudo bash scripts/task/offload-migrate.sh paperless
# 5. Prove the door still works, from a client that is not the new host.
curl -sI -H 'Host: docs.frieren.lan' http://100.97.61.65/ | head -1
curl -sk https://vault.frieren.lan/alive
# 6. Land the copy on the NAS and check it.
sudo bash scripts/task/offload-bridge.sh push
ssh frieren 'sudo du -sh /srv/backup/offload/*'
```

Step 3 only works once frieren's closure carries the new vhosts, because the
repo config runs ahead of it until `task infra:deploy:host:frieren` lands. That
deploy is done (2026-11-02), and the transitional `offload-tunnel` on delphi is
deleted — the vhosts proxy straight to this host's tailnet address.

## Switching back

The NAS never stopped being the shelter, so "back" is a restore, not a rewrite:

1. `sudo systemctl stop <units>` on delphi.
2. Restore the union of `/srv/backup/offload/<set>` and the pre-move tree
   (`/var/lib/paperless`, `/var/lib/vaultwarden`, `/srv/backup/vaultwarden`) —
   both are in frieren's restic snapshots, which is why the old paths were kept.
3. Re-enable the block in `hosts/frieren/` (paperless: one import; vaultwarden:
   the commented struct in `infra-stack.nix`; anki: one block in `media-stack.nix`).
4. Rebuild frieren, then point its vhosts back at `127.0.0.1` in
   `hosts/frieren/reverse-proxy.nix`.

There is no tunnel to reinstate: the vhost's upstream address is the only
coupling, and it points at delphi or at the NAS's own loopback.

## Known edges

- **A relay offloads the fetch, not the file.** `media-relay` on delphi pulls
  YouTube on its own line and serves the tailnet; whether that beats pulling
  directly is still unproven — [docs/media-relay.md](./media-relay.md) records
  what would settle it.
- **The proxy is a dependency.** Both the transitional tunnel and the eventual
  vhosts mean frieren's nginx must be up for `docs.frieren.lan` and
  `vault.frieren.lan` to resolve. What was removed is the *state* and the *CPU*,
  not the front door.
- **An aarch64 build is not free.** paperless was 20 unsubstituted derivations and
  ~41 min of wall clock on 2 OCPU (spacy's thinc/blis compile C++); a Rust or LLVM
  closure would not have finished. Check with `nix build --dry-run` before
  promising a move.
- **`anki.frieren.lan` changed shape**: it was `host:27701`, it is now a vhost on
  port 80.
- **The anki account is no longer a placeholder.** It shipped as `bob`/`password`
  in plaintext in the Nix store; it now takes a 32-character password from sops
  through the module's `passwordFile` (rendered as a systemd credential, so the
  store carries a path and never a value).
  `sops -d modules/secrets.yaml | yq -r '.anki-sync.password'` reads or rotates it.
  Verified against the live server: `/sync/hostKey` answers 200 with an hkey for
  the sops password and 403 for `password`.
- **An upload replaces the whole collection**, and the served copy is schema 18
  (the server migrates on upload), so the base for a merge is the original
  schema-11 `.apkg`, not the download. Cards are authored in `decks/*.toml` —
  `b2.toml` (connectors, drills, telc briefing), `b2-schreiben-mock.toml` — and
  compiled by `anki-author` (`.#cli.learn.anki-author`), with
  `scripts/german/anki-push.sh --base B1_Wortliste….apkg decks/*.toml` doing the
  whole round trip: download for a backup, build each file over the previous
  output, upload, download again and print what is served. 2026-11-06: 5,376
  cards over six decks, 40 of them carrying a `req-` tag.

  **That upload discards review history**, because the build starts from the
  schema-11 base and the served collection is what accumulates reviews; the
  script refuses when the served copy has any card at `type != 0` unless
  `FORCE=1`. A file built without `--base` would take the 5,264 B1 cards with it.

  Protocol facts, all learned from `400`s: a v11 request is one `anki-sync` JSON
  header (`v`/`k`/`c`/`s`) plus a **zstd** body, `k` carries the hkey and empty on
  `hostKey`; `hostKey` wants `{"u":…,"p":…}` (not `username`/`password`) and
  `download` wants `{}`. With the header missing or the body uncompressed the
  server answers a bare `400`; a bad hkey is a `403`.
