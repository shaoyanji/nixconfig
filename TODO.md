# TODO / Handoff

## Current Open Work

1. Documentation alignment completed (April 30, 2026) - All documentation now reflects simplified task control plane and current AI services state. See [AUDIT.md](AUDIT.md) for full details.
2. [x] **nixbuild.net SSH key**: Key deployed to sops (`nixbuild_ssh_key`) and registered with nixbuild.net console. Remote builder enabled on frieren via `profiles.nixbuild-client.enable = true` with store read/write and build permissions verified.
3. **frieren follow-up queue** (2026-10-08 updates):
   - [x] **PostgreSQL automated backups**: Added `services.postgresqlBackup` for Immich's DB scheduled at 03:00 to `/srv/backup/postgresql` and added the dump directory to `services.restic.backups.frieren-local.paths` in `hosts/frieren/infra-stack.nix`.
   - [x] **Cheap resilience win (Battery-as-UPS)**: Added `command_line` sensors to Home Assistant in `hosts/frieren/media-stack.nix` tracking `BAT0` capacity, charging status, and `ADP0` AC online status.
   - [x] **Universal Path Parity (`/Volumes/data`)**: Added `/Volumes/data` bind mount to `/srv/data` in `hosts/frieren/configuration.nix`, fixing local broken `~/Documents/nixconfig` symlink and all Home Manager storage paths.
   - [x] **Zero-conf LAN Discovery**: Configured `services.avahi` with `publish.enable = true` and `extraServiceFiles` for SMB, NFS, Harmonia cache, and Web portal so frieren appears automatically in macOS Finder and Linux file browsers.
   - [x] **Unified Reverse Proxy & Local DNS**: Added `hosts/frieren/reverse-proxy.nix` with Nginx virtual hosts on port 80 for `*.frieren.lan` (`photos`, `docs`, `media`, `ha`, `cache`, `pdf`, `status`, `smart`, `aria`, `wiki`, `paste`) with landing portal, mapped via Pi-hole dnsmasq wildcard in `hosts/frieren/dns.nix`.
   - [x] **Automated Storage Indexing**: Added `services.locate` (`plocate`) in `hosts/frieren/tools.nix` for hourly fast filesystem indexing of `/srv/data`.
   - [x] **24/7 Remote Operator Gateway**: Enabled `antigravity-cli remote-control` as a persistent user service (`antigravity-cli-daemon.service`) with user linger enabled for `devji`. Running 24/7 under instance name `frieren-lunar-rocket` on https://antigravity.google.com.
   - [x] **Declarative Kiwix Wiki Stack**: Replaced hand-rolled user units with declarative `modules/services/kiwix.nix` (native `services.kiwix-serve` on port 8088, reverse-proxied to `wiki.frieren.lan`). Reclaimed 52 GB duplicate ZIM storage.
   - [x] **Reusable Service Modularization**: Extracted Home Assistant IoT stack (`modules/services/home-assistant.nix`), offline wiki (`modules/services/kiwix.nix`), fleet pastebin (`modules/services/paste.nix`), and iVentoy PXE server (`modules/services/iventoy.nix`) into `modules/services/`.
   - [x] **Agent Skills Materialization**: Authored operational skills with complete runbooks in `.agents/skills/` (`home-assistant`, `paste`, `iventoy`, `wikisearch`, `stt`) and synced to user home `~/.agents/skills/`.
   - [x] **Zero SOPS Drift**: Re-keyed all 6 secrets files; zero recipient or file drift.
   - [x] **Lint-Gate & 100% Alejandra Compliance**: 0/181 tracked Nix files violate formatting; deadnix and statix clean.
   - [ ] MQTT hardening: when real devices arrive, switch mosquitto from the loopback-anonymous listener to an authenticated LAN listener with passwordFile via sops (see `modules/services/home-assistant.nix`).
   - [x] **restic hardening**: moved `/root/.restic-password` into sops (`modules/secrets.yaml` -> `/run/secrets/restic-password`) and added secondary cold vault repository target on BurgerNAS via SFTP with Wake-on-LAN and poweroff hooks.
   - [ ] When a Zigbee coordinator dongle is attached: set `services.zigbee2mqtt.settings.serial.port` from `/dev/serial/by-id`.

## HANDOFF Promotion Candidates (2026-10-12)

Staged from the 2026-10-12 brainstorm. These are **operational** work items for the running
fleet (real gaps, not design studies), so they are written in HANDOFF shape and are ready to be
lifted into `~/HANDOFF.md` as P-items. Each carries its own exit criteria. The exploratory halves
(generalizations / per-service isolation) stay in `EXPERIMENTS.md`.

