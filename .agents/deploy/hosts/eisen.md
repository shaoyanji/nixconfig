# eisen Deployment & LLM Architecture Handoff

## Scope
High-core gaming desktop, Sunshine GameStream server, and high-RAM local AI inference host (`Intel Xeon E5-2673 v3`, `64 GiB DDR4`, `AMD Radeon RX 5700 8 GB VRAM`).

---

## Hardware Sizing & Memory Topology

| Component | Specification | AI Inference Role |
| :--- | :--- | :--- |
| **CPU** | Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t @ 2.40-3.10 GHz, 30MB L3 cache) | AVX2 / FMA3 multi-threaded matrix math (`--threads 12`) |
| **RAM** | **64 GiB DDR4 Quad-Channel** (~65 GB/s memory bandwidth) | Primary host memory pool; easily holds 14B–57B model weights |
| **GPU** | **AMD Radeon RX 5700** (Navi 10, **8 GB GDDR6**, PCIe 4.0 x16, radv Vulkan) | Offloads KV-cache + first 12–16 layers via Vulkan backend |
| **Storage** | 256GB NVMe SSD (system) + 16TB HDD `/mnt/steam` / `/mnt/storage` (btrfs+zstd) | Dedicated model weight repository (`/mnt/storage/models/*.gguf`) |
| **Network** | Tailscale mesh (`100.x.x.x`) + Gigabit LAN | Serves fleet-wide OpenAI-compatible API to laptops & servers |

---

## Model Selection Strategy: Mixture of Experts (MoE) Offloading

> [!TIP]
> **Why bypass Ollama?**
> Ollama is a Go wrapper around `llama.cpp` that adds abstraction layers, model blob obfuscation, and fixed runtime defaults. Running native `llama-server` (`llama.cpp`) directly on NixOS provides zero-overhead OpenAI API compatibility, exact Vulkan layer tuning, prompt caching, and declarative systemd service control.

### The Sweet Spot: Sparse MoE with 3B–7B Active Parameters
The primary architectural goal for `eisen` is **MoE Expert Offloading**:
* **Host RAM (64 GiB DDR4 Quad-Channel)**: Holds the entire 30B–45B parameter sparse expert weight matrix in memory (~18–25 GiB at `Q4_K_M`), leaving 40 GiB free for Steam, Sunshine, and background tasks.
* **GPU VRAM (8 GiB RX 5700)**: Serves the **3B to 7B active parameters** required per token:
  - Shared Self-Attention layers + Norms + Gate/Router offloaded to the GPU.
  - KV-Cache with `--flash-attn` allocated in high-bandwidth GDDR6 (~448 GB/s).
  - Only the 2–4 activated experts (3B–7B active parameters) compute during the forward pass.
* **Why this beats Dense 32B**:
  - Memory bandwidth requirements are cut by **75% to 85%** per token.
  - Token generation speed jumps from ~8–12 tok/s (dense 32B) to **25–45+ tok/s** (MoE with 3B–7B active), while retaining the world knowledge and reasoning depth of a 30B–45B model!

### Recommended MoE Models (3B–7B Active Parameters)

| Model Profile | Total Params | Active Params | Quant Size | Offload Strategy | Expected Speed | Strengths |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Phi-3.5-MoE-Instruct** | 41.9B (16 experts) | **6.6B active** (top-2) | 24.5 GB (`Q4_K_M`) | Attention + KV in VRAM, 12c Xeon for active FFNs | **22–32 tok/s** | Premier reasoning, code, math, 128k context |
| **Qwen1.5-MoE-A2.7B** | 14.3B (60 experts) | **2.7B active** (top-4) | 9.2 GB (`Q4_K_M`) | High GPU layer offload into 8GB VRAM | **45–60 tok/s** | Extremely fast, great multilingual & chat |
| **DeepSeek-V2-Lite-Chat**| 15.7B (64 experts) | **2.4B active** (top-6) | 10.1 GB (`Q4_K_M`) | Near-complete VRAM offload | **40–55 tok/s** | Multi-head latent attention (MLA), coding |
| **Qwen2.5-Coder-32B** | 32.5B (Dense) | 32.5B (Dense) | 19.8 GB (`Q4_K_M`) | 14 layers in VRAM, 50 layers in DDR4 | **8–14 tok/s** | Dense baseline; exceptional coding quality |

---

## Native Engine: Declarative `llama-server` Profile

Create a declarative profile in `hosts/eisen/llm-server.nix` (or `modules/services/llama-server.nix`):

```nix
# hosts/eisen/llm-server.nix
{ pkgs, ... }:

let
  modelDir = "/mnt/storage/models";
  defaultModel = "${modelDir}/qwen2.5-coder-32b-instruct-q4_k_m.gguf";
in {
  # Build llama-cpp with Vulkan support for AMD Navi 10 (radv)
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override {
      vulkanSupport = true;
    };
    model = defaultModel;
    host = "0.0.0.0";
    port = 8080;
    openFirewall = false; # Bound to Tailscale / LAN only
    extraFlags = [
      "--n-gpu-layers" "14"
      "--threads" "12"
      "--ctx-size" "16384"
      "--flash-attn"
      "--mlock"
      "--cont-batching"
      "--metrics"
      "--alias" "qwen-32b"
    ];
  };

  # Restrict access or open to Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8080 ];

  # Ensure model directory permissions and storage existence
  systemd.tmpfiles.rules = [
    "d ${modelDir} 0755 devji users - -"
  ];
}
```

---

## Fleet Client Integration

Once `llama-server` is active on `eisen:8080`, any node on the Tailnet (frieren, poseidon, fern, netbook) can use it as a drop-in OpenAI-compatible provider:

### 1. `mods` (`~/.config/mods/mods.yml`)
```yaml
eisen-qwen:
  base-url: http://eisen:8080/v1
  api-key: none
  models:
    qwen-32b:
      aliases: ["qwen", "eisen"]
      max-tokens: 8192
```

### 2. `aichat` (`~/.config/aichat/config.yaml`)
```yaml
- type: openai-compatible
  name: eisen
  api_base: http://eisen:8080/v1
  models:
    - name: qwen-32b
```

### 3. Agent CLI (`antigravity` / `crush` / `hermes`)
Set environment variable:
```bash
export OPENAI_BASE_URL="http://eisen:8080/v1"
export OPENAI_API_KEY="none"
```

---

## Rollout Plan

1. **Storage Setup**:
   Create `/mnt/storage/models/` and fetch the quantized weights:
   ```bash
   huggingface-cli download Qwen/Qwen2.5-Coder-32B-Instruct-GGUF \
     qwen2.5-coder-32b-instruct-q4_k_m.gguf \
     --local-dir /mnt/storage/models/
   ```
2. **Import Module**:
   Add `./llm-server.nix` into `hosts/eisen/configuration.nix`.
3. **Deploy & Validate**:
   ```bash
   task infra:deploy:host:eisen
   curl http://eisen:8080/v1/models
   ```
4. **Vulkan Layer Tuning**:
   Inspect `radeontop` or `vulkaninfo` while running a prompt to verify VRAM usage stays safely below 6.5 GiB during heavy inference.
