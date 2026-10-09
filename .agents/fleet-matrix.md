# Fleet LLM Context Matrix

> Dense machine context matrix optimized for LLM token budgets and prompt injection.
> Source of truth: [`inventory.toml`](file:///home/devji/Documents/nixconfig/inventory.toml).

## Fleet Status Breakdown

- **Active Production Nix Hosts (11)**: `frieren`, `poseidon`, `eisen`, `stark`, `fern`, `scratch`, `netbook`, `guckloch`, `kellerbench`, `kali`, `moto`
- **Active External Non-Nix Hosts (3)**: `serv00`, `dragoncourt`, `envs`
- **Work-in-Progress Hosts (1)**: `delphi` (OCI A1 bastion - NOT yet live)
- **Preserved Architecture Patterns (16)**: `aceofspades`, `alarm`, `ancientace`, `applevalley`, `ares`, `aristotle`, `cassini`, `deckstation`, `demo`, `garnixMachine`, `minyx`, `mtfuji`, `penguin`, `schneeeule`, `sledgehammer`, `testvm`

---

## LLM Operational Constraints by Host Category

### 1. Mainframe & Core Server (`frieren`)
- **Sensitive Window**: 03:00-05:30 CET nightly backup and handoff window. Never schedule rebuilds here.
- **Rebuild Rule**: At most ONE rebuild at a time; always commit and push to origin/main or autoUpgrade will revert next morning at 04:00.
- **Declarative Services**: Kiwix (/var/lib/kiwix) is strictly declarative; never hand-edit.

### 2. Workstations & Kiosks (`poseidon`, `eisen`, `stark`, `kellerbench`)
- **GPU Drivers**: NVIDIA hosts (`poseidon`: RTX 3050 Ti Laptop open; `stark`: MX110 legacy_580 offload; `kellerbench`: GTX 750 Ti legacy_580). AMD hosts (`eisen`: RX 5700 Navi 10 Mesa).
- **UI Priority**: Keep interactive desktop smooth on `poseidon` during heavy inference.

### 3. Lightweight Terminals (`fern`, `scratch`, `netbook`)
- **Thermal & CPU Caps**: Low-power dual-core CPUs. Offload compilation to `frieren` or remote builders.
- **Scratch Disk Diet**: Shaky f2fs SSD; tmpfs logs and zram RAM-only swap.

### 4. Non-Nix Shared Hosting (`serv00`, `dragoncourt`, `envs`)
- **Strict Warning**: NON-NIX. NEVER run `nixos-rebuild`, `nix`, or NixOS commands.
- **Serv00 Quota**: Strict 512 MB RAM limit. Violators killed by FreeBSD kernel. Manage via Devil CLI.

### 5. Work in Progress (`delphi`)
- **Status**: WIP / Not Live. Do not assume active production services until deployed.

---

## Quick Host Spec Reference

| Host | Status | Nix? | Arch | Compute Tier | CPU / RAM / GPU | Primary Role |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| ⚪ **`aceofspades`** | `preserved` | Yes | `x86_64-linux` | `standard-desktop` | Intel Core, 16 GiB, AMD Radeon GPU | AMD Graphics Workstation |
| ⚪ **`alarm`** | `preserved` | Yes | `aarch64-linux` | `strictly-constrained` | ARM64, 1 to 2 GB | Arch Linux ARM Standalone Home Manager |
| ⚪ **`ancientace`** | `preserved` | Yes | `x86_64-linux` | `standard-desktop` | Intel multi-core, 16 GiB, Intel Graphics | Virtualization Host & Local Model Server |
| ⚪ **`applevalley`** | `preserved` | Yes | `x86_64-linux` | `lightweight-legacy` | Intel Core i5-2520M, 8 GiB DDR3, Intel HD Graphics 3000 | Legacy ThinkPad Container & Utility Host |
| ⚪ **`ares`** | `preserved` | Yes | `x86_64-linux` | `kiosk-gaming` | Intel Core i5-6500, 8 GiB DDR4, NVIDIA GeForce GTX 750 Ti | Steam Big Picture Kiosk with Impermanence |
| ⚪ **`aristotle`** | `preserved` | Yes | `x86_64-linux` | `standard-desktop` | Intel 64-bit multi-core, 16 GiB DDR4, Intel / Integrated | Standard Desktop Workstation |
| ⚪ **`cassini`** | `preserved` | Yes | `aarch64-darwin` | `apple-silicon-workstation` | Apple Silicon, Unified Memory (16, Apple Integrated Metal GPU | Apple Silicon macOS Workstation |
| ⚪ **`deckstation`** | `preserved` | Yes | `x86_64-linux` | `heavy-gaming` | Intel 64-bit multi-core, 16 GiB, AMD Radeon RX 5700 XT | High-End Steam Kiosk & Sunshine Host |
| 🟡 **`delphi`** | `wip` | Yes | `aarch64-linux` | `cloud-high-ram` | Ampere Altra Neoverse N1, 24 GiB RAM | Cloud Bastion, Tailscale Exit Node & ARM64 Build Offloader |
| ⚪ **`demo`** | `preserved` | Yes | `x86_64-linux` | `demo-sandbox` | x86_64, 4 GiB | NixOS Demonstration VM |
| 🟢 **`dragoncourt`** | `active` | No (Ext) | `x86_64-linux` | `shared-web-hosting` | Intel x86_64, Shared Hosting Quota | Alwaysdata PHP/Wasm Web Hosting |
| 🟢 **`eisen`** | `active` | Yes | `x86_64-linux` | `heavy-compute-64gb` | Intel Xeon E5-2673 v3, 64 GiB DDR4, AMD Radeon RX 5700 | High-Core Gaming Desktop, Sunshine Stream Server & Offline LLM + Decision-Model Node |
| 🟢 **`envs`** | `active` | No (Ext) | `x86_64-linux` | `shared-pubnix` | Intel Xeon, Shared Pubnix Quota | Envs.net Multi-Protocol Pubnix Node |
| 🟢 **`fern`** | `active` | Yes | `x86_64-linux` | `lightweight-laptop` | AMD Ryzen 3 3250U, 8 GB DDR4, AMD Radeon Vega 3 iGPU | Lightweight Daily-Driver Laptop |
| 🟢 **`frieren`** | `active` | Yes | `x86_64-linux` | `server-heavy-io-sensitive` | Intel Core i5-8250U, 11.47 GiB DDR4 (4GB soldered, Intel UHD Graphics 620 @ 1.10 GHz | Central NAS Mainframe, 4K Media Center & Application Server |
| ⚪ **`garnixMachine`** | `preserved` | Yes | `x86_64-linux` | `ci-cloud` | x86_64 Cloud vCPU, Cloud Allocated | Garnix CI Runner & Bountystash Host |
| 🟢 **`guckloch`** | `active` | Yes | `x86_64-linux` | `wsl2-container` | Host CPU, WSL2 Dynamic Allocation | Windows Subsystem for Linux (WSL2) Container |
| 🟢 **`kali`** | `active` | Yes | `aarch64-linux` | `specialized-cli` | ARM64, 2 to 4 GB, Adreno / VideoCore | Mobile Offensive Security Starter Pack |
| 🟢 **`kellerbench`** | `active` | Yes | `x86_64-linux` | `kiosk-gaming` | Intel 64-bit multi-core, 8 GiB, NVIDIA GeForce GTX 750 Ti | Headless GameStream & Benchmark Rig |
| ⚪ **`minyx`** | `preserved` | Yes | `aarch64-linux` | `strictly-constrained-1gb` | Broadcom BCM2837B0, 1 GiB LPDDR2 SDRAM, Broadcom VideoCore IV | Raspberry Pi 3B+ Edge Node |
| 🟢 **`moto`** | `active` | No (Ext) | `aarch64-linux` | `mobile-termux` | Unisoc T760 / Snapdragon, 4 to 8 GB RAM, Mali-G57 | Primary Mobile Smartphone (Android/Termux) |
| ⚪ **`mtfuji`** | `preserved` | Yes | `x86_64-linux` | `container-compute` | AMD Ryzen 64-bit, 16 GiB DDR4 | Headless Container & AI Inference Host |
| 🟢 **`netbook`** | `active` | Yes | `x86_64-linux` | `strictly-constrained-cpu` | Intel Celeron N3060, 2 to 4 GB RAM, Intel HD Graphics 400 | Alice's Travel Netbook (Pinned NixOS 25.11) |
| ⚪ **`penguin`** | `preserved` | Yes | `x86_64-linux` | `container-client` | Intel x86_64, Shared with ChromeOS, VirtIO GPU with nixGL wrapper | Chromebook Linux Container (Crostini) |
| 🟢 **`poseidon`** | `active` | Yes | `x86_64-linux` | `flagship-compute` | AMD Ryzen 7 Mobile, 16 GiB DDR4, NVIDIA GeForce RTX 3050 Ti Laptop GPU | Primary High-Performance Laptop Workstation |
| ⚪ **`schneeeule`** | `preserved` | Yes | `x86_64-linux` | `standard-laptop` | Intel 64-bit multi-core, 16 GiB, Intel iGPU + NVIDIA GeForce | Impermanent Desktop Laptop |
| 🟢 **`scratch`** | `active` | Yes | `x86_64-linux` | `lightweight-io-diet` | Intel Core i5-6500, 8 GB DDR4, Intel HD Graphics 530 | I/O Diet Lightweight Workstation |
| 🟢 **`serv00`** | `active` | No (Ext) | `x86_64-freebsd` | `shared-freebsd-quota` | Intel Xeon, 512 MB Process Memory Limit (devil info limits) | FreeBSD Web Hosting & Daemon Node |
| ⚪ **`sledgehammer`** | `preserved` | Yes | `x86_64-linux` | `live-installer` | Any x86_64 host, Host RAM | Fleet Provisioning & Disaster Recovery USB |
| 🟢 **`stark`** | `active` | Yes | `x86_64-linux` | `low-power-gaming` | Intel Core i5-7200U, 16 GiB DDR4, Intel HD 620 | Living Room All-in-One Gaming Terminal |
| ⚪ **`testvm`** | `preserved` | Yes | `x86_64-linux` | `microvm-sandbox` | 1-2 vCPU, 1 GiB | MicroVM Sandbox |
