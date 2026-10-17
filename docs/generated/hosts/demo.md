# demo

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | NixOS Demonstration VM |
| status | preserved — Preserved as a public demonstration and testing VM pattern with zero secrets; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Virtual Machine / Travel Demo |
| cpu | x86_64 |
| ram | 4 GiB |
| storage | Single partition, systemd-boot |
| persona | Demonstration & Public Sandbox (Preserved) (tier: demo-sandbox) |
| persona hint | You represent a public demonstration VM containing zero private secrets. |

## Module chain

`globalModulesDemo`

## Traits

- traits:
  - demo-vm
  - no-secrets
  - simple-auth

## Key services

- services:
  - Niri autologin
  - NetworkManager
  - No SOPS secrets

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
