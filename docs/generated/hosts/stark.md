# stark

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Living Room All-in-One Gaming Terminal |
| status | active — In active production as the living room All-in-One Steam Big Picture terminal. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | false |
| hardware | Dell Inspiron 24 3477 All-in-One (AIO) |
| cpu | Intel Core i5-7200U (Kaby Lake-U, 2c/4t, 15 W) |
| gpu | Intel HD 620 (panel) + NVIDIA GeForce MX110 (Maxwell GM108M, PRIME render offload, legacy_580) |
| ram | 16 GiB DDR4 |
| storage | SK hynix SC311 SATA SSD (system) + 1TB HDD /mnt/steam (btrfs+zstd) |
| persona | Living Room Gaming & Media Controller (tier: low-power-gaming) |
| persona hint | You are the living room gaming console and media hub. Ensure gamescope sessions launch reliably with correct PRIME offload switches. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - aio-form-factor
  - optimus-prime
  - dual-gpu
  - steam-gamepadui
  - dual-disk

## Key services

- services:
  - Gamescope Session (steam -gamepadui autologin)
  - DMS Greeter (fallback Niri session)
  - NVIDIA PRIME render offload (nvidia-offload)
  - Steam library on /mnt/steam

## Allowed tasks

- tasks:
  - Steam Big Picture session management
  - PRIME offload optimization (nvidia-offload %command%)
  - Living-room media playback
  - HDD Steam library management

## Constraints

- constraint:
  - CPU is a 15W dual-core; avoid running heavy background tasks during gameplay.
  - dGPU is a Maxwell GM108M (sm_50); CUDA capabilities are legacy.

## Notes

- Dell Inspiron 24 3477 AIO (i5-7200U Kaby Lake-U, 16 GiB) Steam Big Picture desktop mirroring eisen: globalModulesNixos brings in niri + DankMaterialShell greeter + role:heim userland.
- autoLogin drops devji into the upstream gamescope-session (steam -gamepadui) with the DMS greeter as fallback.
- The MX110 (Maxwell GM108M sm_50) dGPU needs the legacy_580 driver and is muxless Optimus: PRIME render offload with the HD 620 iGPU driving the panel, so games opt in via 'nvidia-offload %command%'.
- Dual-disk disko uses persistent by-id paths: SK hynix SATA SSD for system + 1 TB Seagate HDD as the btrfs Steam library at /mnt/steam. Persistent (no impermanence) — eisen-style.
