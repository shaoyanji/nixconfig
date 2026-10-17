# Fleet Device & Host Inventory

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.

Canonical hardware, operational status, network, and agent persona registry for all fleet devices.

Source of truth: `inventory.toml`, compiled once by `lib/inventory.nix`.

## Fleet overview

| metric | count |
| --- | --- |
| total devices | 34 |
| nix hosts | 28 |
| external devices | 6 |
| active | 17 |
| active (nix / external) | 11 / 6 |
| wip | 1 |
| preserved | 16 |

## Active Nix fleet

| host | role | arch | kind | lan | tailnet |
| --- | --- | --- | --- | --- | --- |
| aristotle | ThinkPad T440 Mobile Laptop Workstation | x86_64-linux | nixos | 192.168.3.32 | 100.110.54.71 |
| eisen | High-Core Gaming Desktop, Sunshine Stream Server & Offline LLM + Decision-Model Node | x86_64-linux | nixos | — | — |
| fern | Lightweight Daily-Driver Laptop | x86_64-linux | nixos | — | — |
| frieren | Central NAS Mainframe, 4K Media Center & Application Server | x86_64-linux | nixos | 192.168.3.25 | — |
| guckloch | Windows Subsystem for Linux (WSL2) Container | x86_64-linux | nixos | — | — |
| kali | Mobile Offensive Security Starter Pack | aarch64-linux | home | — | — |
| kellerbench | Headless GameStream & Benchmark Rig | x86_64-linux | nixos | — | — |
| netbook | Alice's Travel Netbook (Pinned NixOS 25.11) | x86_64-linux | nixos | — | — |
| poseidon | Primary High-Performance Laptop Workstation | x86_64-linux | nixos | — | — |
| scratch | I/O Diet Lightweight Workstation | x86_64-linux | nixos | — | — |
| stark | Living Room All-in-One Gaming Terminal | x86_64-linux | nixos | — | — |

## Work in progress

| host | role | arch | kind | lan | tailnet |
| --- | --- | --- | --- | --- | --- |
| delphi | Cloud Bastion, Tailscale Exit Node & ARM64 Build Offloader | aarch64-linux | nixos | — | — |

## Preserved archetypes

| host | role | arch | kind | lan | tailnet |
| --- | --- | --- | --- | --- | --- |
| aceofspades | AMD Graphics Workstation | x86_64-linux | nixos | — | — |
| alarm | Arch Linux ARM Standalone Home Manager | aarch64-linux | home | — | — |
| ancientace | Virtualization Host & Local Model Server | x86_64-linux | nixos | — | — |
| applevalley | Legacy ThinkPad Container & Utility Host | x86_64-linux | nixos | — | — |
| ares | Steam Big Picture Kiosk with Impermanence | x86_64-linux | nixos | — | — |
| cassini | Apple Silicon macOS Workstation | aarch64-darwin | darwin | — | — |
| deckstation | High-End Steam Kiosk & Sunshine Host | x86_64-linux | nixos | — | — |
| demo | NixOS Demonstration VM | x86_64-linux | nixos | — | — |
| frieren-canary | Frieren Canary MicroVM (closure smoke test) | x86_64-linux | nixos | — | — |
| garnixMachine | Garnix CI Runner & Bountystash Host | x86_64-linux | nixos | — | — |
| minyx | Raspberry Pi 3B+ Edge Node | aarch64-linux | nixos | — | — |
| mtfuji | Headless Container & AI Inference Host | x86_64-linux | nixos | — | — |
| penguin | Chromebook Linux Container (Crostini) | x86_64-linux | home | — | — |
| schneeeule | Impermanent Desktop Laptop | x86_64-linux | nixos | — | — |
| sledgehammer | Fleet Provisioning & Disaster Recovery USB | x86_64-linux | nixos | — | — |
| testvm | MicroVM Sandbox | x86_64-linux | nixos | — | — |

## External (non-Nix) devices

| host | role | kind | status |
| --- | --- | --- | --- |
| bitlockerpremium | Windows 11 Pro Workstation & Tailnet OpenSSH Endpoint | external | active |
| burgernas | Cold Vault Storage Extension & Secondary Backup Target | external | active |
| dragoncourt | Alwaysdata PHP/Wasm Web Hosting | external | active |
| envs | Envs.net Multi-Protocol Pubnix Node | external | active |
| moto | Primary Mobile Smartphone (Android/Termux) | external | active |
| serv00 | FreeBSD Web Hosting & Daemon Node | external | active |

## Agent personas

