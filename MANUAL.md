# frieren — operator manual

> The service map for the live fleet mainframe, and the pointer for everything else.
> Design rationale is the note record (`task ops:notes`); what happened is the turn log
> (`task agents:xs:list`); agent routing is `AGENTS.md`; the sentinel runbook is the
> `fleet-sentinel` skill. Live truth is `ss -tlnp`, `systemctl status <unit>` and
> `task ops:health` — never this page.

## 1. Identity and access

Role, status, kind, LAN and tailnet addresses and every hardware field are compiled and
belong to no markdown file: read the generated host card (`docs/generated/hosts/frieren.md`,
built by `lib/docs.nix` and served by the docs site) or ask
`nix eval --json .#inventory.hosts.frieren | toon -e`.

What the registry does not hold, and this page therefore keeps:

- DNS: Pi-hole + unbound here; wildcard `*.frieren.lan` → `192.168.3.25`.
- SSH: `ssh frieren`, CA-signed user certs (`ssh.ca.enableClient`).
- Storage: `/srv/data` ↔ `/Volumes/data` (bind mount + NFS export; `docs/storage-taxonomy.md`).
- Watchdog: the battery is the UPS; UPower clean poweroff at 5 %.

The tailnet address is the only dual-homed identity. `*` below marks a service reached
through nginx on port 80/443.

## 2. Service inventory (audited 2026-11-28)

### Core platform

| Service | Unit | Listen | Reach |
| :--- | :--- | :--- | :--- |
| SSH | `sshd` | 22 | `ssh frieren` |
| Nginx portal/reverse proxy | `nginx` | 80, 443 | `http://frieren.lan/` |
| Tailscale | `tailscaled` | — | tailnet |
| DNS (ad-block + local) | `pihole-ftl`, `unbound` | 53, 5335 | router → frieren |
| NFS | `nfs-mountd`, `rpc-statd`, `nfs-idmapd` | 2049 (+ pinned 20048/32765/32766, 111 accepted) | fleet mounts |
| Samba | `samba-smbd`, `samba-nmbd`, `samba-winbindd`, `samba-wsdd` | 139, 445 | Finder/Explorer |
| Avahi | `avahi-daemon` | 5353/udp | zero-conf discovery |
| PostgreSQL | `postgresql` | 5432 | Immich; the fleet turn/note projection |
| Docker | `docker` | — | container workloads |
| Nix daemon | `nix-daemon` | — | builds/store |

### Storage, backup, cache

| Service | Unit | Listen | Reach / note |
| :--- | :--- | :--- | :--- |
| Harmonia LAN cache | `harmonia` | 5000 | `cache.frieren.lan`*, `nix.settings.substituters` |
| Restic (local) | `restic-backups-frieren-local.timer` | — | `/srv/backup/restic` |
| Restic (BurgerNAS) | `restic-backups-frieren-burgernas.timer` | — | SFTP + WoL/poweroff |
| Restic drill | `restic-drill.timer` | — | weekly `check` + sampled restore |
| Checkout fast-forward | `checkout-ff.timer` | — | 02:45, `/Volumes/data/projects/{nixconfig,bountystash-console}` |
| PostgreSQL backup | `postgresqlBackup-immich.timer` | — | 03:00 |
| SMART | `smartd`, `scrutiny` | 8124 | `smart.frieren.lan`* |
| Btrfs watchdog | `btrfs-watchdog.timer` | — | `modules/services/btrfs-watchdog.nix` |
| Snapshot/sqlite/ups drills | `sqlite-maintenance`, `ups-simulation-drill` | — | timers from graduated experiments |
| InfluxDB (Scrutiny) | `influxdb2` | 8086 loopback | metrics for Scrutiny |

### Media and documents

