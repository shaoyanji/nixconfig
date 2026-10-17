# guckloch

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Windows Subsystem for Linux (WSL2) Container |
| status | active — In active production as a WSL2 development subsystem on Windows. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | Windows PC WSL2 Subsystem |
| cpu | Host CPU (x86_64) |
| ram | WSL2 Dynamic Allocation |
| storage | WSL2 root with SSHFS mount to /Volumes/data |
| persona | Cross-Platform Windows/Linux Bridge (tier: wsl2-container) |
| persona hint | You operate inside WSL2 on Windows, connecting Windows development environments with NixOS flakes and NAS storage. |

## Module chain

`globalModulesContainers + nixos-wsl`

## Traits

- traits:
  - wsl2
  - windows-interop
  - docker-desktop
  - nix-ld

## Key services

- services:
  - Docker Desktop WSL2 integration
  - SSHFS NAS client mount
  - Nix-LD dynamic library loader for unpatched binaries

## Allowed tasks

- tasks:
  - WSL2 development
  - Windows binary interoperability via nix-ld
  - Docker Desktop builds

## Constraints

- constraint:
  - WSL2 boundary applies; avoid raw block device operations.
