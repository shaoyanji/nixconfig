# eisen — LLM Inference Architecture & Handoff

Detailed architecture specification for running local MoE LLMs on Eisen's Xeon E5-2673 v3 (12c/24t) + 64 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM).

**Canonical Documentation**: [`.agents/deploy/hosts/eisen.md`](file:///home/devji/Documents/nixconfig/.agents/deploy/hosts/eisen.md)

---

## Primary Champion Model: Qwen3.6-35B-A3B
* **Architecture**: 35 Billion total parameters, **~3 Billion active parameters per token** (`A3B`), combining Gated DeltaNet / Linear Attention with sparse Mixture of Experts.
* **Quantization**: `Q4_K_M` (~22.5 GiB GGUF file).
* **Hardware Allocation**:
  - **RX 5700 (8 GB GDDR6 VRAM)**: Offloads Linear Attention states, shared self-attention layers, and KV-cache (`--flash-attn`). The 8 GB VRAM easily accommodates the **3B active parameter** forward pass at ~448 GB/s bandwidth.
  - **Xeon + 64 GiB DDR4 RAM**: Holds the full 35B parameter sparse expert pool (~22.5 GiB in RAM), leaving **41.5 GiB free** for Steam, Sunshine, and background tasks.
* **Throughput**: Delivers **35–55+ tokens/second** due to having only 3B active parameters per token streaming across the memory bus.
* **Engine**: Native `services.llama-cpp` with Vulkan support (`pkgs.llama-cpp.override { vulkanSupport = true; }`). Completely bypasses Ollama to eliminate daemon overhead and abstraction.
* **API Endpoint**: Exposes OpenAI-compatible REST API at `http://eisen:8080/v1` over Tailscale interface (`tailscale0`).