| Service | Unit | Listen | Reach |
| :--- | :--- | :--- | :--- |
| Jellyfin | `jellyfin` | 8096 | `media.frieren.lan`* |
| Plex | `plex` | 32400 | direct LAN/tailnet port |
| Audiobookshelf | `audiobookshelf` | 13378 | `audiobooks.frieren.lan`* |
| Immich | `immich-server`, `immich-machine-learning`, `redis-immich` | 2283 | `photos.frieren.lan`* |
| Paperless-ngx | `paperless-web`, `-consumer`, `-scheduler`, `-task-queue` on **delphi** | 28981 tailnet | `docs.frieren.lan`* (moved off frieren 2026-11-02; frieren keeps the vhost and the shelter copy) |
| Gotenberg / Tika | `gotenberg`, `tika` on **delphi** | loopback | Paperless helpers, now beside paperless |
| Stirling PDF | `stirling-pdf` on **delphi** | 7351 loopback / 8445 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8445` (moved off frieren 2026-10-21; `pdf.frieren.lan` no longer serves it) |
| *arr stack | `sonarr`, `radarr`, `lidarr`, `readarr`, `prowlarr` | 8989/7878/8686/8787/9696 | LAN, library hygiene |
| Transmission | `transmission` | 9091 loopback | `torrent.frieren.lan`* (leech-only) |
| aria2 | `aria2` | 6800 loopback, 6801 LAN/tailnet | `aria.frieren.lan`* |
| Anki sync | `anki-sync-server` on **delphi** | 27701 tailnet | `anki.frieren.lan`* (moved 2026-11-02; was `anki.frieren.lan:27701`) |

### Knowledge, automation, fleet

| Service | Unit | Listen | Reach |
| :--- | :--- | :--- | :--- |
| Kiwix (Wikipedia/ArchWiki) | `kiwix-serve` | 8088 | `wiki.frieren.lan`* |
| Home Assistant | `home-assistant` | 8123 | `ha.frieren.lan`* |
| Gatus | `gatus` on **delphi** | 8181 tailnet | `http://delphi.cloudforest-kardashev.ts.net:8181` |
| Fleet sentinel | `fleet-sentinel.timer` | via nginx | `sentinel.frieren.lan`* → `/sentinel/` |
| Pastebin | `nginx` + `/var/lib/paste` | 80 | `paste.frieren.lan`* |
| iVentoy (PXE/ISO) | `iventoy` | 26000, 16000, 10809 | `http://frieren.lan:26000` |
| Vaultwarden | `vaultwarden` on **delphi** | 8222 tailnet | `vault.frieren.lan`* (moved 2026-11-02; DOMAIN unchanged so passkeys survive) |
| SimpleX SMP relay | `smp-server` | 5223 | inter-agent messaging |
| Atuin history sync | `atuin` | 8888 loopback | `atuin.frieren.lan`*; one account, sign-ups closed [[flake/policies.nix#history-sync-is-one-server]] |
| Miniflux | `miniflux` on **delphi** | 8098 loopback / 8455 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8455` — feeds, not mail (added 2026-11-06) |
| Umami | `umami` on **delphi** | 8061 loopback / 8456 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8456` — first-party analytics, tailnet-only by decision: it cannot collect from public pages |
| Radicale | `radicale` on **delphi** | 5232 loopback / 8457 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8457` — CalDAV/CardDAV; `htpasswd` rendered at start from sops, rights `owner_only`, a `personal` collection seeded by the unit so the principal is never empty; client is `accounts.calendar.accounts.radicale`, phone is DAVx5, gate is `checks:caldav` |
| ntfy | `ntfy` on **delphi** | 8096 loopback / 8458 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8458` — push to the phone: one user `fleet` (sops) with rights on topic `fleet`, anonymous denied. Publishers: the appflow sync (a parked question), `fleet-sentinel` (a state change, hashed so a repeated verdict posts once) and `checks:ntfy`. gatus pages through the SimpleX bridge, not here |
| Vikunja | `vikunja` on **delphi** | 8097 loopback / 8459 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8459` — tasks, CalDAV and a REST API; JWT secret from sops |
| Ollama | `ollama` | 11434 | local inference (if enabled) |
| LLM decision router | `llm-decision-router` on **eisen** | 8000 loopback | `eisen` upstream, not on frieren |

> Orientation only. `ss -tlnp` and `systemctl status <unit>` are the live truth, and
> `.agents/SCHEMA.md` §1 forbids a second fleet table — this is the service map, not a copy of
> `inventory.toml`. The service map is compiled: `docs/generated/fleet-services.md` lists
> every registry port with the hosts that enable it, every endpoint a host declares in
> `network.links`, and every service a host declares in `software.services`. Unit names
> and reach URLs stay prose because no compiled source owns them.

## 3. The closed loop, and the agent context

`fleet-sentinel` records failed units, the watched oneshots, generation age, disk and PSI
every 15 min into `/var/lib/fleet-sentinel/ledger.jsonl` and `status.json`, and renders
`sentinel.frieren.lan`; gatus asserts `[BODY].state == ok` and pages through the SimpleX
bridge after three failures. Read it before blaming a host:

```bash
task ops:health            # exit 1 when degraded
task ops:ledger:toon       # TOON projection, fewer tokens
task ops:sentinel:status   # timer + last run
```

The failure modes, the branches (`failed-units`, `unit-failed`, `generation-stale`,
`disk-high`) and the recovery commands are the `fleet-sentinel` skill.

Agent context is compiled, not written down: `.#agentSkills`, `.#agentsNotes`,
`.#knowledgeGraph`. Query with `task ops:kg`, `task ops:ask Q="…"` (deterministic and
offline — no model in the path; `KG_DECIDE_ALWAYS=1` opts into one as an agreement check)
and `task ops:context`. `task ops:bench:kg` is the re-runnable evidence for that routing
choice, and the `knowledge-base` skill says which store answers what. `~/AGENTS.md` is
`.#homeAgents.<host>` (a store symlink); there is no Python generator left to keep in sync.

## 4. The trap worth knowing

A successful `nixos-upgrade` with no new generation looks healthy. `system.autoUpgrade`
builds from the pushed GitHub flake, so a dirty-tree local switch is reverted by the 04:00
run, and `generation-stale` is the only signal that notices:

```bash
journalctl -u nixos-upgrade -n 40 --no-pager | grep -E 'unpacking|new configuration'
git -C /Volumes/data/projects/nixconfig rev-parse HEAD
```

## 5. Desktop integration (DMS / Niri)

The proposed DMS widget would read `http://127.0.0.1:80/sentinel/status.json` — state, generation age, the
first two reasons — with palette `ok #a6e3a1`, `degraded #f38ba8`, accent `#89b4fa`, one
notification on transition and one on resolution, never per poll. It is the `p5-dms-widget` proposal in the note record; until then `task ops:health` is the desktop-agnostic path.

## 6. Runbooks

```bash
task infra:rebuild:nixos               # local: NO pre-flight gate, the switch is the build
task infra:deploy:host:<host>          # remote: gate → plan → apply → validate
task infra:warm:cache                  # all managed hosts → harmonia
task checks:restic:drill               # backup: on-demand check + sampled restore
nas-recover                            # canonical NAS mount recovery
```

Do not rebuild in the 03:00–05:30 window, do not start a second `nixos-rebuild`, and check
`pgrep -af 'nix build .*nixosConfigurations'` for an orphan before retrying. Deploy,
rollback, journald `UNIT` defaults, store maintenance and the sops planes are the `infra`
skill plus `.agents/deploy/hosts/*.md`.

## 7. Known limits

- Sentinel collectors run on frieren, delphi and poseidon and push into frieren's ingest; fleet-wide coverage remains `p1-sentinel-push` (IN FLIGHT).
- DNS has two members (HC-3): frieren primary, minyx backup behind `192.168.3.50`.
  `checks:dns:failover` probes the VIP, so it names a real owner only from the LAN's L2.
- Mosquitto is off since 2026-11-09 after a zero-client week; re-enable it with the ESP32/Zigbee layer rather than treating HC-5 as a live broker.
- `cassini` is preserved/dormant and its darwin projection passes eval; `minyx` is active as DNS failover, with under-voltage/throttling recorded in its inventory notes.
- Uptime Kuma is retired; gatus on delphi is the declarative monitor.

## 8. Where to go next

| Question | Command / file |
| :--- | :--- |
| Is anything degraded? | `task ops:health` |
| What happened recently? | `task agents:xs:list LIMIT=20`, `task ops:ledger` |
| What is being proposed? | `task ops:notes KIND=proposal` |
| What is open? | `task ops:notes KIND=open`, `task ops:notes KIND=handoff` |
| What can an agent do? | `task ops:skills`, `.agents/README.md` |
| Why does this host exist? | `nix eval --json .#inventory.hosts.frieren \| toon -e` |
