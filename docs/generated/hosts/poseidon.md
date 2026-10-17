# poseidon

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Primary High-Performance Laptop Workstation |
| status | active — In active production as the primary high-performance laptop workstation. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | AMD Ryzen Gaming Laptop |
| cpu | AMD Ryzen 7 Mobile (8c/16t) |
| gpu | NVIDIA GeForce RTX 3050 Ti Laptop GPU (4 GB VRAM, Ampere) + AMD Radeon iGPU |
| ram | 16 GiB DDR4 |
| storage | High-speed persistent NVMe partitions |
| persona | Flagship Laptop Workstation Architect (tier: flagship-compute) |
| persona hint | You are the primary portable development powerhouse. You have full access to high-end multi-core CPU and RTX CUDA hardware for rapid compilation, heavy AI model inference, and graphical development. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - flagship-workstation
  - cuda-compute
  - laptop-profile
  - optimus-prime
  - dual-gpu
  - niri-desktop
  - steam-gaming

## Key services

- services:
  - Niri Wayland Compositor
  - DankMaterialShell Greeter
  - Steam (full gaming suite)
  - Ollama (CUDA acceleration with lfm2.5)
  - NVIDIA proprietary drivers (open kernel module)
  - NAS client automount

## Allowed tasks

- tasks:
  - Full fleet flake builds and closures
  - Heavy CUDA LLM inference and model training
  - Graphical software development and testing
  - High-resolution media editing

## Constraints

- constraint:
  - Primary interactive workstation; keep interactive desktop UI smooth and responsive.
