# frieren — Operator Manual

> The manual for the live fleet mainframe: what is running, how to reach it, what
> is new, and how to tell whether the config actually worked. Design rationale is
> in `ARCHITECTURE.md`; per-change history is in `AUDIT.md`; agent routing is in
> `AGENTS.md`.

## 1. Identity and access

| Property | Value |
| :--- | :--- |
| Role | Central NAS, media/service host, fleet cache and build coordinator |
| Hardware | Lenovo IdeaPad 320-15IKB · i5-8250U (4c/8t) · 11.47 GiB RAM · 1 TB SSD + 2 TB HDD |
| LAN | `192.168.3.25` (`frieren.lan`, `nas.frieren.lan`, `frieren`) |
| Tailnet | `frieren` / `100.97.61.65` |
| DNS | Pi-hole + unbound on frieren; wildcard `*.frieren.lan` → `192.168.3.25` |
| SSH | `ssh frieren` (CA-signed user certs; `ssh.ca.enableClient`) |
| Storage | `/srv/data` ↔ `/Volumes/data` (bind mount + NFS export) |
| Watchdog | hardware battery acts as a UPS; UPower clean poweroff at 5 % |

**Never assume the LAN.** The tailnet address is the only dual-homed identity.
`*` below marks a service reached through nginx on port 80/443.

## 2. Service inventory (live, 2026-10-19)

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
| PostgreSQL | `postgresql` | 5432 | Immich, Paperless |
| Docker | `docker` | — | container workloads |
| Nix daemon | `nix-daemon` | — | builds/store |

### Storage, backup, cache

| Service | Unit | Listen | Reach / note |
| :--- | :--- | :--- | :--- |
| Harmonia LAN cache | `harmonia` | 5000 | `cache.frieren.lan`*, `nix.settings.substituters` |
| Restic (local) | `restic-backups-frieren-local.timer` | — | `/srv/backup/restic` |
| Restic (BurgerNAS) | `restic-backups-frieren-burgernas.timer` | — | SFTP + WoL/poweroff |
| Restic drill | `restic-drill.timer` | — | weekly `check` + sampled restore |
| PostgreSQL backup | `postgresqlBackup-immich.timer` | — | 03:00 |
| SMART | `smartd`, `scrutiny` | 8124 | `smart.frieren.lan`* |
| Btrfs watchdog | `btrfs-watchdog.timer` | — | `modules/services/btrfs-watchdog.nix` |
| Snapshot/sqlite/ups drills | `sqlite-maintenance`, `ups-simulation-drill` | — | timers from graduated experiments |
| InfluxDB (Scrutiny) | `influxdb2` | 8086 loopback | metrics for Scrutiny |

### Media and documents

| Service | Unit | Listen | Reach |
| :--- | :--- | :--- | :--- |
| Jellyfin | `jellyfin` | 8096 | `media.frieren.lan`* |
| Plex | `plex` | 32400 | `plex.frieren.lan`* |
| Audiobookshelf | `audiobookshelf` | 13378 | `audiobooks.frieren.lan`* |
| Immich | `immich-server`, `immich-machine-learning`, `redis-immich` | 2283 | `photos.frieren.lan`* |
| Paperless-ngx | `paperless-web`, `-consumer`, `-scheduler`, `-task-queue`, `redis-paperless` | 28981 | `docs.frieren.lan`* |
| Gotenberg / Tika | `gotenberg`, `tika` | loopback | Paperless helpers |
| Stirling PDF | `stirling-pdf` | 8080-ish | `pdf.frieren.lan`* |
| *arr stack | `sonarr`, `radarr`, `lidarr`, `readarr`, `prowlarr` | 8989/7878/8686/8787/9696 | LAN, library hygiene |
| Transmission | `transmission` | 9091 loopback | `torrent.frieren.lan`* (leech-only) |
| aria2 | `aria2` | 6800/6801 loopback | `aria.frieren.lan`* |
| Anki sync | `anki-sync-server` | 27701 | `anki.frieren.lan`* |

### Knowledge, automation, fleet

