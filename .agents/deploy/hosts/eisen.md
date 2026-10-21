# eisen Deployment & Operations

Rationale, design and measurements: [`docs/eisen-llm-architecture.md`](../../../docs/eisen-llm-architecture.md).
Every command lives here; that page explains the choices.

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

## Cold starts & `/health` warm-up (read before probing)

Every model endpoint on this host has a cold-start budget, and **on-demand
services wake on a health probe**. Two consequences:

1. **Never poll an on-demand endpoint from a monitor.** A `/health` request opens
   the socket and starts the model, so a 30 s poll loop keeps it resident (or
   worse, stop/starts it every idle period). That covers `:8181` (TTS), `:8090`
   (Laya) and `:8282` (Qwen-Image) — nothing in `services.fleetMonitors` should
   point at them. Poll `qwen-tts.socket`/`laya-serve.socket` state over SSH
   instead if you need liveness.
2. **A 2–5 s probe is not a health check here.** On a socket-activated service
   the TCP connect succeeds immediately (systemd holds the port; the connection
   waits in the backlog), so a client sees "connected" and then times out
   reading. Pass a `--max-time` that covers the cold load.

| Endpoint | Activation | Idle stop | Cold start | Warm command |
| :--- | :--- | :--- | :--- | :--- |
| llama-swap `:8080` (`/v1`) | always listening (gaming guard may stop it) | model unloaded after `ttl=900` | Kolibri ~4–5 min · Qwen ~2–3 min · Bonsai ~1 min | `curl --max-time 600 …/v1/chat/completions` with `"max_tokens": 1` |
| Qwen3-TTS `:8181` | socket | 900 s with no connection | ~15 s | `curl --max-time 60 http://127.0.0.1:8181/health` |
| Laya `:8090` | socket | 900 s with no request | ~40 s | `curl --max-time 90 http://127.0.0.1:8090/health` |
| Qwen-Image `:8282` | socket | 900 s with no request | minutes (HDD, ~12 GB) | `curl --max-time 600 http://127.0.0.1:8282/health` |
| Parakeet `:8091` | always resident | none | ~1 s (loaded at boot) | `curl --max-time 10 http://127.0.0.1:8091/health` |

`GET /v1/models` on llama-swap is **not** a warm-up: it answers from the swap
config without loading any weights.

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
- **On demand.** `qwen-tts.socket` holds `:8181`; the first connection starts the model server on `:8182` through `qwen-tts-proxy` (`systemd-socket-proxyd`), and 900 s with no open connection stops it again. Idle state is `qwen-tts.socket active`, `qwen-tts`/`qwen-tts-proxy` inactive — that is correct, not a failure. The first request after an idle period pays ~15 s of model load.

```bash
systemctl status qwen-tts.socket
systemctl is-active qwen-tts qwen-tts-proxy   # inactive when idle
curl http://127.0.0.1:8181/health            # cold-starts it
curl -X POST http://127.0.0.1:8181/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"input":"Hello from eisen","voice":"vivian","response_format":"wav"}' -o out.wav
```

**Before first build**, pin the runtime rev + hash in `modules/services/qwen-tts.nix` (the derivation ships `lib.fakeHash` so an unpinned build fails on purpose): `nix-prefetch-git --fetch-submodules https://github.com/ServeurpersoCom/qwentts.cpp.git`.

## Speech to text: Parakeet Redux (`/stt`)

Moondream's 1.58-bit ternary export of NVIDIA `parakeet-tdt-0.6b-v3` (600M, 25
languages incl. German), CPU-only ONNX. Implementation:
[`hosts/eisen/parakeet.nix`](../../../hosts/eisen/parakeet.nix) + the vendored
`parakeet-transcribe.py` / `parakeet-server.py`.

```text
LAN:    http://eisen.lan/stt/transcribe   (nginx :80 -> 127.0.0.1:8091)
Direct: http://127.0.0.1:8091/transcribe  (loopback only)
```

`POST /transcribe` takes **raw audio bytes** (any ffmpeg-decodable format) —
multipart/form-data fails. 25 MB cap, 600 s nginx timeouts, response is
`{"text", "duration_seconds", "segments"}`. `/health` answers only after the
ONNX sessions load.

**Deployment state (2026-10-19):** the module landed 2026-10-17 (`507b8b51`),
but the running generation is 2026-10-13, so `parakeet-stt.service` does **not**
exist on the host and nothing listens on `:8091`. The six ONNX files are already
fetched into `/mnt/storage/parakeet` (425 MB), so the first switch needs no
download.

**Audit 2026-10-19:**

- **Fixed:** error responses that do not consume the request body (413 over the
  25 MB cap, 404 on a POST) now set `Connection: close`. With HTTP/1.1
  keep-alive the unread body was parsed as the next request line on the same
  connection.
- **Open — idle cost:** ~1 GB resident forever with no idle stop, while the
  model loads in about a second. It is the cheapest remaining candidate for the
  socket-activation pattern used by TTS/Laya/Qwen-Image.
- **Open — sandbox:** the unit has no `User=`, `NoNewPrivileges`, `ProtectSystem`
  or `MemoryMax`, so audio decoding (ffmpeg demuxers) runs as root. `DynamicUser`
  + `ProtectSystem=strict` + `MemoryMax` would be appropriate.
- **Open — crash loop:** `Restart=always` with no start limit means a missing or
  corrupt ONNX file restarts forever every 5 s instead of failing loudly.
- **Open — no read timeout:** `ThreadingHTTPServer` has no socket timeout, so a
  client that sends a partial body pins a handler thread indefinitely.
- Threads: `--threads 8` onnxruntime intra-op, deliberately below the LLM's
  budget; requests are serialised by a lock, so bursts queue rather than
  oversubscribe the box.

## Operational Notes

- **Build and eval eisen ON eisen, over ssh** (`ssh eisen 'bash -l -c …'`, repo at
  `/Volumes/data/projects/nixconfig`): 24 threads, 59 GiB free, and `inventory.toml`
  allows heavy parallel builds on this host. Never route its closure through frieren
  (11 GiB live NAS with nightly jobs) — the 2026-10-19 attempt to warm there was the
  wrong call even though the heavy derivations were dispatched to nixbuild.net.
- **Weights are not in the Nix store** — they are multi-GB files in `/mnt/storage/models`, fetched by the units above. Do not `nix-store --gc`-root them; they persist on the btrfs array.
- **Do not hand-run `llama-server` or Ollama** on this host — the declarative `llama-swap` owns `:8080`, and a stray process will make swap failures look like config bugs. The same applies to `laya-serve` on `:8090`.
- **Rebuilds on this host exit 4 and that is not your change.** `home-manager-devji.service` fails because *user*-scope `sops-nix` cannot decrypt (`0 successful groups required, got 0`) — a pre-existing condition since the 2026-09-29 boot. The system generation still switches; verify with `readlink -f /run/current-system` and `systemctl --failed` rather than trusting the exit status.
- **`task infra:deploy:host:eisen`** is the fleet-consistent entrypoint; it wraps the same `nixos-rebuild ... #eisen` switch.
- Model swap latency is real (tens of seconds to minutes for 21–44 GiB off btrfs); `ttl = 900` amortises this for conversational use.
