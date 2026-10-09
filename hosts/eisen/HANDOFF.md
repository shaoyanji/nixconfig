# eisen — LLM Inference Architecture & Handoff

Detailed architecture specification for running local MoE LLMs on Eisen's Xeon E5-2673 v3 (12c/24t) + 64 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM).

**Canonical Documentation**: [`.agents/deploy/hosts/eisen.md`](file:///home/devji/Documents/nixconfig/.agents/deploy/hosts/eisen.md)

---

## Architecture: MoE Expert Offloading (3B–7B Active Parameters)
* **Engine**: Native `services.llama-cpp` with Vulkan support (`pkgs.llama-cpp.override { vulkanSupport = true; }`). Bypasses Ollama to eliminate daemon bloat and fixed runtime limits.
* **Hardware Offloading Sizing**:
  - **RX 5700 (8 GB GDDR6 VRAM)**: Offloads shared Self-Attention layers, KV-cache (`--flash-attn`), and router gates, handling **3B to 7B active parameters** at ~448 GB/s VRAM bandwidth.
  - **Xeon + 64 GiB DDR4 RAM**: Holds the full 30B–45B parameter sparse expert pool (~18–25 GiB in RAM), evaluated across 12 physical Haswell-EP cores (`--threads 12`).
  - **Footprint**: Consumes ~22 GiB total RAM, leaving 42 GiB free for Steam, Sunshine, and background builds.
* **Top MoE Candidates**:
  - **Phi-3.5-MoE-Instruct** (41.9B total, **6.6B active** per token, ~24.5 GB at `Q4_K_M`): ~22–32 tok/s.
  - **Qwen1.5-MoE-A2.7B** (14.3B total, **2.7B active** per token, ~9.2 GB at `Q4_K_M`): ~45–60 tok/s.
  - **DeepSeek-V2-Lite-Chat** (15.7B total, **2.4B active** per token, ~10.1 GB at `Q4_K_M`): ~40–55 tok/s.
* **API Endpoint**: Exposes OpenAI-compatible REST API at `http://eisen:8080/v1` over Tailscale interface (`tailscale0`).