| Service | Unit | Listen | Reach |
| :--- | :--- | :--- | :--- |
| Kiwix (Wikipedia/ArchWiki) | `kiwix-serve` | 8088 | `wiki.frieren.lan`* |
| Home Assistant | `home-assistant` | 8123 | `ha.frieren.lan`* |
| Mosquitto | `mosquitto` | 1883 loopback | no authenticated subscriber yet (HC-5) |
| Uptime Kuma | `uptime-kuma` | 3001 | `status.frieren.lan`* (dashboard only, 0 monitors) |
| Gatus | `gatus` | 8181 loopback | `monitors.frieren.lan`* |
| Fleet sentinel | `fleet-sentinel.timer` | via nginx | `sentinel.frieren.lan`* → `/sentinel/` |
| Pastebin | `nginx` + `/var/lib/paste` | 80 | `paste.frieren.lan`* |
| iVentoy (PXE/ISO) | `iventoy` | 26000, 10809 | `pxe.frieren.lan`* |
| Vaultwarden | `vaultwarden` | 8222 loopback | `vault.frieren.lan`* |
| SimpleX SMP relay | `smp-server` | 5223/5225/5226 | inter-agent messaging |
| Ollama | `ollama` | 11434 | local inference (if enabled) |
| LLM decision router | `llm-decision-router` | 8080-ish | `eisen` upstream, not on frieren |
| Antigravity remote control | `antigravity-cli-daemon` (user) | — | 24/7 remote operator |

> The *arr stack and Stirling's port are recorded for orientation. Use
> `ss -tlnp` and `systemctl status <unit>` as the live truth; do not copy this
> table into another doc — `SCHEMA.md` §1 forbids a second fleet table.

## 3. What is new (2026-10-19)

### 3.1 `fleet-sentinel` — the closed loop

**The gap it closes:** gatus watched sockets, not jobs. A 03:30 restic run that
failed, or a 04:00 `autoUpgrade` that produced no new generation, looked exactly
like a healthy host.

- Every 15 min, `fleet-sentinel.service` records: failed units, the `Result` of
  the watched oneshots (`nixos-upgrade`, `fleet-warm-cache`, both restic jobs,
  `restic-drill`, `postgresqlBackup-immich`), generation age, disk %, and PSI.
- Writes `/var/lib/fleet-sentinel/ledger.jsonl` (bounded 10 000 lines),
  `status.json`, and a static dashboard.
- `sentinel.frieren.lan` renders it (Catppuccin Mocha, no new daemon).
- gatus asserts `[BODY].state == ok` on `status.json`; its SimpleX bridge pages
  after 3 failures and sends a resolved notice.

```bash
task ops:health            # exit 1 when degraded
task ops:ledger            # events, JSONL
task ops:ledger:toon       # TOON projection (fewer tokens)
task ops:sentinel:status   # timer + last run
```

### 3.2 Compiled agent context

- `.#agentSkills` / `.#agentSkillsBundle`: 43 skills parsed from frontmatter,
  schema-gated by `checks.<system>.skills-schema`; materialized to
  `~/.agents/skills` and `~/.gemini/config/skills` by Home Manager.
- `.#knowledgeGraph`: 34 hosts × 43 skills × 21 docs, 416 mention edges;
  `task ops:kg`, `task ops:kg:host HOST=<h>`.
- `.agents/SCHEMA.md`: one fact one home, document budgets, status vocabulary.

### 3.3 Documentation split

| File | Job |
| :--- | :--- |
| `AGENTS.md` | agent invariants + verification protocol |
| `MANUAL.md` | this operator guide |
| `ARCHITECTURE.md` | proposals, ADRs, rejected options |
| `AUDIT.md` | current state + change ledger |
| `TODO.md` / `HANDOFF.md` | bounded open-work queues |
| `EXPERIMENTS.md` | archived design studies + status index |
| `docs/history/` | superseded narrative (audit/TODO/HANDOFF) |

## 4. The failure loop, end to end

