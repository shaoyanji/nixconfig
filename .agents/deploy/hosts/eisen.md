# eisen Deployment & LLM Architecture Handoff

## Scope
High-core gaming desktop, Sunshine GameStream server, and high-RAM local AI inference host (`Intel Xeon E5-2673 v3`, `64 GiB DDR4`, `AMD Radeon RX 5700 8 GB VRAM`).

**Implementation lives in [`hosts/eisen/llm-server.nix`](../../../hosts/eisen/llm-server.nix).** This document is the rationale + operations guide for it.

---

## Hardware Sizing & Memory Topology

| Component | Specification | AI Inference Role |
| :--- | :--- | :--- |
| **CPU** | Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t @ 2.40 GHz, 30MB L3) | AVX2 + FMA3 multi-threaded expert FFN math (`--threads 12`) |
| **RAM** | **62 GiB DDR4 Quad-Channel** + 31 GiB swap | Holds the resident MoE expert pool; the binding constraint for model sizing |
| **GPU** | **AMD Radeon RX 5700** (Navi 10, **8 GB GDDR6**, PCIe 4.0 x16, radv **Vulkan**) | Attention/norms/gate + q8_0 KV cache (`--n-gpu-layers 99`) |
| **Storage** | 119 GB NVMe (`/`, `/nix`, `/persist`) + 931 GB btrfs `/mnt/steam` + **14.6 TB btrfs `/mnt/storage`** | Model repository at `/mnt/storage/models/*.gguf` |
| **Network** | Gigabit LAN `192.168.3.76` (DHCP, `enp9s0`) + Tailscale `100.119.172.99` | Serves a fleet-wide OpenAI-compatible API |

> **No ROCm.** Navi 10 (gfx1010) is not a ROCm-supported target; Vulkan/radv is the supported compute path on this card.

---

## Serving Design: `llama-swap` in front of native `llama-server`

**Why `llama-swap` instead of plain `services.llama-cpp`?** The two models cannot co-reside in 62 GiB (21 GiB + 44 GiB > 62 GiB). `llama-swap` exposes **one** OpenAI-compatible endpoint (`:8080`) and starts/unloads a `llama-server` child per requested model, so the fleet never has to know which model is currently resident.

```
client ──> nginx :80 (eisen.lan)          ─┐
       ──> tailscale serve tcp:443         ├─> llama-swap :8080 ──> llama-server (per model, ${PORT})
       ──> http://eisen:8080               ─┘
```

- `services.llama-swap.listenAddress = "0.0.0.0"`, `port = 8080`.
- `settings.healthCheckTimeout = 600` — first load of a 21–44 GiB GGUF off btrfs takes minutes.
- `settings.ttl = 900` — idle model is unloaded so the next swap has the RAM to load the other.
- `settings.models.<name>.cmd` carries the full `llama-server` invocation; **`${PORT}` is substituted by llama-swap** with a free port per child.
- Server aliases: `qwen3.6-35b-a3b` (+ `qwen`), `kolibri-1` (+ `kolibri`, `aleph`).

### Engine

```nix
llama = pkgs.llama-cpp.override { vulkanSupport = true; };   # cached in the binary cache
```

Shared per-model flags:

```
--host 127.0.0.1 --port ${PORT} --threads 12 --ctx-size 32768
--flash-attn on --jinja --metrics --n-gpu-layers 99
--override-tensor exps=CPU --cache-type-k q8_0 --cache-type-v q8_0
```

- **`--n-gpu-layers 99`** moves every non-expert tensor (attention, norms, embeddings, router/gate) into the 8 GiB VRAM.
- **`--override-tensor exps=CPU`** keeps the sparse expert FFN tensors in DDR4, so only the ~3B active parameters per token touch the GPU.
- **`q8_0` KV cache + `--flash-attn on`** keep the attention working set inside 8 GiB.
- **`--jinja`** is required for the models' tool-call / chat templates.

