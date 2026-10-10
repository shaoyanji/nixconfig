# eisen — Offline Qwen3-TTS Speech Server (`tts.lan`)

OpenAI-compatible text-to-speech, fully offline, on eisen's RX 5700 (Navi 10 —
**Vulkan, not ROCm**). The implementation is
[`modules/services/qwen-tts.nix`](../../modules/services/qwen-tts.nix); eisen enables
it in [`configuration.nix`](./configuration.nix).

| | |
| :--- | :--- |
| Runtime | `ServeurpersoCom/qwentts.cpp` (MIT) — C++17/GGML port of Qwen3-TTS 12 Hz, built from source with `-DGGML_VULKAN=ON` |
| Weights | `Serveurperso/Qwen3-TTS-GGUF` — `qwen-talker-1.7b-customvoice-Q4_K_M.gguf` + `qwen-tokenizer-12hz-Q8_0.gguf` |
| Default voice | `vivian` (named speaker; also `serena`, `uncle_fu`, `ryan`, `aiden`, `ono_anna`, `sohee`, `eric`, `dylan`) |
| Listening | `127.0.0.1:8181` (loopback only — **not** in the firewall) |
| LAN | `http://tts.lan/…` (nginx `:80` → `:8181`) |
| Tailnet | `https://eisen.<tailnet>.ts.net:8444/…` (`tailscale serve`) |

**Why this runtime:** it is actively maintained, builds against its bundled ggml with a
Vulkan backend (the only GPU path this card has), and already ships an
OpenAI-compatible `tts-server` — so the module *wraps* that rather than adding a Python
layer. The `tts-server` accepts `--model`, `--codec`, `--alias`, `--port`, and the speech
body takes optional `seed`/`temperature`/`top_k`/`top_p`/`max_new_tokens`/
`repetition_penalty`; `response_format` `pcm` streams s16le, `wav` returns a file.
Confirm the live surface with `tts-server --help` on first deploy.

---

## Manual steps (cannot be automated)

1. **Pin the runtime.** The derivation ships `rev = 000…0` + `lib.fakeHash` on purpose so
   an unpinned build fails loudly. Pin it once:

   ```bash
   nix-prefetch-git --fetch-submodules https://github.com/ServeurpersoCom/qwentts.cpp.git
   # → copy "rev" and "hash" into modules/services/qwen-tts.nix
   ```

2. **First model download** happens on boot via the oneshot `qwen-tts-models-{talker,codec}`
   units (~1.5 GB, resumable, idempotent). It never blocks boot. To pre-seed:
   download both GGUFs into `/mnt/storage/tts/models/`.
3. **Tailscale auth** is assumed already done on eisen (`ssh eisen tailscale status`).
   No Funnel is enabled anywhere in this module — access is tailnet-only.

## Deploy

```bash
nixos-rebuild switch --flake .?submodules=1#eisen
```

> eisen rebuilds reportedly exit **4** because user-scope `sops-nix` cannot decrypt
> (`0 successful groups required, got 0`) — the *system* generation still applies. Verify
> with `readlink -f /run/current-system` + `systemctl --failed`, not the exit code.

## Verify

```bash
systemctl status qwen-tts
systemctl is-active qwen-tts-models-talker qwen-tts-models-codec qwen-tts tailscale-serve-tts
journalctl -u qwen-tts -n 40 --no-pager   # must show the Vulkan device, not CPU

curl http://127.0.0.1:8181/health

# OpenAI-compatible speech
curl -X POST http://127.0.0.1:8181/v1/audio/speech \
  -H 'Content-Type: application/json' \
  -d '{"input":"Hello from eisen","voice":"default","response_format":"wav"}' \
  --output out.wav
file out.wav   # expect: RIFF ... WAVE audio, 24000 Hz, mono

# list named / registered voices
curl -s http://127.0.0.1:8181/v1/audio/voices | jq .
```

From **another tailnet device** (no MagicDNS on this tailnet → pin the address):

```bash
curl --resolve eisen.cloudforest-kardashev.ts.net:8444:100.119.172.99 \
  https://eisen.cloudforest-kardashev.ts.net:8444/health

curl --resolve tts.lan:80:100.119.172.99 http://tts.lan/health
```

## Acceptance

- [ ] rebuild succeeds (ignoring the known exit-4)
- [ ] `qwen-tts` active and `systemctl --failed` shows nothing new
- [ ] `/health` returns ok
- [ ] speech endpoint yields a valid 24 kHz mono WAV
- [ ] `journalctl -u qwen-tts` shows a **Vulkan device**, not a CPU fallback
- [ ] reachable from another tailnet device on `:8444`
- [ ] **not** publicly exposed: `ss -ltnp | grep 8181` is `127.0.0.1` only, and 8181 is
      absent from `networking.firewall.allowedTCPPorts`

## Notes / deviations

- **Weights are on `/mnt/storage/tts/models`, not a `StateDirectory`.** They are multi-GB
  and belong on the data array (same as the Qwen and Laya weights); only the small
  cloned-voice registry uses `StateDirectory=qwen-tts` (`/var/lib/qwen-tts`).
- **Warm process.** The runtime is long-lived (`Restart=always`); it does not spawn per
  request, so there is no per-call model-load cost. Prefer this over per-request spawning.
- **No gaming guard.** TTS loads its model into VRAM on demand; if it contends with a
  running game, `MemoryMax=8G` + the GPU scheduler handle it. Revisit if VRAM pressure
  shows up.
- **Optional auth.** Set `services.qwen-tts.apiKeyFile` to require
  `Authorization: Bearer <key>` (enforced in nginx, key read at service start). Unset =
  the LAN/tailnet is the boundary, as for Qwen and Laya.
