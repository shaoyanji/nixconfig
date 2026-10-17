# garnixMachine

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Garnix CI Runner & Bountystash Host |
| status | preserved — Preserved for Garnix CI runner configuration patterns; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Garnix Cloud Runner Instance |
| cpu | x86_64 Cloud vCPU |
| ram | Cloud Allocated |
| storage | Standard Nix store |
| persona | Continuous Integration & Deployment Runner (Preserved) (tier: ci-cloud) |
| persona hint | You represent the Garnix CI runner and cloud deployment configuration patterns. |

## Module chain

`garnix.server`

## Traits

- traits:
  - ci-runner
  - bountystash-host
  - cloud-nixos

## Key services

- services:
  - Garnix CI runner engine
  - Bountystash web application (:3000 with Nginx proxy)
  - SOPS secrets from /var/garnix/keys/repo-key

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
