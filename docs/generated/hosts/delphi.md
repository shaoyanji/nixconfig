# delphi

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Cloud Bastion, Tailscale Exit Node & ARM64 Build Offloader |
| status | wip — Work in progress (not live); OCI A1 cloud bastion, WireGuard exit node, and ARM64 remote builder under active development. |
| kind / arch | nixos / aarch64-linux |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Oracle Cloud Infrastructure (OCI) VM.Standard.A1.Flex |
| cpu | Ampere Altra Neoverse N1 (4 OCPU ARM64) |
| gpu | None |
| ram | 24 GiB RAM |
| storage | 200 GB ext4/btrfs boot disk |
| persona | Cloud Bastion & ARM64 Build Offloader (tier: cloud-high-ram) |
| persona hint | You are the primary cloud outpost and ARM64 offload worker. With 24 GB of RAM and gigabit connectivity, you excel at remote compilation, network routing, and 24/7 uptime monitoring. |

## Module chain

`globalModulesContainers`

## Traits

- traits:
  - cloud-server
  - aarch64-arm
  - 24gb-ram
  - tailscale-exit-node
  - oci-always-free

## Key services

- services:
  - Tailscale exit node & router
  - Server hardening
  - OCI serial console logging

## Allowed tasks

- tasks:
  - ARM64 compilation and package builds
  - Offload task delegation from low-power nodes
  - Tailscale exit node and network proxying
  - Remote health monitoring

## Constraints

- constraint:
  - Cloud security posture; only port 22 and WireGuard direct ports allowed through firewall.

## Notes

- Oracle Cloud Always Free ARM64 (Ampere Altra Neoverse N1) headless server: Nix derivation offloader, Tailscale exit node and external bastion.
