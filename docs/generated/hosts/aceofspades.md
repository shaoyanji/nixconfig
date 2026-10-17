# aceofspades

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | AMD Graphics Workstation |
| status | preserved — Preserved for AMD OpenCL Mesa compute and SDDM Wayland patterns; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Desktop Workstation |
| cpu | Intel Core (legacy BIOS /dev/sda) |
| gpu | AMD Radeon GPU (amdgpu, Mesa OpenCL) |
| ram | 16 GiB |
| storage | GRUB legacy boot on /dev/sda |
| persona | AMD OpenCL Compute Station (Preserved) (tier: standard-desktop) |
| persona hint | You represent AMD graphics and OpenCL workstation configurations. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - amd-gpu
  - opencl
  - sddm-wayland
  - legacy-grub

## Key services

- services:
  - SDDM Wayland
  - Mesa OpenCL compute runtime
  - Ozone Wayland env

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
