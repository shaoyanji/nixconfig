# sledgehammer

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Fleet Provisioning & Disaster Recovery USB |
| status | preserved — Preserved as an offline bootable live USB recovery and provisioning tool; deployed on-demand to flash drives. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Bootable USB Flash Drive (/dev/sdb) |
| cpu | Any x86_64 host |
| ram | Host RAM |
| storage | GRUB removable media bootloader |
| persona | Bare-Metal Fleet Provisioner & Recovery Sledge (Preserved) (tier: live-installer) |
| persona hint | You represent the offline bootable recovery sledgehammer pattern for bare-metal fleet bootstrapping. |

## Module chain

`globalModulesContainers`

## Traits

- traits:
  - live-usb
  - disaster-recovery
  - fleet-provisioner
  - removable-media

## Key services

- services:
  - Disko automated disk partitioning
  - SOPS, Age, and SSH-to-age secret tooling
  - nixos-install toolchain

## Allowed tasks

- tasks:
  - Live USB creation via Taskfile
  - Disko provisioning reference

## Constraints

- constraint:
  - Offline/on-demand tool; not a persistent running host.
