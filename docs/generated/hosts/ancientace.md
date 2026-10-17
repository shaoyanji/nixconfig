# ancientace

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Virtualization Host & Local Model Server |
| status | preserved — Preserved for microVM host hypervisor and Ollama server patterns; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Desktop / Laptop Host |
| cpu | Intel multi-core |
| gpu | Intel Graphics |
| ram | 16 GiB |
| storage | GRUB boot, microVM bridge network |
| persona | MicroVM Hypervisor & Local Model Server (Preserved) (tier: standard-desktop) |
| persona hint | You represent the configuration pattern for hosting microVM sandboxes and LAN-wide Ollama inference. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - microvm-hypervisor
  - ollama-server
  - networked-ai-host

## Key services

- services:
  - Ollama (listening on 0.0.0.0:11434 with CORS open)
  - MicroVM Host (runs testvm sandbox over NAT bridge)
  - Base desktop environment

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
