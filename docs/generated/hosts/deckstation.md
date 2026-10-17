# deckstation

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | High-End Steam Kiosk & Sunshine Host |
| status | preserved — Preserved for AMD RX 5700 XT gamescope kiosk and tuigreet configurations; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Custom Gaming Box |
| cpu | Intel 64-bit multi-core |
| gpu | AMD Radeon RX 5700 XT (Navi 10) |
| ram | 16 GiB |
| storage | Persistent storage |
| persona | High-Performance Stream & Kiosk Station (Preserved) (tier: heavy-gaming) |
| persona hint | You represent high-performance gamescope kiosk configurations. |

## Module chain

`globalModulesContainers`

## Traits

- traits:
  - amd-rx-5700xt
  - sunshine-host
  - gamescope-kiosk

## Key services

- services:
  - greetd + tuigreet + gamescope-session
  - Sunshine GameStream server
  - AMD RX 5700 XT driver stack

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
