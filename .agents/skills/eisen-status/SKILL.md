---
name: eisen-status
description: Check the health and current state of the Eisen LLM stack — which model is loaded, whether the router and services are up, whether a Steam game is running (gaming guard), and disk space.
---

# eisen-status

**Runs on:** Eisen (SSH `devji@eisen`, or directly on the host).
**Use when:** before running a generation, before switching models, when something returns a 429 / timeout / 502, or when you need to know what the stack is doing.
**Pick me over:** `infra` (host lifecycle) when the question is specifically "what is the LLM stack doing right now?"

## Power & Wake-on-LAN

If Eisen is powered off, wake it from Frieren (or any LAN node) via Wake-on-LAN:

```bash
task infra:wol:eisen
```

## Quick status (one pass)

```bash
# Which model is loaded (llama-swap)
curl -s http://127.0.0.1:8080/v1/models

# Router (chat + decisions) — should answer 200
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/v1/models

# On-demand services: the SOCKET is the health signal, the service idles at 0.
# socket active + service inactive is the correct steady state (TTS, Laya, image).
systemctl is-active qwen-tts.socket qwen-tts.service qwen-tts-proxy.service
systemctl is-active laya-serve.socket laya-serve.service
systemctl is-active qwen-image.socket qwen-image.service

# Parakeet STT (always resident; absent on generations older than 2026-10-17)
systemctl is-active parakeet-stt.service

# Disk (weights live on /mnt/storage; a full disk breaks fetches)
df -h /mnt/storage

# Gaming guard — is a Steam game running (llama-swap stopped)?
systemctl is-active llama-swap.service
```

## Reading the output

- `llama-swap /v1/models` lists each model with `status: running` (loaded) or `unloaded`. Only one model is loaded at a time (RAM: 71 GiB of weights > 62 GiB).
- If `llama-swap` is `inactive` and a Steam game is running, the gaming guard stopped it (frees VRAM). It restarts when the game exits. Do **not** manually start llama-swap during a game.
- Router `429 {"error":{"code":"llm_busy"}}` means a generation is already running (one slot). Wait and retry — do not hammer it.
- Laya `inactive` is normal (on-demand via socket activation). The first decision request wakes it; that request may 502 (cold start > router's 25s decision timeout). Retry — the second request succeeds.
- A request during a model swap waits (llama-swap queues it) or times out. Cold-load times: Kolibri ~4–5 min, Qwen ~2–3 min, Bonsai ~1 min. Pre-warm a cold model (send a request for it with `"max_tokens": 1` and `--max-time 600`, then wait) before running SubZeroClaw (its cap is 120s). `/v1/models` does **not** load weights.

## Warm-up probes (`/health`) — timeouts matter

`inactive` on an on-demand service means "asleep", not "down". Waking it costs
time, so probe with a budget, never a 2–5 s default:

| Service | Idle stop | Cold start | Probe |
| :--- | :--- | :--- | :--- |
| Qwen3-TTS `:8181` | 900 s no connection | ~15 s | `curl --max-time 60 http://127.0.0.1:8181/health` |
| Laya `:8090` | 900 s no request | ~40 s | `curl --max-time 90 http://127.0.0.1:8090/health` |
| Qwen-Image `:8282` | 900 s no request | minutes | `curl --max-time 600 http://127.0.0.1:8282/health` |
| Parakeet `:8091` | always resident | ~1 s | `curl --max-time 10 http://127.0.0.1:8091/health` |
| llama-swap `:8080` | model unloads after 900 s | 1–5 min | tiny completion, `--max-time 600` |

**Do not health-poll an on-demand endpoint from a monitor or watch loop** (gatus,
watch, cron): each `/health` wakes the model, so polling defeats the idle saving
and can stop/start it every idle period. Check the *socket* unit over SSH if you
need liveness without waking anything.

## Logs (when something is wrong)

```bash
journalctl -u llama-swap --since "10 min ago" | tail -30
journalctl -u llm-decision-router --since "10 min ago" | tail -30
journalctl -u qwen-image --since "10 min ago" | tail -30
```

**Confirm before:** restarting a service that would drop an in-flight generation (`systemctl restart llama-swap` unloads the model and kills the current generation). Ask first, or wait for the generation to finish.
