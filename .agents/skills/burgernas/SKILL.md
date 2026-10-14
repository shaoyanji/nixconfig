---
name: burgernas
description: "BurgerNAS (Synology DS220j cold vault): WoL power, restic backup target, leech-only Transmission."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['burgernas', 'synology', 'dsm', 'cold-vault', 'restic', 'wol', 'transmission']
    related_skills: ['infra', 'data']
---

# burgernas — DS220j Cold Vault Control Plane

Operate BurgerNAS, the fleet's secondary cold backup vault and storage extension
(a Synology DiskStation **DS220j**, DSM 7.4.1, aarch64, **512 MiB RAM**).

- **Host**: `192.168.3.92` (`eth0`), MAC `90:09:D0:06:C1:EE`
- **Tailscale**: `burgernas` / `100.72.61.23`
- **SSH alias**: `burgernas` (user `devji`)
- **Web UI**: `https://192.168.3.92:5001/`
- **restic target**: `sftp:devji@192.168.3.92:/volume1/backup/frieren/restic`
- **Credential**: NAS sudo password is read from `~/nas` (devji)

## Role

Cold vault: normally powered **off** (~0 W). Frieren is the *controller* — it
wakes the NAS via Wake-on-LAN for the Sunday 03:35 restic push and the NAS powers
itself off daily at **22:45**. Never write imperative cron jobs or ad-hoc scripts
on the device (see its `~/AGENTS.md`).

## Quick Tasks

| Task | Description |
|------|-------------|
| `task burgernas:ssh` | Interactive SSH shell |
| `task burgernas:exec -- "<cmd>"` | Non-interactive command (agent-friendly) |
| `task burgernas:status` | System, memory, storage, WoL and Transmission state |
| `task burgernas:info` | DSM build, shared folders, restic repo |
| `task burgernas:wol` | Wake via Wake-on-LAN magic packet |
| `task burgernas:online` | Wait for SSH after a wake (120s) |
| `task burgernas:poweroff` | Arm WoL and cleanly power off |
| `task burgernas:transmission:status` | Transmission state + leech-only keys |
| `task burgernas:transmission:leech` | Apply the shared leech-only policy (needs `~/nas`) |
| `task burgernas:backup:seed` | `[frieren root]` Start the restic seed systemd unit |
| `task burgernas:snapshot` | `[frieren root]` List repository snapshots |
| `task burgernas:menu` | Interactive gum menu |

## Constraints

- ⚠ **512 MiB RAM** — never run heavy compilers, browsers, containers, or full AI
  runtimes on the NAS; they OOM-kill.
- ⚠ **Non-Nix** — no `nix`, `nixos-rebuild`, or flake commands.
- ⚠ **Frieren is the backup controller** — no imperative cron/rsync on the NAS.
- ⚠ **Keep WoL armed** on `eth0` so the backup window can wake it.
- Power ops use devji's passwordless sudo (`/sbin/poweroff`, `/bin/ethtool`,
  `/bin/systemctl`); writing `settings.json` needs the `~/nas` password.

## Remote `task -t`

```bash
task -t taskfiles/burgernas.yml burgernas:status
task -t taskfiles/burgernas.yml burgernas:transmission:leech
```

See also: `inventory.toml` (`[hosts.burgernas]`), `hosts/frieren/infra-stack.nix`
(restic target + `burgernas-poweroff` timer), and `docs/download-taxonomy.md`.
