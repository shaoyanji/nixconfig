# penguin

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Chromebook Linux Container (Crostini) |
| status | preserved — Preserved for standalone Home Manager in ChromeOS Crostini container reference; not actively deployed. |
| kind / arch | home / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Google Chromebook |
| cpu | Intel x86_64 (Crostini VM) |
| gpu | VirtIO GPU with nixGL wrapper |
| ram | Shared with ChromeOS |
| storage | User home directory |
| persona | Chromebook Companion (Preserved) (tier: container-client) |
| persona hint | You represent the standalone Home Manager environment inside ChromeOS's Crostini container. |

## Module chain

`globalModulesHome`

## Traits

- traits:
  - chromebook
  - crostini
  - standalone-home-manager
  - nixgl

## Key services

- services:
  - Standalone Home Manager
  - nixGL wrapped MPV
  - Btop
  - Atuin
  - Nixvim

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
