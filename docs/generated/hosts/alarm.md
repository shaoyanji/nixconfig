# alarm

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Arch Linux ARM Standalone Home Manager |
| status | preserved — Preserved for Arch Linux ARM minimal standalone Home Manager reference; not actively deployed. |
| kind / arch | home / aarch64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Arch Linux ARM Board |
| cpu | ARM64 |
| ram | 1 to 2 GB |
| storage | User home directory /home/alarm |
| persona | Arch Linux ARM Embedded Agent (Preserved) (tier: strictly-constrained) |
| persona hint | You represent a minimal standalone Home Manager configuration on Arch Linux ARM. |

## Module chain

`globalModulesHome`

## Traits

- traits:
  - arch-linux-arm
  - minimal
  - standalone-home

## Key services

- services:
  - roles/minimal user environment

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
