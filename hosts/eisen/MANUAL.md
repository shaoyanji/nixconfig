# Eisen Strata MoE Inference Manual: Qwen3.8-Flash-Next on RX 5700 (Navi 10 / gfx1010)

This manual documents the architecture, operations, tuning, and API consumption for running **Qwen3.8-Flash-Next** (125B MoE) on Eisen's AMD Radeon RX 5700 via **Strata**'s HIP backend.

---

## 1. Hardware & Memory Topology

| Subsystem | Hardware Spec | Strata Allocation & Role |
| :--- | :--- | :--- |
| **GPU** | **AMD Radeon RX 5700** (Navi 10 / `gfx1010`, 8 GB GDDR6, PCIe 4.0 x16) | HIP backend: Attention projections, layer norms, router, top-k gates, and ~600+ expert slices cached directly in VRAM. |
| **CPU** | **Intel Xeon E5-2673 v3** (12 cores / 24 threads @ 2.40 GHz, AVX2, 30 MB L3) | Multi-threaded CPU expert pool for remaining experts (`--pool-workers 11`). |
| **System RAM** | **64 GiB DDR4 Quad-Channel** | Holds resident MoE expert arena in page-locked host memory (~23–32 GiB for `IQ1_M`). |
| **Storage** | **14.6 TB btrfs `/mnt/storage`** | Engine source/binaries at `/mnt/storage/strata`, model shards and packs at `/mnt/storage/strata-data`. |

### Zero-Pollution FHS Container Isolation
Host Mesa and RADV Vulkan drivers remain 100% clean and unpolluted. No system-wide ROCm packages are installed.
Strata compiles and executes inside a hermetic Nix `buildFHSEnv` (`strata-fhs`) providing standard glibc/libstdc++ headers alongside official AMD TheRock ROCm 7.14 `gfx101X-dgpu` wheels in `/mnt/storage/strata/.venv`.

---

## 2. Service Endpoints & Network Access

Strata serves an OpenAI- and Anthropic-compatible API on **port 8085**, seamlessly integrated into Eisen's reverse proxy and Tailnet topology:

```
[Local Host]        ──> http://127.0.0.1:8085/v1/chat/completions (Direct engine)
[SubZeroClaw]       ──> http://127.0.0.1:8085/v1/chat/completions (Local agent harness)
[LAN Clients]       ──> http://eisen.lan/v1/chat/completions      (Nginx :80 -> :8085)
[Tailnet Clients]   ──> https://eisen.cloudforest-kardashev.ts.net/v1/chat/completions (Tailscale serve 443 -> :8085)
[Decision Router]   ──> http://eisen.lan/router/                 (Nginx :80 -> :8000)
```

### Health & Model Discovery
```bash
# Check service health
curl -s http://127.0.0.1:8085/health

# List available models
curl -s http://127.0.0.1:8085/v1/models | jq
```

---

## 3. Recommended Context Windows & VRAM Guardrails

Eisen's RX 5700 has **8,176 MiB total VRAM**. Gamescope/X11 typically consumes ~450–500 MiB at idle, leaving ~7,600 MiB for inference.

> [!WARNING]
> **The decode column is not a measurement on this card.** These figures match
> Strata's reference table for a 16 GB RX 9070 XT (its README lists Coder at
> 44 tok/s decode, 1,420 tok/s prompt). The only measured run on eisen's RX 5700
> is §7: **14.6–21.0 tok/s decode, 167 tok/s prompt ingestion**. Use this table
> for VRAM planning; do not quote its speed column as eisen's.

| Context Length | KV Cache Type | VRAM Footprint | Expert Slots in VRAM | Decode Speed | Status & Recommendations |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **8K (8,192)** | `int8` | ~512 MiB | ~750 experts | ~52 tok/s | Fastest decode, ideal for short chat & single turns. |
| **32K (32,768)** | `int8` | ~1,850 MiB | ~607 experts | **40–48 tok/s** | **Recommended Standard**. Perfect balance for coding agents and documents. |
| **64K (65,536)** | `int8` (streaming) | ~2,100 MiB | ~580 experts | ~36–42 tok/s | Requires `--kv-resident 32768` to avoid GPU OOM. |
| **128K (131,072)** | `q4_0` / `k8v4` | ~2,400 MiB | ~520 experts | ~30–35 tok/s | Use `--kv q4_0` or `--kv k8v4` to save 50% KV memory. |
| **256K (262,144)** | `q4_0` (streaming) | ~3,200 MiB | ~450 experts | ~24–28 tok/s | Max trained context. Low expert count in VRAM. |
| **>256K** | RoPE YaRN | >4,000 MiB | <350 experts | <20 tok/s | Requires `--rope-scaling yarn --rope-scale 2.0`. |

> [!WARNING]
> **OOM Prevention**: Do not set `--context` higher than 32K without KV streaming (`--kv-resident 32768` or `--kv int8`). Never use FP16 KV cache on an 8 GB card for contexts above 16K, as it will exhaust GPU memory and trigger a driver reset.

---

## 4. Driving the Model

