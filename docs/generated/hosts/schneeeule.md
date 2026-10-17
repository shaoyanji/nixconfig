# schneeeule

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Impermanent Desktop Laptop |
| status | preserved — Preserved for impermanent laptop and dual-GPU legacy driver reference; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Intel/NVIDIA Laptop |
| cpu | Intel 64-bit multi-core |
| gpu | Intel iGPU + NVIDIA GeForce (legacy_470 driver, Optimus prime) |
| ram | 16 GiB |
| storage | /dev/sda (root erased on boot, persistent /persist, /persist/data ext4) |
| persona | Impermanent Laptop Sentinel (Preserved) (tier: standard-laptop) |
| persona hint | You represent the configuration pattern for an impermanent laptop system where root is vaporized upon reboot. |

## Module chain

`globalModulesImpermanence`

## Traits

- traits:
  - impermanence
  - ephemeral-root
  - nvidia-legacy-470
  - laptop-profile

## Key services

- services:
  - Impermanence (root wiped each boot)
  - Niri + DMS greeter
  - Steam gaming
  - thermald laptop power/thermal daemon

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
