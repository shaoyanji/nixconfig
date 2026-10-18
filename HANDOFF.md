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

### 8. Uncommitted working tree *(historical — resolved 2026-10-17)*
> **Resolved:** the tree is clean and every file below is committed. The 12
> formatting failures noted here are gone: `task checks:nix:format` reports
> 218/218 clean. See the 2026-10-17 session at the end for how the tree was
> reconciled with a rewritten `origin/main`.

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

### 13. [x] BurgerNAS Static aarch64 Binary Sync Deployment (`10ff65e`, Generation 132)
* **Status:** `COMMITTED, PUSHED & LIVE VERIFIED`
* **What:** Operator requested weekly synchronization of static compiled ARM64 binaries between Frieren's `/Volumes/data/bin-aarch64/` and BurgerNAS's `/volume1/Shared Library/bin-aarch64/`.
* **Implementation:**
  - Declared `systemd.services.burgernas-bin-sync` and `systemd.timers.burgernas-bin-sync` in [`hosts/frieren/infra-stack.nix`](file:///Volumes/data/projects/nixconfig/hosts/frieren/infra-stack.nix), running as `devji:users` on Sundays at 03:32 CEST (`Sun *-*-* 03:32:00`), timed after daily restic push finishes and within the 03:25–04:00 DSM uptime window.
  - Rsync command utilizes `--rsync-path=/usr/bin/rsync` to bypass Synology DSM's restricted non-login shell wrapper, with `--delete`, `-avz`, and clean path quoting for spaces.
  - Added interactive task `task burgernas:bin:sync` to [`taskfiles/burgernas.yml`](file:///Volumes/data/projects/nixconfig/taskfiles/burgernas.yml) and registered in `task burgernas:menu`.
  - Executed initial live rsync transferring 256 MB compressed across 46+ static binaries; verified parity on BurgerNAS.
  - Deployed to NixOS Generation 132 (`l3kaaf3j1vprkmlsgla9dclsahdsgcrn`) and verified live systemd execution in 2.2s.

### 14. [x] Tmux Status Bar Restoration & Kitty Window Title Bar Removal (`d355727`, Generation 133)
* **Status:** `COMMITTED, PUSHED & LIVE VERIFIED`
* **What:** Reverted mistaken tmux statusbar debloat lines (`set -g status off`, `set -g set-titles off`, `set -g pane-border-status off`) in `modules/shell/tmux.nix` that disabled tmux's status line and Catppuccin theme.
* **Kitty Title Bar:** Added `hide_window_decorations = "yes"` to `programs.kitty.settings` in [`modules/kitty/default.nix`](file:///Volumes/data/projects/nixconfig/modules/kitty/default.nix) to hide Kitty's top GUI window title bar.
* **Verification:** Switched cleanly to NixOS Generation 133 (`px28k7jav07j5jymrrf9mp1161lx1lgb`), verified `hide_window_decorations yes` in `~/.config/kitty/kitty.conf`, and verified `status on` in tmux.

---

## 2026-10-17 Session — lineage reconciliation, LF hygiene, and what a push runs

### 15. [x] `main` reconciled with the rewritten `origin/main` (`7a9b2c70`, `507b8b51`, `5e5aab79`, `c0afd727`)
* **Status:** `COMMITTED (local), NOT PUSHED` — the old tip is tagged
  `pre-integration` (`7e90cd5a`).
* **The shape of the problem:** `git merge-base HEAD origin/main` returns
  **nothing**. The rotated-key purge rewrote every hash on the remote, so the two
  lineages share content but no history; a plain `git merge` conflicts on
  almost every path. The reconciliation is therefore a **union**, not a merge:
  `7a9b2c70` joins both lineages as parents (`origin/main` `e520abc` +
  our `7e90cd5a`). **Do not `git pull` / `rebase` / `reset` on this branch**;
  fetch, inspect, apply on top.
* **The defect worth remembering:** the first union (`7a9b2c70`) was built as
  *`origin/main`'s tree + our uncommitted delta (77 paths)*, which silently
  dropped everything our lineage had **committed** and the rewritten remote
  lacked — the six `c811602` skills, `hosts/eisen/{qwen-image-server,
  parakeet-server,parakeet-transcribe}.py`, `main_test.go`, the
  `gpu_busy`/`GPU_LOCK_FILE`/429 path in `llm-decision-router/main.go`, and
  `go.mod` 1.23. It was caught by a file count (`452` vs `458`), not by a gate:
  **`git ls-tree -r --name-only <commit> | wc -l` is the cheap test that a union
  did not lose a whole class of content.** `507b8b51` rebuilds from our tree and
  keeps the remote-only files as additions; `git diff --stat 7e90cd5a main` is
  now a short, reviewable list.
* **Two files genuinely come from the remote lineage**, because ours are worse:
  `.gitignore` (CRLF) and `modules/user/ai/skills/jev-ultrafast/scripts/env_helper.js`
  (ours carried `env.TYPESAFE_API_KEY=REDACTED` purge residue that breaks the key
  mapping). Note the CRLF was *cosmetic*: git strips the trailing CR when
  matching ignore patterns, so no path was ever mis-ignored.
* **Recovery refs if anyone needs the old state:** tag `pre-integration`,
  tag `archive/kolibri-orphan-8493d4d7` (an unreachable duplicate of the merged
  Kolibri work, pinned so `git gc` cannot drop it — its content is already in
  `main`), and `.task/backup/p-repo-eaa11f0-2026-10-17/` (uncommitted work from
  the separate clone `/Volumes/data/p/repo/nixconfig`, patch verified with
  `git apply --check` against a clean extraction of `eaa11f0`).

### 16. [x] LF-only line endings and a `.gitattributes` pin (`5e5aab79`)
* `.gitignore` carried 9 CRLF lines inherited from an old checkout; normalised to
  LF (`git diff --ignore-cr-at-eol` is empty, so it was byte-only) and pinned
  with `* text=auto eol=lf`. No tracked file contains CR today and
  `git add --renormalize --dry-run` is empty, so nothing renormalises later.

### 17. Gate note — `checks:qmd:docs` goes stale on any markdown change
* The local qmd index is compared against the tree, so after a merge or a doc
  commit the gate fails `STALE`. Remedy is the gate's own message:
  `task dev:qmd:docs:refresh` (local collection only). Verified green after
  refreshing; `checks:docs:sync` and `checks:inventory:sync` are unaffected.

### 18. What a `git push` runs — and it is not frieren
* `.github/workflows/nixcachix.yml` triggers `on: push` (any branch) and
  `workflow_dispatch`. Every job is GitHub-hosted: `runs-on: ubuntu-latest` for
  `sops-drift` and `plan`, and `runs-on: ${{ matrix.os }}` (ubuntu/macOS) for the
  per-host `build-machines` matrix.
* **Nothing executes on this host.** There is no self-hosted runner
  (no `actions-runner` unit or directory, no `runs-on: self-hosted` anywhere),
  no local forge (the only `:3000` listener is paperless' gotenberg), and this
  clone has **no installed git hooks** (`core.hooksPath` unset, samples only) —
  the repo's `pre-push` installer task belongs to `bountystash-console`, not
  here. So a push cannot trigger a hook that rebuilds or switches frieren.
* CI consequences to expect: affected hosts are detected from the diff, each is
  built and eval-gated on GitHub's runners, and results go to the **Cachix cache
  `shaoyanji`** — *not* to frieren's harmonia. The workflow contains no
  `deploy`/`ssh` step, so deploys stay manual (`infra:warm:host:*` →
  `infra:deploy:host:*`).

### 19. Open after 2026-10-17
* **Push** `main` (fast-forward ahead of `origin/main`; no force needed) — not
  done, awaiting the operator.
* `chore/deadnix-cleanup` and `picobot/pipe-operator-refactor` are the only local
  branches **not** merged into `main`.
* `/Volumes/data/openclaw/{nixconfig,projects/nixconfig}` are sibling clones owned
  by `vaultwarden:influxdb2`, unreadable as `devji`; each has files that are not
  in `main` (62 and 70 respectively), so someone with read rights should
  inventory them before assuming nothing was lost.
* frieren's committed closure baseline (`32104328080`, 29.9 GiB) is the **pre-cut**
  measurement: deploy the debloat cuts, then `task dev:closure:budget:adopt` to
  re-baseline rather than predicting the new size.
* From the Eisen side (the reply that prompted the audit above): the **canary
  microVM test has still not been run**, and Eisen's shutdown stays gated on the
  canary test, the microVM operating docs and the final Eisen HANDOFF — the last
  two landed in `c0afd727` (`hosts/microvms/README.md`, `hosts/eisen/HANDOFF.md`).
  The running Eisen system is activated from the pre-merge commits: do not rebuild
  it from `main` until that is confirmed, since the live closures are the good
  state.

### 20. [x] Fleet Monitoring 5AM SimpleX Alerting, Alpine Kiwix ZIM & Libation Audiobooks Audit (2026-10-18)
* **Fleet Monitoring 5AM SimpleX Report & Alerting Bridge (HC-6, Commit `c6679a44`):**
  - Integrated `fleetGatusReport` into `agySystemRunner` (`hosts/frieren/infra-stack.nix`). Every morning at 05:00 CEST, Gatus endpoint statuses are queried, formatted into a 7-endpoint scorecard, and delivered to `#Fleet` on SimpleX Chat via WebSocket RPC (`ws://127.0.0.1:5225`). Tested live (message item 41 delivered).
  - Wired degradation directly to the System One reflex gate: service failure trips `SHOULD_RUN_CASCADE=1` to invoke autonomous repair.
  - Added declarative alerting in `modules/services/fleet-monitors.nix` with loopback custom webhook bridge (`fleet-alert-bridge` on port 5226) that forwards realtime downtime alerts to `#Fleet` on SimpleX, resolving HC-6.
* **Kiwix ZIM Knowledge Base Catalog Expansion (EXP-059, Commit `c6679a44`):**
  - Ingested `alpinelinux_en_all_maxi_2026-07.zim` (62 MB, SRI `sha256-LRkanai/3keuUFFk0Hahh1EwcL+SKY/g6qvfuqmB3fE=`) into `modules/services/kiwix.nix` and `kiwixLibrary`.
  - Cataloged heavy sysadmin archives (Server Fault 1.63 GB, Unix & Linux Stack Exchange 1.31 GB, Stack Overflow Top 500k 5.5 GB) for off-peak ingestion during scheduled 03:00 maintenance window.
* **Home Assistant Core Network Infrastructure Device Integration:**
  - Provisioned 10 local network devices into Home Assistant via native Ping integration with custom friendly names and MDI icons (192.168.3.1 router, .7 printer, .8 vacuum, .11/.13/.15/.17/.21 mesh APs, .18/.19 powerline adapters).
  - Loaded pending Zeroconf flow for HP LaserJet M15w (192.168.3.6) into native IPP integration.
* **Audible Liberation Audiobooks Download & NAS Serving Audit:**
  - Audited `LibationContext.db`: 2,318 audiobooks cataloged.
  - 63 audiobooks (89 `.m4b` files) converted in `/srv/data/audiobooks/Books/` (46 GB). 0 errors recorded. Interrupted at 05:00 CEST restart (partial download of `The Laws of Human Nature`, 266 MB, preserved in `.inprogress/`).
  - **Storage Warning:** 2,318 audiobooks require **~1.69 TB of storage**. Available space on `/srv/data` (`/dev/sda2`) is **842 GB**. Unrestricted full liberation will exhaust the 2TB HDD, crashing PostgreSQL, Immich, and backups.
  - **Recommendation:** Implement phased batch liberation (100–150 books per batch, keeping >= 300 GB headroom) and deploy `services.audiobookshelf` (port 13378) or map `/srv/data/audiobooks/Books` as a "Books" library in Jellyfin.