### A. SubZeroClaw Agent Harness
Configure `~/.subzeroclaw/config`:
```ini
api_key = "apikey_..."
endpoint = "http://127.0.0.1:8085/v1/chat/completions"
request_extra = {"model":"qwen3.8-flash-next-coder-iq1_m"}
skills_dir = "/home/devji/.subzeroclaw/skills"
log_dir = "/home/devji/.subzeroclaw/logs"
max_turns = 10
```

Execute a task through SubZeroClaw:
```bash
echo "write me a hello.txt in home directory" | subzeroclaw
```
Check execution trajectory in `~/.subzeroclaw/logs/`.

### B. OpenAI-Compatible API (Python / Curl)
```bash
curl -s http://127.0.0.1:8085/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.8-flash-next-coder-iq1_m",
    "messages": [
      {"role": "system", "content": "You are a concise programming assistant."},
      {"role": "user", "content": "Write a fast fibonacci function in Rust with memoization."}
    ],
    "temperature": 0.2,
    "max_tokens": 512
  }' | jq '.choices[0].message.content'
```

### C. Anthropic Messages API
Strata natively translates Anthropic `/v1/messages` requests:
```bash
curl -s http://127.0.0.1:8085/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.8-flash-next-coder-iq1_m",
    "messages": [{"role": "user", "content": "Explain Rust ownership in 3 bullets."}],
    "max_tokens": 256
  }' | jq '.content[0].text'
```

---

## 5. Speculative Decoding & Tuning

Strata's reference card reaches 40–50 tok/s on 16 GB by combining four optimizations. On eisen's 8 GB RX 5700 the same configuration measured **14.6–21.0 tok/s decode** (§7) — the levers below are real; the headline number belongs to a different card.

1. **Multi-Token Prediction (MTP) Drafting (`--spec 4`)**:
   - Evaluates 4 candidate tokens in parallel using the model's native MTP draft layer (`mtp/rt`).
   - `--spec-min-p 0.5` ensures the engine accepts speculative drafts only when model confidence exceeds 50%.
2. **Quantized Expert Placement**:
   - `IQ1_M` (Coder) retains 256 of 512 experts selected specifically for code, math, and instruction following.
   - The hottest ~607 experts reside in RX 5700 GDDR6 VRAM; the rest reside in 4-channel DDR4 RAM.
3. **Adaptive Asynchronous Swaps (`--adapt-async 1`)**:
   - Swaps expert slices between host DDR4 RAM and GPU VRAM asynchronously across verification windows without stalling generation.
4. **Pool Worker Affinity (`--pool-workers 11 --host-core first`)**:
   - Binds the host event loop to Core 0 while worker threads utilize remaining physical Haswell-EP cores for expert dot-products.

---

## 6. Service Management & Gaming Guard

### Lifecycle Commands
```bash
# Check Strata systemd service status
systemctl status strata.service

# View live inference logs
journalctl -u strata.service -f

# Restart Strata
sudo systemctl restart strata.service
```

### Automatic Gaming Yield
The `llama-swap-gaming-guard` unit polls `/proc/[0-9]*/exe` every 15 seconds. If any process executes under `*/steamapps/common/*`, the guard automatically suspends `strata.service` to release 100% of GPU VRAM to Steam/Gamescope/Proton, and resumes Strata once the game exits.

---

## 7. Measured Benchmark Results (Eisen RX 5700)

Empirically verified on Eisen's AMD Radeon RX 5700 (`gfx1010`) with `tools/strata_bench.py` and `subzeroclaw`:

| Benchmark Metric | Measured Result | Operational Notes |
| :--- | :--- | :--- |
| **Prompt Ingestion Speed** | **167.0 – 167.9 tok/s** | Sustained across 4,096 and 16,384 token input sequences. |
| **Decode Speed (Single Turn)** | **14.6 – 21.0 tok/s** | Peak 21.0 tok/s on structured code generation; median 14.6 tok/s. |
| **Time to First Token (TTFT)** | **1.7 – 2.1 s** | Measured on 4K context inputs. |
| **MTP Draft Acceptance Rate** | **87.5% (70 / 80 tokens)** | `--spec 4 --spec-min-p 0.5` with native MTP runtime pack (`mtp/rt`). |
| **Turn Decode (Agent Session)** | **19.4 tok/s** | Multi-turn agent trajectory with prompt prefix caching. |
| **Prompt Cache Hit Rate** | **69.4%** | Fast re-entry on SubZeroClaw and agent tool loops. |
| **GPU VRAM Allocation** | **6.1 GiB / 8.18 GiB** | 763 resident GPU expert slots (1.47 GiB), MTP layer (839 MiB), INT8 KV (1.85 GiB). |

**Read these two rows together.** 167 tok/s is *prompt ingestion*, about 10k
tokens/minute: a fresh 30k-token agent prefix costs ~3 minutes before the first
answer token, while a cached follow-up does not. 14.6–21.0 tok/s is *decode*, and
it is the interactive constraint — a 500-token reply takes 25–35 s to stream. A
persistent server is what makes the 69.4% cache-hit row pay off; a restart pays
the prefix again.