### HC-1 — Single declarative exposure registry (`profiles.serviceExposure`)

- **Why:** every exposed service is declared in **four** independently-maintained places — the
  global `allowedTCPPorts` (which `hosts/frieren/firewall-scope.nix` clears with `lib.mkForce`),
  the per-interface `scopedTCP`/`scopedUDP` lists, the nginx vhosts in
  `hosts/frieren/reverse-proxy.nix`, and the Pi-hole wildcard records in `hosts/frieren/dns.nix`.
  `firewall-scope.nix` itself warns "Keep in sync with the global contributions", and the live
  audit already found drift (stray 67/69/4011 from `dns.nix`/`iventoy.nix` leaking onto `enp1s0`).
- **Deliverable:** a `profiles.serviceExposure` module where a service declares
  `expose = { port; lan = true; tailnet = true; proxy = { name, upstream }; dns = { name }; }` and the
  module _derives_ all four surfaces — there is no second list to edit.
- **Where:** new `modules/profiles/service-exposure.nix`; refactor
  `hosts/frieren/{firewall-scope,reverse-proxy,dns}.nix` to consume it.
- **Exit criteria:** `task checks:ports` reports zero DEAD-HOLE / FIREWALL-ONLY drift for frieren;
  adding a service touches exactly one file; `nix eval` of the frieren config is unchanged.

### HC-2 — Backup restore drill (`services.backupDrill`)

- **Why:** `restic-backups-frieren-local` writes nightly to `/srv/backup/restic`, but **no restore
  has ever been exercised** — the backup is unproven. The password still lives at
  `/root/.restic-password` (unmanaged disk state) and there is no offsite target.
- **Deliverable:** a scheduled `restic check --read-data-subset` + `restic restore --verify` of a
  sampled path into a scratch dir, with the result surfaced to the journal and (optionally) an
  HA/MQTT sensor; migrate the repo password into sops-nix.
- **Where:** `hosts/frieren/infra-stack.nix` (alongside the existing restic block); a `checks:*`
  runbook.
- **Exit criteria:** a documented restore proof on file; the `checks:*` task reproduces it;
  failure is loud (non-zero exit + journal).
- **Delivered (2026-10-12, `60451f0`):** `restic-drill.service` + `restic-drill.timer`
  (Sun 06:30, `Persistent`, 15 min jitter) run `restic check` plus a sampled restore of
  `/srv/private/home-assistant` into a scratch dir, asserting the extracted copy contains real
  regular files (not the live `/etc` symlink, which `test -f` would resolve and prove nothing).
  Reproducible on demand via `task checks:restic:drill`. Verified once against snapshot
  `c3e0f078` (2102 files / 215 MiB); not yet exercised through the systemd unit (needs a switch).
- **Delivered (2026-10-14):**
  1. **Password to sops.** Moved `/root/.restic-password` into `modules/secrets.yaml` (`sops.secrets.restic-password`) and pointed `services.restic.backups.frieren-local.passwordFile`, `frieren-burgernas.passwordFile`, and `resticDrill` to `/run/secrets/restic-password`. Eliminated the imperative `restic-ensure-password` oneshot.
  2. **Secondary/Off-host target.** Added `services.restic.backups.frieren-burgernas` pushing to BurgerNAS (DS220j, 4.5TB RAID) via SFTP with automated Wake-on-LAN wake and poweroff hooks.
  3. **BurgerNAS baseline + credential (2026-10-14).** Baseline seed verified (`restic check` clean, sampled restore matched) and the legacy `core/Sandy` plaintext copy retired; the NAS sudo credential moved to sops (`sops.secrets."burgernas-sudo-password"` → `/run/secrets/nas`), replacing the hand-placed `~/nas`.

### HC-3 — DNS high availability (`profiles.dnsFailover`)

- **Why:** frieren is the fleet's only resolver — it serves `*.frieren.lan`
  (`address=/frieren.lan/192.168.3.25`) and ad-blocking (`pihole-ftl` → `unbound` on
  `127.0.0.1#5335`) from one host. Losing frieren breaks name resolution for every client.
- **Deliverable:** a second resolver on an always-on host with a declared primary/secondary
  (VRRP or a DHCP-distributed secondary), an assertion that prevents split-brain, and a documented
  failover test.
- **Where:** new `modules/profiles/dns-failover.nix`; secondary on an always-on container host
  (candidate: `mtfuji`); `hosts/frieren/dns.nix` declares the primary role.
- **Exit criteria:** in a test, stopping frieren's resolver still leaves clients resolving; `dig`
  against the secondary returns the wildcard record; runbook written.