| host | persona | compute tier | allowed tasks |
| --- | --- | --- | --- |
| aceofspades | AMD OpenCL Compute Station (Preserved) | standard-desktop | Configuration pattern reference |
| alarm | Arch Linux ARM Embedded Agent (Preserved) | strictly-constrained | Configuration pattern reference |
| ancientace | MicroVM Hypervisor & Local Model Server (Preserved) | standard-desktop | Configuration pattern reference |
| applevalley | Vintage ThinkPad Utility Node (Preserved) | lightweight-legacy | Configuration reference |
| ares | Impermanent Arcade & Steam Kiosk (Preserved) | kiosk-gaming | Configuration pattern reference |
| aristotle | Philosophical ThinkPad T440 Mobile Workstation | lightweight-laptop | Everyday coding and markdown notes, NFS synchronization with NAS, Lightweight desktop productivity, Battery lifecycle management |
| cassini | macOS Executive & Creative Operator (Preserved) | apple-silicon-workstation | macOS configuration pattern reference, Darwin flake maintenance |
| deckstation | High-Performance Stream & Kiosk Station (Preserved) | heavy-gaming | Configuration pattern reference |
| delphi | Cloud Bastion & ARM64 Build Offloader | cloud-high-ram | ARM64 compilation and package builds, Offload task delegation from low-power nodes, Tailscale exit node and network proxying, Remote health monitoring |
| demo | Demonstration & Public Sandbox (Preserved) | demo-sandbox | Configuration pattern reference |
| eisen | High-Core Gaming, Streaming, LLM & Decision-Model Host | heavy-compute-64gb | Heavy parallel multi-threaded builds, GameStream / Sunshine streaming management, Steam game library management on /mnt/steam, FFmpeg hardware-accelerated transcoding, Local MoE LLM inference (llama.cpp) serving the fleet OpenAI-compatible API, Typed decision queries via the CPU-only Laya model (Jev-compatible POST /v1/systemone) |
| fern | Portable Field Operative | lightweight-laptop | Everyday coding and markdown notes, NAS client synchronization and recovery, Lightweight local builds and documentation, Battery lifecycle management |
| frieren | Fleet Mainframe & Storage Steward | server-heavy-io-sensitive | Service maintenance & health auditing, SOPS secrets management and rekeying, Storage hygiene and permission audits, Backup verification and snapshot tracking, Fleet binary cache warming and closure pushing |
| garnixMachine | Continuous Integration & Deployment Runner (Preserved) | ci-cloud | Configuration pattern reference |
| guckloch | Cross-Platform Windows/Linux Bridge | wsl2-container | WSL2 development, Windows binary interoperability via nix-ld, Docker Desktop builds |
| kali | Offensive Security & Pen-Testing Operative | specialized-cli | Network port scanning & enumeration (nmap, rustscan), Web application fuzzing & testing (gobuster, ffuf, sqlmap), Wireless security auditing (aircrack-ng, bettercap), Security telemetry logging |
| kellerbench | Remote GameStream & Benchmark Rig | kiosk-gaming | Sunshine streaming configuration, Gaming benchmark automation, Remote display hosting |
| minyx | Edge Sensor & Minimalist IoT Guardian (Preserved) | strictly-constrained-1gb | Configuration pattern reference |
| mtfuji | Container & AI Inference Worker (Preserved) | container-compute | Configuration pattern reference, Container layout replication |
| netbook | Alice's Travel Companion | strictly-constrained-cpu | Simple note taking, Document viewing, Alice user assistance |
| penguin | Chromebook Companion (Preserved) | container-client | Configuration pattern reference |
| poseidon | Flagship Laptop Workstation Architect | flagship-compute | Full fleet flake builds and closures, Heavy CUDA LLM inference and model training, Graphical software development and testing, High-resolution media editing |
| schneeeule | Impermanent Laptop Sentinel (Preserved) | standard-laptop | Configuration pattern reference |
| scratch | I/O Diet Minimalist & RAM-First Steward | lightweight-io-diet | RAM-resident development tasks, Lightweight text editing and browsing, Clean memory management |
| sledgehammer | Bare-Metal Fleet Provisioner & Recovery Sledge (Preserved) | live-installer | Live USB creation via Taskfile, Disko provisioning reference |
| stark | Living Room Gaming & Media Controller | low-power-gaming | Steam Big Picture session management, PRIME offload optimization (nvidia-offload %command%), Living-room media playback, HDD Steam library management |
| testvm | MicroVM Sandbox Testbed (Preserved) | microvm-sandbox | Configuration pattern reference |
