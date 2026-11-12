# Eisen Strata MoE inference manual: Qwen3.8-Flash-Next on RX 5700 (Navi 10 / gfx1010)

This manual documents the architecture, operations, tuning, and API consumption for running **Qwen3.8-Flash-Next** (125B MoE) on Eisen's AMD Radeon RX 5700 via **Strata**'s HIP backend.

---

## 1. Hardware & Memory Topology

| Subsystem | Hardware Spec | Strata Allocation & Role |
| :--- | :--- | :--- |
| **GPU** | **AMD Radeon RX 5700** (Navi 10 / `gfx1010`, 8 GB GDDR6, PCIe 4.0 x16) | HIP backend: Attention projections, layer norms, router, top-k gates, and ~600+ expert slices cached directly in VRAM. |
| **CPU** | **Intel Xeon E5-2673 v3** (12 cores / 24 threads @ 2.40 GHz, AVX2, 30 MB L3) | Multi-threaded CPU expert pool for remaining experts (`--pool-workers 11`). |
| **System RAM** | **64 GiB DDR3-1600** (4 × 16 GiB unbuffered, dual-channel) | Holds resident MoE expert arena in page-locked host memory (~23–32 GiB for `IQ1_M`). ~25.6 GB/s peak: this, not capacity, sets decode speed. |
| **Storage** | **14.6 TB btrfs `/mnt/storage`** | Engine source/binaries at `/mnt/storage/strata`, model shards and packs at `/mnt/storage/strata-data`. |

### Zero-Pollution FHS container isolation
Host Mesa and RADV Vulkan drivers remain 100% clean and unpolluted. No system-wide ROCm packages are installed.
Strata compiles and executes inside a hermetic Nix `buildFHSEnv` (`strata-fhs`) providing standard glibc/libstdc++ headers alongside official AMD TheRock ROCm 7.14 `gfx101X-dgpu` wheels in `/mnt/storage/strata/.venv`.

---

## 2. Service Endpoints & Network Access

Strata serves an OpenAI- and Anthropic-compatible API on **port 8085**; Eisen's reverse proxy exposes it on the tailnet:

```
[Local Host]        ──> http://127.0.0.1:8085/v1/chat/completions (Direct engine)
[SubZeroClaw]       ──> http://127.0.0.1:8085/v1/chat/completions (Local agent harness)
[LAN Clients]       ──> http://eisen.lan/v1/chat/completions      (Nginx :80 -> :8085)
[Tailnet Clients]   ──> https://eisen.cloudforest-kardashev.ts.net/v1/chat/completions (Tailscale serve 443 -> :8085)
[Decision Router]   ──> http://eisen.lan/router/                 (Nginx :80 -> :8000)
```

### Health & model discovery
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

### A. Any OpenAI-compatible agent harness
The SubZeroClaw harness this section documented was packaged inside the
`frieren-canary` microVM module and went with it when that guest was narrowed to a
runbook sandbox (2026-11-01, `hosts/microvms/README.md`). The endpoint it used is
what any harness needs: `http://127.0.0.1:8085/v1/chat/completions`, model
`qwen3.8-flash-next-coder-iq1_m`, no API key for the local vhost.

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
   - `--spec-min-p 0.5` takes a speculative draft only when the model's confidence exceeds 50%.
2. **Quantized Expert Placement**:
   - `IQ1_M` (Coder) retains 256 of 512 experts selected specifically for code, math, and instruction following.
   - The hottest ~607 experts reside in RX 5700 GDDR6 VRAM; the rest reside in dual-channel DDR3-1600 RAM.
3. **Adaptive Asynchronous Swaps (`--adapt-async 1`)**:
   - Swaps expert slices between host DDR3-1600 RAM and GPU VRAM asynchronously across verification windows without stalling generation.
4. **Pool Worker Affinity (`--pool-workers 11 --host-core first`)**:
   - Binds the host event loop to Core 0 while worker threads use the remaining physical Haswell-EP cores for expert dot-products.

---

## 6. Service Management & Gaming Guard

### Lifecycle commands
```bash
# Check Strata systemd service status
systemctl status strata.service

# View live inference logs
journalctl -u strata.service -f

# Restart Strata
sudo systemctl restart strata.service
```

### Automatic gaming yield
The `llama-swap-gaming-guard` unit polls `/proc/[0-9]*/exe` every 5 seconds. If any process executes under `*/steamapps/common/*`, the guard stops `strata.service` to release 100% of GPU VRAM to Steam/Gamescope/Proton, and starts it again once the game exits. The stop is re-applied on every poll while the game runs, so anything that brings Strata back mid-game (a hand `systemctl start`, a switch activating a changed unit) is stopped again; the marker lives in `/run`, so a guard restart mid-game still resumes the engine afterwards.

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

### Tier comparison, 2026-11-04 (`tools/strata_bench.py`, same host)