- **Delivered (2026-10-12):** `modules/profiles/dns-failover.nix` — a role-based
  resolver (unbound + pihole-ftl core + wildcard zone + LAN firewall hole + optional
  VRRP), with split-brain assertions (`virtualRouterId` required once `virtualIp` is
  set; `primaryPriority` must exceed `secondaryPriority`). frieren now declares the
  `primary` role from it (behaviour-preserving: firewall sets and pihole settings are
  byte-identical). `task checks:dns:failover` + `scripts/task/dns-failover-check.sh`
  verify the group, and `docs/dns-failover.md` is the runbook.
- **Remaining (mechanism-complete, not yet redundant):**
  1. **Provision the second resolver.** No always-on second NixOS host exists — every
     other host is `preserved`/dormant or offline, and `mtfuji` (the design candidate)
     is `preserved` with a "do not target for live deployment" constraint. The
     secondary is a 3-line opt-in once a host is chosen; add its address to frieren's
     `resolvers` so clients are handed both.
  2. **Point clients at the group.** LAN clients come from the FritzBox (DHCP), so the
     router must hand out both resolvers (or a VRRP `virtualIp` outside its pool) — a
     manual router change, not Nix-owned.
  3. **Lift the check out of exit 2.** `checks:dns:failover` exits 2 until the group has
     ≥2 members; that is the honest "failover not evaluable" state, and the gate flips
     to a real 0 only with (1).
  4. **Optional VRRP.** The `virtualIp`/keepalived path evaluates (verified) but is
     unused in production; it stays dormant until two resolvers exist.

### HC-4 — Closure budget gate (`checks:closure:budget`)

- **Why:** the Tier-1 debloat work (fonts, nix-path, printing, AI-stack gating) has no regression
  guard, so a closure can silently re-bloat. The store-DB closure tooling already exists.
- **Deliverable:** a per-host byte budget that **exits non-zero** when a closure regresses, wired
  as a `checks:*` task and optionally as a CI gate.
- **Where:** `scripts/task/closure-analysis.sh` (add a budget mode) + `taskfiles/{dev,checks}.yml`;
  budget table documented in `docs/closure-reduction.md`.
- **Exit criteria:** `task checks:closure:budget` fails when a budget is exceeded and passes
  otherwise; result reproducible against `dev:closure:size`.
- **Delivered (2026-10-12):** `closure-budgets.toml` holds a per-host `bytes` ceiling
  (yq-read, guarded by `checks:toml:lint`); `closure-analysis.sh` gained a `budget` mode
  with `--all`; wired as `checks:closure:budget` (gate) and `dev:closure:budget` (tool);
  documented in `docs/closure-reduction.md` §7. Verified: exits 1 (task 201) when a host is
  over budget and 0 when within, and the measurement shares `total_of` with
  `dev:closure:size`, so the two views cannot disagree.
- **Remaining:**
  1. **Budgets exist only for measured hosts** (`frieren`). Add each host when it is next
     online and measured — an invented number is worse than none.
  2. **Not yet a CI gate.** Wiring it in needs a built toplevel (`TARGET=<store path>`) plus a
     change to `.github/workflows/nixcachix.yml`; deliberately left as its own change.
  3. **Tighten the ratchet.** +1% headroom (352.9 MiB) absorbs `flake.lock` drift but is larger
     than the ~70 MiB Tier-1 font item, so that class of change will not trip it.
  4. **The drift is already real, and it is a warning — not a blocker:** the live frieren closure
     is back to 3949 paths / 34.5 GiB (the pre-L1 figures) even though L1 is applied, so the
     33.8 GiB recorded post-L1 has been given back by later changes. The gate's job is to _surface_
     that; it is not wired into CI, so it cannot block a merge, and nothing else here waits on the
     drift being fixed.

### HC-5 — Wire Home Assistant to its own broker, and make `extraComponents` honest

- **Why:** `services.ha-stack` runs Mosquitto, but the broker has **neither publisher nor
  subscriber**: `mosquitto` is active with **0 clients on `:1883`**, `journalctl -u home-assistant |
grep -ci mqtt` is **0**, and there is no `mqtt:` stanza in the rendered `configuration.yaml`. The
  `mqtt` entry in `extraComponents` installs a Python dependency and subscribes nothing. So the repo
  declares an MQTT stack that does not exist — and 7 of the 11 `extraComponents` entries are dormant
  (`rest`, `todoist`, `jellyfin`, `plex`, `fritzbox`, `immich`, `mqtt`) against 4 actually active.
  This is the live half of EXP-009 (`EXPERIMENTS.md`), it needs **no hardware**, and it is the
  precondition for EXP-007/008/014/015.
