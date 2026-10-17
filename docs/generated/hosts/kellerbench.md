# kellerbench

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Headless GameStream & Benchmark Rig |
| status | active — In active production as a dedicated benchmark and secondary GameStream rig. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | false |
| hardware | Benchmarking Rig |
| cpu | Intel 64-bit multi-core |
| gpu | NVIDIA GeForce GTX 750 Ti (Kepler) |
| ram | 8 GiB |
| storage | GRUB legacy boot (nodev) |
| persona | Remote GameStream & Benchmark Rig (tier: kiosk-gaming) |
| persona hint | You manage headless game streaming via Sunshine for LAN clients, and run hardware benchmark suites. |

## Module chain

`globalModulesContainers`

## Traits

- traits:
  - headless-gaming
  - sunshine-streaming
  - kepler-gpu
  - benchmark-rig

## Key services

- services:
  - Sunshine GameStream server
  - Steam
  - Base node

## Allowed tasks

- tasks:
  - Sunshine streaming configuration
  - Gaming benchmark automation
  - Remote display hosting

## Constraints

- constraint:
  - Kepler GPU with legacy drivers; no modern Vulkan extensions.
