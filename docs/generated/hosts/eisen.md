# eisen

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | High-Core Gaming Desktop, Sunshine Stream Server & Offline LLM + Decision-Model Node |
| status | active — In active production as the primary 12-core gaming workstation, Sunshine GameStream host, and local MoE LLM node: Qwen3.6-35B-A3B under llama-swap with DFlash2 speculative decoding, served as an OpenAI /v1 API at eisen.lan (LAN) and via tailscale serve (tailnet), and auto-yielding to Steam games. Also serves Laya, a 421M CPU-only Jev-compatible decision model speaking POST /v1/systemone at laya.lan and tailscale serve :8443. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | Custom Multi-Core Gaming Rig |
| cpu | Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t, no iGPU) |
| gpu | AMD Radeon RX 5700 (Navi 10, 8 GB VRAM, VCN 2.0) |
| ram | 64 GiB DDR4 |
| storage | 119GB NVMe SSD (btrfs @root, @nix, @persist, @log, @snapshots) + 931GB SSD /mnt/steam (btrfs+zstd) + 14.6TB HDD /mnt/storage (btrfs+zstd, LLM weights) |
| persona | High-Core Gaming, Streaming, LLM & Decision-Model Host (tier: heavy-compute-64gb) |
| persona hint | You are the powerhouse multi-core gaming, streaming, and local inference station. Leverage 64 GB of RAM and 12-core Xeon parallelism for compilation, AMD hardware-accelerated video streaming, serving the fleet's offline OpenAI-compatible MoE model (Qwen3.6-35B-A3B via llama.cpp), and answering typed decisions with the CPU-only Jev-compatible Laya model (POST /v1/systemone on laya.lan). |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - 12-core-24-thread
  - 64gb-ram
  - amd-gpu
  - sunshine-streaming
  - steam-gaming
  - llm-inference
  - llm-model-router
  - moe-expert-offload
  - speculative-decoding
  - game-aware-yield
  - vulkan-compute
  - decision-model
  - jev-compatible
  - cpu-inference

## Key services

- services:
  - Niri Wayland Desktop + DMS Greeter
  - Steam (gamescope-session)
  - Sunshine GameStream server (Moonlight LAN host)
  - RX 5700 VCN 2.0 hardware video encode
  - NAS client automount
  - llama-swap model router on :8080 (OpenAI /v1 via nginx on eisen.lan:80 and tailscale serve; model 'qwen' = qwen3.6-35b-a3b)
  - Qwen3.6-35B-A3B on Vulkan/radv llama.cpp with DFlash2 speculative decoding (+40% decode, measured) and expert tensors kept in CPU RAM
  - llama-swap-gaming-guard: suspends the LLM while a Steam game runs, freeing ~21 GiB RAM + 5.4 GiB VRAM, and resumes on exit
  - Kolibri-1 (78B A3B, German/English) weights staged at /mnt/storage/models but not loadable: stock llama.cpp lacks the kolibri1 architecture
  - Laya decision model (421M, CPU-only) on 127.0.0.1:8090 behind nginx on laya.lan:80 and tailscale serve :8443, exposing the Jev-compatible POST /v1/systemone (choice/score/noul) — holds no VRAM, so it keeps answering while a game runs

## Allowed tasks

- tasks:
  - Heavy parallel multi-threaded builds
  - GameStream / Sunshine streaming management
  - Steam game library management on /mnt/steam
  - FFmpeg hardware-accelerated transcoding
  - Local MoE LLM inference (llama.cpp) serving the fleet OpenAI-compatible API
  - Typed decision queries via the CPU-only Laya model (Jev-compatible POST /v1/systemone)

## Constraints

- constraint:
  - No Intel iGPU present; all display and encoding flows through the RX 5700.
  - While a model is loaded the LLM holds ~5.75 of 8 GiB VRAM and uses 12 of 24 threads; it auto-yields (llama-swap stops, API answers connection-refused) whenever a Steam game runs.
  - First request after 15 min idle reloads a 21 GiB GGUF (about 2 minutes); do not set short client timeouts.
  - Laya is CPU-only and independent of the gaming guard, but it is not a Jev replacement: benchmark macro accuracy is 0.583 (Jev 0.966), so never let it gate a destructive decision unattended.

## Notes

- Converted from a cage-based Steam kiosk into a full desktop (poseidon-style): globalModulesNixos brings in niri + DankMaterialShell plus the sops/nix-index HM modules.
- Steam runs under the upstream gamescope-session, which is safe on the RX 5700's modern Vulkan ICD (unlike kellerbench's Kepler card).
- History: the previous cage-kiosk specialisation and greetd dual-session experiments hung at graphical.target, so the DMS greeter path (as on poseidon) is used instead of greetd auto-login.
