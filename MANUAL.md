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
| Stirling PDF | `stirling-pdf` on **delphi** | 7351 loopback / 8445 tailnet | `https://delphi.cloudforest-kardashev.ts.net:8445` (moved off frieren 2026-10-21; `pdf.frieren.lan` no longer serves it) |
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
| Atuin history sync | `atuin` | 8888 loopback | `atuin.frieren.lan`*; one account, sign-ups closed [[flake/policies.nix#history-sync-is-one-server]] |
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

- `.#agentSkills` / `.#artifacts.agent-skills-bundle`: 43 skills parsed from frontmatter,
  schema-gated by `checks.<system>.skills-schema`; materialized to
  `~/.agents/skills` and `~/.gemini/config/skills` by Home Manager.
- `.#knowledgeGraph`: hosts × skills × docs × tag links, compiled from the
  files on every eval; `task ops:kg` prints the live counts and
  `task ops:kg:host HOST=<h>` the inbound edges. Counts are not stored here —
  they drift with every doc edit, and a frozen number is a lie.
- `task ops:ask Q="what touches frieren"` — an English question routed to a jq
  query over `.#knowledgeGraph.graph` (a 50 KB store artifact, cached per
  revision). Routing is **deterministic and offline**; no model is in the path.
- `task ops:bench:kg [--set rule|paraphrase|unnamed|both]` — the evidence,
  re-runnable. Three labelled sets on purpose: `rule` is phrased in the
  vocabulary the router encodes, `paraphrase` asks the same questions without it,
  and `unnamed` asks for a relation without naming its subject (`--set both` is
  rule+paraphrase; the unnamed set stays separate because the bundle cannot
  answer it, and merging would hide that). It also prints a routing census,
  because a scorer sees only the intent and a fallback that silently answered
  everything would look the same as the rules working. Measured 2026-10-19:

  | router | rule set | paraphrase set | names no node | latency |
  | :--- | ---: | ---: | ---: | ---: |
  | keyword + context bundle (offline) | **14/14** | **10/10** | 4/9 | 0 ms |
  | Jev (cloud, `jev-1.13.0`) | 13/14 | 9/10 | **7/9** | ~330 ms |
  | in-repo `systemone-decision` | 5/14 | 1/10 | 4/9 | ~180 ms |

  **Read the paraphrase 10/10 carefully, because four of those are circular.**
  The rule set's labels come from the six intents, so 14/14 measures the router.
  The paraphrase labels were written before the bundle existed, but four of them
  name only a NODE ("tell me about fern"), and the bundle's policy is exactly
  "a question naming a node means that node's context" — so those four matches
  confirm the policy against itself, which is coverage, not comprehension. The
  bench prints how many of a runner's matches are bundle answers so the number
  can be discounted instead of trusted. Independently: rules alone are 6/10 on
  that set, Jev is 9/10 (it declined "tell me about fern" — defensible, and
  scored as a miss here).

  The third column is the bundle's blind spot, measured rather than argued: it
  resolves a node NAME, so a question naming nothing has nothing for it to
  return even in principle, and the rules fall back to keywords (4/9). Jev wins
  that column, but read the misses, not just the count — the rules decline
  (`UNKNOWN`, which a caller can see and rephrase around), whereas Jev gave two
  confident wrong intents, including `DOC_CONTEXT` for an off-topic question.
  For an automated caller a silent wrong relation is worse than a visible no.

  Hence the policy: **no model at all.** A model used to run when no rule
  matched; the context bundle replaced it, on grounds that do not depend on the
  circular matches: when no rule matches but the question NAMES A NODE, `ops:ask`
  returns that node's whole context — mentions, related hosts, tags — as
  `route: bundle` with the neighbours in `related`, so it returns a *superset*
  and cannot mis-pick a relation. It is offline with no key, and 0 ms beats
  ~330 ms. Tags are checked between exact and loose node names, because a bare
  tag word ("the nix label") is a membership question and the candidate scan
  cannot see tags at all. Nothing matched → `intent: UNKNOWN` and `note` prints
  the six patterns, so an off-topic question gets a menu, not a confident guess.
  `KG_DECIDE_ALWAYS=1` (+ `KG_DECIDE_URL`/`KG_DECIDE_TOKEN`; `task ops:ask:jev`
  reads the key from sops, never echoes it) still opts into the model as an
  agreement check (`route: agreed` / `keyword+disagree`). The default path makes
  no network call at all, so a dead endpoint cannot break a query. The in-repo
  engine stays for coarse triage only (SYSTEM.md / HANDOFF.md buckets) —
  `engine.py` is a hash-embedding heuristic, 5/14 and 1/10 here.
- `task ops:context` — the same query driven by the monitor: fleet-sentinel
  state plus the docs and skills that touch this host. Advisory: the sentinel
  detects, it never acts.
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
- DNS has two members (HC-3): frieren primary, minyx backup behind `192.168.3.50`.
  `checks:dns:failover` probes the VIP, so it reports a real owner only when run
  from the LAN's L2 — from delphi it says undecided rather than green.
- MQTT has no subscriber (HC-5); HA needs one config-entry action.
- `cassini` fails its per-host gate (`xdg.desktopEntries` on darwin) and is dormant.
- `minyx` passes its gate and is active, but its power supply is short:
  `dmesg` shows continuous under-voltage (see `.agents/deploy/hosts/minyx.md`).
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
