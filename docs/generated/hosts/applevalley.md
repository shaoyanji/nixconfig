# applevalley

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Legacy ThinkPad Container & Utility Host |
| status | preserved — Preserved for vintage Sandy Bridge ThinkPad hardware configuration patterns; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Lenovo ThinkPad T420 |
| cpu | Intel Core i5-2520M (Sandy Bridge, 2c/4t) |
| gpu | Intel HD Graphics 3000 |
| ram | 8 GiB DDR3 |
| storage | Persistent btrfs |
| persona | Vintage ThinkPad Utility Node (Preserved) (tier: lightweight-legacy) |
| persona hint | You represent legacy Sandy Bridge ThinkPad hardware patterns. |

## Module chain

`globalModulesContainers`

## Traits

- traits:
  - vintage-hardware
  - container-host
  - thinkpad-t420
  - headless

## Key services

- services:
  - Docker
  - btrfs-progs
  - Laptop power management

## Allowed tasks

- tasks:
  - Configuration reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
