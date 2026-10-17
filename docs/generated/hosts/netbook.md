# netbook

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Alice's Travel Netbook (Pinned NixOS 25.11) |
| status | active — In active production as Alice's lightweight travel netbook on pinned NixOS 25.11. |
| kind / arch | nixos / x86_64-linux |
| flake output | false |
| managed | false |
| in CI | true |
| hardware | Intel Celeron Netbook |
| cpu | Intel Celeron N3060 (Braswell, 2c/2t, 1.60 GHz) |
| gpu | Intel HD Graphics 400 |
| ram | 2 to 4 GB RAM |
| storage | f2fs root, vfat /boot, systemd-boot |
| persona | Alice's Travel Companion (tier: strictly-constrained-cpu) |
| persona hint | You assist Alice on her ultra-lightweight travel netbook. The Celeron CPU is extremely weak; keep everything lightweight, smooth, and friendly. |

## Module chain

`Independent NixOS 25.11 (No Flake)`

## Traits

- traits:
  - alice-user
  - celeron-n3060
  - pinned-25.11
  - f2fs
  - ultra-low-spec

## Key services

- services:
  - Niri Compositor
  - greetd
  - Pipewire
  - NFS client automount

## Allowed tasks

- tasks:
  - Simple note taking
  - Document viewing
  - Alice user assistance

## Constraints

- constraint:
  - NEVER run local Nix builds or heavy evals; offload all packages to frieren.
  - Host is pinned to NixOS 25.11 channel due to upstream kernel initrd bug.

## Notes

- Independent NixOS 25.11 host: pinned to the 25.11 channel because of an upstream initrd bug on newer kernels, so it is deliberately NOT a flake output (flake = false).
- Managed by remote fleet ops (task infra:apply:host:netbook), not flake closure projection.
