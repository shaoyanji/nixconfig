# eisen — LLM Inference Architecture & Handoff

Detailed architecture specification for running local MoE LLMs on Eisen's Xeon E5-2673 v3 (12c/24t) + 62 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM, **Vulkan/radv** — Navi 10 has no ROCm target).

**Canonical Documentation**: [`.agents/deploy/hosts/eisen.md`](file:///home/devji/Documents/nixconfig/.agents/deploy/hosts/eisen.md)
**Implementation**: [`hosts/eisen/llm-server.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/llm-server.nix) (generative LLM), [`hosts/eisen/decision-models.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/decision-models.nix) (Laya), [`modules/services/llm-decision-router.nix`](file:///home/devji/Documents/nixconfig/modules/services/llm-decision-router.nix) (router)

Updated **2026-10-17**. Merged to main: kolibri, parakeet, serving, bonsai-apply, skills-audit. Main tip `b7fc8af`. The old `laya-HANDOFF.md` (a 2026-10-09 verification checklist for a superseded Laya deployment — it still listed Kolibri as blocked and "no hosted Jev") was deleted; the current Laya state is in this doc.

---

## Serving Topology

One OpenAI-compatible endpoint, **three** models, swapped on demand by `services.llama-swap` (they cannot co-reside: ~21 GiB + ~44 GiB + ~6 GiB = ~71 GiB > 62 GiB RAM).

```
SubZeroClaw ──> router :8000 (llm-decision-router)
                    ├─ /v1/chat/completions ──> llama-swap :8080 ──> llama-server (one child per model, ${PORT})
                    └─ /v1/decisions ──> TypeSafe Jev (cloud, 25s) ──> fallback: local Laya :8090

http://eisen.lan/v1                       (nginx :80 -> 127.0.0.1:8080)
https://eisen.<tailnet>.ts.net/v1         (services.tailscale.serve tcp:443)
http://eisen:8080/v1                      (llama-swap on 0.0.0.0)
```

`eisen.lan` resolves to the **tailnet IP** (`100.119.172.99`) via frieren's pi-hole (`hosts/frieren/dns.nix`), so the same name works on and off LAN. `ttl = 900` unloads an idle model so another can load; `healthCheckTimeout = 600` tolerates multi-minute first loads off btrfs.

---

## Models (three, one at a time)

| Model | Aliases | Total / active | Quant | Weights | Engine (llama.cpp variant) | Speed |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kolibri-1** (default) | `kolibri`, `aleph` | 78B / 3.46B | Q4_K_M, 44.2 GiB | `Kolibri-1-Q4_K_M.gguf` | upstream `836d571` + Hob-forge kolibri1 patch | 14.1 tok/s (bench) |
| Qwen3.6-35B-A3B | `qwen` | 35B / ~3B | Q4_K_M, ~21 GiB + DFlash2 drafter | `Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf` | stock `0.7.0` (nixpkgs) | 13.5→19.0 tok/s |
| Bonsai-2-27B | `bonsai` | 27B ternary | PTQ1_0, 5.9 GiB | `Ternary-Bonsai-2-27B-PTQ1_0.gguf` | PrismML fork `3ae4f51` (ternary) | 2.5 tok/s smoke (first gen) |

Shared flags: `--threads 12 --parallel 1 --flash-attn on --jinja --metrics --n-gpu-layers 99 --override-tensor exps=CPU --cache-type-k q8_0 --cache-type-v q8_0`. Bonsai: ctx 16384, `--reasoning-effort medium`. Kolibri + Qwen: ctx 32768.

Weights live on the 14.6 TB `/mnt/storage` btrfs array at `/mnt/storage/models/*.gguf`, kept in place by idempotent fetch units (`ConditionPathExists` + resumable `curl -C -`). They are **not** Nix store paths — never hand-run `llama-server` or Ollama on this host. The gaming guard stops llama-swap when a Steam game runs (frees VRAM).

**Bonsai bench pending**: a proper `llama-bench` + PQ2_0 bench (the 2.5 tok/s was a 38-token first-gen smoke sample). **Kolibri caveat**: the patch is community code (Seraphiel102 / Hob-forge); treat Kolibri output as "loads and talks", not numerically verified against Aleph Alpha.

### Why three llama.cpp builds (not one)

One build cannot serve all three **today** — each model needs a different llama.cpp variant:

- **Bonsai** needs the PrismML fork: ternary TQ1 weights + ternary kernels. Upstream llama.cpp has no ternary support.
- **Kolibri** needs the Hob-forge kolibri1 patch: the `kolibri1` architecture is not upstream. Stock llama.cpp errors `unknown arch 'kolibri1'`.
- **Qwen** works on stock upstream llama.cpp (Qwen3 MoE is upstream-supported).

Serving is one-at-a-time (llama-swap swaps) because RAM forbids all three loaded (71 > 62 GiB). Kolibri + Qwen alone = 65 > 62.

**Recommendation**: keep the three builds (Nix-managed, disk only). Do **not** merge the Kolibri patch + Prism ternary into one fork — a maintenance trap (you'd own a fork and re-merge on every upstream update, and the patches come from different projects). The lever for fewer builds is dropping a model (e.g. if Kolibri proves strictly better than Qwen, drop Qwen), not merging forks. If upstream ever merges `kolibri1` + ternary, one build would work — not now.

---

## Switching models

**Per-request** — set `"model"` in the chat-completions body to `kolibri-1` (or `kolibri` / `aleph`), `qwen3.6-35b-a3b` (or `qwen`), or `bonsai-2-27b` (or `bonsai`). Aliases work. llama-swap swaps (unloads the current model, loads the requested one).

**Default** — for requests with no model, or a `policy:`-prefixed model, the router uses `services.llm-decision-router.defaultModel` (Nix option, default `qwen3.6-35b-a3b`; Eisen sets `kolibri-1` in `hosts/eisen/configuration.nix`). Change it there + rebuild/activate. For the direct binary (see Router), restart it with `DEFAULT_MODEL=<model>`.

**SubZeroClaw** follows the default: its `~/.subzeroclaw/config` sends `request_extra = {"model":"policy:auto", ...}`, so the router normalizes it to the Nix default. To pin SubZeroClaw to a specific model, set `request_extra`'s `model` to that model's id — but the default is the intended path; keep it on `policy:auto`.

**Check which model is loaded**:

```bash
curl -s http://127.0.0.1:8080/v1/models   # status: running / unloaded per model
```

**Cold-load times** (approx, off btrfs): Kolibri ~4–5 min, Qwen ~2–3 min, Bonsai ~1 min. A request during a swap waits (llama-swap queues it) or times out: router 110s timeout, SubZeroClaw `--max-time 120`. Switching to a cold model can therefore exceed SubZeroClaw's cap — **pre-warm the model first** (send a request for it, wait for it to load) before running SubZeroClaw. The router does not return a "model loading" 503; fail-fast + retry is the current behavior.

**Concurrency**: one generation slot (router, `--parallel 1` upstream). A second concurrent generation gets `429 {"error":{"code":"llm_busy","message":"LLM generation slot busy; retry later"}}`. A disconnected client frees the slot (slot fix, `76bab63`) — no more 90s slot holds from a dead client.

---

## Router (`llm-decision-router`)

Go binary, port 8000, env-only config. Routes chat → llama-swap, decisions → Jev (cloud, 25s) → Laya fallback.

- **Slot fix** (`76bab63`): releases the generation slot on client disconnect (watcher goroutine + `sync.Once`), so a dead client can't hold the slot while the upstream is stuck.
- **Default model** (`b7fc8af`): `DEFAULT_MODEL` env / `services.llm-decision-router.defaultModel` Nix option (Eisen: `kolibri-1`). The chat handler normalizes missing / `policy:` models to the default.
- **Static build**: Nix `buildGoModule` has `env.CGO_ENABLED = 0` (verified 2026-10-17: the Nix-built binary is statically linked, 7.3 MB). The remote builder does **not** run the full C chain for the router. Direct build: `CGO_ENABLED=0 go build`.
- **Current state (2026-10-17)**: the router runs as a **direct binary** (`/tmp/llm-decision-router`, user unit `llm-router-direct.service`, env `DEFAULT_MODEL=kolibri-1`), **not** the Nix system service (which is stopped). The binary is in `/tmp` (ephemeral — it will not survive an Eisen reboot). The Nix declaration (service + package) is in the flake (module + Eisen config) but the service is stopped; the separate-flake declaration is deferred. To restore the Nix service: stop the direct binary first, then `sudo systemctl start llm-decision-router.service` — both can't hold :8000.

---

## Decision Models: Jev (cloud) + Laya (local fallback)

SubZeroClaw's decisions go to the router's `/v1/decisions` → TypeSafe Jev (cloud, `DEFAULT_DECISION_MODEL=jev-latest`, 25s timeout) with fallback to local Laya on Jev failure. The router forwards the client's auth to Jev (it does not hold the key itself).

**Laya** — a 421M "System One" decision model that answers typed questions about one document in a single forward pass and returns no text. It speaks the same `POST /v1/systemone` contract as TypeSafe's hosted Jev, so a Jev client works by changing the base URL.

| | |
| :--- | :--- |
| Question shapes | `choice` (n options) · `score` (ordinal) · `noul` (yes/no probability) |
| Device | **CPU only** (torch `2.14.1+cpu`, `LAYA_THREADS=12`) — holds no VRAM |
| Measured | 4 questions over a 274-token state: **0.43 s** (12 threads), 0.56 s (8), 0.98 s (4); 3-state batch **0.25 s**; RSS ~3.5 GiB |
| Preloaded | `english` + `multilingual`; `typed-decisions` stays lazy (`LAYA_AUTO_TASK=1`) |
| Package | `laya 0.4.1` in a uv venv at `/mnt/storage/decision/laya` |
| Serving | **On-demand** via socket activation (`laya-serve.socket`); idle-stop after 900s of no served requests (`laya-serve-idle.timer`, fires every 5 min). It wakes on the first decision request. |

**First-request 502 (working behavior, not a bug)**: after idle, Laya's cold start can exceed the router's 25s decision timeout, so the first decision 502s. SubZeroClaw retries and succeeds (Laya is warm by then). Do not "fix" this by lengthening the timeout — fail-fast + retry returns faster than waiting for the full load.

**It needs no gaming guard** and is deliberately excluded from `llama-swap-gaming-guard`: it touches no VRAM, and the calls are short enough that a running game never starves.

`laya` is not in nixpkgs, so the bootstrap unit builds the venv once with uv onto `/mnt/storage` and marks it ready only on success (self-healing: a deleted venv or a half-finished install is retried on the next boot). Python and libstdc++ come from the store and are referenced by the system closure, so the venv's shebangs point at store paths that can never be collected out from under it. The bootstrap overrides the fleet's uv index — `modules/dev.nix` points `pip.index-url` at `test.pypi.org`, which carries no real releases.

**Known tension (flagged, not yet resolved with Joiu)**: Laya runs via a uv venv on `/mnt/storage`, which conflicts with the Nix-only rule (everything declarative in Nix). The code/services are Nix-declared; the venv is the exception.

**Kev-4B was evaluated and rejected for this host**: it serves only on CUDA, ROCm or Apple MLX, and the RX 5700 (Navi 10 / gfx1010) is outside ROCm's support matrix with 8 GiB against Kev-4B's ~16 GiB floor. Its llama.cpp route is closed too — Kev is a LoRA adapter plus pointer head on Qwen3.5-4B-Base, not a merged model.

> **Accuracy is not Jev's.** On the public 49-task / 869-case benchmark Jev scores 0.966 macro accuracy against Laya-base 0.583, and on large option sets the base checkpoints fall to ~0.43 where Jev holds 0.87. Do not let this gate a destructive decision on its own, and gate on `answer_confidence` fit on your own data — Laya's `confidence` is `1 - normalized entropy`, so a Jev cutoff does not transfer.

---

## Speech: Parakeet (STT) + Qwen3-TTS

**Parakeet Redux (STT)** — service `parakeet-stt` on 127.0.0.1:8091, nginx merges `/stt/` into the `eisen.lan` vhost (`http://eisen.lan/stt/transcribe`, 600s timeouts, 25 MB cap). **Endpoint contract: POST `/transcribe` takes RAW audio bytes in the request body** (multipart fails — ffmpeg chokes on the MIME body). Weights in `/mnt/storage/parakeet` (six mkFetch units, NOT the store). Code: `hosts/eisen/parakeet.nix` + vendored `parakeet-transcribe.py` (community eschmidbauer/parakeet-redux-onnx export, NOT Moondream-official) + `parakeet-server.py` (stdlib HTTP). CPU-only (RX 5700 has no ROCm, ONNX has no Vulkan path). Real-speech test passed (exact transcription of "The quick brown fox jumps over the lazy dog.", 2.64s). Parakeet gets its own endpoint (not llama-swap — it execs llama-server, Parakeet is ONNX).

**Qwen3-TTS** (`tts.lan`) — offline, OpenAI-compatible text-to-speech alongside the text endpoints, also on the RX 5700 via **Vulkan**. Implementation: [`modules/services/qwen-tts.nix`](../../modules/services/qwen-tts.nix); enablement + commands: [`hosts/eisen/TTS.md`](./TTS.md).

```
http://tts.lan/v1/audio/speech            (nginx :80 -> 127.0.0.1:8181)
https://eisen.<tailnet>.ts.net:8444/…     (tailscale serve)
```

Runtime `ServeurpersoCom/qwentts.cpp` (C++17/GGML, MIT) built from source with `-DGGML_VULKAN=ON`; its own `tts-server` is wrapped (no Python). Weights `Serveurperso/Qwen3-TTS-GGUF` — `qwen-talker-1.7b-customvoice-Q4_K_M.gguf` + `qwen-tokenizer-12hz-Q8_0.gguf` on `/mnt/storage/tts/models`, fetched by idempotent oneshot units. Named voices: `vivian` (default), `serena`, `uncle_fu`, `ryan`, `aiden`, `ono_anna`, `sohee`, `eric`, `dylan`; zero-shot cloning registers via the runtime's voice registry. Loopback-only `:8181`, exposed through nginx and `tailscale serve` — never in the firewall. Note: `default` is not a valid speaker (errors `unknown speaker 'default'`) — use `aiden`.

---

## Visual Generation & Editing: Qwen-Image-2.1 (`image.lan`)

Offline, OpenAI-compatible text-to-image generation and complex image editing (local inpainting, expanding, object extraction, and native RGBA transparency), tailored for Eisen's **Xeon E5-2673 v3 (12c/24t) + 62 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM, Vulkan/radv)**.

```
http://image.eisen.lan/v1/images/generations   (nginx :80 -> 127.0.0.1:8282)
https://eisen.<tailnet>.ts.net:8445/v1/images… (tailscale serve)
```

### 1. Model Architecture & Selection
* **Architecture**: Unified multimodal generative model pairing a **7B Single-Stream Diffusion Transformer (DiT)** (32 layers) with a **Qwen3-VL 8B text encoder** (~15B total parameter pipeline).
* **Champion Checkpoint**: **`Qwen-Image-2.1-Turbo`** (October 2026 release).
  - *Why Turbo*: Replaces the base model's 40-step diffusion loop with an accelerated **8-step denoising schedule** while retaining 2K resolution, multi-image identity reference conditioning (up to 10 images), and alpha transparency. Crucial for acceptable latency on Eisen's compute budget without high-end data-center GPUs.

### 2. Compute & Memory Topology on Eisen
* **RAM / VRAM Split**:
  - Full FP16 weights require ~30 GiB. Quantized INT8 / INT4 weights (or Diffusers NF4 / GGUF) require ~9–12 GiB.
  - **Xeon + 62 GiB DDR4**: Holds the text encoder (Qwen3-VL 8B) and primary tensor staging in RAM, keeping CPU memory pressure well within the 62 GiB boundary.
  - **RX 5700 (8 GB GDDR6, Vulkan/radv)**: Navi 10 has no ROCm target, so compute offload utilizes Vulkan (`GGML_VULKAN` or DirectML/ZLUDA) with sequential layer offloading.
* **Gaming Guard & Text LLM Coordination**:
  - **GPU Contention**: Unlike Laya (which is pure CPU), Qwen-Image claims the RX 5700 GPU. It **must** integrate into `llama-swap-gaming-guard` to yield immediately when Steam Big Picture or Sunshine streaming activates.
  - **Swapping with Qwen3.6-35B**: Because Qwen3.6-35B allocates the full 8 GB VRAM for non-expert tensors, concurrent GPU execution with Qwen-Image will trigger OOM. `services.llama-swap` or a unified model router must swap between text inference and image generation on demand.

### 3. Storage & Deployment Paths
* **Storage Location**: `/mnt/storage/image/models/` on the 14.6 TB btrfs array.
* **Fetch Automation**: Idempotent systemd oneshot units (`eisen-image-models.service`) downloading model checkpoints via resumable `curl -C -` guarded by `ConditionPathExists`.
* **Runtime Packaging**: Managed via a Python/uv venv under `/mnt/storage/image/venv` (or native C++/GGML wrapper when upstream GGML DiT support lands), with store-pinned Python and Vulkan libraries.

### 4. Next-Session Activation Checklist (When Eisen Powers On)
1. Verify network reachability: `ping -c 3 192.168.3.87` (or tailnet `100.119.172.99`).
2. SSH to Eisen: `ssh eisen`.
3. Check btrfs pool space: `df -h /mnt/storage`.
4. Materialize `/mnt/storage/image/models` and test checkpoint download.
5. Benchmark 8-step generation latency on RX 5700 Vulkan vs CPU 12-thread baseline.
6. Wire reverse proxy and tailscale serve port `:8445`.

---

## Known state / caveats

- **Eisen's SSH tunnel drops frequently** (broken pipes). Keep SSH calls short; run long jobs via `systemd-run --user` (survives disconnects; `nohup` / `setsid` / `disown` do **not** — Tailscale SSH kills the whole session's processes on disconnect). Never detect a build by `pgrep -f "nixos-rebuild …"` (the pattern self-matches the remote bash wrapper); poll a done-file marker.
- Eisen enforces Tailscale SSH (extra approval per session). `sudo -n` works.
- **Rebuild + activate**: `nixos-rebuild test` builds; if activation fails on polkit over SSH ("requires interactive authentication"), activate the built closure directly: `sudo -n /nix/store/<hash>-nixos-system-eisen-.../bin/switch-to-configuration test`. Use `test`, not `switch` (boot entry unchanged) unless you intend to change the boot entry.
- **Two checkouts on Eisen**: the working repo is `~/Documents/nixconfig` (main `b7fc8af`, all merges + fixes). The `~/nixconfig` checkout is behind (`e520abc`, pre-merge). Push to origin, then pull in `~/nixconfig`.
- **Follow-ups (not gating)**: Bonsai `llama-bench` + PQ2_0 bench. Router test hardening (defer-close + longer timeout for the Nix sandbox) for the later separate flake. Router Nix declaration in a separate flake (deferred by Joiu).
