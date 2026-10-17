# frieren-canary

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Frieren Canary MicroVM (closure smoke test) |
| status | preserved — Ephemeral canary microVM used to smoke-test a built system closure (scripts/task/run-canary.sh). |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | microVM guest on frieren (shared host CPU/RAM) |
| cpu | host-provided vCPU |
| ram | host-provided |

## Module chain

`microvm`

## Traits

- traits:
  - microvm
  - canary
  - ephemeral

## Key services

- services:
  - nixos-rebuild switch smoke test (run-canary.sh)
