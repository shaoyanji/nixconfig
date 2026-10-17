# ares

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Steam Big Picture Kiosk with Impermanence |
| status | preserved — Preserved for impermanent Steam Big Picture kiosk patterns with Kepler GPU; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Custom Kiosk Tower |
| cpu | Intel Core i5-6500 (Skylake, 4c/4t) |
| gpu | NVIDIA GeForce GTX 750 Ti (Kepler sm_30, legacy_580) |
| ram | 8 GiB DDR4 |
| storage | /dev/sda (root ephemeral on boot, devji home + /etc persisted to /persist) |
| persona | Impermanent Arcade & Steam Kiosk (Preserved) (tier: kiosk-gaming) |
| persona hint | You represent the configuration pattern for an impermanent, arcade-style Steam Big Picture kiosk. |

## Module chain

`containers + impermanence`

## Traits

- traits:
  - kiosk-only
  - no-de
  - impermanence
  - ephemeral-root
  - kepler-gpu

## Key services

- services:
  - greetd autologin to gamescope-session (steam -gamepadui)
  - Impermanence (/persist subvolume)
  - NVIDIA legacy_580 driver with DRM KMS

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.

## Notes

- The T440p SSD moved into a desktop case (i5-6500 + GTX 750 Ti) and became a Steam Big Picture kiosk (steamos.nix), mirroring eisen/kellerbench.
- Uses the noDE containers chain plus impermanence: root is wiped each boot, devji's home and /etc persist to /persist.
- The T440p-specific nixos-hardware module is dropped — Lenovo fan curves and power management do not apply to desktop boards. The btrfs /persist layout on /dev/sda is unchanged (disko).
