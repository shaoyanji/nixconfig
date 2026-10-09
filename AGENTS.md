# AGENTS.md

**Nixconfig** — Personal Nix flake managing NixOS, nix-darwin, and Home Manager across ~25 hosts.

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `taskfiles/README.md` for ownership and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth. Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md` — see `.agents/README.md` for the full index.

---

## Home Initialization & Tautological Control Plane

When an AI agent or developer session initializes from the home directory (`$HOME` / `~`):

1. **Repository Root & Provenance**:
   - The canonical repository path is `~/Documents/nixconfig` (symlink to persistent NAS storage at `/Volumes/data/projects/nixconfig`).
   - All Nix modules, flake definitions, secrets, and taskfiles originate from here.
2. **Tautological Taskfile Control Plane**:
   - `~/Taskfile.yml` includes `~/Documents/nixconfig/Taskfile.yml` with `dir: ~/Documents/nixconfig` and `flatten: true`.
   - Running `task <cmd>` in `$HOME` (or `task -g <cmd>` globally) executes immediately against the repository with correct working directory context. Speculative path discovery or tool calls are unnecessary.
3. **Agent Guidance & Skills Materialization**:
   - `~/.agents/` (`~/.agents/skills/`, `~/.agents/deploy/`, `~/.agents/README.md`) provides guidance and skill shards.
   - The canonical fleet operational manual is `AGENTS.md`. The local host system card + persona is compiled into `~/AGENTS.md` via `task dev:inventory:home-agents` (or `hermes-user.nix`).
4. **Secrets & SOPS State**:
   - Encrypted secrets live in `modules/secrets.yaml` (mirrored from the private `modules/secrets/` submodule).
   - Host and user age keys are registered in `.sops.yaml` and loaded from `~/.config/sops/age/keys.txt`.

---

## Architecture Overview

### Flake Output Assembly

```
flake.nix → flake/outputs.nix (hub)
  ├── nixosConfigurations ← flake/nixos-configurations.nix ← mkNixosHost (lib/mk-nixos-host.nix)
  ├── darwinConfigurations ← flake/darwin-configurations.nix
  ├── homeConfigurations  ← flake/home-configurations.nix
  ├── packages            ← flake/packages.nix
  ├── checks              ← flake/checks.nix
  ├── devShells           ← flake/devshells.nix
  └── docsSite/docs-site  ← docs-site/default.nix
