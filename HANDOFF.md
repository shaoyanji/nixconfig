# HANDOFF.md — Fleet Architecture & Declarative Codebase Handoff

> **Scope:** Multi-Host Declarative Fleet Configuration (`shaoyanji/nixconfig`)  
> **Target Fleet:** `frieren` (NAS / Media Mainframe), `poseidon` (Workstation), `eisen` (Living Room Kiosk), `stark` (AIO Kiosk), `fern`, `scratch`, `guckloch`, `delphi`, `garnixMachine`  
> **Updated:** 2026-10-14 13:50 CEST
> **Status:** Production Active (NixOS 26.11)

---

## 🚨 2026-10-14 Incident — `frieren` DNS outage (LAN unanswered + unbound SERVFAIL)

**Symptom.** LAN clients got **no answer** from `192.168.3.25:53` (UDP timeout,
TCP accepted-then-EOF); `frieren` itself **SERVFAILed external names** while
`*.frieren.lan` still resolved. The gateway hands out `192.168.3.25` as the
resolver, so LAN name resolution was down.

**Two independent faults, both on `frieren`:**

1. **dnsmasq excluded the LAN interface — CODE BUG, FIXED.**
   `services.pihole-ftl` set `dns.interface = "enp1s0"` together with
   `listeningMode = "ALL"`, and Pi-hole v6 **ignores `dns.interface` under `ALL`**.
   The generated `/etc/pihole/dnsmasq.conf` therefore carried only
   `interface=tailscale0` (from the host's `extraDnsmasqLines`) — and **any**
   `interface=` line switches dnsmasq to interface-restricted listening, so
   `enp1s0` was dropped and client queries never reached dnsmasq (verified: the
   NAS's probe query is **absent** from `/var/log/pihole/pihole.log`).
   *Fix:* `modules/profiles/dns-failover.nix` now always emits
   `interface=${cfg.lanInterface}` in `misc.dnsmasq_lines`. Live-applied on
   `frieren` by adding `"interface=enp1s0"` to `/etc/pihole/pihole.toml`
   (backup `/root/pihole.toml.bak-*`).

2. **`unbound` recursed over IPv6 with no IPv6 uplink — CODE BUG, FIXED.**
   The running `unbound` (`127.0.0.1#5335`) SERVFAILed external names — at first
   domain-specific (`example.com` OK, `github.com` SERVFAIL even with `+cd`),
   then everything. A foreground `unbound -d` on a spare port showed the cause in
   one line: it sent *every* root query to the **IPv6** root servers
   (`sending to target: <.> 2001:503:c27::2#53` → `module_event_noreply`) — the
   host has **no IPv6 route**, so each reply is a no-reply and recursion never
   completes. Direct IPv4 to the roots and authoritative servers worked fine,
   which is why it initially looked like "the network is fine".
   *Fix:* `do-ip6 = false` in `modules/profiles/dns-failover.nix`
   (`services.unbound.settings.server`). Live-applied on `frieren` by replacing
   the `/etc/unbound/unbound.conf` store symlink with a real file carrying
   `do-ip6: no`; the public-resolver upstream stopgap was reverted.
   **Verified:** host, `unbound`, `pihole-ftl` and the LAN client (BurgerNAS) all
   resolve again.

**⚠ Follow-ups**
- `do-ip6 = false` is in the module now; the live override on `frieren` is
  regenerated from it on the next rebuild.
- Add a resolver health check (`gatus` / `checks:dns:failover`) so a future
  resolver outage is detected automatically instead of by a human.
- Treat `do-ip4`/`do-ip6` as explicit, documented resolver-host policy rather
  than relying on unbound's IPv6-on-by-default.

---

## ⚠ Disambiguation of Handoff Documents

To maintain clean separation of concerns across the fleet, two distinct handoff documents exist:

| Document | Location | Authority & Scope | Read/Write Lifecycle |
| :--- | :--- | :--- | :--- |
| **Fleet Architecture Handoff** | `/Volumes/data/projects/nixconfig/HANDOFF.md` *(This file)* | **Declarative Source of Truth.** Tracks git commits, flake inputs, NixOS modules, cross-host configuration, shared profiles, and architectural migrations across the entire fleet. | Edited by human operators and autonomous engineering agents during feature development. Tracked in git (`origin/main`). |
| **Node Runtime Handoff** | `/home/devji/HANDOFF.md` | **Live Host Operational State.** Tracks local machine runtime findings on `frieren` (e.g., active drive sector errors, glibc collation version mismatches, transient service logs, and daily systemd audit findings). | Updated daily by autonomous background services (`agy-nightly-handoff.service`, `agy-nightly-system.service`). Lives on local host filesystem. |

---

## Current Architecture Initiatives & Status

### 1. [x] EXP-102: Ephemeral MicroVM Deployment Sandbox & Model B Service Migration
* **Status:** `PROTOTYPED, VERIFIED & COMMITTED` ([`b11b5e9`](https://github.com/shaoyanji/nixconfig/commit/b11b5e9))
* **Architecture:**
  - `hosts/microvms/frieren-canary.nix`: Lightweight Canary MicroVM running under `cloud-hypervisor` via KVM.
  - Zero-duplication `/nix/store` shared read-only via `virtiofs` with ephemeral writable overlay (`/nix/.rw-store`).
  - Hard resource limits (2 vCPUs, 2048 MB RAM) protecting host stability without daemon polling.
  - Fixed host ed25519 keys (`/var/lib/microvms/frieren-canary/ssh-host-keys`) mounted via virtiofs paired with `/var/lib/microvms/.known_hosts`—0 prompts, 0 collision churn across teardowns.
  - Local bridge networking (`microbr` on `192.168.83.1/24`) with host NAT through `enp1s0`.
  - Hypervisor Nginx dynamically routes `/canary/` and `canary.frieren.lan` over LAN and Tailnet (`100.97.61.65`). Verified 504 on teardown and instant 200 OK recovery on boot.
* **Workflows:** `task vm:canary:build`, `task vm:canary:run`, `task vm:canary:test`.
* **Next Migration Steps (Model B Rollout):**
  - Migrate standalone background services (Kiwix offline library, Gatus monitoring backend, Paperless document queue) into dedicated, bounded MicroVMs.

### 2. [x] EXP-101: Grammar-Constrained JSON Schema Tool Dispatcher for System 2
* **Status:** `INTEGRATED & VERIFIED`
* **Architecture:** Constrains Ollama Nemotron-3 deliberation to a typed JSON schema (`query_system2_schema()`), cutting output tokens by 85% and routing operational primitives through a sandboxed Python allowlist dispatcher (`modules/services/systemone/ensemble.py`).

### 3. [x] EXP-100: Declarative 3-Tier Fleet Governor (`services.fleetGovernor`)
* **Status:** `ACTIVE IN SYSTEMD`
* **Architecture:** Replaced ad-hoc standalone daemon timers with a consolidated 3-tier governor:
  - **S0 (Deterministic Rules):** < 500ms execution, SQLite WAL maintenance, Btrfs capacity checks.
  - **S1 (System 1 Reflex Classifier):** Julia-1 (144M) sub-millisecond triage across 10 service telemetry feeds.
  - **S2 (System 2 Deep Deliberation):** Ollama Nemotron-3-Ultra structured JSON schema reasoning for complex, unresolvable anomalies.

### 4. Ongoing Fleet Maintenance Items
* **DNS Failover:** Secondary resolver hardware node pending declaration in `profiles.dnsFailover.resolvers`.
* **SOPS Secrets Management:** 32 recipient keys synchronized across all 6 SOPS files (`task checks:sops:drift` clean).
* **Nightly Auto-Upgrade Window:** 03:00 - 05:30 nightly backup window strictly observed; all commits pushed to `origin/main`.

---

## 2026-10-15 Session — build routing, eval granularity, fern

### 5. [x] EXP-113 — builder-first warm path with no ssh (`scripts/task/warm-host.sh`)
* **Status:** `IMPLEMENTED; GAP branch unexercised`, uncommitted.
* **What:** `task infra:warm:host:<h>` builds on the builder and verifies harmonia serves
  the result; `task checks:build:route` is the read-only gate (EXP-107's enforcement).
  Readiness is one bounded HTTP request (`<cache>/<hash>.narinfo`), so it **cannot hang**.
* **Two defects it produced and fixed:** the first version `ssh`-ed to the builder
  (**deleted** — Tailscale SSH's browser check hung an unattended run 5 min), and
  `--check` used `nix build --print-out-paths`, which *starts a build* — it launched a
  full stark compile and hung 400 s. Now `nix eval --raw "<attr>.outPath"`.

### 6. [x] EXP-114 — the eval-granularity defect
* **Status:** `CAUSE IDENTIFIED; AGENTS.md protocol rewritten`, uncommitted.
* **Finding:** `AGENTS.md` prescribed `nix eval …config.networking.hostName` as the
  "quick eval smoke test". It forces **one option** and type-checks nothing else. A real
  hard failure survived it on four hosts:
  `networking.networkmanager.dispatcherScripts.*.type = "up"` — invalid; upstream accepts
  only `basic`, `pre-up`, `pre-down`. Fixed in `modules/profiles/nas-client.nix` as one
  `basic` hook filtering `$2`; verified by forcing the full toplevel for 7 hosts.
* **Now documented:** eval the **whole toplevel** pre-build, build to prove a closure
  (on the builder), and treat `dev:closure:top|size|reduce` as build *preparation*.

### 7. fern — deployed out of schedule, 2026-10-15
* **State:** `nixos-rebuild switch` run from frieren via `infra:deploy:host:fern`
  (transport `devji@192.168.3.23` — the tailnet path needs interactive auth). fern was
  on `…-nixos-system-fern-26.11.20260928.f45c6f0`, a week behind; the switch was copying
  ~2539 paths.
* **Boot-path verification is still missing (rec 6 in
  `docs/fleet-operations-recommendations.md`).**

### 8. Open: fern has no DankMaterialShell bar
* DMS **is** running (`dms … run` + `quickshell`), niri is running, 0 failed units —
  but `~/.config/DankMaterialShell/` **does not exist** (only
  `~/.local/state/DankMaterialShell/session.json`). DMS 1.6.2 expects
  `CONFIG_DIR/DankMaterialShell/settings.json`. The module comment says *"Don't manage
  settings.json — let DMS write its own at runtime"*; on the 20260928 generation it never
  did. **Next:** compare against a host whose bar works (frieren/poseidon/scratch) on the
  same chain, over the LAN IP.

### 9. Uncommitted working tree
`modules/profiles/nas-client.nix`, `modules/profiles/desktop-client.nix`,
`scripts/task/warm-host.sh` (new), `taskfiles/infra.yml`, `taskfiles/checks.yml`,
`taskfiles/services-core.yml`, `AGENTS.md`, `EXPERIMENTS.md` (EXP-113/114),
`docs/fleet-operations-recommendations.md` (new).
* **Gate:** `task checks:nix:format` fails on 12 files that **also fail at HEAD**
  (pre-existing, none of these) — it is a hard commit gate, so `task checks:nix:fix`
  is required before committing.

---

## 2026-10-16 Session — pb fleet distribution, burgernas WoL & standby power

### 10. [x] Fleet-Wide `pb` Utility Module Extraction (`modules/scripts/pb.nix`, `49da8a6`)
* **Status:** `COMMITTED, PUSHED & TESTED`
* **What:** Extracted the `pb` bash wrapper script out of the server-only module `modules/services/paste.nix` into a new declarative script module [`modules/scripts/pb.nix`](file:///Volumes/data/projects/nixconfig/modules/scripts/pb.nix).
* **Scope:** Included in `modules/scripts/default.nix`, which is inherited across all fleet desktop, container, and standalone hosts. Tested live on `fern`: uploaded test paste to `http://paste.frieren.lan/test-from-fern.txt`, verified curl fetch, and deleted with `pb rm`.

### 11. [x] BurgerNAS WoL Subnet Broadcast & Clean DSM Standby (`49da8a6`, `8ae4376`, `78feec3`)
* **Status:** `COMMITTED, PUSHED & STANDBY VERIFIED`
* **What:** Remediation for Wake-on-LAN backup failures on the DS220j cold vault:
  - Directed WoL broadcasts to `192.168.3.255:9` instead of global `255.255.255.255:9` to prevent packet drops over multi-homed interfaces.
  - Replaced raw `/sbin/poweroff` with `sudo /usr/syno/sbin/synopoweroff || sudo /sbin/poweroff` to ensure Synology hardware sleep leaves the Realtek RTL8111H PHY in standby listening mode.
  - Added `pkgs.wakeonlan` to Frieren `environment.systemPackages` for CLI / task execution.
### 12. [x] BurgerNAS WoL Removal & Daily 03:28 Window Alignment (`5b7253a`, Generation 131)
* **Status:** `COMMITTED, PUSHED & ACTIVE`
* **What:** Operator configured Synology DSM Control Panel power schedule to turn on BurgerNAS daily at 03:25 AM and shut down at 04:00 AM.
* **Architecture:**
  - Removed Wake-on-LAN hooks completely from `hosts/frieren/infra-stack.nix` and `taskfiles/burgernas.yml`.
  - Re-timed `services.restic.backups.frieren-burgernas.timer` to run daily at 03:28:00 (`*-*-* 03:28:00`), 3 minutes after DSM boot.
  - Retained Frieren push model over SFTP: BurgerNAS's 512 MB RAM ceiling would immediately cause OOM if restic pull were run on the NAS; Frieren push keeps BurgerNAS memory footprint to < 10 MB (OpenSSH `sftp-server`), verified stable during live pack repacking.