- **Deliverable:** HA genuinely subscribed to the broker (with the YAML-stanza-vs-config-entry drift
  that EXP-009 flags as the open question, answered), plus `extraComponents` documented or renamed so
  it stops reading as "enabled components".
- **Where:** `modules/services/home-assistant.nix`; evidence rows in `EXPERIMENTS.md` EXP-009.
- **Delivered (2026-10-12, `95452bb`):** the premise turned out to be wrong in a way worth
  recording. MQTT in Home Assistant is **config-entry only**: in the pinned
  `homeassistant-2026.9.4`, `components/mqtt/__init__.py` registers only publish/websocket
  actions for a YAML stanza (and raises the `yaml_setup_without_active_setup` repair issue),
  the broker comes from `entry.data[CONF_BROKER]` in `async_setup_entry()`, and
  `config_flow.py` has no `async_step_import` — so no YAML and no `extraComponents` entry can
  connect a broker. Hand-seeding `.storage/core.config_entries` was rejected for the same
  reason Kuma's DB was: HA owns and rewrites that file. The delivered half is therefore the
  honest one — the module header documents all of this, `extraComponents` is documented as
  what it is (Python dependencies, not enabled components; 7 of 11 entries are dormant), and
  `task checks:ha:mqtt` + `scripts/task/ha-mqtt-check.sh` make the gap testable: it currently
  reports `broker listening yes / mqtt entry false / established 0` and exits non-zero.
- **Remaining (not Nix-expressible):**
  1. **The broker still has no publisher or subscriber.** The broker connection has to be
     created through HA's config flow (or written by HA itself); a declarative module cannot
     do it. EXP-014 (upsTelemetry) and the Zigbee/ESPHome work both wait on this.
  2. `extraComponents` values are unvalidated strings — a typo fails at runtime, not at eval.

### HC-6 — Monitors as code: watch something (`services.fleetMonitors`)

- **Why:** Uptime-Kuma runs with **0 monitors** (`select count(*) from monitor` → `0`, verified
  2026-10-12), so **nothing in the fleet is actually watched** — not the 03:30 restic job, not the
  04:00 `system.autoUpgrade`, not DNS (`*.frieren.lan`) and not the nginx vhosts. The obvious
  declarative fix is blocked by the product, not by effort: Kuma **2.5.5**'s HTTP API is read-only
  (`GET /api/entry-page`, `GET /api/badge/:id/*`) with monitor CRUD only on Socket.IO, so monitors
  **cannot be declared** — a monitoring service that monitors nothing is the gap (EXP-008).
- **Deliverable:** a config-file-driven monitor backend whose endpoint list is Nix state — `gatus`
  (5.37.0 in the pinned nixpkgs) is the declarable option; `prometheus-blackbox-exporter` is the
  alternative if probe semantics matter more than the UI. Probe `127.0.0.1:<port>` so **no**
  `firewall-scope.nix` change is needed. Kuma may keep the dashboard and badge endpoints.
- **Where:** new `modules/services/fleet-monitors.nix`; a `checks:*`/runbook proving a down service
  is visible; `docs/`.
- **Delivered (2026-10-12, `9ee6236`):** new `modules/services/fleet-monitors.nix`
  (`services.fleetMonitors`) emits nixpkgs' `services.gatus`, so every definition is Nix state.
  frieren watches seven endpoints — nginx:80, jellyfin:8096, immich:2283, paperless:28981,
  home-assistant:8123, harmonia:5000 (with an HTTP status condition) and `tcp://127.0.0.1:53` —
  all probed on loopback, so no `firewall-scope.nix` change and no new hole (8181, deliberately
  not 8080, which Pi-hole uses). `monitors.frieren.lan` is an explicit vhost in
  `reverse-proxy.nix` plus a landing-page card. Verified by eval: the gatus settings carry all
  seven endpoints and 8181 appears in no interface firewall list.
- **Remaining:**
  1. **The failure modes named in the why are still unwatched.** The 03:30 restic job, the 04:00
     `nixos-upgrade` and DNS resolution for `*.frieren.lan` are oneshot/timer units or a query,
     not HTTP endpoints — watching them needs a small exporter or a push from the job itself.
     The endpoint list is a start, not the set.
  2. **Uptime-Kuma still runs with zero monitors.** Decide whether it stays as the dashboard
     (and gatus is alert-only) or is retired now that the declarative monitor exists.
  3. **Nothing is wired to a notifier.** A down service is visible in the UI and nowhere else —
     no mail/push on transition, which is the actual point of a monitor.

### HC-7 — Close the ingress gaps `checks:ports` reports