```

**Host registration flow**:

1. One entry per host in `flake/host-inventory.nix`: defines `kind` (nixos/darwin/home), `system`, module chain, and host module path
2. `flake/host-projection.nix` projects inventory into per-kind attrsets automatically — no manual output wiring
3. `flake/module-sets.nix` defines the 5 global module chains used as baselines

### Module Chains (defined in `flake/module-sets.nix`)

| Chain                            | What it includes                                                                       | Used by                                                                            |
| -------------------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `globalModulesNixos`             | global + nixos + home-manager-shared + sops + nix-index + dms + dank-greeter (desktop) | poseidon, aristotle, aceofspades, ancientace, eisen, frieren, scratch, stark, fern |
| `globalModulesImpermanence`      | globalModulesNixos + impermanence + disko                                              | schneeeule                                                                         |
| containers + impermanence (ares) | globalModulesContainers + impermanence + disko                                         | ares (Steam kiosk)                                                                 |
| `globalModulesContainers`        | global + noDE + sops + home-manager + nix-index (no dms/niri desktop)                  | mtfuji, kellerbench, applevalley, minyx, sledgehammer, guckloch (WSL), deckstation |
| `globalModulesMacos`             | global + macos + nix-homebrew + home-manager + sops                                    | cassini (darwin)                                                                   |
| `globalModulesDemo`              | global + demo + home-manager (no sops)                                                 | demo (NixOS demo VM)                                                               |
| `globalModulesHome`              | standalone HM sharedModules + allowUnfree                                              | penguin, alarm, kali (standalone home-manager)                                     |

### Complete Client OS Fleet Inventory (`flake/host-inventory.nix`)

> **Source of truth**: [`inventory.toml`](file:///home/devji/Documents/nixconfig/inventory.toml) (31 total devices: 11 active Nix, 3 active non-Nix external, 1 WIP, 16 preserved).

| Host | Status | Environment | Arch | Role & Hardware Overview | Module Path | Storage Layout |
|------|--------|-------------|------|---------------------------|-------------|----------------|
| `eisen` | **Active** | `nixos` | `x86_64-linux` | High-Core Gaming Desktop & Sunshine Stream Server (Intel Xeon E5-2673 v3, 64 GiB DDR4, AMD Radeon RX 5700) | `hosts/eisen/configuration.nix` | 256GB NVMe SSD (btrfs @root, @nix, @persist) + 16TB HDD /mnt/s... |
| `fern` | **Active** | `nixos` | `x86_64-linux` | Lightweight Daily-Driver Laptop (AMD Ryzen 3 3250U, 8 GB DDR4, AMD Radeon Vega 3 iGPU) | `hosts/fern/configuration.nix` | /dev/nvme0n1 (disko: ESP + 8G swap + btrfs /root,/nix) |
| `frieren` | **Active** | `nixos` | `x86_64-linux` | Central NAS Mainframe, 4K Media Center & Application Server (Intel Core i5-8250U, 11.47 GiB DDR4 (4GB soldered, Intel UHD Graphics 620 @ 1.10 GHz) | `hosts/frieren/configuration.nix` | /dev/sdb3 (1TB SSD: 923GB btrfs @root, @home, @nix, @snapshots... |
| `guckloch` | **Active** | `nixos` | `x86_64-linux` | Windows Subsystem for Linux (WSL2) Container (Host CPU, WSL2 Dynamic Allocation) | `hosts/guckloch/configuration.nix` | WSL2 root with SSHFS mount to /Volumes/data |
| `kellerbench` | **Active** | `nixos` | `x86_64-linux` | Headless GameStream & Benchmark Rig (Intel 64-bit multi-core, 8 GiB, NVIDIA GeForce GTX 750 Ti) | `hosts/kellerbench/configuration.nix` | GRUB legacy boot (nodev) |
| `netbook` | **Active** | `nixos` | `x86_64-linux` | Alice's Travel Netbook (Pinned NixOS 25.11) (Intel Celeron N3060, 2 to 4 GB RAM, Intel HD Graphics 400) | `hosts/netbook/configuration.nix` | f2fs root, vfat /boot, systemd-boot |
| `poseidon` | **Active** | `nixos` | `x86_64-linux` | Primary High-Performance Laptop Workstation (AMD Ryzen 7 Mobile, 16 GiB DDR4, NVIDIA GeForce RTX 3050 Ti Laptop GPU) | `hosts/poseidon/configuration.nix` | High-speed persistent NVMe partitions |
| `scratch` | **Active** | `nixos` | `x86_64-linux` | I/O Diet Lightweight Workstation (Intel Core i5-6500, 8 GB DDR4, Intel HD Graphics 530) | `hosts/scratch/configuration.nix` | Legacy BIOS + GRUB (ext4 /boot, f2fs /) |
| `stark` | **Active** | `nixos` | `x86_64-linux` | Living Room All-in-One Gaming Terminal (Intel Core i5-7200U, 16 GiB DDR4, Intel HD 620) | `hosts/stark/configuration.nix` | SK hynix SC311 SATA SSD (system) + 1TB HDD /mnt/steam (btrfs+z... |
| `dragoncourt` | **Active** | **Non-Nix** (External) | `x86_64-linux` | Alwaysdata PHP/Wasm Web Hosting (Intel x86_64, Shared Hosting Quota) | `taskfiles/dragoncourt.yml` | /home/dragoncourt/www |
| `envs` | **Active** | **Non-Nix** (External) | `x86_64-linux` | Envs.net Multi-Protocol Pubnix Node (Intel Xeon, Shared Pubnix Quota) | `taskfiles/envs.yml` | /home/jisifu (public_html, public_gemini, public_gopher) |
| `moto` | **Active** | **Non-Nix** (External) | `aarch64-linux` | Primary Mobile Smartphone (Android/Termux) (Unisoc T760 / Snapdragon, 4 to 8 GB RAM, Mali-G57) | `taskfiles/moto.yml` | Android storage (/storage/emulated/0) |
| `serv00` | **Active** | **Non-Nix** (External) | `x86_64-freebsd` | FreeBSD Web Hosting & Daemon Node (Intel Xeon, 512 MB Process Memory Limit (devil info limits)) | `taskfiles/serv00.yml` | /home/jisifu |
| `delphi` | *WIP (Not Live)* | `nixos` | `aarch64-linux` | Cloud Bastion, Tailscale Exit Node & ARM64 Build Offloader (Ampere Altra Neoverse N1, 24 GiB RAM) | `hosts/delphi/configuration.nix` | 200 GB ext4/btrfs boot disk |
| `aceofspades` | Preserved | `nixos` | `x86_64-linux` | AMD Graphics Workstation (Intel Core, 16 GiB, AMD Radeon GPU) | `hosts/aceofspades/configuration.nix` | GRUB legacy boot on /dev/sda |
| `alarm` | Preserved | `home` | `aarch64-linux` | Arch Linux ARM Standalone Home Manager (ARM64, 1 to 2 GB) | `hosts/alarm.nix` | User home directory /home/alarm |
| `ancientace` | Preserved | `nixos` | `x86_64-linux` | Virtualization Host & Local Model Server (Intel multi-core, 16 GiB, Intel Graphics) | `hosts/ancientace/configuration.nix` | GRUB boot, microVM bridge network |
| `applevalley` | Preserved | `nixos` | `x86_64-linux` | Legacy ThinkPad Container & Utility Host (Intel Core i5-2520M, 8 GiB DDR3, Intel HD Graphics 3000) | `hosts/applevalley/configuration.nix` | Persistent btrfs |
| `ares` | Preserved | `nixos` | `x86_64-linux` | Steam Big Picture Kiosk with Impermanence (Intel Core i5-6500, 8 GiB DDR4, NVIDIA GeForce GTX 750 Ti) | `hosts/ares/configuration.nix` | /dev/sda (root ephemeral on boot, devji home + /etc persisted ... |
| `aristotle` | Preserved | `nixos` | `x86_64-linux` | Standard Desktop Workstation (Intel 64-bit multi-core, 16 GiB DDR4, Intel / Integrated) | `hosts/aristotle/configuration.nix` | Persistent root with NFS /Volumes/data mount |
| `cassini` | Preserved | `darwin` | `aarch64-darwin` | Apple Silicon macOS Workstation (Apple Silicon, Unified Memory (16, Apple Integrated Metal GPU) | `hosts/cassini/configuration.nix` | Encrypted APFS Macintosh HD |
| `deckstation` | Preserved | `nixos` | `x86_64-linux` | High-End Steam Kiosk & Sunshine Host (Intel 64-bit multi-core, 16 GiB, AMD Radeon RX 5700 XT) | `hosts/deckstation/configuration.nix` | Persistent storage |
| `demo` | Preserved | `nixos` | `x86_64-linux` | NixOS Demonstration VM (x86_64, 4 GiB) | `hosts/demo/configuration.nix` | Single partition, systemd-boot |
| `garnixMachine` | Preserved | `nixos` | `x86_64-linux` | Garnix CI Runner & Bountystash Host (x86_64 Cloud vCPU, Cloud Allocated) | `hosts/garnixMachine.nix` | Standard Nix store |
| `kali` | Preserved | `home` | `aarch64-linux` | Mobile Offensive Security Starter Pack (ARM64, 2 to 4 GB, Adreno / VideoCore) | `hosts/kali.nix` | Tight mobile flash storage (/home/kali) |
| `minyx` | Preserved | `nixos` | `aarch64-linux` | Raspberry Pi 3B+ Edge Node (Broadcom BCM2837B0, 1 GiB LPDDR2 SDRAM, Broadcom VideoCore IV) | `hosts/minyx/configuration.nix` | SD card with extlinux bootloader and impermanence |
| `mtfuji` | Preserved | `nixos` | `x86_64-linux` | Headless Container & AI Inference Host (AMD Ryzen 64-bit, 16 GiB DDR4) | `hosts/mtfuji/configuration.nix` | f2fs / + btrfs subvolume for /nix |
| `penguin` | Preserved | `home` | `x86_64-linux` | Chromebook Linux Container (Crostini) (Intel x86_64, Shared with ChromeOS, VirtIO GPU with nixGL wrapper) | `hosts/penguin.nix` | User home directory |
| `schneeeule` | Preserved | `nixos` | `x86_64-linux` | Impermanent Desktop Laptop (Intel 64-bit multi-core, 16 GiB, Intel iGPU + NVIDIA GeForce) | `hosts/schneeeule/configuration.nix` | /dev/sda (root erased on boot, persistent /persist, /persist/d... |
| `sledgehammer` | Preserved | `nixos` | `x86_64-linux` | Fleet Provisioning & Disaster Recovery USB (Any x86_64 host, Host RAM) | `hosts/sledgehammer/configuration.nix` | GRUB removable media bootloader |
| `testvm` | Preserved | `nixos` | `x86_64-linux` | MicroVM Sandbox (1-2 vCPU, 1 GiB) | `hosts/microvms/testvm.nix` | MicroVM disk image |

### Module Layout

```
modules/
  global/          — Global NixOS/Darwin/Home-Manager module chains
    user.nix       — Canonical user constants (user = devji, import this, not hardcode)
    global.nix     — Nix config: experimental features, substituters, GC
    nixos.nix      — NixOS HM embedded: overlays, home-manager-shared, role:heim
    noDE.nix       — Container host HM: role:minimal + shell
    macos.nix      — Darwin HM: role:home
    impermanence.nix — Persistence rules for devji user
    demo.nix       — Demo HM: role:demo, no sops
    home-manager-shared.nix — sharedModules for embedded HM (sops, nixvim, nix-index, niri, dms)
  profiles/        — Reusable host profiles
    base-node.nix  — Common NixOS baseline (kernel, SSH, keyd, networkmanager, sops, user devji)
    boot.nix       — Boot loader profile (systemd-boot/EFI defaults)
    firewall-baseline.nix — Firewall on, only TCP/22 by default
    server-hardening.nix — Journald caps, tmp cleanup, /var bind-mount to data disk
    nas-client.nix — Automount /Volumes/data from the NAS server (frieren)
    steamos.nix — Steam kiosk (greetd autologin + upstream gamescope-session, audio, 32-bit GL, Avahi)
    sunshine.nix — GameStream/Moonlight server (Sunshine on LAN, video/render/input groups)
    nixbuild-client.nix — Optional nixbuild.net remote builder (distributedBuilds, off by default)
  services/        — Service modules
    aria2-daemon.nix  — aria2 RPC + AriaNg web UI via nginx (delegates to native services.aria2)
  roles/           — User role assemblers
    minimal.nix    — Base user stack + AI
    heim.nix       — devji desktop preferences (niri, kitty, dev, zen)
    home.nix       — Desktop-oriented role (MacOS)
    portable-home.nix — Shared HM baseline (shell/base + nixvim)
  user/            — User module domains
    base/          — CLI/editor/env base
    ai/            — AI tools (gemini-cli, mods, opencode, aichat, agents)
    desktop/       — Niri compositor integration
  shell/           — Shell modules (bash, tmux, nu, zsh)
  config/          — Config data (authorized-keys, fetches.json, shells/*.nix)
    shells/        — Dev shell definitions (flaskpy, jekyll, yarn, pdf, yt, kali, pi, etc.)
  hm/              — Home-manager-only modules
  lib/             — Internal library functions
```

### Packages

Custom packages built from the flake:

- (none — the `pkgs/` directory and agent-era packages were removed in 2026-09/10; the `packages` output is `{}`)

---

## Essential Commands

### Taskfile Entrypoints

```bash
task help                        # List all tasks
task --list-all                  # Same, unfiltered
task status                      # git status + hostname
```

### Host Lifecycle

```bash
task infra:plan:host:<host>      # Build/evaluate host closure (dry run)
task infra:apply:host:<host>     # Apply configuration to remote host
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:rollback:host:<host>  # Roll back to previous generation
task infra:logs:host:<host>      # View remote journald logs
```

### Local Rebuilds

```bash
task infra:rebuild:nixos         # sudo nixos-rebuild switch (local) + refresh ~/Taskfile.yml
task infra:rebuild:darwin        # darwin-rebuild switch (local) + refresh ~/Taskfile.yml
task infra:rebuild:home-manager  # home-manager switch (local) + refresh ~/Taskfile.yml
```

### Client OS Maintenance & Debugging Runbooks

#### 1. Dry Run & Evaluation

Before deploying changes to any client OS, evaluate its configuration:

```bash
task infra:plan:host:<host>                                        # Dry-run evaluation and closure build
nix eval .#nixosConfigurations.<host>.config.networking.hostName   # Fast eval smoke test
```

#### 2. Deploying Remote Hosts

Apply configurations over SSH:

```bash
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:apply:host:<host>     # Apply closure directly
```

#### 3. Remote Log & Service Inspection

Diagnose failing units or check live output:

```bash
task infra:logs:host:<host> UNIT=<unit>   # Tail journald for UNIT (defaults to go-backend)
ssh <host> systemctl status <unit>        # Inspect unit status on remote host
ssh <host> journalctl -b -p err           # View system errors from current boot
```

#### 4. Rollback Runbook

If a deployment degrades a host:

```bash
task infra:rollback:host:<host>           # Roll back remote host generation
# For local recovery:
sudo nixos-rebuild --rollback switch      # Local NixOS rollback
```

#### 5. NAS Client Automount Recovery (fern & clients)

If `/Volumes/data` fails to mount due to early-boot network timing (causing `StartLimitBurst` hit):

```bash
nas-recover                               # Canonical recovery tool
# Or manually restart the automount unit:
sudo systemctl restart Volumes-data.automount
```

#### 6. SOPS Secrets & Key Verification

Verify decryption across all hosts and rotate recipient keys:

```bash
scripts/task/sops-drift-check.sh          # Verify all encrypted files decrypt cleanly
task infra:sops:update-keys               # Rekey all files when .sops.yaml changes
```

#### 7. frieren (NAS) Rebuild Topology — read this before rebuilding this host

frieren is a laptop-class NAS (11 GiB RAM, 8 threads, btrfs). Its nightly
window is already load-saturated; a rebuild started blind will look "stuck"
and tempt you into a retry loop, which is the failure mode this section exists
to prevent.

**Nightly job matrix (all timers `Persistent = true`):**

| Time                    | Unit                                   | Source of truth                                                |
| ----------------------- | -------------------------------------- | -------------------------------------------------------------- |
| 03:00                   | `agy-nightly-handoff` (user)           | executes `~/HANDOFF.md` via `agy`, then deletes it             |
| 03:00                   | `postgresqlBackup-immich`              | local                                                          |
| 03:30 (+10m jitter)     | `restic-backups-frieren-local`         | local                                                          |
| Sun 01:30 (+30m jitter) | `fleet-warm-cache`                     | **`github:shaoyanji/nixconfig`** — builds 7 active host closures |
| 04:00                   | `nixos-upgrade` (`system.autoUpgrade`) | **`github:shaoyanji/nixconfig#frieren`**                       |
| 05:00                   | `agy-nightly-system` (user)            | executes `~/SYSTEM.md` via `agy` (mem peak ~4.2 GB)            |
| Sun 06:00               | `nix-optimise`                         | weekly hardlink deduplication across live store paths          |

**The origin-vs-local trap (this is the one that bites):**
`system.autoUpgrade` builds from the **pushed GitHub flake**, not
`/Volumes/data/projects/nixconfig`. Any local `nixos-rebuild switch` from a
dirty tree is therefore **silently reverted by the next 04:00 run** unless the
change is committed **and pushed**. A local switch that produced no new
generation usually means exactly this. Confirm what the 04:00 run used:

```bash
journalctl -u nixos-upgrade -n 40 --no-pager | grep -E 'unpacking|new configuration'
git -C /Volumes/data/projects/nixconfig rev-parse HEAD     # must match the unpacked rev
```

**Rebuild rules:**

1. **At most one `nixos-rebuild` at a time.** Never retry-loop it — six
   concurrent attempts is what caused the 2026-10-07 06:46 incident. If it
   seems slow, _measure_ progress (next point) before touching anything.
2. **After a dirty `flake.lock` bump the closure is re-fetched, not rebuilt.**
   A nixpkgs rev change invalidates every store hash, so expect a multi-GB
   download (tens of minutes on this host). It is not hung. Watch it:
   ```bash
   find /nix/store -maxdepth 1 -newermt '-2 minutes' | wc -l   # >0 = progressing
   ls -l /nix/var/nix/temproots/<nix-pid>                      # mtime advances
   ```
   Fat tail to expect: frieren's closure contains **`paperless-ngx` →
   `python3.14-torch` + `triton-llvm` + `wandb` + `google-cloud-cpp`**
   (`nix why-depends /run/current-system <torch-path>` to re-verify). Cheap
   slimming levers here are worth more than any build tuning.
3. **Do not rebuild in the 03:00–05:30 window** on this host. Also avoid
   Sunday mornings while `fleet-warm-cache` is running.
4. **Load average lies here.** It is dominated by D-state btrfs kworkers and
   `kswapd0`, not CPU. Judge pressure with `free -h` + `vmstat 1 3` (look at
   `si/so`, `wa`, and idle%) — CPU is often 60–90% idle at loadavg 8+.
5. **A killed `nixos-rebuild` leaves an orphaned root `nix build`** that can
   never switch anything but keeps ~2 GB resident. Before retrying:
   ```bash
   pgrep -af 'nix build .*nixosConfigurations'    # kill it if it is an orphan
   ```
6. **After a successful switch, verify state, not vibes:**
   ```bash
   readlink -f /run/current-system
   nixos-rebuild list-generations | tail -3
   systemctl --failed; systemctl --user --failed
   ```

### frieren wiki stack & cache-warm workflow (2026-10-08)

- **Kiwix is declarative** (`hosts/frieren/kiwix.nix`, native
  `services.kiwix-serve`): ZIMs are store paths / `fetchurl` entries, served on
  8088 and reverse-proxied at `http://wiki.frieren.lan`. Data lives in
  `/var/lib/kiwix` (NOT `$HOME` — DynamicUser + ProtectHome can't read
  `/home`); the big ZIMs live only as GC-rooted `/nix/store` paths and
  `library.xml` is force-synced from the declarative copy by the
  `kiwix-library` activation script (tmpfiles `C+` never overwrites — it left
  a stale library until 2026-10-08). Add a new wiki by adding a `fetchurl`
  entry (use `nurl <url>` for
  the hash) + a book entry in `kiwixLibrary`. Never hand-run `kiwix-manage`
  and never hand-roll units under `~/.config/systemd/user/` — they shadow the
  declarative ones (that shadowing broke the gateway on 2026-10-08).
- **Uncached fleet builds (NVIDIA 580 etc. are unfree, never upstream-cached):**
  run `task infra:update:fleet` — flake update → `infra:warm:cache` (build all
  host closures on frieren) → `infra:apply:fleet`. Closures built elsewhere:
  `task infra:cache:push:host:<host>` pushes them into harmonia.
- **hermes-gateway:** never run `hermes gateway install` on frieren; edit the
  unit in `modules/user/ai/hermes-user.nix`. Full checklist in
  `.agents/deploy/hosts/frieren.md`.
- **SSH CA:** every host (incl. frieren) can sign certs — `ssh.ca.enableClient`
  - `rotate-ssh-cert` (1-week user certs, CA key via sops-nix at
    `~/.ssh/user_ca_key`).

### Git & Flake

```bash
task dev:git:quick-push          # Stage tracked, AI-commit, push
task dev:git:ai-commit           # Stage + interactive AI commit
task dev:git:ai-commit-push      # Stage + AI commit + push
task dev:git:build-push          # AI commit after successful build
task dev:git:quick-pull          # Pull with submodules, reload taskfile
task dev:flake:update-complete   # Full flake update workflow
task dev:flake:update:bountystash # Update single input
task dev:flake:update-transitive # Update transitive inputs a root update misses
task dev:nixbuild:plan           # Report build/fetch gaps per host vs substituters
task dev:nixbuild:warm           # Build gaps on remote builder + cachix push (budget!)
task dev:qmd:refresh             # (Re)index markdown docs (repo docs + personal vault) into qmd
task dev:qmd:vault:refresh       # (Re)index personal Obsidian vault into qmd
```

**Git pre/post hooks auto-run** — `dev:git:prehook` refreshes Taskfile.yml from encrypted secrets; `dev:git:posthook` pushes.

### Data & Storage Lifecycle

```bash
task data:audit                  # Audit NAS storage taxonomy, permissions, media hygiene
task data:clean:metadata         # Scan and remove macOS metadata artifacts (._*, .DS_Store)
task data:clean:downloads        # Cleanup orphaned control files and empty staging dirs
task data:protect:private        # Enforce 0700 permissions and .nomedia shields
task data:index:refresh          # Refresh qmd docs and vault search indices
```

### Validation

```bash
task checks:quick                # Quick eval + host-architecture check + nix lint
task checks:flake:transitive     # Sweep transitive flake pins vs upstream (read-only)
task checks:qmd:docs             # qmd repo-docs collection registered + index fresh
task checks:qmd:vault            # qmd Obsidian vault collection registered + index fresh
nix eval .#nixosConfigurations.<host>.config.networking.hostName  # Quick eval check
nix build .#checks.x86_64-linux.host-architecture -L              # Host architecture validation
nix flake check                  # Full evaluation (slower, catches everything)
task checks:nix:lint             # nixpkgs-fmt --check
```

#### Agent Verification Protocol (compute discipline)

Verification must be proportional to the change — never eval as a ritual:

1. **Eval only what the change touches.** One host per affected module chain is
   enough:
   - Host-local edit (`hosts/<name>/…`) → eval that host only.
   - Edit to a chain module (`modules/global/*`, `modules/profiles/*`) → eval
     one representative host per chain it feeds (e.g. `mtfuji` for containers,
     `poseidon` for desktops, `frieren` for servers, `cassini` for darwin).
   - Edit to `flake/` wiring → eval one host per kind (nixos, darwin, home).
2. **Batch into ONE command.** Run all needed evals in a single `bash` call
   (a `for` loop over hosts), not one tool call per eval. Count the evals
   before running; if it's more hosts than the change can affect, trim.
3. **Keyless environments (Codespaces, CI sandboxes, fresh clones).** Nix
   evaluation never needs sops keys, age keys, or secret values — sops-nix
   only declares file paths at eval time. Safe keyless checks:
   `nix eval`, `nixpkgs-fmt --check`, `deadnix`, `statix check`.
   NOT keyless (skip in Codespaces, they fail or hang without
   `~/.config/sops/age/keys.txt` and SSH access):
   `task checks:quick` (sops drift step), any `infra:*` secret/deploy task.
4. **Never build without cause.** `nix eval` suffices for config validity;
   reserve `nix build`/`infra:plan` for changes that alter the closure
   (packages, kernels, services) and say so before running.

````
### Secrets & SOPS

```bash
task infra:secrets:edit:secrets  # Edit sops secrets file
task infra:secrets:edit:apikeys  # Edit API keys env file
task infra:secrets:edit:taskfile # Edit encrypted Taskfile
task infra:sops:get:*            # Query a secret value
task infra:sops:fzf              # Select env entries interactively
task infra:sops:update-keys      # Rotate SOPS recipient keys
````

### SMTP Auth

```bash
task infra:smtp:auth             # Interactive SMTP auth for hosts (using app passwords)
# Prompts for: host, username, app-password; outputs MSMTP/MUTT config for the host
```

### Site (docs-site/)

```bash
task dev:site:build              # Build documentation site
task dev:site:preview            # Live preview
task dev:site:deploy             # Deploy to target
task dev:site:list               # List deployment targets (from taskfiles/site-manifest.json)
```

### TOTP (cloak)

```bash
task dev:cloak:view              # Pick TOTP from list (gum filter)
task dev:cloak:view:github       # Direct by name
task dev:cloak:edit              # Edit TOTP accounts file
task dev:cloak:sync-bw -- ./export.json  # Import from Bitwarden export
```

### Operator Helpers

```bash
task agents:menu                 # Interactive operator control plane
```

### Nix Raw Commands

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel          # Build host closure
nix build .?submodules=1#nixosConfigurations.<host>.config.system.build.toplevel  # With submodules (CI)
nix build .#checks.x86_64-linux.host-architecture -L                         # Run host checks
nix build .#checks.x86_64-linux.host-eval-frieren                        # Build a single check
nix build .#devShells.x86_64-linux.default                                   # Enter dev shell
nixpkgs-fmt <file>                                                           # Format Nix file
nixpkgs-fmt --check <file>                                                   # Check formatting
```

---

## Network Storage Taxonomy & Media Server Architecture

The persistent network storage is hosted on the primary 24/7 server `frieren` at `/srv/data` and mounted across the fleet at `/Volumes/data` via NFS (`modules/profiles/nas-client.nix`).

### Canonical Storage Layout

| Path (`/srv/data/` / `/Volumes/data/`)    | Role & Purpose                                       | Indexing & Access Policy                                                                                                                                                  |
| ----------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `arr/`                                    | Movies and TV series                                 | **Indexed by Jellyfin & Plex**. Strictly clean video containers (`.mkv`, `.mp4`). No archives, software installers, or ISOs.                                              |
| `media/`                                  | Primary media library mirror                         | Legacy and direct media storage.                                                                                                                                          |
| `software/`                               | Software installers, desktop utilities, fonts, tools | **Unindexed**. Contains `software/torrents/` (software downloads moved out of `arr/`) shielded with `.nomedia` and `.plexignore` to prevent media scanner probe failures. |
| `books/`                                  | Books, papers, theses, comics                        | Unindexed by video media servers; indexed by document search (`qmd`). Organized into `programming/`, `philosophy/`, `ai/`, `science/`, `comics/`.                         |
| `isos/`                                   | Operating system images and installers               | Linux (`arch`, `nixos`, `ubuntu`, `fedora`), appliances (`opnsense`, `openwrt`), and Raspberry Pi images.                                                                 |
| `german/`                                 | Language learning materials                          | Organized into `books/`, `audio/`, and `notes/`.                                                                                                                          |
| `devices/`                                | Device firmwares and recovery ROMs                   | Hardware payloads (e.g. OnePlus 6 recovery tools).                                                                                                                        |
| `projects/`                               | Cloned git repositories and source projects          | Active code checkouts (e.g. `nixconfig`, `bountystash-web`, `gpt2099.nu`).                                                                                                |
| `bin-x86/`, `bin-aarch64/`, `bin-script/` | Lazily served standalone binaries & scripts          | Accessible directly across the fleet over NFS/HTTP without building Nix derivations.                                                                                      |
| `appimages/`                              | Lazily served AppImages                              | Portable Linux applications served across the network.                                                                                                                    |
| `downloads/`                              | Active aria2 RPC staging directory                   | Permissions `0775 aria2:users`. Kept clean as an ephemeral staging area; finished downloads are sorted to their target taxonomy folder.                                   |
| `p/zhuomin`                               | User's archives                                      | **Private**: Permissions strictly enforced at `0700 devji:users`. Preserved intact for private review. Shielded with `.nomedia`.                                          |
| `p/ppp`                                   | User's private stash                                 | **Private**: Permissions `0700 devji:users`. Fully shielded with `.nomedia` and `.plexignore` so Jellyfin/Plex do not scan it.                                            |
| `p/web`                                   | Backward-compatibility symlink                       | Symlink pointing to `/srv/data/projects/bountystash-web`.                                                                                                                 |
| `security/`                               | Credentials, recovery keys, certificates             | **Restricted**: Permissions strictly `0700 devji:users` (`0600` for private files). Never exposed to network guests.                                                      |
| `storage/`                                | Backward-compatibility symlink                       | Points to `.` (the data root) so legacy paths like `/Volumes/data/storage/...` resolve seamlessly.                                                                        |

### Media Server Isolation Rules

- **Jellyfin and Plex libraries**: Point to `/srv/data/arr` and `/srv/data/media`.
- **The Probe Failure Trap**: Media scanners invoke `ffprobe` on all files within indexed trees. When non-media files (e.g., Windows ISOs, Mathematica binaries, zip archives) exist in `arr/`, the scanner crashes with recurring probe exceptions.
- **Enforcement**:
  1. Only video and subtitle files (`.mkv`, `.mp4`, `.srt`, etc.) belong in `arr/`.
  2. Software torrents and non-media data are isolated in `software/torrents/` or `books/`.
  3. Directories that should never be indexed must contain `.nomedia` and `.plexignore` sentinel files.
  4. Run `task data:audit` to verify media hygiene.

### Security Directory & Key Fallback Architecture

- **SOPS as Canonical Truth**: All primary secrets, API tokens, and user credentials reside in `modules/secrets.yaml` (and `modules/secrets/apikeys.yaml`).
- **Cloak (TOTP)**: Fully integrated into `modules/secrets.yaml` under `.cloak`. Managed with `task dev:cloak:*`.
- **Master Key (`id_ed25519`)**: Kept at `0600` inside `security/` (protected by `0700` directory permissions) and encrypted as `id_ed25519.age` using fleet age keys (`frieren`, `devji`, `poseidon`).
- **Universal NuShell Fallback (`gist.nu`)**:
  - Dynamically searches for `apikeys.yaml` in standard workspace locations (`~/Documents/nixconfig`, `/srv/data/nixconfig`) and decrypts via `sops`.
  - Automatically discovers age identities (`~/.config/sops/age/keys.txt`, `~/.ssh/id_ed25519`, or local security keys) for transparent decryption.

---

## Secrets Architecture

Two separate encrypted files, decrypted via `sops-nix` using host age keys:

| File                      | Decryptors                                                                         | Contents                                      |
| ------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------- |
| `modules/secrets.yaml`    | All hosts (via `ssh_host_ed25519_key`)                                             | App secrets, `hashedPassword`, API keys, TOTP |
| `modules/ssh-ca-key.yaml` | Full fleet (all age recipients in `.sops.yaml`; includes frieren since 2026-10-08) | SSH User CA private key                       |

**Key locations**:

- `.sops.yaml` — age key registrations (each host maps its `ssh_host_ed25519_key` age pubkey)
- `modules/secrets/` — **git submodule** pointing to private `shaoyanji/secrets` repo (contains actual encrypted files)
- `modules/secrets.yaml` — local symlink/mirror of the submodule's secrets.yaml

**SSH CA workflow**:

- Servers trust a single CA public key (`modules/ssh-ca.nix`)
- Workstations sign 1-week certs via `rotate-ssh-cert` (uses `~/.ssh/user_ca_key` from sops-nix)
- No `authorized_keys` management needed after CA setup

**Bootstrap**: First connection to bare metal is outside CA model (USB ISO/temp password).

---

## CI Pipeline & Control Plane

GitHub Actions in `.github/workflows/`:

- `nixcachix.yml` — Dynamic change-detection matrix (`scripts/ci/detect-affected-hosts.py`):
  - Inspects `git diff` against active NixOS hosts in `inventory.toml`.
  - Documentation/meta changes (`*.md`, `docs/`, `taskfiles/`) skip runner allocation (0 builds).
  - Host-specific changes (`hosts/<host>/**`) build only the affected host.
  - Shared Nix modules (`modules/**`, `flake.lock`) anchor to `frieren` by default.
  - Commit message overrides: `[skip ci]`, `[ci all]`, `[ci <host1,host2>]`.
  - Manual dispatch: `task dev:ci:trigger:<host>` or via GitHub Actions UI.
- `nixcachix-darwin.yml` — macOS builds (deactivated: `cassini` is preserved)
- `nixcachix-aarch64.yml` — ARM builds (deactivated: `minyx` and `kali` are preserved)

Operator control tasks:
- `task dev:ci:plan` — Evaluate CI impact of unpushed commits against `origin/main`
- `task dev:ci:plan:worktree` — Evaluate CI impact of current working tree changes
- `task dev:ci:trigger:<host>` — Manually trigger CI build for `<host>` (or `all`)

CI uses `nix build -L .?submodules=1#...` (note `?submodules=1` for git submodule support).

---

## Nix Patterns & Gotchas

### Non-obvious patterns

- **User constants**: `modules/global/user.nix` is the single source of truth for the primary user (`devji`). Import it with `let user = import ../global/user.nix;` — never hardcode user paths or the username.
- **Attrset merging**: `//` is **shallow, right-biased** — `{ a.x = 1; } // { a.y = 2; }` loses `a.x`. Use `lib.recursiveUpdate` for deep merge.
- **`lib.mkIf` / `lib.mkMerge`**: the standard conditional patterns. Also `lib.optionalAttrs` for conditional attrsets and `lib.optionals` for conditional list items.
- **Option priorities**: `lib.mkDefault` vs `lib.mkForce` vs `lib.mkOverride` are used for option priority layering.
- **`profiles.boot` module**: boot options are accessed via `config.profiles.boot.systemd-boot` and `config.profiles.boot.efi` (not direct `boot.loader.*`).

### Build-avoidance traps

Some packages build from source (Maven, Go, etc.) with no cached variant for overridden configurations:

| Module                                 | Issue                                                      | Mitigation                                                |
| -------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------- |
| `services.tika` (`search/tika.nix`)    | `cfg.package.override { enableGui = false }` → Maven build | Inline systemd unit with stock `pkgs.tika`                |
| `services.gotenberg` (`paperless.nix`) | Chromium stub at module level keeps ~300 MiB chromium      | Configure `services.gotenberg.chromium.package` with stub |

Before deploying a host referencing Java (Maven/Gradle), Go, or Rust packages, run `nix build --dry-run` to verify the closure is cached.

### Service module conventions

- **Option namespaces**: `services.<name>` for system services, `profiles.<name>` for composable profiles
- **`lib.types.nullOr lib.types.path`**: optional file path patterns use this type
- **Secret injection**: uses `systemd LoadCredential` (never on command line). Example: `rpcSecretFile` in aria2-daemon module.

### CI quirk

CI commands use `nix build -L .?submodules=1#...` — the `?submodules=1` is critical for accessing the `modules/secrets` submodule. Local `nix build` without that flag works fine since the submodule is already checked out.

---

## Adding a New Host

1. Create host module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix` for simple cases)
2. Add hardware/storage as needed (e.g., `hardware-configuration.nix`, `disko.nix`, or profile imports)
3. Register in `flake/host-inventory.nix` with:
   - `kind` (`nixos`, `darwin`, or `home`)
   - `system` (e.g., `"x86_64-linux"`)
   - Module chain (`globalModulesNixos`, `globalModulesImpermanence`, `globalModulesContainers`, etc.)
   - Host module path(s)
   - `specialArgs` or `extraSpecialArgs` as needed
4. Output assembly is automatic via `flake/host-projection.nix`
5. Build: `task infra:plan:host:<name>` or `nix build .#nixosConfigurations.<name>.config.system.build.toplevel`

For provisioning a new server:

- The host's age key (from `ssh_host_ed25519_key`) must already be in `.sops.yaml` for `hashedPassword` decryption
- `ssh.ca.enable = true` is inherited from `base-node.nix`
- SSH in using a cert from your workstation

---

## Task Namespace Summary

See [Task Control Plane](docs/task-control-plane.md) for full namespace definitions and workflow examples.

| Namespace       | What                                                                                                         | Skill                                  |
| --------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| `infra:*`       | Host lifecycle, secrets, SOPS                                                                                | `.agents/skills/infra/SKILL.md`        |
| `agents:*`      | Operator menu, xs, OAuth                                                                                     | `.agents/skills/agents/SKILL.md`       |
| `checks:*`      | Validation, smoke checks, nix lint                                                                           | `.agents/skills/checks/SKILL.md`       |
| `dev:*`         | Git, flake, site, PRs, packages                                                                              | `.agents/skills/dev/SKILL.md`          |
| `data:*`        | NAS storage taxonomy, hygiene, permissions, media unindexing                                                 | `.agents/skills/data/SKILL.md`         |
| `moto:*`        | Motorola Android (Termux) shell, file push/pull, Wish/Gum menu                                               | `.agents/skills/moto/SKILL.md`         |
| `serv00:*`      | Serv00 FreeBSD hosting, Devil CLI, webserver lifecycle                                                       | `.agents/skills/serv00/SKILL.md`       |
| `dragoncourt:*` | Alwaysdata Debian hosting, PHP/Wasm webserver                                                                | `.agents/skills/dragoncourt/SKILL.md`  |
| `envs:*`        | Envs.net Debian hosting, public_html / Gemini / Gopher, build pipeline                                       | `.agents/skills/envs/SKILL.md`         |
| `bountystash:*` | Bountystash Console (<14KB TCP budget), preview & Cloudflare Pages deployment                                | `.agents/skills/bountystash/SKILL.md`  |
| `apps:*`        | Job application workflow (appflow): status updates, email flow, sync, builds                                 | `.agents/skills/apps/SKILL.md`         |
| `services:*`    | Legacy wrappers (canonical: `infra:*`)                                                                       | `.agents/skills/services/SKILL.md`     |
| `google-drive`  | Google Drive OAuth setup, rclone, tailscale funnel                                                           | `.agents/skills/google-drive/SKILL.md` |
| `antigravity`   | Delegate coding to Antigravity CLI (Google's agent) with `--dangerously-skip-permissions` and `--jsonschema` | `.agents/skills/antigravity/SKILL.md`  |
| `crush`         | Delegate coding to Crush CLI (Charm's agent) with `--yolo` and structured output                             | `.agents/skills/crush/SKILL.md`        |

---

## Memory hierarchy (jev decides escalation)

| Layer              | Role                                          | When used                                      |
| ------------------ | --------------------------------------------- | ---------------------------------------------- |
| MEMORY.md          | Boot — persists across sessions               | Always loaded                                  |
| Vault              | Fast working memory — offline, personal       | First stop for context                         |
| qmd wiki           | Resource — docs, runbooks, codebase           | Concept/location queries                       |
| mem0 / supermemory | Deep consult — when vault + wiki insufficient | Decided by jev (min-prob 0.8, min-margin 0.15) |

Search order: vault → wiki (qmd BM25) → mem0/supermemory (jev-decided) → web.

When unsure which skill to read, search the skills index first: `qmd search "<topic>" -c skills --format json`.

---

## qmd Search Operations

Local hybrid search over markdown docs and notes via `qmd` (`pkgs.llm-agents.qmd`, installed fleet-wide). Three canonical collections:

| Collection  | Target Path                                              | Content                                                                                 |
| ----------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `nixconfig` | `/srv/data/projects/nixconfig` (`~/Documents/nixconfig`) | This repo's documentation: README, AGENTS.md, runbooks, `docs/*`, `taskfiles/README.md` |
| `vault`     | `/Volumes/data/Obsidian-Git-Sync` (`~/vaults/personal`)  | Personal Obsidian vault: zettels, schematics, notes                                     |
| `skills`    | `~/.hermes/skills/`                                      | Agent skills indexed for BM25 search                                                    |

### Index lifecycle

```bash
task dev:qmd:refresh             # Register (if missing) and reindex both collections
task dev:qmd:vault:refresh       # Reindex the Obsidian vault only
task dev:qmd:docs:refresh        # Reindex nixconfig docs only
task checks:qmd:docs             # Verify nixconfig collection registered + index fresh
task checks:qmd:vault            # Verify vault collection registered + index fresh
```

The `checks:qmd:*` tasks exit 1 when a collection is missing or any `.md` file is newer than the index; run them after doc edits.

### Querying

```bash
qmd search "impermanence disko" -c nixconfig   # repo docs only
qmd search "zettel topic" -c vault             # vault only
qmd search "query"                             # all collections
qmd search "query" --json                      # agent-friendly output
qmd get "#docid"                               # fetch a full document from search results
qmd status                                     # index health and file counts
qmd update                                     # incremental reindex (fast, BM25)
```

Prefer BM25 `qmd search` (instant); `qmd embed` (semantic vectors) is optional and slower. Prefer qmd over raw `grep` when locating concepts or runbooks across repo docs and the vault — it is ranked and collection-scoped.

---

## Key Operator Helpers

- `agents:menu` is the interactive operator control plane
- NAS client recovery logic lives under `modules/profiles/nas-client.nix`

## Deployment Guidance

Host deployment flows use `infra:*` tasks directly. See `.agents/deploy/README.md` for host-specific deployment notes. Per-host quirks live in `.agents/deploy/hosts/*.md`.

## Git Hooks Setup

Pre-commit hooks in `.githooks/` run deadnix (hard gate), statix (advisory), and a formatting check accepting either alejandra or nixpkgs-fmt (hard gate). Tools missing from PATH are fetched via nix from the nixpkgs revision pinned in `flake.lock`, so the checks are machine-independent. Enable with:

```bash
bash .git-hooks-setup.sh    # sets core.hooksPath to .githooks/
```

## Nixpkgs Formatting

Nix files use `nixpkgs-fmt`. The formatter is included in `base-node.nix` system packages and dev shells. CI checks formatting via `task checks:nix:lint`.

## External Package Registry

External fetched dependencies are registered in `modules/config/fetches.json` and resolved through `lib/fetches-extra.nix`. Update hashes with:

```bash
task dev:config:hash-update    # runs nix-hash-update.sh
```

## Documentation Map

| File                                 | Content                                                                |
| ------------------------------------ | ---------------------------------------------------------------------- |
| `README.md`                          | Full repo documentation, architecture, all workflows                   |
| `AGENTS.md`                          | This file — canonical agent routing and codebase manual                |
| `inventory.toml`                     | Canonical 31-device fleet inventory source of truth                    |
| `docs/fleet-inventory.md`            | Fleet device catalog, hardware profiles, roles & operating disciplines |
| `.agents/fleet-matrix.md`            | Compact fleet context matrix for LLMs and agent prompts                |
| `docs/task-control-plane.md`         | Task namespace policy and workflow examples                            |
| `docs/frieren-access.md`             | frieren service-access runbook (LAN/tailnet matrix, DNS, direct ports) |
| `docs/userland-package-ownership.md` | Package ownership and role wiring                                      |
| `taskfiles/README.md`                | Taskfile ownership map and shard reference                             |
| `hosts/sledgehammer/USB.md`          | Sledgehammer live USB creation guide                                   |
| `AUDIT.md`                           | AI module cleanup audit                                                |
| `TODO.md`                            | Current work tracking and backlog                                      |
