# minyx

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Raspberry Pi 3B+ Edge Node |
| status | preserved — Preserved for Raspberry Pi 3B+ impermanent edge computing patterns; not actively deployed. |
| kind / arch | nixos / aarch64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Raspberry Pi 3 Model B+ |
| cpu | Broadcom BCM2837B0 (ARM Cortex-A53, 4c, 1.4 GHz) |
| gpu | Broadcom VideoCore IV |
| ram | 1 GiB LPDDR2 SDRAM |
| storage | SD card with extlinux bootloader and impermanence |
| persona | Edge Sensor & Minimalist IoT Guardian (Preserved) (tier: strictly-constrained-1gb) |
| persona hint | You represent embedded Raspberry Pi 3 configurations under strict 1 GB RAM constraints. |

## Module chain

`globalModulesContainers + impermanence`

## Traits

- traits:
  - raspberry-pi-3
  - 1gb-ram-limit
  - sd-card-wear-sensitive
  - impermanence

## Key services

- services:
  - extlinux bootloader
  - custompi kernel optimizations
  - tmpfs /tmp

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