- **Why:** `task checks:ports` (verified 2026-10-12) reports five **DEAD-HOLE** ports — declared with
  nothing behind them (`631` after the CUPS debloat, `3005`, `8324`, `8920`, `32469`) — and thirteen
  **FIREWALL-ONLY** listeners that bind public addresses and are held back **only** by
  `firewall-scope.nix`'s interface scope (`111` rpcbind, `20048` mountd, `8080`/`8086` Pi-hole web,
  `10809` (mis-attributed to InfluxDB in this list — see the correction below), `5355` LLMNR, and the
  **dynamic rpc/NFS ports** — a _different_ set on each boot:
  `34737 36145 39781 42513 49597 59543 61199` now vs `38139 40769 42795 46357` recorded earlier).
  This is the exit criterion **HC-1 did not meet**: any loosening of that scope, or any host that
  lacks it, exposes them. The dynamic NFS port set is the proof that the interface scope is
  load-bearing (EXP-017, and the audit findings section of `EXPERIMENTS.md`).
- **Deliverable:** prune the dead holes from the exposure registry, and bind-scope the public
  listeners to loopback (or to the one interface they actually need) so the firewall is **not** the
  sole control. NFS/Samba are the hard part — they need a concrete, non-dynamic port policy first.
- **Where:** `hosts/frieren/firewall-scope.nix` (registry) + the owning modules
  (`nfs`, `immich`, `pihole-web`, `influxdb`, `iventoy`); `scripts/task/port-audit.sh` is the guard.
- **Owner map corrected (2026-10-12, read from `ss -tulnp` + the owning units):** `8080` is the
  Pi-hole web UI (not `8086`), `8086` is the InfluxDB that Scrutiny starts (nothing in the tree
  configures it), `10809` is a second iVentoy listener alongside the declared `26000` UI, and
  `34737` is an immich-internal listener, not a service port. `36145`/`39781` have no process
  attached because they are the kernel's NFS `lockd`; `42513`/`59543` are `rpc.statd`.
- **Delivered (2026-10-12, `bec94db`):** the fixable half is closed. Five DEAD-HOLE ports
  (`631` CUPS, `3005`, `8324`, `8920` Jellyfin-HTTPS, `32469` Plex DLNA) are pruned from the
  exposure registry — none had an owning service left in the tree. NFS gained the non-dynamic
  port policy the item asked for first: `mountdPort = 20048`, `statdPort = 32765`,
  `lockdPort = 32766`, so the rpc/NFS surface stops being re-drawn every boot. LLMNR is off,
  the Pi-hole web UI is bound to `127.0.0.1:8080` (its documented access path is an SSH
  forward) and Scrutiny's InfluxDB to `127.0.0.1:8086`. `scripts/task/port-audit.sh` now
  separates a `DYNAMIC` bucket (listeners on kernel-drawn ports — undeclarable by
  construction, so failing on them would be an unsatisfiable gate), a documented `ACCEPTED`
  list (each entry with a reason), and `STRICT=1` fails on `FIREWALL-ONLY` as well as
  `DEAD-HOLE`. Verified: frieren evals with the new binds/pins, `STRICT=1` exits 0 against the
  expected post-switch listener set (stubbed `ss`), and still exits 1 on a synthesised fixed
  undeclared port.
- **Remaining:**
  1. **The rebinds need the next switch.** Nothing here is live yet (gen 83 is still running),
     so "every rebind verified with its own client" is unproven: after the switch, check
     `ss -tlnp` for the three loopback binds and the two pinned NFS ports, then run
     `task checks:ports STRICT=1` (it is red until then, on `5355 8080 8086`).
  2. **Five listeners still rely on the interface scope** and are recorded, not fixed, in the
     audit's `ACCEPTED` list: `111` rpcbind, `20048` mountd, `32765` statd, `32766` lockd and
     iVentoy's `10809`. Their NixOS modules expose no narrower bind address, and no intended
     client reaches them from the LAN (fleet NFS mounts are v4, which needs none of them), so
     declaring them would widen the firewall for nothing. Reviewed whenever that bucket changes.
  3. **NFSv3 can probably be switched off entirely** — with v4-only clients, rpcbind/mountd/
     statd/lockd have no consumer, and deleting them is the honest version of (2). It is a
     fleet-breaks-if-wrong change (macOS/client v3 mounts would stop) and needs a maintenance
     window with a real client test, so it is deliberately not part of this item.
  4. **The truly dynamic listeners stay dynamic** (`34737` immich-internal, tailscaled's
     peerapi on the tailnet address): no stable port to declare, so the interface scope is
     their only control. That is EXP-017's problem — per-service isolation, not a firewall list.
