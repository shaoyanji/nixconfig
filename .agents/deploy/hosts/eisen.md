# eisen deployment & operations

Rationale, design and measurements: [`docs/eisen-llm-architecture.md`](../../../docs/eisen-llm-architecture.md).
Every command lives here; that page explains the choices.

---

## Exposure

| Path | URL | Mechanism |
| :--- | :--- | :--- |
| LAN | `http://eisen.lan/v1` | nginx `:80` → `127.0.0.1:8080` (`serverAliases = [ "eisen" "192.168.3.91" ]`) |
| Tailnet | `https://eisen.<tailnet>.ts.net/v1` | `services.tailscale.serve`, `endpoints."tcp:443"` → `http://127.0.0.1:8080` |
| Direct | `http://eisen:8080/v1` | llama-swap listening on `0.0.0.0` |
| LAN (Laya) | `http://laya.lan/v1/systemone` | nginx `:80` → `127.0.0.1:8090` (vhost `laya.lan`) |
| Tailnet (Laya) | `https://eisen.<tailnet>.ts.net:8443/v1/systemone` | `tailscale serve --bg --https=8443` → `http://127.0.0.1:8090` |

nginx sets `proxy_buffering off` (never buffer SSE token streams) and `proxy_read_timeout/proxy_send_timeout 3600s` (model swaps are slow). `networking.firewall.allowedTCPPorts = [ 80 8080 ]`.

> **The LAN address is DHCP and it drifts.** It moved from `192.168.3.76` to
> `192.168.3.91` (found 2026-11-03), which left this page and the nginx `serverAliases` stale while
> `inventory.toml` was already right. Read the live value from the compiled inventory before trusting
> any address below — `nix eval --raw .#inventory.hosts.eisen.network.lan_ip` (0.15 s, no host eval) —
> or address the host by name (`eisen.lan`, tailnet) and let DNS move with it. A DHCP reservation is
> the durable fix; hand-editing an alias is not.

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

## Fleet client integration

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

## Deploy & validate

```bash
# from the repo (dirty tree is fine; activation needs the secrets submodule)
ssh eisen 'cd ~/Documents/nixconfig && sudo nixos-rebuild switch --flake ".?submodules=1#eisen"'

# service state
ssh eisen 'systemctl status llama-swap nginx eisen-llm-qwen eisen-llm-kolibri'

# endpoint reachability (all three paths)
curl -s http://eisen.lan/v1/models | jq -r '.data[].id'
curl -s http://192.168.3.91/v1/models | jq -r '.data[].id'
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

## Speech to text: Parakeet redux (`/stt`)

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

**Deployment state (2026-10-19):** the module landed 2026-10-17 (`6578c91b`),
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

## Boot personas: gaming desktop (default) and `server`

The default generation is the gamescope kiosk: greetd auto-logs devji into
`steam-gamescope` and there is no desktop shell and no login screen (since
2026-11-12; the Dux-on-niri desktop before it is gone). `hosts/eisen/server.nix` is
`specialisation.server`: the same system with the whole display stack subtracted —
no greetd, no compositor, no gamescope, no Steam, no Sunshine, no gaming guard, and
no `video=HDMI-A-1:1920x1080@60` (that mode exists only so gamescope has a known
output; the persona writes to the console and does not care whether anything is
plugged in). It exists because the kiosk holds ~450–500 MiB of VRAM at idle
(`hosts/eisen/MANUAL.md` §3) and several GiB of RAM that an mmapped expert arena
would rather have as page cache.

Both toplevels are built and shipped inside one generation, so the persona needs no
separate rebuild:

```bash
# at the power button: systemd-boot lists "NixOS - Configuration <n> - specialisation server"
bootctl list | grep -i specialisation

# live, without a reboot (switches /run/current-system to the specialisation)
sudo /run/current-system/specialisation/server/bin/switch-to-configuration switch

# back to the gaming desktop: the *profile* still points at the base toplevel
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Three things that bite:

- **A specialisation is boot-time state, not profile state.** Activating one leaves
  `/nix/var/nix/profiles/system` on the base config, which is what makes the switch
  back a one-liner. A reboot boots the *base* entry unless you pick the
  specialisation again; make it sticky with `sudo bootctl set-default <entry-id>`
  from `bootctl list`.
- **`nixos-rebuild` as root cannot evaluate this flake** (2026-11-03: dirty git dir
  owned by `devji`). Build as `devji`, stage as root:
  `nixos-rebuild build --flake .#eisen` → `sudo nix-env -p /nix/var/nix/profiles/system --set ./result`
  → `sudo ./result/bin/switch-to-configuration boot`. The boot entries (base *and*
  specialisation) come from that last step.
- **The persona cannot be flipped by editing the running generation.** Any change to
  `server.nix` needs a build and a switch/boot to stage it, like any other.

**What the persona does and does not buy (measured 2026-11-04).** It is worth
using for a benchmark — it is the same `strata.service`, same ExecStart, same
config, so the only variable is the desktop — but it does not close a page-cache
gap: at IQ3_XXS the chat-decode median was 12.2 tok/s on the desktop and 10.4 on
`server`. It also does not rescue that tier: the agent-suite turn 0 was lost in
both personas, and at IQ2_XS too, while IQ1_M finished the same suite. Size, not
the desktop, is the variable. Numbers: `hosts/eisen/MANUAL.md` §7.