### Speculative Decoding (Qwen only, measured)

`qwen3.6-35b-a3b` runs with a **DFlash2** block-diffusion draft head (`aminya/Qwen3.6-35B-A3B-DFlash2-GGUF`, Q8_0, 570 MB) fully resident in VRAM:

```
--spec-draft-model /mnt/storage/models/Qwen3.6-35B-A3B-DFlash2-Q8_0.gguf
--spec-type draft-dflash --spec-draft-n-max 7 --spec-draft-ngl 99
```

Same prompt, same base flags, 256-token generation, measured on eisen:

| Speculation | tok/s | vs baseline |
| :--- | ---: | ---: |
| none (baseline) | 13.54 | — |
| `draft-dflash` (README defaults) | 18.38 | **+36%** |
| `draft-dflash` + `--spec-draft-ngl 99` | **19.02** | **+40%** |

Draft acceptance 196/408 tokens (48%). Through the deployed API the same run measures **18.0 tok/s**, so the gain survives the llama-swap/nginx layer.

What does **not** work here — recorded so it is not re-litigated:

- **No small Qwen3 draft (0.6B/1.7B/4B) can be used.** Qwen3.6's tokenizer is **248,320** tokens vs Qwen3's ~152k, so llama.cpp refuses the pair (`tokenizer.json` 12,807,982 B / sha `5f9e4d49…` vs 11,422,654 B / sha `aeb13307…`). Qwen3.6-35B-A3B has no small dense sibling at all.
- **n-gram speculation is a wash on this workload:** `ngram-simple` 13.79, `ngram-map-k4v` 13.52, `ngram-cache` 12.54 tok/s against a 13.76 baseline — free-form reasoning and code leave it nothing to copy.
- **Kolibri-1 has no draft head**, so it runs at the plain baseline rate.

### Model Weights (fetched, not vendored)

Both GGUFs live on the persistent `/mnt/storage` array and are fetched by two idempotent, resumable oneshot units:

