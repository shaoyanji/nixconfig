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
   - [ ] restic hardening: move `/root/.restic-password` into sops and add an offsite repository target (B2/rest-server) alongside the local one.
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
module *derives* all four surfaces — there is no second list to edit.
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
- **Remaining half:**
  1. **Password to sops.** `/root/.restic-password` is unmanaged on-device state. The
     `restic-ensure-password` oneshot generates it if absent, but a lost disk loses the key and
     every snapshot becomes unreadable. Move it into `modules/secrets.yaml` and point
     `services.restic.backups.frieren-local.passwordFile` — and the drill's
     `RESTIC_PASSWORD_FILE` — at the sops-rendered path.
  2. **Offsite target.** `/srv/backup/restic` is the same pool as the data it protects, so a
     pool loss takes the source *and* the backup. Add a second repository (restic REST server on
     an always-on host, or Backblaze B2) with its own credentials and retention policy.

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
  4. **The drift is already real:** the live frieren closure is back to 3949 paths / 34.5 GiB —
     the pre-L1 figures — even though L1 is applied. The 33.8 GiB recorded post-L1 has been
     given back by later changes; a ratchet set at 33.8 GiB would have flagged it.

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

