---
name: eisen-status
description: Check the health and current state of the Eisen LLM stack — which model is loaded, whether the router and services are up, whether a Steam game is running (gaming guard), and disk space.
---

# eisen-status

**Runs on:** Eisen (SSH `devji@eisen`, or directly on the host).
**Use when:** before running a generation, before switching models, when something returns a 429 / timeout / 502, or when you need to know what the stack is doing.
**Pick me over:** `infra` (host lifecycle) when the question is specifically "what is the LLM stack doing right now?"

## Quick status (one pass)

```bash
# Which model is loaded (llama-swap)
curl -s http://127.0.0.1:8080/v1/models

# Router (chat + decisions) — should answer 200
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/v1/models

# Laya decision model (on-demand; may be inactive until first use)
systemctl is-active laya-serve.service laya-serve.socket

# Image server
systemctl is-active qwen-image.service

# Parakeet STT + TTS
systemctl is-active parakeet-stt.service qwen-tts.service

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
- A request during a model swap waits (llama-swap queues it) or times out. Cold-load times: Kolibri ~4–5 min, Qwen ~2–3 min, Bonsai ~1 min. Pre-warm a cold model (send a request for it, wait) before running SubZeroClaw (its cap is 120s).

## Logs (when something is wrong)

```bash
journalctl -u llama-swap --since "10 min ago" | tail -30
journalctl -u llm-decision-router --since "10 min ago" | tail -30
journalctl -u qwen-image --since "10 min ago" | tail -30
```

**Confirm before:** restarting a service that would drop an in-flight generation (`systemctl restart llama-swap` unloads the model and kills the current generation). Ask first, or wait for the generation to finish.