| Unit | File | Bytes | Source |
| :--- | :--- | ---: | :--- |
| `eisen-llm-qwen` | `Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf` | 22,285,080,192 | `bartowski/Qwen_Qwen3.6-35B-A3B-GGUF` |
| `eisen-llm-kolibri` | `Kolibri-1-Q4_K_M.gguf` | 47,454,113,472 | `Hob-forge/Kolibri-1-GGUF` |
| `eisen-llm-dflash` | `Qwen3.6-35B-A3B-DFlash2-Q8_0.gguf` | 570,468,544 | `aminya/Qwen3.6-35B-A3B-DFlash2-GGUF` (Qwen's draft head) |

Both use `unitConfig.ConditionPathExists = "!<file>"` and `curl -fL --retry 5 -C -` into `<file>.part`, then `mv` into place — so they no-op once the weights exist and resume a partial `.part` if interrupted. `llama-swap` is ordered `after`/`wants` both units plus `mnt-storage.mount`.

`systemd.tmpfiles.rules` creates `/mnt/storage/models` (`0755 devji users`).

---

## Model Roster

| Model | Total / Active | Quant | Aliases | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 🌟 **Qwen3.6-35B-A3B** | 35B / **~3B** | `Q4_K_M` (22.5 GB) | `qwen3.6-35b-a3b`, `qwen` | Primary champion: 2026 agentic coding/thinking-preservation MoE. Whole expert pool fits with ~40 GiB RAM to spare. |
| **Aleph-Alpha Kolibri-1** | 78B / **3.46B** | `Q4_K_M` (44.2 GB) | `kolibri-1`, `kolibri`, `aleph` | German + English MoE (Apache 2.0, ctx up to 262144). Wired up and installed, but **not yet loadable — see below**. |

Larger Kolibri quants exist (`Q3_K_M` ≈ 37.5 GB, `Q5_K_M` split in two parts) but `Q4_K_M` is the best fit for 62 GiB alongside the OS and Steam.

Also evaluated and rejected for this box: dense 32B (`Qwen2.5-Coder-32B`, ~8–14 tok/s — no active-parameter win), `Phi-3.5-MoE-Instruct` (6.6B active, worse RAM/speed tradeoff).

### Kolibri-1 is blocked on llama.cpp, not on this configuration

Weights, fetch unit, aliases and the llama-swap entry are all in place and correct, but **stock llama.cpp cannot load it**:

```
E llama_model_load: error loading model: unknown model architecture: 'kolibri1'
```

so a request for the `kolibri` alias fails with HTTP 500 in ~0.4 s (`llama-swap: upstream command exited prematurely`).

This is an upstream gap, not a misconfiguration: the GGUF card states outright that stock llama.cpp does not support the `kolibri1` architecture yet and ships `kolibri1-llama.cpp.patch` (against upstream `836d571`); Ollama and LM Studio are in the same position. To enable it, build `llama-cpp` with that patch (an overlay/override carrying the patch), then re-test:

```bash
curl -s http://eisen.lan/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"kolibri","messages":[{"role":"user","content":"Sag hallo."}]}'
```

Until then use `qwen`. Note the 44 GiB Kolibri GGUF is already resident on `/mnt/storage` holding space for a model that cannot load yet — worth deleting if that space is needed before llama.cpp catches up.

---

## Exposure

| Path | URL | Mechanism |
| :--- | :--- | :--- |
| LAN | `http://eisen.lan/v1` | nginx `:80` → `127.0.0.1:8080` (`serverAliases = [ "eisen" "192.168.3.76" ]`) |
| Tailnet | `https://eisen.<tailnet>.ts.net/v1` | `services.tailscale.serve`, `endpoints."tcp:443"` → `http://127.0.0.1:8080` |
| Direct | `http://eisen:8080/v1` | llama-swap listening on `0.0.0.0` |

nginx sets `proxy_buffering off` (never buffer SSE token streams) and `proxy_read_timeout/proxy_send_timeout 3600s` (model swaps are slow). `networking.firewall.allowedTCPPorts = [ 80 8080 ]`.

**DNS**: `eisen.lan` is served by frieren's pi-hole via `hosts/frieren/dns.nix` (`misc.dnsmasq_lines`):

```nix
"address=/eisen.lan/100.119.172.99"
```

It intentionally resolves to the **tailnet** IP, so the same name works on-LAN and off-LAN. Verify with `dig @100.97.61.65 eisen.lan A`.

---

## Gaming Coexistence (auto-yield)

eisen is a gaming desktop first, so `llama-swap-gaming-guard.service` **stops `llama-swap` while a Steam game is running** and restarts it when the game exits. That returns the model's RAM (21 GiB Qwen / 44 GiB Kolibri) and, measured with Qwen loaded, **5,367 MiB of the 8 GiB VRAM** to the game — a model left resident would hold roughly two-thirds of the GPU while the game fights it for the rest. While yielded, the API answers connection-refused rather than that half-starved state.

A game is detected as **any process whose executable lives under a Steam library's `steamapps/common/`** (covers native, Proton and SteamLinuxRuntime-container games alike). Gamescope and `gamescopereaper` are deliberately **not** used as signals — both run permanently here (the Steam tenfoot kiosk session), so they would suspend the LLM forever.

Verified on 2026-10-09: no false positive with Steam idle and the full game library installed, and a simulated game (a binary run from `steamapps/common/`) made the guard log `game detected - yielding, stopping llama-swap` and stop the unit within ~15 s, then resume it on exit.

---

## Measured Performance (2026-10-09, generation 10)

First real completions after the initial switch, all served through the declarative stack (llama-swap → nginx / tailscale serve):

| Metric | Value |
| :--- | :--- |
| Cold request (includes loading the 20.8 GiB GGUF) | **2m 00s** |
| Warm request, same model | **1.2–1.4 s** |
| Steady-state decode, Qwen3.6-35B-A3B Q4_K_M | **12.7–13.8 tok/s** (18.0 with DFlash2) |
| Prompt processing | 14–30 tok/s |
| GPU VRAM in use while decoding | **5.75 GiB of 7.98 GiB** (2.65 GiB without the draft head) |

Decoding is **CPU-bound, not VRAM-bound**: offload is engaged (5.75 GiB of 7.98 GiB resident with the draft head), so the per-token cost is the sparse expert FFN reads from DDR4, not the GPU. Remaining levers, in order of effort: raise `--threads` toward 24, or move to a smaller target quant.

> **There is no spare VRAM to shift experts onto the GPU.** An earlier note suggested relaxing `--override-tensor exps=CPU` using ~5 GiB of headroom; that measurement (2.65 GiB) predated the DFlash2 draft head, which now claims most of the free VRAM. Only ~2.2 GiB is unallocated while decoding.

Treat any "35–55 tok/s" figure in older notes as unverified — the measured numbers above are the reference.

---

## Fleet Client Integration

Point any OpenAI-compatible client at `http://eisen.lan/v1` (LAN/tailnet) with model `qwen` or `kolibri`.

### `mods` (`~/.config/mods/mods.yml`)
```yaml
eisen:
  base-url: http://eisen.lan/v1
  api-key: none
  models:
    qwen:
      aliases: ["qwen", "eisen"]
      max-tokens: 8192
    kolibri:
      aliases: ["aleph"]
      max-tokens: 8192
```

### `aichat` (`~/.config/aichat/config.yaml`)
```yaml
- type: openai-compatible
  name: eisen
  api_base: http://eisen.lan/v1
  models:
    - name: qwen
    - name: kolibri
```

### Agent CLIs
```bash
export OPENAI_BASE_URL="http://eisen.lan/v1"
export OPENAI_API_KEY="none"
```

---

## Deploy & Validate

```bash
# from the repo (dirty tree is fine; activation needs the secrets submodule)
ssh eisen 'cd ~/Documents/nixconfig && sudo nixos-rebuild switch --flake ".?submodules=1#eisen"'

# service state
ssh eisen 'systemctl status llama-swap nginx eisen-llm-qwen eisen-llm-kolibri'

# endpoint reachability (all three paths)
curl -s http://eisen.lan/v1/models | jq -r '.data[].id'
curl -s http://192.168.3.76/v1/models | jq -r '.data[].id'
ssh eisen 'tailscale serve status'

# a real completion (first call loads the weights — allow minutes)
curl -s http://eisen.lan/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Say hi in one word."}]}' | jq -r '.choices[0].message.content'

# confirm the swap actually happened
curl -s http://eisen.lan/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"kolibri","messages":[{"role":"user","content":"Sag hallo."}]}' | jq -r '.choices[0].message.content'
```

### Vulkan / VRAM tuning
`vulkaninfo` is **not** installed. VRAM is observable without it:

```bash
cat /sys/class/drm/card1/device/mem_info_vram_used   # bytes in use
cat /sys/class/drm/card1/device/mem_info_vram_total
```

Watch a load with `journalctl -fu llama-swap`. If a model OOMs, lower `--n-gpu-layers` (e.g. 40) or drop the KV cache to `q4_0`.

---

## Operational Notes

- **Weights are not in the Nix store** — they are multi-GB files in `/mnt/storage/models`, fetched by the units above. Do not `nix-store --gc`-root them; they persist on the btrfs array.
- **Do not hand-run `llama-server` or Ollama** on this host — the declarative `llama-swap` owns `:8080`, and a stray process will make swap failures look like config bugs.
- **`task infra:deploy:host:eisen`** is the fleet-consistent entrypoint; it wraps the same `nixos-rebuild ... #eisen` switch.
- Model swap latency is real (tens of seconds to minutes for 21–44 GiB off btrfs); `ttl = 900` amortises this for conversational use.
