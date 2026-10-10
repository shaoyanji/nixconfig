# eisen Deployment & LLM Architecture Handoff

## Scope
High-core gaming desktop, Sunshine GameStream server, and high-RAM local AI inference host (`Intel Xeon E5-2673 v3`, `64 GiB DDR4`, `AMD Radeon RX 5700 8 GB VRAM`).

**Implementation lives in [`hosts/eisen/llm-server.nix`](../../../hosts/eisen/llm-server.nix) (generative LLM) and [`hosts/eisen/decision-models.nix`](../../../hosts/eisen/decision-models.nix) (Laya, the CPU-only Jev-compatible decision model).** This document is the rationale + operations guide for both.

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
| LAN (Laya) | `http://laya.lan/v1/systemone` | nginx `:80` → `127.0.0.1:8090` (vhost `laya.lan`) |
| Tailnet (Laya) | `https://eisen.<tailnet>.ts.net:8443/v1/systemone` | `tailscale serve --bg --https=8443` → `http://127.0.0.1:8090` |

nginx sets `proxy_buffering off` (never buffer SSE token streams) and `proxy_read_timeout/proxy_send_timeout 3600s` (model swaps are slow). `networking.firewall.allowedTCPPorts = [ 80 8080 ]`.

**DNS**: `eisen.lan` is served by frieren's pi-hole via `hosts/frieren/dns.nix` (`misc.dnsmasq_lines`):

```nix
"address=/eisen.lan/100.119.172.99"
"address=/laya.lan/100.119.172.99"
```

Both intentionally resolve to the **tailnet** IP, so the same name works on-LAN and off-LAN. Verify with `dig @100.97.61.65 eisen.lan A` (and `laya.lan`).

> **`.lan` names do not resolve through a host's default resolver** — `getent hosts eisen.lan` and `curl http://eisen.lan/...` fail from both frieren and eisen, while `dig @100.97.61.65 eisen.lan A` answers correctly. This is **pre-existing and fleet-wide**, affects the Qwen endpoint identically, and is *not* caused by the Laya addition. Until it is fixed, address the endpoints by tailnet name + port (`:443` for the LLM, `:8443` for Laya) or with `curl --resolve`.

---

## Decision Model: Laya (`laya.lan`, CPU-only)

A 421M "System One" decision model that answers typed questions about one document and returns **no text** — just calibrated probabilities over options supplied at request time. It implements the same `POST /v1/systemone` contract as TypeSafe's hosted Jev, so a Jev client works by changing the base URL; this fleet has no hosted Jev, which is why it exists here.

Questions come in three shapes: `choice` (n options, `criteria` a label→description map), `score` (ordinal, `criteria` a list of levels), and `noul` (a yes/no probability). Every question in a call is answered in **one** forward pass. `POST /v1/systemone/batch` takes `{states: [...], questions: {...}}` (up to 64 states) and shares forward passes; note it keys on `states`, not `requests` (a wrong key is a plain HTTP 400).

```bash
curl -s http://127.0.0.1:8090/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": {"document": "I was charged twice this month. Please refund the duplicate or I will cancel."},
  "questions": {
    "department": {"type": "choice", "instructions": "Which department should handle this?",
                   "criteria": {"billing": "invoices, payments, refunds", "technical": "bugs and errors"}},
    "urgency": {"type": "score", "instructions": "How urgent is this?",
                "criteria": ["not urgent", "soon", "critical deadline or blocking issue"]},
    "churn_risk": {"type": "noul", "instructions": "Does the user threaten to cancel or leave?"}
  }}'
```

Verified on 2026-10-09 — the state above returns `department: billing` (0.975), `urgency: 1.70` with 0.75 on "critical", `churn_risk: 0.78`, `refund_requested: 0.90`.

**It is CPU-only and needs no gaming guard.** `llama-swap-gaming-guard` deliberately does not manage it: it holds no VRAM, so it keeps answering mid-game, and it co-resides with Qwen instead of competing for the 62 GiB — which is what makes a **qwen + laya offline tandem** possible on this one box. Port 8090 is bound to `127.0.0.1` and is **not** in `allowedTCPPorts`; nginx and `tailscale serve` are the only ways in.

| | |
| :--- | :--- |
| Device / threads | CPU `torch 2.14.1+cpu`, `LAYA_THREADS=12` |
| Measured latency | 4 questions / 274-token state **0.43 s** (12t) · 0.56 s (8t) · 0.98 s (4t) · 3-state batch **0.25 s** |
| RSS | ~3.5 GiB with `english` + `multilingual` resident |
| Preloaded | `english,multilingual`; `typed-decisions` lazy via `LAYA_AUTO_TASK=1` |
| Version | `laya 0.4.1` (venv at `/mnt/storage/decision/laya`); lock at `/mnt/storage/decision/laya-requirements.lock` |

**The venv is built at first boot, not in the store** — `laya` is not in nixpkgs. `eisen-laya-bootstrap.service` writes it once with `uv` and touches `/mnt/storage/decision/.laya-ready` only on success; the guard lives in the script (both the entry point *and* the ready mark must exist), so a deleted venv or a half-finished install is rebuilt on the next boot. Re-bootstrap deliberately with `sudo rm -f /mnt/storage/decision/.laya-ready && sudo systemctl restart eisen-laya-bootstrap`.

Two traps this bootstrap encodes, both of which cost a debugging cycle on 2026-10-09:
1. **`LD_LIBRARY_PATH` must be set in the bootstrap as well as the service.** PyPI's manylinux torch wheel links `libstdc++.so.6`, which NixOS does not ship at `/usr/lib`; the venv installs fine and then the *verification* import fails with `ImportError: libstdc++.so.6: cannot open shared object file`. Both units export `LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib`.
2. **`HOME` must be set explicitly** — a systemd unit with `User=` does not set it and `uv` locates its cache through it.

