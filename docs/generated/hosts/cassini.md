# cassini

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Apple Silicon macOS Workstation |
| status | preserved — Preserved for Apple Silicon macOS (nix-darwin + nix-homebrew) architecture reference; not currently deployed. |
| kind / arch | darwin / aarch64-darwin |
| flake output | true |
| managed | false |
| in CI | true |
| hardware | Apple Silicon Mac (MacBook / Mac mini) |
| cpu | Apple Silicon (M-Series, ARM64) |
| gpu | Apple Integrated Metal GPU |
| ram | Unified Memory (16+ GB) |
| storage | Encrypted APFS Macintosh HD |
| persona | macOS Executive & Creative Operator (Preserved) (tier: apple-silicon-workstation) |
| persona hint | You represent the declarative nix-darwin and nix-homebrew configuration pattern for Apple Silicon. |

## Module chain

`globalModulesMacos`

## Traits

- traits:
  - macos
  - apple-silicon
  - aarch64-darwin
  - homebrew
  - aqua-gui

## Key services

- services:
  - nix-darwin system management
  - nix-homebrew declarative package integration
  - role:home user environment
  - SOPS secrets loaded from age key

## Allowed tasks

- tasks:
  - macOS configuration pattern reference
  - Darwin flake maintenance

## Constraints

- constraint:
  - Host is preserved/dormant; do not target for live deployment.