### Retesting a larger tier (IQ2_XS / IQ3_XXS)

Both are blocked by an engine abort, not by memory, and neither short lever works:

- **`--no-ple` is refused.** `--native requires --ple-gguf (the PLE key is native
too)` — the PLE table lives inside the native shard, so there is no ~28 GB piece to
  drop. Passing `--no-ple` next to `--native` exits 2 at load with that message.
- **A smaller context does not help — it makes it worse.** IQ2_XS at
  `--max-context 16384` loaded fine (636 MiB VRAM free, 50.9 GB RSS) and aborted on
  the *4K prompt* stage after ~7k tokens of chat traffic with `exit code -6`. The
  served pack at 16384 stalls the same way: all three 2026-11-04 agent runs lost
  the engine at turn 3 of 6, `no progress for 60 s during a request (reading the
  prompt (batched): layer 1 of the prompt chunk from token 9076)` — the engine's
  own guard, [upstream #5229](https://github.com/Niko1221/Strata/issues/5229), now
  filed with the repro, the numbers and the build fingerprint. It fires during
  **prefill** at ~9k–16k prompt tokens, at 32768 too, so it is one engine bug and
  not a property of the tier.
  The served config is therefore back at `--max-context 32768`; do not "save KV"
  by lowering it while this is open.

To measure a tier without touching the generation, run it as a transient unit
beside the real one (stop `strata` first — both want `:8085`):

```bash
FHS=/nix/store/*-strata-fhs/bin/strata-fhs     # from `systemctl cat strata`
sudo systemctl stop strata
sudo systemd-run --unit=strata-probe --property=User=devji --property=Group=users \
  --property=SupplementaryGroups="video render" --property=WorkingDirectory=/mnt/storage/strata \
  --property=LimitCORE=0 --property=StandardOutput=append:/mnt/storage/strata/probe.out \
  -E ROCR_VISIBLE_DEVICES=0 -E HIP_VISIBLE_DEVICES=0 -E "STRATA_ALLOWED_HOSTS=*" \
  $FHS -c 'source /mnt/storage/strata/.venv/bin/activate && python -m serve.server \
    --engine strata --config /mnt/storage/strata/strata-coder-iq2_xs.json --port 8085'
```

Read the RSS with `systemctl show strata-probe -p MemoryCurrent`, then run the
suite **inside the FHS env** — `.venv/bin/python` is dynamically linked and exits
127 with the NixOS stub-ld message on its own:

```bash
$FHS -c 'source /mnt/storage/strata/.venv/bin/activate && python \
  tools/strata_bench.py --url http://127.0.0.1:8085'
```

Finish with `sudo systemctl stop strata-probe && sudo systemctl start strata`.

**What upstream already knows (checked 2026-11-04).** Our engine is `0.1.46.2`;
public Strata 0.2.10 ships engine **0.1.56**, so ten point releases are untested here.
The family is tracked, not novel: #3807 reports the same guard on 0.1.46/0.1.47 and
names the silent respawn as the thing that hides it; #4566 is the gfx10
batched-prefill thread. Its 2026-11-03 comment (same Coder IQ1_M pack, gfx1031)
reports a working mitigation on 0.1.56 — **`--adapt-swaps 0` plus
`STRATA_VERIFY_COHERENT=1`** — after a `verify: timed out at layer 37` variant. That
was a verify-path stall, ours is inside a batched chunk read, so test it rather
than assume it: one flag pair, the same suite, and the stall sites tell you.

**DFlash2 does not apply to this card.** 0.2.10 makes DFlash2 the default drafter
for Qwen3.8 on CUDA 8.6/8.9/12.0/12.1, Radeon gfx1100/gfx1151/gfx1201, Metal and
Arc — gfx1010 is not in that list, so MTP stays the drafter here.

## DeepSeek-V4-Flash 284B (evening copy + benchmark)

Procedure: [`docs/deepseek-v4-flash.md`](../../../docs/deepseek-v4-flash.md) — the LAN copy from
frieren's aria2 job, the publisher-hash check, the `server` persona, the transient probe and the
measurement. Open question: `AGENTS.nix` note `deepseek-v4-flash-eisen`.

## Operational notes

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
- **Strata's served tier is a host file, not a Nix option.** `hosts/eisen/strata.nix`
  ExecStart names the config (`strata-coder-iq1_m.json` — the only tier that finishes
  an agent session; IQ2_XS's and IQ3_XXS's sit beside it with their packs under
  `/mnt/storage/strata-data/packs/`). Changing the config needs a `systemctl restart
  strata` and a ~4 minute expert load, not a rebuild; changing the *config path*
  needs a switch. A swap between tiers is one line plus a restart.
- **A crash of `strata` can eat the root filesystem for five minutes.** The kernel
  streams the dying process's address space into systemd-coredump's spool *before*
  `ProcessSizeMax` is checked, so one abort on 2026-11-04 took `/` from 44 GB to 94 GB
  used until the dump unit hit its runtime limit. `serviceConfig.LimitCORE = "0"` in
  `strata.nix` is the fix (RLIMIT_CORE=0, so the dump never starts); do not "fix" a
  full disk on this host by deleting store paths until you have read `df` *and*
  `du -x`: `/nix` and `/home` are separate mounts (`/home` held 13 GB of `uv` cache,
  16 GB total, and `/nix/store/.links` 31 GB).
