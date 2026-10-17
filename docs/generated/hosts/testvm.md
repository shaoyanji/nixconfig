# testvm

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | MicroVM Sandbox |
| status | preserved — Preserved as a cloud-hypervisor microVM sandbox configuration pattern; not actively deployed. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Cloud-Hypervisor MicroVM |
| cpu | 1-2 vCPU |
| ram | 1 GiB |
| storage | MicroVM disk image |
| persona | MicroVM Sandbox Testbed (Preserved) (tier: microvm-sandbox) |
| persona hint | You represent an isolated microVM sandbox pattern used for untrusted execution. |

## Module chain

`microvm.nixosModules`

## Traits

- traits:
  - microvm
  - cloud-hypervisor
  - isolation-sandbox

## Key services

- services:
  - cloud-hypervisor
  - vsock communications

## Allowed tasks

- tasks:
  - Configuration pattern reference

## Constraints

- constraint:
  - Preserved host; do not target for live deployment.
