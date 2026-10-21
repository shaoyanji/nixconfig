# eisen — LLM stack architecture, rationale and measurements

Runbook (every command): [`.agents/deploy/hosts/eisen.md`](../.agents/deploy/hosts/eisen.md).
This page is why the stack looks like this and what it measured; it is not a procedure.

---

## Scope
High-core gaming desktop, Sunshine GameStream server, and high-RAM local AI inference host (`Intel Xeon E5-2673 v3`, `64 GiB DDR4`, `AMD Radeon RX 5700 8 GB VRAM`).

**Implementation lives in [`hosts/eisen/llm-server.nix`](../../../hosts/eisen/llm-server.nix) (generative LLM) and [`hosts/eisen/decision-models.nix`](../../../hosts/eisen/decision-models.nix) (Laya, the CPU-only Jev-compatible decision model).** This document is the rationale + operations guide for both.

---

## Hardware Sizing & Memory Topology

| Component | Specification | AI Inference Role |
| :--- | :--- | :--- |
| **CPU** | Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t @ 2.40 GHz, 30MB L3) | AVX2 + FMA3 multi-threaded expert FFN math (`--threads 12`; Kolibri 12 gen / 24 prompt) |
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
- **Threads are split per phase** (`mkCmd { threads = …; threadsBatch = …; }`): generation runs on **12 physical cores** for every model, and Kolibri additionally runs prompt processing on **24** (`--threads-batch`). Measured 2026-10-19 on the patched build (45 GiB GGUF, CPU path because no DRM node): tg128 **9.17 t/s at 12 vs 8.42 at 24**, pp256 **47.41 vs 64.70**. Generation is bandwidth-bound (SMT hurts), prompt processing is compute-bound (SMT helps). Re-run `llama-bench -m /mnt/storage/models/Kolibri-1-Q4_K_M.gguf -t 12 -t 24 -p 256 -n 128 -r 3 -ngl 99 -ot exps=CPU` if the GPU returns.

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
| **Aleph-Alpha Kolibri-1** | 78B / **3.46B** | `Q4_K_M` (44.2 GB) | `kolibri-1`, `kolibri`, `aleph` | German + English MoE (Apache 2.0, ctx up to 262144). Loads via the patched llama.cpp build — see below. |

Larger Kolibri quants exist (`Q3_K_M` ≈ 37.5 GB, `Q5_K_M` split in two parts) but `Q4_K_M` is the best fit for 62 GiB alongside the OS and Steam.

Also evaluated and rejected for this box: dense 32B (`Qwen2.5-Coder-32B`, ~8–14 tok/s — no active-parameter win), `Phi-3.5-MoE-Instruct` (6.6B active, worse RAM/speed tradeoff).

### Kolibri-1 needs a patched llama.cpp (the patch is wired in)

Stock llama.cpp cannot load it:

```
E llama_model_load: error loading model: unknown model architecture: 'kolibri1'
```

`hosts/eisen/llm-server.nix` therefore serves it with `llamaKolibri` — the
`llama-cpp` package with the GGUF card's `kolibri1-llama.cpp.patch` (against
upstream `836d571`) and `-DGGML_VULKAN=ON`. That build **works**: llama-swap logs
`<kolibri-1> Health check passed` (2026-10-17) and the model is listed by
`/v1/models` alongside Qwen.

Caveats: the patch is community code (Seraphiel102 / Hob-forge), so treat output
as "loads and talks" rather than numerically verified against Aleph Alpha, and
`llama-bench` from a stock llama.cpp build cannot read the file (same arch error).
Re-test with:

A completion smoke test is in the runbook: `Deploy & Validate` in
[`.agents/deploy/hosts/eisen.md`](../.agents/deploy/hosts/eisen.md).

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

Decoding is **CPU-bound, not VRAM-bound**: offload is engaged (5.75 GiB of 7.98 GiB resident with the draft head), so the per-token cost is the sparse expert FFN reads from DDR4, not the GPU. Levers: `--threads` (generation stays at 12 for every model; Kolibri's prompt path uses 24, measured 2026-10-19) and a smaller target quant.

> **There is no spare VRAM to shift experts onto the GPU.** An earlier note suggested relaxing `--override-tensor exps=CPU` using ~5 GiB of headroom; that measurement (2.65 GiB) predated the DFlash2 draft head, which now claims most of the free VRAM. Only ~2.2 GiB is unallocated while decoding.

Treat any "35–55 tok/s" figure in older notes as unverified — the measured numbers above are the reference.

---

## GPU off the PCIe bus (no `/dev/dri`)

`0000:05:00.0` (NAVI10 / RX 5700) disappeared between the 2026-10-18 22:22
shutdown and the 2026-10-19 13:43 boot. In the 2026-10-18 21:31 boot it was
healthy — `amdgpu 3.64.0` initialised it, DCN 2.0, 6 planes, `fb0`, and greetd
ran the gamescope session for 50 min. It is now absent from firmware
enumeration (`pci 0000:05:00.0` never appears in dmesg), `/sys/class/drm` holds
only `version`, `/dev/dri` does not exist, and the x16 root port it used
(`0000:00:02.0`) is not exposed at all. `amdgpu` loads only its CPU topology
node, so greetd's greeter exits and gamescope falls back to llvmpipe.

**This is not the build and not OOM**: `journalctl -k` since 2026-10-18 20:00
has no `Out of memory` / `oom-kill` line, and the desktop was running until the
poweroff. `nix.settings.max-jobs = 8` (commit `6d1eaac6`) is the build-side fix
and is live.

A warm reboot, `echo 1 > /sys/bus/pci/rescan` and a link retrain on the CPU root
ports all fail, and the x16 port has no hotplug slot (`Slot-`), so there is no
software power cycle to try either. The link is `Width x0` with `PresDet-`, i.e.
the card is not electrically present. Power the chassis off at the PSU (a
reboot keeps standby power on the slot), check the 8-pin PCIe power, reseat the
card, then power on. Diagnosis: `ls -d /sys/bus/pci/devices/0000:05:00.0`,
`ls /dev/dri`, `journalctl -k -b | grep -c 'pci 0000:05:00.0'` (0 = absent).

**Resolved 2026-10-19 16:43** by exactly that: PSU rocker off, cord out, power
back on. `05:00.0` re-enumerated, `amdgpu` initialised, `/dev/dri/card1` +
`renderD128` appeared, greetd started gamescope and Steam, GPU idle at 37 °C.
`SltSta: PresDet-` is the tell to check first next time.
