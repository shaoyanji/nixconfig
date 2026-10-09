# eisen — LLM Inference Architecture & Handoff

Detailed architecture specification for running local MoE LLMs on Eisen's Xeon E5-2673 v3 (12c/24t) + 62 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM, **Vulkan/radv** — Navi 10 has no ROCm target).

**Canonical Documentation**: [`.agents/deploy/hosts/eisen.md`](file:///home/devji/Documents/nixconfig/.agents/deploy/hosts/eisen.md)
**Implementation**: [`hosts/eisen/llm-server.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/llm-server.nix)

---

## Serving Topology

One OpenAI-compatible endpoint, two MoE models, swapped on demand by `services.llama-swap` (they cannot co-reside: ~21 GiB + ~44 GiB > 62 GiB RAM).

```
http://eisen.lan/v1                       (nginx :80 -> 127.0.0.1:8080)
https://eisen.<tailnet>.ts.net/v1         (services.tailscale.serve tcp:443)
http://eisen:8080/v1                      (llama-swap on 0.0.0.0)
        └─> llama-swap :8080 ──> llama-server (one child per model, ${PORT})
```

`eisen.lan` resolves to the **tailnet IP** (`100.119.172.99`) via frieren's pi-hole (`hosts/frieren/dns.nix`), so the same name works on and off LAN. `ttl = 900` unloads an idle model so the other can load; `healthCheckTimeout = 600` tolerates multi-minute first loads off btrfs.

Engine: `pkgs.llama-cpp.override { vulkanSupport = true; }`, shared flags `--threads 12 --ctx-size 32768 --flash-attn on --jinja --metrics --n-gpu-layers 99 --override-tensor exps=CPU --cache-type-k q8_0 --cache-type-v q8_0`.

---

## Models

### Primary Champion: Qwen3.6-35B-A3B (`qwen`)
* **Architecture**: 35B total parameters, **~3B active per token** (`A3B`), Gated DeltaNet / linear attention + sparse MoE.
* **Quantization**: `Q4_K_M` — 22,285,080,192 B (~20.8 GiB) from `bartowski/Qwen_Qwen3.6-35B-A3B-GGUF`.
* **Hardware allocation**:
  - **RX 5700 (8 GB GDDR6)**: all non-expert tensors (`--n-gpu-layers 99`) — attention, norms, embeddings, router/gate — plus the q8_0 KV cache under flash-attn.
  - **Xeon + 62 GiB DDR4**: the full expert pool (`--override-tensor exps=CPU`, ~21 GiB), leaving ~40 GiB for Steam/Sunshine.
* **Engine**: native `llama-server` via llama-swap — no Ollama daemon in the path.

### Alternative: Aleph-Alpha Kolibri-1 (`kolibri` / `aleph`)
* **Architecture**: 78B total, **3.46B active**, German + English, Apache 2.0, context up to 262144.
* **Quantization**: `Q4_K_M` — 47,454,113,472 B (~44.2 GiB) from `Hob-forge/Kolibri-1-GGUF`.
* Tighter fit: requests for it trigger a swap that unloads Qwen first.

Weights live on the 14.6 TB `/mnt/storage` btrfs array at `/mnt/storage/models/*.gguf`, kept in place by the idempotent `eisen-llm-qwen` / `eisen-llm-kolibri` fetch units (`ConditionPathExists` + resumable `curl -C -`). They are **not** Nix store paths — never hand-run `llama-server` or Ollama on this host.
