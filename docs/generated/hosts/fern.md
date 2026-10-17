# fern

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Lightweight Daily-Driver Laptop |
| status | active — In active production as the primary lightweight daily-driver laptop. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | HP 15 Laptop (15s-eq series) |
| cpu | AMD Ryzen 3 3250U (Picasso/Zen+, 2c/4t, 15 W) |
| gpu | AMD Radeon Vega 3 iGPU (amdgpu) |
| ram | 8 GB DDR4 |
| storage | /dev/nvme0n1 (disko: ESP + 8G swap + btrfs /root,/nix) |
| persona | Portable Field Operative (tier: lightweight-laptop) |
| persona hint | You are the lightweight daily laptop companion. Prioritize snappy UI response, battery endurance, and smooth NAS file synchronization. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - battery-optimized
  - lightweight-desktop
  - no-steam
  - laptop-profile
  - btrfs

## Key services

- services:
  - Niri Wayland Compositor (autologin devji)
  - DMS Greeter (DankMaterialShell)
  - auto-cpufreq (powersave on battery, performance on AC)
  - libinput touchpad tuning
  - NAS client automount (/Volumes/data from frieren)
  - NO Steam (deliberately omitted)

## Allowed tasks

- tasks:
  - Everyday coding and markdown notes
  - NAS client synchronization and recovery
  - Lightweight local builds and documentation
  - Battery lifecycle management

## Constraints

- constraint:
  - 15W dual-core processor and 8GB RAM; avoid heavy compilation loops.
  - Never install or launch Steam; this machine is strictly work-focused.

## Notes

- HP 15 laptop (Ryzen 3 3250U Picasso, Vega 3 iGPU, 8 GB): lightweight niri desktop mirroring scratch — globalModulesNixos (niri + DankMaterialShell greeter via programs.dms-greeter + role:heim userland), autoLogin straight into niri as devji.
- Deliberately NO Steam (contrast stark/eisen). modules/profiles/laptop.nix layers auto-cpufreq + libinput.
- Single-disk disko (ESP + 8G swap + btrfs /root,/nix). This unit's SSD is NVMe (KIOXIA KBG40ZNV256G), so the device is /dev/nvme0n1; HP 15s-eq units with a SATA M.2 enumerate as /dev/sda instead — verify with lsblk BEFORE disko formats it. Persistent (no impermanence).
