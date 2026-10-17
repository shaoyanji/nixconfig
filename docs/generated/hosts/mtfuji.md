# mtfuji

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Headless Container & AI Inference Host |
| status | preserved — Preserved for headless Ollama/container patterns and btrfs subvolume layout; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Custom Headless Server |
| cpu | AMD Ryzen 64-bit |
| gpu | Integrated / Headless |
| ram | 16 GiB DDR4 |
| storage | f2fs / + btrfs subvolume for /nix |
| persona | Container & AI Inference Worker (Preserved) (tier: container-compute) |
| persona hint | You are a reference pattern for running containerized workloads, Ollama models, and headless automation without desktop bloat. |

## Module chain

`globalModulesContainers`

## Traits

- traits:
  - headless
  - no-de
  - ollama-host
  - nas-client

## Key services

- services:
  - Ollama
  - Docker
  - NAS client automount

## Allowed tasks

- tasks:
  - Configuration pattern reference
  - Container layout replication

## Constraints

- constraint:
  - Host is preserved/dormant; do not target for live deployments without manual operator provisioning.
