# eisen — LLM Inference Architecture & Handoff

Detailed architecture specification for running local MoE LLMs on Eisen's Xeon E5-2673 v3 (12c/24t) + 62 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM, **Vulkan/radv** — Navi 10 has no ROCm target).

**Canonical Documentation**: [`.agents/deploy/hosts/eisen.md`](file:///home/devji/Documents/nixconfig/.agents/deploy/hosts/eisen.md)
**Implementation**: [`hosts/eisen/llm-server.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/llm-server.nix) (generative LLM), [`hosts/eisen/decision-models.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/decision-models.nix) (Laya)

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

---

## Decision Models: Laya (`laya.lan`)

Alongside the generative endpoint, eisen serves **Laya** — a 421M "System One" decision model that answers typed questions about one document in a single forward pass and returns no text. It speaks the same `POST /v1/systemone` contract as TypeSafe's hosted Jev, so a Jev client works by changing the base URL. This fleet has no hosted Jev, so it is the offline stand-in.

```
http://laya.lan/v1/systemone            (nginx :80 -> 127.0.0.1:8090)
https://eisen.<tailnet>.ts.net:8443/v1/systemone
```

| | |
| :--- | :--- |
| Question shapes | `choice` (n options) · `score` (ordinal) · `noul` (yes/no probability) |
| Device | **CPU only** (torch `2.14.1+cpu`, `LAYA_THREADS=12`) — holds no VRAM |
| Measured | 4 questions over a 274-token state: **0.43 s** (12 threads), 0.56 s (8), 0.98 s (4); 3-state batch **0.25 s**; RSS ~3.5 GiB |
| Preloaded | `english` + `multilingual`; `typed-decisions` stays lazy (`LAYA_AUTO_TASK=1`) |
| Package | `laya 0.4.1` in a uv venv at `/mnt/storage/decision/laya` |

**It needs no gaming guard** and is deliberately excluded from `llama-swap-gaming-guard`: it touches no VRAM, and the calls are short enough that a running game never starves. It also co-resides with Qwen rather than competing for the 62 GiB — which is what would make a **qwen + laya offline tandem** possible on this one box.

`laya` is not in nixpkgs, so `eisen-laya-bootstrap.service` builds the venv once with uv onto `/mnt/storage` and marks it ready only on success (self-healing: a deleted venv or a half-finished install is retried on the next boot). Python and libstdc++ come from the store and are referenced by the system closure, so the venv's shebangs point at store paths that can never be collected out from under it. The bootstrap overrides the fleet's uv index — `modules/dev.nix` points `pip.index-url` at `test.pypi.org`, which carries no real releases.

**Kev-4B was evaluated and rejected for this host**: it serves only on CUDA, ROCm or Apple MLX, and the RX 5700 (Navi 10 / gfx1010) is outside ROCm's support matrix with 8 GiB against Kev-4B's ~16 GiB floor. Its llama.cpp route is closed too — Kev is a LoRA adapter plus pointer head on Qwen3.5-4B-Base, not a merged model.

> **Accuracy is not Jev's.** On the public 49-task / 869-case benchmark Jev scores 0.966 macro accuracy against Laya-base 0.583, and on large option sets the base checkpoints fall to ~0.43 where Jev holds 0.87. Do not let this gate a destructive decision on its own, and gate on `answer_confidence` fit on your own data — Laya's `confidence` is `1 - normalized entropy`, so a Jev cutoff does not transfer.