| Tier | Size | Experts | Decode (chat) | Ingestion | Agent session |
| :--- | ---: | :--- | :--- | :--- | :--- |
| IQ1_M pruned Coder — `strata-coder-iq1_m.json`, served | 58.41 GB | 256 of 512 | 14.6 – 21.0 warm (2026-10-21) · 13.8 / 7.0 / 7.3 cold (2026-11-04) | 167 tok/s | **completes**, 19.4 tok/s, 81% prefix reuse |
| IQ2_XS Swift 1.5 — `strata-coder-iq2_xs.json` | 68.15 GB | all 512 | 7.2 – 20.3, median 13.0 | 158 tok/s | froze at turn 0 |
| IQ2_XS again at `--max-context 16384` — `strata-coder-iq2_xs-16k.json` | 68.15 GB | all 512 | 7.5 – 20.8, median 11.7 | — | SIGABRT on the 4K prompt stage |
| IQ3_XXS Swift 1.5 — `strata-coder-iq3_xxs.json` | 75.97 GB | all 512 | 7.4 – 20.8, median 12.2 desktop / 10.4 `server` | 157 tok/s | aborted / froze at turn 0 |

**The decode medians here are not a fair fight, and the raw column above is
why.** The first two questions after a load answer at ~7 tok/s and the same
questions warm answer at 14–20: IQ1_M was re-measured on 2026-11-04 immediately
after a restart and scored 13.8 / 7.0 / 7.3, which would "lose" to its own
2026-10-21 warm run. Page cache, not quantisation, sets that floor. Compare tiers
only on a server that has been up and answering for a while.

The agent column is not confounded in the same way, but it is **not** a size
split, which is what the 2026-11-04 baseline settled: 58 GB finishes the suite
(turn 5 at 11818 of 14637 prompt tokens reused) *and* loses the engine on long
prefill when the context is small enough to make turns 4–5 impossible, while
68 GB and 76 GB lose it earlier. Every loss has the same signature — `oom_kill
0`, no kernel line, no coredump payload, frozen with no CPU and no disk until the
engine's own stall guard kills it during *prefill*. That is one engine bug (#29),
not a tier property, and it is why the served tier went back to IQ1_M: it is the
pack that gets furthest before the stall and answers fastest between them.

**Two hypotheses were tested and both are dead.** *Context*: IQ2 re-run at
`--max-context 16384` loaded with **636 MiB of VRAM free** and 50.9 GB RSS, and
still aborted (`exit code -6`) — this time on the **4K prompt** stage, after only
~7k tokens of chat traffic, so it is not a long-context or KV-footprint wall.
*PLE*: `--no-ple` cannot be used to shrink the pack at all — the engine rejects
it under `--native` because the PLE key is itself native (`--native requires
--ple-gguf … no shard of the model holds per_layer_token_embd.weight`). Neither
flag is the lever; an engine fix is. Both packs and configs stay on the host, so
a retest is one line and a restart.

**And the failure is not size at all — IQ1_M does it too.** A 16K-context run of
the served pack on 2026-11-04 lost the engine in **all three** agent runs, at the
same place each time:

```
no progress for 60 s during a request (reading the prompt (batched):
  layer 1 of the prompt chunk from token 9076) - stopping the engine so the
  server starts it again (issue #29)
```

The engine's own stall guard fires during *prefill*, the wrapper restarts it, and
the session resumes — which is why the earlier tier runs looked like "froze at
turn 0" with no CPU and no disk. Reported upstream as
[Niko1221/Strata#5229](https://github.com/Niko1221/Strata/issues/5229) (with a
pointer from the closed #29, whose guard message our build still prints). The same stall hit a 16,384-token prompt at
`--max-context 32768`, so it tracks prompt length (~9k–16k), not the KV budget and
not the quantisation. `engine/BUILD.json` reads `0.1.46.2` and the binary is dated
2026-10-21 — the same build that ran the suite clean that day, so this is
intermittent in *when* it fires, not a build that changed overnight.

**16K-context baseline of the served pack, 2026-11-04** (`--runs 3`, warm server):

| Stage | Result |
| :--- | :--- |
| chat decode | median **11.30 tok/s** (7.60 – 19.90, n=9) |
| chat first token | 2.22 s |
| 4K prompt | 166.8 tok/s, first token 24.17 s |
| agent cache hit | 55.8 % |
| agent first token per turn | 93.77 s (60.42 – 176.68, n=9) |
| agent decode | **8.40 tok/s** (7.90 – 10.50, n=9) |
| failures | 3 requests lost to the stall; the 16K prompt stage skipped (context was 16384) |

So the agent turn cost is dominated by prefill, not decode: 90+ s to first token
for a ~9k-token turn against 8.4 tok/s once it starts. The stall truncates the
session at turn 3 of 6, which is why `--max-context 16384` was **reverted to
32768** — the KV saving buys nothing an agent session can use if turns 4–5 never
arrive.

**Served config (2026-11-04, final):** IQ1_M at `--max-context 32768` with
`--kv int8`, MTP on (`--mtp …/mtp/rt`, `--spec 4 --spec-min-p 0.5`) and the
engine's 24 threads.