```
unit fails / generation stale / disk high / PSI high
        │
        ▼
fleet-sentinel collect (15 min) ──► ledger.jsonl + status.json
        │                                   │
        │                                   ├─► gatus [BODY].state == ok
        │                                   │        └─► SimpleX bridge (3x)
        │                                   └─► sentinel.frieren.lan (human)
        ▼
task ops:health (agent gate)
        │
        ├─ failed-units ──► systemctl --failed; journalctl -u <unit>
        ├─ unit-failed    ──► journalctl -u <unit>; check inputs (disk/net/secrets)
        ├─ generation-stale ──► journalctl -u nixos-upgrade; check git rev vs running
        └─ disk-high      ──► task dev:closure:size; GC/snapshot prune
```

**The trap this catches:** a successful `nixos-upgrade` with no new generation.
`system.autoUpgrade` builds from the pushed GitHub flake, so a local dirty-tree
switch is reverted by the next 04:00 run. `generation-stale` is the only signal
that notices. Confirm with:

```bash
journalctl -u nixos-upgrade -n 40 --no-pager | grep -E 'unpacking|new configuration'
git -C /Volumes/data/projects/nixconfig rev-parse HEAD
```

## 5. Desktop integration (DMS / Niri)

The host runs Niri via `greetd`/`dms-greeter`. The sentinel should be *present*,
not a browser tab:

| Element | Design |
| :--- | :--- |
| DMS widget | reads `http://127.0.0.1:80/sentinel/status.json`; shows state, generation age, first two reasons |
| Palette | `ok #a6e3a1`, `degraded #f38ba8`, accent `#89b4fa` (same tokens as the dashboard) |
| Notification | one on transition (3 failures, matching gatus), one on resolution; never per poll |
| Menu | Kando/DMS entry `fleet status` → `sentinel.frieren.lan` |
| Alternative | a Quickshell/Waybar module works, but maintaining two widgets is the anti-pattern; DMS is the fleet standard |

Implementation is P5 in `ARCHITECTURE.md`; the widget is a config file, not a
new service. Until then, `task ops:health` is the desktop-agnostic path.

## 6. Runbooks

### Deploy / rebuild

```bash
# Local rebuild: NO pre-flight check. The switch evaluates and builds.
task infra:rebuild:nixos

# Remote host: the deploy gate is the check for that one host.
task infra:deploy:host:<host>          # gate → plan → apply → validate

# Routing audit (CI/operator only: forces the whole toplevel, never chain it
# in front of a rebuild):
task checks:build:route
```

### Cache warming

```bash
task infra:warm:cache                  # all managed hosts → harmonia
task infra:update:fleet                # flake update → warm → apply
task checks:build:route                # would THIS host compile? (HTTP only)
```

### Backup verification

```bash
task checks:restic:drill               # on-demand check + sampled restore
systemctl status restic-drill.service  # last unit run
```

### NAS mount recovery

```bash
nas-recover                            # canonical recovery
sudo systemctl restart Volumes-data.automount
```

### Sentinel is red

```bash
task ops:ledger | jq -r 'select(.state=="degraded") | .ts + " " + (.reasons|join(","))'
systemctl --failed --no-legend
systemctl list-timers --all | grep -E 'restic|nixos-upgrade|fleet'
df -h / /nix/store /srv/data
```

Do **not** rebuild in the 03:00–05:30 window; do not start a second
`nixos-rebuild` while one is running; check `pgrep -af 'nix build .*nixosConfigurations'`
for an orphan before retrying.

## 7. Known limits

- Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
- DNS has one resolver (HC-3); `checks:dns:failover` exits 2 by design.
- MQTT has no subscriber (HC-5); HA needs one config-entry action.
- `minyx` and `cassini` fail their per-host gate; both are dormant.
- Uptime Kuma still has zero monitors; gatus is the declarative monitor.
- `~/AGENTS.md` is `.#homeAgents.<host>` (a store symlink); the offline fleet-matrix table still uses `compile-llm-specs.py`.

## 8. Where to go next

| Question | Command / file |
| :--- | :--- |
| Is anything degraded? | `task ops:health` |
| What happened recently? | `task ops:ledger`, `AUDIT.md` |
| What is being proposed? | `ARCHITECTURE.md` |
| What is open? | `TODO.md`, `HANDOFF.md` |
| What can an agent do? | `task ops:skills`, `.agents/README.md` |
| Why does this host exist? | `nix eval --json .#inventory.hosts.frieren` |
