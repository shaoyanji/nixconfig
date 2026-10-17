# eisen — LLM Inference Architecture & Handoff

Detailed architecture specification for running local MoE LLMs on Eisen's Xeon E5-2673 v3 (12c/24t) + 62 GiB DDR4 + AMD Radeon RX 5700 (8 GiB VRAM, **Vulkan/radv** — Navi 10 has no ROCm target).

**Canonical Documentation**: [`.agents/deploy/hosts/eisen.md`](file:///home/devji/Documents/nixconfig/.agents/deploy/hosts/eisen.md)
**Implementation**: [`hosts/eisen/llm-server.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/llm-server.nix) (generative LLM), [`hosts/eisen/decision-models.nix`](file:///home/devji/Documents/nixconfig/hosts/eisen/decision-models.nix) (Laya), [`modules/services/llm-decision-router.nix`](file:///home/devji/Documents/nixconfig/modules/services/llm-decision-router.nix) (router)

Updated **2026-10-17 (final)**. Main tip `7a9b2c70` (union merge: pre-integration lineage + `origin/main`). The old `laya-HANDOFF.md` (a 2026-10-09 verification checklist for a superseded Laya deployment — it still listed Kolibri as blocked and "no hosted Jev") was deleted; the current Laya state is in this doc. The local `~/nixconfig` checkout (behind at `e520abc`) was deleted 2026-10-17 — `~/Documents/nixconfig` is the only live repo.

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

`eisen.lan` resolves to the **tailnet IP** (`100.119.172.99`) via frieren's pi-hole (`hosts/frieren/dns.nix`), so the same name works on and off LAN. `ttl = 900` unloads an idle model so another can load; `healthCheckTimeout = 600` tolerates multi-minute first loads off the HDD.

---

## Models (three, one at a time)

| Model | Aliases | Total / active | Quant | Weights | Engine (llama.cpp variant) | Speed |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kolibri-1** (default) | `kolibri`, `aleph` | 78B / 3.46B | Q4_K_M, 44.2 GiB | `Kolibri-1-Q4_K_M.gguf` | upstream `836d571` + Hob-forge kolibri1 patch | 14.1 tok/s (bench) |
| Qwen3.6-35B-A3B | `qwen` | 35B / ~3B | Q4_K_M, ~21 GiB + DFlash2 drafter | `Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf` | stock `0.7.0` (nixpkgs) | 13.5→19.0 tok/s |
| Bonsai-2-27B | `bonsai` | 27B ternary | PTQ1_0, 5.9 GiB | `Ternary-Bonsai-2-27B-PTQ1_0.gguf` | PrismML fork `3ae4f51` (ternary) | 2.5 tok/s smoke (first gen) |

Shared flags: `--threads 12 --parallel 1 --flash-attn on --jinja --metrics --n-gpu-layers 99 --override-tensor exps=CPU --cache-type-k q8_0 --cache-type-v q8_0`. Bonsai: ctx 16384, `--reasoning-effort medium`. Kolibri + Qwen: ctx 32768. Kolibri also runs `--reasoning-effort low` (`ee61bb1`): a "just say hi" went from 383 output tokens / 57s to 254 / 46s. Kolibri still thinks ~254 tokens for "hi" — 46s is roughly the floor with Kolibri + low effort. If SubZeroClaw needs to be snappy, that's the Qwen argument (shorter think, faster).

Weights live on the 14.6 TB `/mnt/storage` HDD array at `/mnt/storage/models/*.gguf`, kept in place by idempotent fetch units (`ConditionPathExists` + resumable `curl -C -`). They are **not** Nix store paths — never hand-run `llama-server` or Ollama on this host. The gaming guard stops llama-swap when a Steam game runs (frees VRAM).

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

**Default** — for requests with no model, or a `policy:`-prefixed model, the router uses `services.llm-decision-router.defaultModel` (Nix option, default `qwen3.6-35b-a3b`; Eisen sets `kolibri-1` in `hosts/eisen/configuration.nix`). Change it there + rebuild/activate.

**SubZeroClaw** follows the default: its `~/.subzeroclaw/config` sends `request_extra = {"model":"policy:auto", ...}`, so the router normalizes it to the Nix default. To pin SubZeroClaw to a specific model, set `request_extra`'s `model` to that model's id — but the default is the intended path; keep it on `policy:auto`.

**Check which model is loaded**:

```bash
curl -s http://127.0.0.1:8080/v1/models   # status: running / unloaded per model
```

**Cold-load times** (approx, off HDD): Kolibri ~4–5 min, Qwen ~2–3 min, Bonsai ~1 min. A request during a swap waits (llama-swap queues it) or times out: router 110s timeout, SubZeroClaw `--max-time 120`. Switching to a cold model can therefore exceed SubZeroClaw's cap — **pre-warm the model first** (send a request for it, wait for it to load) before running SubZeroClaw. The router does not return a "model loading" 503; fail-fast + retry is the current behavior.

**Concurrency**: one generation slot (router, `--parallel 1` upstream). A second concurrent generation gets `429 {"error":{"code":"llm_busy","message":"LLM generation slot busy; retry later"}}`. A disconnected client frees the slot (slot fix, `76bab63`) — no more 90s slot holds from a dead client.

---

## Router (`llm-decision-router`)

Go binary, port 8000, env-only config. Routes chat → llama-swap, decisions → Jev (cloud, 25s) → Laya fallback.

- **Slot fix** (`76bab63`): releases the generation slot on client disconnect (watcher goroutine + `sync.Once`), so a dead client can't hold the slot while the upstream is stuck.
- **Default model** (`b7fc8af`): `DEFAULT_MODEL` env / `services.llm-decision-router.defaultModel` Nix option (Eisen: `kolibri-1`). The chat handler normalizes missing / `policy:` models to the default.
- **GPU busy check** (`ca0de6e`): `gpuBusy()` stats `GPU_LOCK_FILE` (default `/run/qwen-image/active`); `serveChat` returns **429 `{"error":{"code":"gpu_busy",...}}`** before taking the slot when the image server holds the GPU. LLM wins by not starting, not by killing.
- **Static build**: Nix `buildGoModule` has `env.CGO_ENABLED = 0` (verified 2026-10-17: the Nix-built binary is statically linked, 7.3 MB). Direct build: `CGO_ENABLED=0 go build`.
- **Current state (2026-10-17)**: the router runs as the **Nix system service** `llm-decision-router.service` (port 8000). The transient direct binary (`/tmp/llm-decision-router`, user unit `llm-router-direct.service`) is inactive. Do not start both — both can't hold :8000. The Nix declaration (service + package) is in the flake; the separate-flake declaration is deferred.

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
| Serving | **On-demand** via socket activation (`laya-serve.socket`); idle-stop after 900s of no served requests (`laya-serve-idle.timer`, fires every 5 min). It wakes on the first decision request. Idle-stop after 900s is configured but **not yet directly verified** (still pending). |

**First-request 502 (working behavior, not a bug)**: after idle, Laya's cold start can exceed the router's 25s decision timeout, so the first decision 502s. SubZeroClaw retries and succeeds (Laya is warm by then). Do not "fix" this by lengthening the timeout — fail-fast + retry returns faster than waiting for the full load.

**It needs no gaming guard** and is deliberately excluded from `llama-swap-gaming-guard`: it touches no VRAM, and the calls are short enough that a running game never starves.

`laya` is not in nixpkgs, so the bootstrap unit builds the venv once with uv onto `/mnt/storage` and marks it ready only on success (self-healing: a deleted venv or a half-finished install is retried on the next boot). Python and libstdc++ come from the store and are referenced by the system closure, so the venv's shebangs point at store paths that can never be collected out from under it. The bootstrap overrides the fleet's uv index — `modules/dev.nix` points `pip.index-url` at `test.pypi.org`, which carries no real releases.

**Known tension (flagged, not yet resolved with Joiu)**: Laya runs via a uv venv on `/mnt/storage`, which conflicts with the Nix-only rule (everything declarative in Nix). The code/services are Nix-declared; the venv is the exception.

**Kev-4B — tested, no endpoint (2026-10-17).** The earlier "rejected" note (CUDA/ROCm/MLX-only, LoRA-only) is obsolete: the merged/converted GGUF at `ggml-org/Kev-4B-GGUF` (Apache-2.0) serves natively in stock llama.cpp 0.7.0 (build 11669+) via `POST /v1/systemone` (decision support landed in build 11361). Fetch unit `eisen-llm-kev` pulled `Kev-4B-Q8_0.gguf` (~4.2 GB) into `/mnt/storage/models/`. **Test PASSED** (2026-10-17): stock llama-server on :8092, `POST /v1/systemone` (cancel-threat state + one choice question) returned `offer_discount` (p 0.597, confidence 0.395). Server killed after the test. Per Joiu: Kev gets **NO endpoint** (images get an endpoint; Kev does not). Kev is **NOT wired into the router** (fallback is Laya only). The `decision-picker` skill describes length-based routing as the rule — that overstates the current code; correct the skill or implement the wiring before relying on it. **Correction to the earlier "8,192 tokens / 16x Laya" figure**: that came from the **Kev-0.8b** card, not Kev-4B. Kev-4B's GGUF declares a 262,144-token context, but its **validated decision context is not published** — test on your own long inputs before trusting it. Publisher metrics (unverified): transfer-v4 0.838, breadth-v1 0.69, hard-v1 0.803, devtools-v1 0.756.

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

## Visual Generation: Qwen-Image-2.1 (persistent sd-server, VERIFIED 2026-10-17)

Offline, OpenAI-compatible text-to-image generation. Pipeline: **stable-diffusion.cpp** (leejet) + Qwen-Image-2.1-Turbo weights (designated storage, NOT the store).

```
http://eisen.lan/images/v1/images/generations   (nginx -> 127.0.0.1:8282)
https://eisen.<tailnet>.ts.net:8445/v1/images…  (tailscale serve, oneshot)
```

**Weights** (`/mnt/storage/image/models/`, fetch units `eisen-image-dit/-encoder/-vae/-mmproj`): DiT Turbo Q8_0 (7.12 GiB), encoder Q4_K_M (4.68 GiB), VAE bf16 (0.63 GiB), mmproj F16 (1.08 GiB) — ~14.1 GB total, downloads done 2026-10-17.

**sd.cpp pin**: nixpkgs' `stable-diffusion-cpp` pins commit `656a135` (2026-09-18), predating Qwen-Image 2.1 support. `qwen-image.nix` overrides src to `leejet/stable-diffusion.cpp` rev `f0aac52` (`fetchSubmodules = true` REQUIRED for the ggml submodule).

**Turbo schedule** (fixed, do not override): `--sigmas 1.0,0.978453,0.95418,0.926626,0.89508,0.845148,0.704534,0.414568,0.0` (preset `qwen-image-2.1-turbo`, 8 steps), `--steps 8 --cfg-scale 1.0 --sampling-method euler --offload-to-cpu`. Dims divisible by 32. RGBA transparency is prompt-driven (prefix `This is an RGBA image with transparency. ...`).

**Serving** (persistent, socket-activated): wrapper `qwen-image-server.py` (front-end :8282, `qwen-image.socket`, Accept=false, like Laya; takes systemd's FD via LISTEN_FDS). On first request it claims the GPU: `POST http://127.0.0.1:8080/api/models/unload` on llama-swap (unload failure -> **429**, LLM generation in progress). Then it spawns **sd-server on :8283** (weights stay loaded across generations; HDD load paid once per session) and forwards the OpenAI request. It writes **`/run/qwen-image/active`** while sd-server holds the GPU and touches **`/run/qwen-image/last-request`** per request. `qwen-image-idle.timer` (every 5 min) stops the service after **900s** idle, killing sd-server and freeing the GPU; the socket keeps listening.

**sd-server API facts**: OpenAI `POST /v1/images/generations` accepts ONLY `prompt`, `n`, `size`, `output_format`, `output_compression` (+ native controls only via `<sd_cpp_extra_args>{...}</sd_cpp_extra_args>` embedded in the prompt). Response `data[].b64_json`. **sd-server has NO `/health` (404)** — readiness is `GET /v1/models` (200, id `sd-cpp-local`). Also exposes `/v1/images/edits`, `/sdapi/v1/...`, `/sdcpp/v1/...`. Wrapper exposes text-to-image only; editing flags exist in code but are not exposed via HTTP yet.

**Bugs fixed during the rework**: (1) wrapper killed a still-loading sd-server child on every request -> never healthy (fixed: a live child is waited on, never terminated; cold-load wait 900s); (2) DynamicUser device policy denied `/dev/dri` (fixed: `PrivateDevices = false` + `DeviceAllow` for `/dev/dri/renderD128` + `/dev/dri/card0`, sd-server stderr to the journal); (3) readiness polled `/health` (404) -> fixed to `/v1/models`.

**Verification (2026-10-17)**: first sd-cli one-shot generation ("a lovely cat holding a sign that says hi", 1024x1024) took 719s (cold HDD load + generation), correct 2.28 MB PNG. Persistent sd-server rework verified: same prompt returned a correct 2,280,455-byte PNG (same cat / "hi" sign, full quality); the `active` lock was written while generating; llama-swap was unloaded first. Journal showed two **non-fatal** VAE errors (`wan_vae segment failed`, `vae decode compute failed`) — image unaffected (fallback path); watch whether they recur on the next generation. Generation is still slow (~10 min: cold-ish load + CPU encoder/VAE are the slow parts).

**License (Joiu, 2026-10-17)**: "Qwen research license doesn't matter... I just want the best model in class and it's not commercial uses" — **Turbo stays**. Base alternative (Apache-2.0, 40 steps) is worse/slower; not used.

**GPU sharing**: the router 429s chat (`gpu_busy`) while the image server holds the GPU. The image server 429s if llama-swap can't unload (LLM generation in progress). LLM wins by not starting, not by killing. The image server is deliberately NOT in the llama-swap gaming guard (it claims the GPU on demand, not via llama-swap).

---

## MicroVM SubZeroClaw (canary, VERIFIED 2026-10-17)

SubZeroClaw inside the `frieren-canary` microVM, model on Eisen. Full operating docs: [`hosts/microvms/README.md`](../microvms/README.md) (frieren as the example).

- Guest: `hosts/microvms/frieren-canary.nix` (microvm.nix, cloud-hypervisor/KVM, 2 vCPU, 2 GB RAM, vsock cid 10). Tap `microvm1` on host bridge `microbr`. Guest `192.168.83.10/24`, gateway `192.168.83.1`.
- Guest SubZeroClaw config (activation-script-seeded, unconditional): endpoint `http://192.168.83.1/eisen/v1/chat/completions`, `request_extra = {"model":"policy:auto"}` (router default = Kolibri), `api_key = "none"` (router forwards to Jev -> Jev rejects -> Laya fallback, fine for the hi test; real Jev needs a real key via a secret, never in the repo).
- Endpoint chain: canary -> `http://192.168.83.1/eisen/v1/chat/completions` -> host nginx `/eisen/` -> `/router/` -> router :8000 -> llama-swap/Jev/Laya. On frieren, `/eisen/` proxies to Eisen with **`proxy_set_header Host "eisen.lan"`** (required). On Eisen, `/eisen/` rewrites to `/router/` locally.
- **Proof (2026-10-17, on Eisen)**: canary built, booted, SSH worked, `subzeroclaw "just say hi"` exited 0 with `Hi! 👋`. Decision fell back to Laya as expected. Stopped cleanly. Runtime prerequisites created: `microbr` bridge, `/var/lib/microvms/frieren-canary/` + `ssh-host-keys`, `microvm` system user.
- **Pre-warm Kolibri first** (cold load ~4-5 min can exceed SubZeroClaw's 120s cap).

---

## `.agents/skills/` — audit recommendations (2026-10-17)

Audit of all 32 skills in `.agents/skills/` (read-only, report `~/workspace/skills-audit-2026-10-17.md`). **Counts: 16 KEEP / 15 REWRITE / 1 MERGE.** These are **recommendations, not done work** — the rewrites below are proposals, not applied changes.

**Already done + merged (2026-10-17):**
- `jevdecide`: live `TYPESAFE_API_KEY` deleted + history purged (key rotated by Joiu). Non-REDACTED key count = 0 in every commit touching the file on all branches.
- `agy` version pin removed from skills (7 mentions → "installed version"; Nix-side effective pin is the `llm-agents` flake-lock rev).
- `google-drive` skill deleted entirely (Joiu's call).

**Six new skills built 2026-10-17 (commit `c811602`):** `eisen-status` (stack health), `confirm-before-destructive` (shared policy, audit's #1 defect), `nixos-deploy` (SSH-safe rebuild/activate), `image-generate` (Qwen-Image endpoint + fixed Turbo schedule + RGBA), `decision-picker` (Jev/Laya/Kev-4B table, `/v1/systemone` object shape, confidence caveats; **overstates Kev router wiring** — see Kev section above), `voice-loop` (Parakeet raw-bytes + TTS speakers, `default` invalid).

**REWRITE (13 remaining):** `antigravity` (malformed frontmatter, stale agy 1.2.16 vs installed 1.3.5, every example bakes in `--dangerously-skip-permissions`), `frieren-offload` (core tool `agy-offload` doesn't exist, nightly runners auto-delete `~/HANDOFF.md`/`~/SYSTEM.md`), `crush` (calls nonexistent `terminal()`/`process()`, `--yolo` default contradicts its own warning), `agents` (3/4 sections Legacy with no working invocation, `service-oauth.sh` doesn't exist), `ai-memory` (stale layout — live v3.0.0 uses `~/.local/share/ai-memory`, `:49374`), `home-assistant` (§5 points at `media-stack.nix`, real module is `modules/services/home-assistant.nix`), `bountystash` (pre-push hook asks about the wrong project `cv-resume`), `qmd` (references a `skills` collection that isn't registered + a `jev` skill that doesn't exist), `simplex-admin` (L169 contradicts L97 on the allowlist format, `SIMPLEX_AUTO_ACCEPT` defaults true with no warning), `toon` (`--no-coerce` doesn't exist — real flag `--no-strict`; §2 is a dead macOS path), `officecli` (stub — binary missing, `pkgs.llm-agents.officecli` has zero hits; REWRITE-or-DELETE), `moto` (`moto` SSH alias not defined in `~/.ssh/config` on Eisen), `iventoy` (§4A lists ISO subdirs that don't exist in `/Volumes/data/isos`).

**MERGE (1):** `services` → `infra` (every row routes to `infra:*`/`checks:*`/`dev:*`; fold the alias table into `infra/SKILL.md`, delete `services`). Only hard merge. Redundancy map: `reasonix`/`crush`/`antigravity`/`frieren-offload` overlap on delegation (discriminators first, no bulk merge); `envs`/`dragoncourt`/`serv00` share hosting shape but different hosts (keep per-host split); `wikisearch`/`qmd`/`parallel-cli` are adjacent search (routing lines, no merge); `reasonix`+`stt` duplicate the same `command -v` → `nix shell github:numtide/llm-agents.nix#X` fallback block (extract to one shared snippet).

**Cross-cutting (5 patterns):**
1. **No confirmation policy for destructive actions** (dominant defect). `data:clean:*` deletes, `dev` push/merge/deploy, `dragoncourt`/`envs` push/harden, `serv00` harden/stop/cron-disable, `simplex-admin` sends, `wikisearch` rebuild, `infra` deploy/rollback/GC, `ai-memory reset`, `apps:sync:push`, `bountystash:deploy:prod`, `paste` `pb rm`, `moto:obsidian:sync`, `jevdecide` Trash move — nearly all ungated. `crush` (`--yolo`) and `frieren-offload` (`--dangerously-skip-permissions`) normalize bypassing the prompt. **Fix: one shared rule — confirm before delete / overwrite / send / deploy / push / stop / restart — stated at each destructive step, not delegated to Taskfiles.**
2. **Phantom dependencies** — skills cite binaries/paths/tasks/skills that don't exist (`jev-decide`, `jev`/`email` skills, `officecli` package, `moto` `~/.ssh/config`, `qmd` `skills` collection, `agents` `service-oauth.sh`, `ai-memory` paths, `frieren-offload` `agy-offload`, `antigravity` HANDOFF.md, `toon` archive path, `crush` `terminal()`/`process()`). Fix: a verification gate before a skill ships — every cited binary/path/task must resolve.
3. **Secrets in the wrong place** — live key in `jevdecide` (done); secrets on shell command lines (`google-drive` `client_secret`, `stt` API key); missing token hygiene (`home-assistant`). Fix: secrets only from files/env, never on command lines or in repo files.
4. **Single-session leakage + copy-paste drift** — `antigravity`'s email-cleansing job, `agents`' anecdote, `burgernas`' dated state, `envs`' `alwaysdata` tag, agy version three ways (1.2.9 / 1.2.16 / installed 1.3.5), `home-assistant` §1 vs §5 disagreeing on the defining file. Fix: session/job details go to runbooks, not SKILL.md; single source of truth for versions/paths.
5. **Missing trigger/routing, unstated host scope, frontmatter rot** — no "runs on: X" line (`wikisearch` frieren-only, `simplex-admin` frieren daemon, `apps` `/srv/data` path); overlapping triggers with no discriminator; `related_skills` pointing at nonexistent skills, malformed YAML (`antigravity`), inconsistent frontmatter. Fix: every skill gets first-lines "runs on / use when / pick me over" header; validate frontmatter + cross-refs in a check task.

**KEEP (16, with minor fixes noted in the audit report):** `agent-browser`, `apps`, `burgernas`, `checks`, `data`, `dev`, `dragoncourt`, `envs`, `infra`, `parallel-cli`, `paste`, `pdfvision`, `reasonix`, `serv00`, `stt`, `wikisearch`.

---

## Known state / caveats

- **Eisen's SSH tunnel drops frequently** (broken pipes). Keep SSH calls short; run long jobs via `systemd-run --user` (survives disconnects; `nohup` / `setsid` / `disown` do **not** — Tailscale SSH kills the whole session's processes on disconnect). Never detect a build by `pgrep -f "nixos-rebuild …"` (the pattern self-matches the remote bash wrapper); poll a done-file marker.
- Eisen enforces Tailscale SSH (extra approval per session). `sudo -n` works.
- **Rebuild + activate**: `nixos-rebuild test` builds; if activation fails on polkit over SSH ("requires interactive authentication"), activate the built closure directly: `sudo -n /nix/store/<hash>-nixos-system-eisen-.../bin/switch-to-configuration test`. Use `test`, not `switch` (boot entry unchanged) unless you intend to change the boot entry.
- **One repo**: `~/Documents/nixconfig` (`/Volumes/data/projects/nixconfig`) is the only live repo. The local `~/nixconfig` checkout was deleted 2026-10-17. Do not recreate it — it had unrelated history and caused merge confusion.
- **Frieren is off-limits** (Joiu, 2026-10-17): do not access frieren (it runs the LAN pi-hole/DNS). The frieren-side `/eisen/` proxy change is committed but not activated on frieren — it only matters for a real frieren deployment.
- **Follow-ups (not gating)**: Bonsai `llama-bench` + PQ2_0 bench. Router test hardening (defer-close + longer timeout for the Nix sandbox) for the later separate flake. Router Nix declaration in a separate flake (deferred by Joiu). Kolibri threads 12→24 (identified, not applied). Laya idle-stop (900s) direct verification. Kev→router wiring (not implemented; `decision-picker` skill overstates it). Image editing endpoint (wrapper exposes t2i only). Router `gpu_busy` 429 live test. Watch whether the sd-server VAE errors recur.