Do not hand-run `laya-serve`: the declarative unit owns `:8090` (the same rule as `llama-server`/Ollama on `:8080`).

> **Accuracy is not Jev's.** On the public 49-task / 869-case benchmark, Jev scores **0.966** macro accuracy, Laya-base **0.583**, and on large option sets the base checkpoints fall to ~0.43 where Jev holds 0.87. Do not let this gate a destructive decision on its own, and threshold on `answer_confidence` **fit on your own held-out data** — Laya's `confidence` is `1 - normalized entropy`, not Jev's `(n·p_max - 1)/(n - 1)`, so a Jev cutoff does not transfer. Prefer `typed-decisions` for typed workflows.

**Kev-4B was evaluated for this host and rejected** (do not re-litigate it): it serves only on CUDA, ROCm or Apple MLX, and the RX 5700 (Navi 10 / gfx1010) sits outside ROCm's support matrix with 8 GiB VRAM against Kev-4B's ~16 GiB floor. Its llama.cpp route is closed too, because Kev is a LoRA adapter plus pointer head on `Qwen/Qwen3.5-4B-Base` rather than a merged model, and llama.cpp cannot load those artifacts.

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

Laya — service state and both exposure paths (address it by tailnet name; see the `.lan` resolution caveat above):

```bash
ssh eisen 'systemctl is-active laya-serve eisen-laya-bootstrap tailscale-serve-laya'
ssh eisen 'tailscale serve status'   # :443 -> 8080 (qwen), :8443 -> 8090 (laya)

# loopback (on eisen)
curl -s http://127.0.0.1:8090/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": {"document": "billed twice, refund please"},
  "questions": {"dept": {"type": "choice", "instructions": "which team?",
                "criteria": {"billing": "refunds", "tech": "bugs"}}}}'

# tailnet, with a valid cert (no MagicDNS on this tailnet, so pin the address)
curl -s --resolve eisen.cloudforest-kardashev.ts.net:8443:100.119.172.99 \
  https://eisen.cloudforest-kardashev.ts.net:8443/v1/systemone \
  -H 'Content-Type: application/json' \
  -d '{"state":{"document":"billing bug"},"questions":{"q":{"type":"noul","instructions":"is this a bug?"}}}'
```

A healthy bootstrap logs `laya 0.4.1 torch 2.14.1+cpu` and touches `/mnt/storage/decision/.laya-ready`. The first start downloads ~1.5 GiB of checkpoints into `/mnt/storage/decision/hf` (allow ~4 minutes; `TimeoutStartSec = 600`).

### Vulkan / VRAM tuning
`vulkaninfo` is **not** installed. VRAM is observable without it:

```bash
cat /sys/class/drm/card1/device/mem_info_vram_used   # bytes in use
cat /sys/class/drm/card1/device/mem_info_vram_total
```

Watch a load with `journalctl -fu llama-swap`. If a model OOMs, lower `--n-gpu-layers` (e.g. 40) or drop the KV cache to `q4_0`.

---

## Speech: Qwen3-TTS (`tts.lan`)

Offline, OpenAI-compatible text-to-speech. Implementation: [`modules/services/qwen-tts.nix`](../../../modules/services/qwen-tts.nix); enablement + full command reference: [`hosts/eisen/TTS.md`](../../../hosts/eisen/TTS.md).

- Runtime `ServeurpersoCom/qwentts.cpp` (MIT), built from source with `-DGGML_VULKAN=ON`, wrapped around its own OpenAI-compatible `tts-server` (no Python layer).
- Weights `Serveurperso/Qwen3-TTS-GGUF` on `/mnt/storage/tts/models` (talker `qwen-talker-1.7b-customvoice-Q4_K_M.gguf` + codec `qwen-tokenizer-12hz-Q8_0.gguf`), fetched by idempotent oneshot units.
- Loopback `127.0.0.1:8181` (no firewall entry) → `http://tts.lan/v1/audio/speech` (nginx `:80`) and `https://eisen.<tailnet>.ts.net:8444` (`tailscale serve`).

```bash
systemctl status qwen-tts
curl http://127.0.0.1:8181/health
curl -X POST http://127.0.0.1:8181/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"input":"Hello from eisen","voice":"vivian","response_format":"wav"}' -o out.wav
```

**Before first build**, pin the runtime rev + hash in `modules/services/qwen-tts.nix` (the derivation ships `lib.fakeHash` so an unpinned build fails on purpose): `nix-prefetch-git --fetch-submodules https://github.com/ServeurpersoCom/qwentts.cpp.git`.

## Operational Notes

- **Weights are not in the Nix store** — they are multi-GB files in `/mnt/storage/models`, fetched by the units above. Do not `nix-store --gc`-root them; they persist on the btrfs array.
- **Do not hand-run `llama-server` or Ollama** on this host — the declarative `llama-swap` owns `:8080`, and a stray process will make swap failures look like config bugs. The same applies to `laya-serve` on `:8090`.
- **Rebuilds on this host exit 4 and that is not your change.** `home-manager-devji.service` fails because *user*-scope `sops-nix` cannot decrypt (`0 successful groups required, got 0`) — a pre-existing condition since the 2026-09-29 boot. The system generation still switches; verify with `readlink -f /run/current-system` and `systemctl --failed` rather than trusting the exit status.
- **`task infra:deploy:host:eisen`** is the fleet-consistent entrypoint; it wraps the same `nixos-rebuild ... #eisen` switch.
- Model swap latency is real (tens of seconds to minutes for 21–44 GiB off btrfs); `ttl = 900` amortises this for conversational use.
