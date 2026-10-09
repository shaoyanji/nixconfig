# Fleet Device & Host Inventory

> Canonical device, hardware, operational status, and agent persona registry for `nixconfig`.
> Source of truth: [`inventory.toml`](file:///home/devji/Documents/nixconfig/inventory.toml).

## Fleet Overview Statistics

- **Total Registered Devices**: 31
- **Active Production Nix Devices**: 10
- **Active External Non-Nix Hosting**: 4 (`serv00`, `dragoncourt`, `envs`)
- **Work-in-Progress (Not Live)**: 1 (`delphi`)
- **Preserved Architecture Archetypes**: 16
- **Canonical Repository**: [https://github.com/shaoyanji/nixconfig](https://github.com/shaoyanji/nixconfig)

---

## 1. Active Production Nix Fleet (11 Devices)

| Host | Category | Role | Hardware Summary | Desktop / Environment | Storage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`eisen`** | `workstation` | High-Core Gaming Desktop, Sunshine Stream Server & Local MoE LLM Node | Intel Xeon E5-2673 v3, 64 GiB DDR4, AMD Radeon RX 5700 | Niri + DankMaterialShell greeter / Gamescope Session | NVMe SSD + SATA SSD + SATA HDD |
| **`fern`** | `laptop` | Lightweight Daily-Driver Laptop | AMD Ryzen 3 3250U, 8 GB DDR4, AMD Radeon Vega 3 iGPU | Niri + DankMaterialShell greeter | NVMe SSD |
| **`frieren`** | `server-and-media-center` | Central NAS Mainframe, 4K Media Center & Application Server | Intel Core i5-8250U, 11.47 GiB DDR4 (4GB soldered, Intel UHD Graphics 620 @ 1.10 GHz | niri (Wayland) via greetd/dms-greeter autologin (4K TV output) | Dual-disk btrfs (1TB SSD System + 2TB HDD Data Pool) |
| **`guckloch`** | `container-host` | Windows Subsystem for Linux (WSL2) Container | Host CPU, WSL2 Dynamic Allocation | WSL2 Windows Integration | Virtual Hard Disk (vhdx) |
| **`kali`** | `security` | Mobile Offensive Security Starter Pack | ARM64, 2 to 4 GB, Adreno / VideoCore | CLI / Terminal | Internal Flash / MicroSD |
| **`kellerbench`** | `gaming-kiosk` | Headless GameStream & Benchmark Rig | Intel 64-bit multi-core, 8 GiB, NVIDIA GeForce GTX 750 Ti | Gamescope Session / Headless | SATA SSD |
| **`netbook`** | `laptop` | Alice's Travel Netbook (Pinned NixOS 25.11) | Intel Celeron N3060, 2 to 4 GB RAM, Intel HD Graphics 400 | Niri + greetd | f2fs SSD |
| **`poseidon`** | `workstation` | Primary High-Performance Laptop Workstation | AMD Ryzen 7 Mobile, 16 GiB DDR4, NVIDIA GeForce RTX 3050 Ti Laptop GPU | Niri + DankMaterialShell greeter | NVMe SSD |
| **`scratch`** | `workstation` | I/O Diet Lightweight Workstation | Intel Core i5-6500, 8 GB DDR4, Intel HD Graphics 530 | Niri + DankMaterialShell greeter | 128 GB f2fs SSD (Shaky Disk - Strict I/O Diet) |
| **`stark`** | `gaming-kiosk` | Living Room All-in-One Gaming Terminal | Intel Core i5-7200U, 16 GiB DDR4, Intel HD 620 | Gamescope Session (Steam Big Picture) / Niri + DMS | Dual-disk (SSD + HDD) |

---

## 2. Active External Non-Nix Hosting (3 Devices)

These environments are not managed by Nix/NixOS. Operations are executed via dedicated taskfiles and SSH commands.

| Host | Environment / OS | Role | Management | Memory Limit / Quota | Primary Services |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`dragoncourt`** | `x86_64-linux` | Alwaysdata PHP/Wasm Web Hosting | `taskfiles/dragoncourt.yml` | Shared Hosting Quota | Apache + alproxy webserver, PHP / Wasm engine |
| **`envs`** | `x86_64-linux` | Envs.net Multi-Protocol Pubnix Node | `taskfiles/envs.yml` | Shared Pubnix Quota | Nginx Web Hosting (/home/jisifu/public_html), Gemini Capsule (/home/jisifu/public_gemini) |
| **`moto`** | `aarch64-linux` | Primary Mobile Smartphone (Android/Termux) | `taskfiles/moto.yml` | 4 to 8 GB RAM | OpenSSH daemon on port 8022, Obsidian mobile notes sync |
| **`serv00`** | `x86_64-freebsd` | FreeBSD Web Hosting & Daemon Node | `taskfiles/serv00.yml` | 512 MB Process Memory Limit (devil info limits) | Go 1.24 webserver on port 49613 (proxied to jisifu.serv00.net), Devil CLI resource and port management |

---

## 3. Work-in-Progress Outposts (1 Device)

| Host | Status | Role | Cloud Shape / Hardware | Target Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **`delphi`** | *WIP (Not Live)* | Cloud Bastion, Tailscale Exit Node & ARM64 Build Offloader | Ampere Altra Neoverse N1 (4 OCPU ARM64), 24 GiB RAM | ARM64 compilation and package builds, Offload task delegation from low-power nodes, Tailscale exit node and network proxying |

---

## 4. Preserved Archetypes & Configurations (16 Devices)

These hosts are not in active production but are preserved as architectural reference patterns and test configurations.

| Host | Category | Architectural Role | Pattern Preserved / Reference Value |
| :--- | :--- | :--- | :--- |
| **`aceofspades`** | `workstation` | AMD Graphics Workstation | Preserved for AMD OpenCL Mesa compute and SDDM Wayland patterns; not actively deployed. |
| **`alarm`** | `embedded` | Arch Linux ARM Standalone Home Manager | Preserved for Arch Linux ARM minimal standalone Home Manager reference; not actively deployed. |
| **`ancientace`** | `workstation` | Virtualization Host & Local Model Server | Preserved for microVM host hypervisor and Ollama server patterns; not actively deployed. |
| **`applevalley`** | `container-host` | Legacy ThinkPad Container & Utility Host | Preserved for vintage Sandy Bridge ThinkPad hardware configuration patterns; not actively deployed. |
| **`ares`** | `gaming-kiosk` | Steam Big Picture Kiosk with Impermanence | Preserved for impermanent Steam Big Picture kiosk patterns with Kepler GPU; not actively deployed. |
| **`aristotle`** | `workstation` | Standard Desktop Workstation | Preserved for standard Niri desktop workstation patterns; not actively deployed. |
| **`cassini`** | `workstation` | Apple Silicon macOS Workstation | Preserved for Apple Silicon macOS (nix-darwin + nix-homebrew) architecture reference; not currently deployed. |
| **`deckstation`** | `gaming-kiosk` | High-End Steam Kiosk & Sunshine Host | Preserved for AMD RX 5700 XT gamescope kiosk and tuigreet configurations; not actively deployed. |
| **`demo`** | `vm` | NixOS Demonstration VM | Preserved as a public demonstration and testing VM pattern with zero secrets; not actively deployed. |
| **`garnixMachine`** | `cloud` | Garnix CI Runner & Bountystash Host | Preserved for Garnix CI runner configuration patterns; not actively deployed. |
| **`minyx`** | `embedded` | Raspberry Pi 3B+ Edge Node | Preserved for Raspberry Pi 3B+ impermanent edge computing patterns; not actively deployed. |
| **`mtfuji`** | `container-host` | Headless Container & AI Inference Host | Preserved for headless Ollama/container patterns and btrfs subvolume layout; not actively deployed. |
| **`penguin`** | `laptop` | Chromebook Linux Container (Crostini) | Preserved for standalone Home Manager in ChromeOS Crostini container reference; not actively deployed. |
| **`schneeeule`** | `laptop` | Impermanent Desktop Laptop | Preserved for impermanent laptop and dual-GPU legacy driver reference; not actively deployed. |
| **`sledgehammer`** | `ephemeral-tool` | Fleet Provisioning & Disaster Recovery USB | Preserved as an offline bootable live USB recovery and provisioning tool; deployed on-demand to flash drives. |
| **`testvm`** | `vm` | MicroVM Sandbox | Preserved as a cloud-hypervisor microVM sandbox configuration pattern; not actively deployed. |

---

## 5. Device-Specific Agent Personas

Each device defines an agent persona specifying its operational compute tier, allowed tasks, and strict constraints.

| Host | Persona Title | Compute Tier | Allowed Workloads | Operational Constraints |
| :--- | :--- | :--- | :--- | :--- |
| ⚪ **`aceofspades`** | AMD OpenCL Compute Station (Preserved) | `standard-desktop` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| ⚪ **`alarm`** | Arch Linux ARM Embedded Agent (Preserved) | `strictly-constrained` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| ⚪ **`ancientace`** | MicroVM Hypervisor & Local Model Server (Preserved) | `standard-desktop` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| ⚪ **`applevalley`** | Vintage ThinkPad Utility Node (Preserved) | `lightweight-legacy` | • Configuration reference | ⚠ Preserved host; do not target for live deployment. |
| ⚪ **`ares`** | Impermanent Arcade & Steam Kiosk (Preserved) | `kiosk-gaming` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| ⚪ **`aristotle`** | Philosophical Desktop Workstation (Preserved) | `standard-desktop` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| ⚪ **`cassini`** | macOS Executive & Creative Operator (Preserved) | `apple-silicon-workstation` | • macOS configuration pattern reference<br>• Darwin flake maintenance | ⚠ Host is preserved/dormant; do not target for live deployment. |
| ⚪ **`deckstation`** | High-Performance Stream & Kiosk Station (Preserved) | `heavy-gaming` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| 🟡 **`delphi`** | Cloud Bastion & ARM64 Build Offloader | `cloud-high-ram` | • ARM64 compilation and package builds<br>• Offload task delegation from low-power nodes<br>• Tailscale exit node and network proxying<br>• Remote health monitoring | ⚠ Cloud security posture; only port 22 and WireGuard direct ports allowed through firewall. |
| ⚪ **`demo`** | Demonstration & Public Sandbox (Preserved) | `demo-sandbox` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| 🌐 **`dragoncourt`** | Alwaysdata Webmaster & Archival Host | `shared-web-hosting` | • Web asset sync<br>• PHP/Wasm application deployment<br>• HTTP health check | ⚠ Non-Nix environment: standard Debian shared hosting webroot in ~/www.<br>⚠ Deployments managed via task dragoncourt:deploy. |
| 🟢 **`eisen`** | High-Core Gaming, Streaming & LLM Inference Host | `heavy-compute-64gb` | • Heavy parallel multi-threaded builds<br>• GameStream / Sunshine streaming management<br>• Steam game library management on /mnt/steam<br>• FFmpeg hardware-accelerated transcoding<br>• Local MoE LLM inference (llama.cpp) serving the fleet OpenAI-compatible API | ⚠ No Intel iGPU present; all display and encoding flows through the RX 5700. |
| 🌐 **`envs`** | Small-Web Diplomat & Protocol Ambassador | `shared-pubnix` | • Public HTML website maintenance<br>• Gemini capsule page publishing<br>• Gopher hole navigation map updates<br>• Community pubnix interaction | ⚠ Non-Nix environment: standard Debian pubnix userland.<br>⚠ Shared community server; abide by pubnix community etiquette and quota guidelines. |
| 🟢 **`fern`** | Portable Field Operative | `lightweight-laptop` | • Everyday coding and markdown notes<br>• NAS client synchronization and recovery<br>• Lightweight local builds and documentation<br>• Battery lifecycle management | ⚠ 15W dual-core processor and 8GB RAM; avoid heavy compilation loops.<br>⚠ Never install or launch Steam; this machine is strictly work-focused. |
| 🟢 **`frieren`** | Fleet Mainframe & Storage Steward | `server-heavy-io-sensitive` | • Service maintenance & health auditing<br>• SOPS secrets management and rekeying<br>• Storage hygiene and permission audits<br>• Backup verification and snapshot tracking<br>• Fleet binary cache warming and closure pushing | ⚠ NEVER run heavy compilations or rebuilds during the 03:00-05:30 nightly backup window.<br>⚠ At most ONE nixos-rebuild at a time; never retry-loop builds.<br>⚠ Never edit /var/lib/kiwix by hand; Kiwix is strictly declarative.<br>⚠ Always push commits to origin/main so 04:00 system.autoUpgrade does not revert local state. |
| ⚪ **`garnixMachine`** | Continuous Integration & Deployment Runner (Preserved) | `ci-cloud` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| 🟢 **`guckloch`** | Cross-Platform Windows/Linux Bridge | `wsl2-container` | • WSL2 development<br>• Windows binary interoperability via nix-ld<br>• Docker Desktop builds | ⚠ WSL2 boundary applies; avoid raw block device operations. |
| 🟢 **`kali`** | Offensive Security & Pen-Testing Operative | `specialized-cli` | • Network port scanning & enumeration (nmap, rustscan)<br>• Web application fuzzing & testing (gobuster, ffuf, sqlmap)<br>• Wireless security auditing (aircrack-ng, bettercap)<br>• Security telemetry logging | ⚠ Mobile storage is tight; avoid installing heavy desktop tools (Ghidra, Burp, Metasploit).<br>⚠ All tools must build cleanly on aarch64-linux. |
| 🟢 **`kellerbench`** | Remote GameStream & Benchmark Rig | `kiosk-gaming` | • Sunshine streaming configuration<br>• Gaming benchmark automation<br>• Remote display hosting | ⚠ Kepler GPU with legacy drivers; no modern Vulkan extensions. |
| ⚪ **`minyx`** | Edge Sensor & Minimalist IoT Guardian (Preserved) | `strictly-constrained-1gb` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| 🌐 **`moto`** | Mobile Companion & Field Sensor | `mobile-termux` | • Obsidian mobile git sync<br>• Photo, camera, and download file transfers via `task moto:push/pull`<br>• Battery, network, and storage status checks<br>• Termux CLI execution | ⚠ Battery and thermal throttling aware.<br>⚠ Operates in Termux user sandbox (UID u0_a301); cannot touch root Android partitions. |
| ⚪ **`mtfuji`** | Container & AI Inference Worker (Preserved) | `container-compute` | • Configuration pattern reference<br>• Container layout replication | ⚠ Host is preserved/dormant; do not target for live deployments without manual operator provisioning. |
| 🟢 **`netbook`** | Alice's Travel Companion | `strictly-constrained-cpu` | • Simple note taking<br>• Document viewing<br>• Alice user assistance | ⚠ NEVER run local Nix builds or heavy evals; offload all packages to frieren.<br>⚠ Host is pinned to NixOS 25.11 channel due to upstream kernel initrd bug. |
| ⚪ **`penguin`** | Chromebook Companion (Preserved) | `container-client` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| 🟢 **`poseidon`** | Flagship Laptop Workstation Architect | `flagship-compute` | • Full fleet flake builds and closures<br>• Heavy CUDA LLM inference and model training<br>• Graphical software development and testing<br>• High-resolution media editing | ⚠ Primary interactive workstation; keep interactive desktop UI smooth and responsive. |
| ⚪ **`schneeeule`** | Impermanent Laptop Sentinel (Preserved) | `standard-laptop` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
| 🟢 **`scratch`** | I/O Diet Minimalist & RAM-First Steward | `lightweight-io-diet` | • RAM-resident development tasks<br>• Lightweight text editing and browsing<br>• Clean memory management | ⚠ ABSOLUTELY MINIMIZE DISK WRITES. Keep all caches and logs in RAM.<br>⚠ Do not run heavy builds that write multi-gigabyte store paths.<br>⚠ Legacy BIOS GRUB on /dev/sda; never touch systemd-boot. |
| 🌐 **`serv00`** | FreeBSD Web Sentry & Daemon Guardian | `shared-freebsd-quota` | • Devil CLI port and domain administration<br>• Go webserver compilation and process supervision<br>• Keep-alive cron monitoring<br>• Permissions and security hardening (750 domains, 700 SSH) | ⚠ Non-Nix environment: do not run nix or nixos-rebuild.<br>⚠ STRICT 512 MB RAM QUOTA. Processes exceeding this limit are instantly killed by FreeBSD kernel.<br>⚠ FreeBSD syntax applies (sockstat, devil, pkill). |
| ⚪ **`sledgehammer`** | Bare-Metal Fleet Provisioner & Recovery Sledge (Preserved) | `live-installer` | • Live USB creation via Taskfile<br>• Disko provisioning reference | ⚠ Offline/on-demand tool; not a persistent running host. |
| 🟢 **`stark`** | Living Room Gaming & Media Controller | `low-power-gaming` | • Steam Big Picture session management<br>• PRIME offload optimization (nvidia-offload %command%)<br>• Living-room media playback<br>• HDD Steam library management | ⚠ CPU is a 15W dual-core; avoid running heavy background tasks during gameplay.<br>⚠ dGPU is a Maxwell GM108M (sm_50); CUDA capabilities are legacy. |
| ⚪ **`testvm`** | MicroVM Sandbox Testbed (Preserved) | `microvm-sandbox` | • Configuration pattern reference | ⚠ Preserved host; do not target for live deployment. |
