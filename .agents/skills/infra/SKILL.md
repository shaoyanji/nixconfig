---
name: infra
description: "Host lifecycle: plan, apply, deploy, rollback, logs."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['infra', 'host', 'lifecycle', 'deploy']
    related_skills: []
---

# infra — Host Lifecycle

Canonical surface for all host lifecycle, secrets, and store operations.

## Host deployment

| Task | Description |
|------|-------------|
| `infra:deploy:host:<host>` | Plan + apply + validate |
| `infra:plan:host:<host>` | Build/evaluate closure (no apply) |
| `infra:apply:host:<host>` | Apply config to remote host |
| `infra:rollback:host:<host>` | Roll back to previous generation |
| `infra:rollback:apply:host:<host>` | Rollback apply step only |
| `infra:logs:host:<host>` | Tail journal logs via ssh (unit: `go-backend`) |

## Local rebuilds

| Task | Description |
|------|-------------|
| `infra:rebuild:nixos` | Rebuild local NixOS host |
| `infra:rebuild:darwin` | Rebuild local Darwin host |
| `infra:rebuild:home-manager` | Rebuild Home Manager profile |
| `infra:rebuild:wsl` | Rebuild WSL host (guckloch) |
| `infra:rebuild:orb` | Rebuild OrbStack host |
| `infra:switch:<os>` | Switch host using nixos/darwin-rebuild |
| `infra:boot:<os>` | Boot into next generation |

## Store maintenance

| Task | Description |
|------|-------------|
| `infra:store:clean` | Full cleanup — gc + optimise |
| `infra:store:gc` | `nix store gc` |
| `infra:store:optimise` | Deduplicate store paths |
| `infra:store:collect-garbage` | Remove old generations |
| `infra:store:menu` | Interactive store chooser |

## Secrets / SOPS

| Task | Description |
|------|-------------|
| `infra:secrets:edit:apikeys` | Edit encrypted API keys |
| `infra:secrets:edit:taskfile` | Edit encrypted Taskfile |
| `infra:secrets:edit:detaskfile` | Edit encrypted DE Taskfile |
| `infra:secrets:edit:secrets` | Edit encrypted secrets |
| `infra:secrets:new:generate` | Generate SSH + AGE keys |
| `infra:secrets:new:copy-nas` | Copy AGE key from NAS |
| `infra:secrets:decrypt:detaskfile-home` | Decrypt DE Taskfile to ~/ |
| `infra:sops:get:<query>` | Query secrets file |
| `infra:sops:fzf` | Select env entries via fzf |
| `infra:sops:update-keys` | Rotate SOPS recipient keys |
| `infra:api:get:<key>` | Print API key line from encrypted env |
| `infra:load:env` | Load API env lines |
| `infra:load:taskfile` | Decrypt operator Taskfile |

## Provenance and Initialization from $HOME

- **Execution from $HOME**: When running from `$HOME` (`~`), `~/Taskfile.yml` automatically forwards commands to `~/Documents/nixconfig/Taskfile.yml` with working directory set to `~/Documents/nixconfig`.
- **Repo Location**: `~/Documents/nixconfig` (symlink to `/Volumes/data/projects/nixconfig`).
- **Secrets & Keys**: Decrypted using keys in `~/.config/sops/age/keys.txt`.

## Fleet Inventory Matrix

All hosts configured in `flake/host-inventory.nix`:

### NixOS Desktops
- `fern`: HP 15 laptop (Ryzen 3 3250U, Vega 3, NVMe `/dev/nvme0n1`), niri desktop, autologin, NAS client.
- `stark`: Dell Inspiron 24 3477 AIO (i5-7200U, MX110 Optimus), gamescope-session + DMS greeter, dual-disk (`/dev/sdb` SSD, `/dev/sda` HDD).
- `eisen`: Desktop (RX 5700), niri desktop + gamescope-session.
- `frieren`: HP EliteDesk 800 G2 NAS/server (ZFS `/Volumes/data`, auto-upgrade 04:00, Prometheus, Syncthing, Paperless, Tika).
- `scratch`: Fujitsu ESPRIMO D556 (i5-6500, f2fs SSD), niri desktop, tmpfs IO diet, GRUB legacy BIOS (`/dev/sda`).
- `poseidon`: Workstation (Ryzen 7 3700X, RTX 2070 Super), niri desktop.
- `aceofspades`, `ancientace`, `aristotle`: Desktop workstations.

### NixOS Impermanence
- `schneeeule`: Desktop with impermanence (root wiped each boot, devji + /etc persisted to `/persist`, disko `/dev/sda`).
- `ares`: Steam Big Picture kiosk with impermanence (i5-6500, GTX 750 Ti, disko `/dev/sda`).
- `minyx`: Raspberry Pi 3 (aarch64-linux, impermanence, custompi).

### NixOS Headless & Containers
- `mtfuji`: Headless container host.
- `kellerbench`: Headless container host (GTX 750 Ti).
- `deckstation`: Headless container host.
- `applevalley`: Lenovo ThinkPad T420 container host.
- `sledgehammer`: Live USB recovery system.
- `netbook`: Independent NixOS 25.11 host (Celeron N3060, f2fs, niri desktop for alice, pinned channel).
- `guckloch`: WSL2 NixOS container.

### Darwin & Standalone Home Manager
- `cassini`: Apple Silicon macOS (aarch64-darwin, nix-darwin + nix-homebrew).
- `penguin`: Chromebook / Linux standalone Home Manager (`roles/portable-home`).
- `alarm`: Arch Linux ARM standalone Home Manager (`roles/minimal`).
- `kali`: Kali Linux ARM standalone Home Manager (`roles/minimal`).

### VM & CI
- `garnixMachine`: Garnix CI VM.
- `demo`: NixOS demo VM (no sops).
- `testvm`: MicroVM sandbox (`cloud-hypervisor`).

## Client OS Maintenance and Debugging Runbooks

### 1. Evaluate / Dry Run Closure
```bash
task infra:plan:host:<host>
# Or quick host evaluation:
nix eval .#nixosConfigurations.<host>.config.networking.hostName
```

### 2. Deploy or Apply to Remote Host
```bash
# Full workflow: plan + apply + validate
task infra:deploy:host:<host>

# Apply only (assumes already built):
task infra:apply:host:<host>
```

### 3. Inspect Remote Logs & Services
```bash
# Tail journald via SSH (default unit: go-backend):
task infra:logs:host:<host> UNIT=<unit>

# Direct service inspection:
ssh <host> systemctl status <unit>
```

### 4. Rollback Remote Host
```bash
task infra:rollback:host:<host>
```

### 5. Local Rebuilds
```bash
# NixOS local switch and refresh ~/Taskfile.yml:
task infra:rebuild:nixos

# Darwin local switch:
task infra:rebuild:darwin

# Home Manager switch:
task infra:rebuild:home-manager
```

### 6. Storage & NAS Client Recovery (fern and clients)
If `/Volumes/data` automount enters a failed state due to boot network timing:
```bash
# Run recovery tool:
nas-recover
# Or manually restart automount unit:
sudo systemctl restart Volumes-data.automount
```

### 7. SOPS & Secret Verification
```bash
# Verify all encrypted files decrypt cleanly against age keys:
scripts/task/sops-drift-check.sh

# Rotate/update recipient keys across all SOPS files:
task infra:sops:update-keys
```