- **HC-1 note:** the registry landed in `a376893`, but its audit criterion ("zero DEAD-HOLE /
  FIREWALL-ONLY drift for frieren") could only be reached once the _listeners_ were fixed, which
  is this item. Adding a service still touches exactly one file.

### HC-8 — Graceful Gamescope / DankMaterialShell session switching (`modules/profiles/steam.nix`)

- **Why:** On Steam gaming & console hosts (`eisen`, `stark`, `deckstation`, `kellerbench`), users alternate between Steam Big Picture in Gamescope (Gaming Mode) and DankMaterialShell / Niri (Desktop Mode). In Gamescope, Steam Big Picture's "Switch to Desktop" button expects `/usr/bin/steamos-session-select` to handle the transition gracefully, but no switcher existed. Abrupt killing or uncoordinated restarts risked corrupted cloud saves, hanging gamescope compositors, and stuck greeters.
- **Deliverable:** A dedicated `deck-session-switch` shellbin script in `modules/profiles/steam.nix`, symlinked/wrapped as `steamos-session-select` and accompanied by a standard `return-to-gamemode.desktop` FreeDesktop entry for DankMaterialShell application menus. Provides graceful `steam -shutdown` with cloud sync wait loop, clean `niri msg action quit --skip-confirmation`, target session state tracking in `~/.local/state/deck-session/target-session`, and coordinated greetd autologin reboot/restart.
- **Where:** `modules/profiles/steam.nix` (exported to all Steam/Gamescope hosts).
- **Delivered (2026-10-12, `9354712`):** `deck-session-switch`, `steamos-session-select`, and `return-to-gamemode.desktop` packaged via `pkgs.writeShellScriptBin` / `pkgs.makeDesktopItem` in `modules/profiles/steam.nix`. Supports `desktop`, `gamescope`, `--toggle`, and `--status`. Verified by `nix eval` across `eisen`, `stark`, `deckstation`, and `frieren`.

### Not promoted (kept as experiments) — and why

Promotion needs a _real, currently-actionable_ fleet gap. These are the near-misses, recorded so the
decision is visible rather than forgotten:

- **EXP-001/002/005/006 (fleetWifi / segmentation)** — the largest genuine gap (the FritzBox LAN is
  flat with no VLAN capability, so guests and future IoT share one trust domain with Vaultwarden,
  Immich, Paperless and the `p/` stores). Held back for one reason: **no AP has ever been started**,
  and the single-radio trade (AP vs. uplink) is unresolved. It needs a verification spike first — start
  an AP, measure throughput, test Pi-hole against a live AP interface. EXP-005's USB-tether island is
  the best-shaped variant (it sidesteps the radio trade entirely).
- **EXP-016 (agentScheduler)** — worth promoting once one job is pinned: the argument is that
  hand-rolled units have twice shadowed declarative ones (kiwix, hermes). Held because the agent CLIs'
  flag surfaces move (that is why the `antigravity` and `crush` skills exist) and the guardrail
  semantics are undefined.
- **EXP-014 (upsTelemetry)** — a real gap (the battery-as-UPS only _reports_; the other laptops expose
  `AC`/`ACAD`/`ADP1`, not `BAT0`; and `TODO.md:8` marking the frieren snippet "done" is the trap). It
  pays off once HC-5's bus exists, so it follows HC-5 rather than competing with it.
- **EXP-015 (memoryPressure)** — frieren-local tuning whose own exit criteria require a _measurement_
  before it is a module; not a fleet-wide promotion.
- **EXP-017 (serviceIsolation)** — the egress half of HC-7; intentionally last.
- **EXP-003/004** — thin by design: EXP-003 trades against EXP-001/002, EXP-004 is the likeliest to be
  closed as novelty.

## Fleet Optimizations (2026-10-01 review)

1. [x] **Local binary cache on frieren.** Run `harmonia` (signed, port 5000)
       on the NAS so LAN hosts share store paths instead of each pulling from
       WAN caches. `modules/services/harmonia.nix` enabled in
       `hosts/frieren/configuration.nix`; `http://192.168.3.25:5000` prepended to
       `nix.settings.substituters` and its key (`frieren.lan-1:BUg+1UmfYlF0…`)
       to `trusted-public-keys` in `modules/global/global.nix`. The private
       signing key was generated once and stored as `harmonia_signing_key` in
       sops (committed to the secrets submodule). Deploy frieren to activate;
       verify with `curl http://192.168.3.25:5000/nix-cache-info`.
2. [x] **Gate the AI stack behind an option.** `roles/minimal.nix` no longer
       unconditionally imports `user/ai`; `user/ai/default.nix` now defines
       `profiles.ai.enable` (default on for desktop/heim roles, off in
       `globalModulesContainers` via `noDE.nix`) so headless container hosts
       (mtfuji, kellerbench, netbook, guckloch, …) drop crush/freebuff/qmd/
       antigravity-cli/translate-shell from their closures.
3. [x] **nixbuild.net remote builder.** Key found at
       `/Volumes/data/security/nixbuild keys/` and stored as
       `nixbuild_ssh_key` in sops (committed to the secrets submodule).
       `profiles.nixbuild-client.enable = true` is on for `frieren` (the
       fleet cache-warmer); eval confirms `nix.buildMachines` targets
       eu.nixbuild.net with the key decrypting to `/root/.ssh/nixbuild`.
       Key registered with the account (default-permissions grant
       build:write, store:read/write). NOTE: do not verify with
       `ssh eu.nixbuild.net echo ok` — arbitrary SSH command execution needs
       the undocumented `run:write` permission, which default-permissions
       refuses to grant. Correct probe:
       `NIX_SSHOPTS="-i <key>" nix store ping --store ssh://eu.nixbuild.net`.
4. [x] **Dedupe `specialArgs` in host-inventory.** `lib/mk-nixos-host.nix`
       now defaults `specialArgs = { inherit inputs self; }` (wired from
       `flake/nixos-configurations.nix`); the 26 per-host copies were removed
       from `flake/host-inventory.nix` (per-host overrides still possible).
5. [x] **Parallel fleet deploy.** New `infra:apply:fleet` task in
       `taskfiles/infra.yml`: takes a `HOSTS` list (defaults to all inventory
       hosts of kind nixos) and fans out `nixos-rebuild --target-host` jobs in
       parallel, streaming each host's output through `nom`.
6. [x] **Nix daemon resiliency tuning.** Added to `nix.settings` in
       `modules/global/global.nix`: `connect-timeout = 5` (fail over to other
       substituters fast), `fallback = true` (build locally when caches are
       unreachable), and `keep-outputs = true` (GC keeps dev-shell closures).
7. [x] **LTS kernel for server-class hosts.** `frieren` now pins
       `boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12` (the LTS
       track); desktops keep `linuxPackages_latest` from
       `modules/profiles/base-node.nix`.
8. [x] **X11Forwarding off fleet-wide.** Set to `false` in
       `modules/profiles/base-node.nix` (it was re-introduced as `true` during a
       settings refactor) alongside `KbdInteractiveAuthentication = false` — no
       consumer was using X11 over SSH.
9. [x] **Fleet cache-warmer on frieren.** Shipped as `task infra:warm:cache`
       (builds every host closure locally so harmonia serves them at LAN speed;
       `UPDATE=1` also refreshes `flake.lock` and commits) plus a weekly
       unattended timer on frieren (`fleet-warm-cache`, Sundays 03:30,
       persistent, builds from `github:shaoyanji/nixconfig` like autoUpgrade).
       Note: LTS kernel pin reduces but does not remove reboots — keep
       `allowReboot = true` on frieren so 6.12.x security bumps still get
       applied at 04:00.
10. [x] **Declarative kiwix wiki stack (2026-10-08).** Hand-rolled
        `wikipedia-download.service` + `kiwix-serve.service` user units replaced by
        `hosts/frieren/kiwix.nix` (native `services.kiwix-serve`, declarative
        library, `http://wiki.frieren.lan` via nginx). Data at `/var/lib/kiwix`
        (moved from `~/wikipedia-offline` — DynamicUser/ProtectHome can't read
        `/home`); 52GB Wikipedia ZIM imported into the store (`nix store
   add-file`, GC-rooted); ArchWiki added as `fetchurl`. The downloader was a
        one-time bootstrap — removed; new wikis = `fetchurl` entries + `nurl`.
11. [x] **hermes-gateway hardening (2026-10-08).** `hermesGatewayUnitCleanup`
        activation step (hand-rolled unit shadowing aborted every switch),
        `/run/wrappers/bin` first in the unit PATH (profile sudo lacked setuid →
        agent escalation failures), interim unit drop-in removed. Full notes:
        `.agents/deploy/hosts/frieren.md` Deploy Checklist.
12. [x] **Hand-rolled unit purge + cache-warm chain (2026-10-08).**
        `antigravity-cli-daemon` shadow removed (declarative `/etc/systemd/user`
        unit took over), stale `agy-onetime-handoff-run.timer` + dangling wants
        links deleted, `wikipedia-download`/`kiwix-serve` user units replaced.
        New tasks: `infra:update:fleet` (update → warm → apply) and
        `infra:cache:push:host:*` (nix copy into harmonia). Known issue: the
        project-root `Taskfile.yml` shim had an include cycle via the
        `~/Documents/nixconfig` HM-store symlink — **fixed** by flatten-includes
        (do not include the root file itself); `task` with no `-t` works again.
13. [x] **SSH CA client on frieren (2026-10-08).** `ssh.ca.enableClient =
   true` (rotate-ssh-cert + CertificateFile); CA key was already deployed via
        sops-nix; signing verified live. Stale "workstations only" notes in
        AGENTS.md/README corrected to full-fleet.

## TestVM Follow-Up

1. Inventory every host that embeds or plans to embed `testvm`-style microVM wiring.
   - poseidon's `testvm` microVM is **disabled** (2026-08): the microvm imports and `microvm.vms` block are commented out in `hosts/poseidon/configuration.nix` for easy re-enable.
2. Extend the shared guest baseline only when host-local bridge/share differences stay small.
3. Keep host-local bridge/NAT, bind mounts, persistence, and external interface choices in the host files.
4. Decide whether the standalone `testvm` output should eventually move into `modules/profiles/*` or stay under `hosts/microvms/*`.

## Things To Avoid

- Do not do a broad host rewrite in one pass.
- Do not move secrets or encrypted data.
- Do not silently widen system support.
- Do not assume Garnix persistence.
- Do not merge host-local storage layout into shared modules unless the reuse is clearly real.

## Immediate Next Reasonable Tasks

1. **Monitor Fleet Warm Cache & Rebuild Matrix**:
   - Observe the weekly `fleet-warm-cache` timer (Sundays 01:30) and nightly `nixos-upgrade` (04:00) on frieren.
   - Ensure disk capacity on `/nix/store` and `/srv/data` stays healthy; watch `find /nix/store -maxdepth 1 -newermt '-2 minutes'` when monitoring multi-GB closure updates.
2. **Secondary Offsite Target for Restic**:
   - Complement the local `/srv/backup/restic` target with a remote offsite target (Backblaze B2, rsync.net, or rest-server).
   - Migrate `/root/.restic-password` from unmanaged disk state into sops-nix secret management.
3. **Monitor nixbuild.net Remote Builder Budget**:
   - Track build usage against the free tier (25 build-hours/month) using `task dev:nixbuild:plan`.
4. **Mosquitto Authentication for LAN IoT Clients**:
   - When physical ESPHome or Zigbee devices are deployed, configure an authenticated TCP/TLS listener on Mosquitto with user credentials in sops.
5. **Transitive Flake Lock Maintenance**:
   - Run `task dev:flake:update-transitive` when ready to advance drifted transitive flake inputs in batches.
6. **Watch Module Cleanliness**:
   - Maintain service separation in `modules/services/` and avoid accumulating host-local service forks.
7. **TUI Menus for Declarative Fleet Control Knobs (`modules.toml`)**:
   - Model after `task inventory` (`scripts/task/inventory-menu.sh`): Charm `gum` frontend paired with fast, native `yq` backend for zero-overhead in-place TOML edits.
   - Design declarative control knob registry (e.g. `modules.toml` or similar schema) to manage optional roles, services, and profile flags fleet-wide or per-host without manual Nix file editing.
   - Build dedicated Charm `gum` interactive menus for other fleet control knobs that the top-level operator control plane (`task menu`) currently lacks.
   - Ensure all future TOML edits strictly preserve comments and structure via native `yq`, followed by validation and documentation synchronization gates.
8. **eisen Local MoE LLM Inference Engine (`llama.cpp` + Qwen3.6-35B-A3B / 3B–7B Active)**:
   - Leverage 64 GiB DDR4 RAM + 12c/24t Xeon E5-2673 v3 + AMD RX 5700 (8 GiB VRAM) on `eisen`.
   - Deploy native `services.llama-cpp` with Vulkan backend (`vulkanSupport = true`) instead of Ollama wrapper daemon.
   - Primary champion: `Qwen3.6-35B-A3B` (35B total, ~3B active, ~22.5 GB at `Q4_K_M`) — 8 GB VRAM comfortably offloads Linear Attention states, KV cache, and 3B active compute at 35–55 tok/s, while 64 GB DDR4 holds the full 35B expert pool.
   - Expose OpenAI-compatible endpoint on `http://eisen:8080/v1` over Tailscale for fleet AI tools (`mods`, `aichat`, `opencode`). Detailed blueprint documented in `.agents/deploy/hosts/eisen.md`.
   - lfm2.5-24b-a2b set to be primary after dspark becomes available
