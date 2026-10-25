---
name: eisen-status
description: "What eisen's LLM stack is doing right now: one task prints the served model, router code, socket states, disk, and whether the gaming guard is yielding. Read-only and probe-free, so it never wakes an on-demand model."
version: 0.2.0
platforms: [linux]
metadata:
  hermes:
    tags: [eisen, llm, llama-swap, strata, tts, sockets]
    related_skills: [voice-loop, stt, infra]
---

# eisen-status

**Runs on:** eisen (its facts), from frieren or any LAN node (the reach).
**Use when:** before a generation, before switching models, after a 429 / timeout / 502, or when you need to know what the stack is doing.
**Pick me over:** `infra` (host lifecycle) when the question is specifically this stack.

## The read

```bash
task infra:status:eisen            # human lines
JSON=1 task infra:status:eisen     # one object, for a program (needs jq, exit 3 without)
```

Exit 0 whenever eisen answered — a sleeping stack is a state, not a failure.
Exit 2 when the host is unreachable, which is the same condition
`task infra:wol:eisen` fixes; `infra:wol:eisen:online` then waits for sshd.

It reads **socket units, never `/health`**: the on-demand services idle-stop, and
a probe is what wakes them. `qwen-tts.socket=active` with `qwen-tts.service=inactive`
is the correct steady state, not a fault.

## Reading it

- `strata` is the live server on `:8085`; `llama-swap` on `:8080` is **dormant**
  in `hosts/eisen/llm-server.nix` and reports `inactive` by design. The model line
  comes from strata's `/v1/models`; only one model is resident at a time (71 GiB
  of weights against 62 GiB of RAM).
- `gaming=yes` means a process whose executable lives under a Steam library
  (`steamapps/common/`) is running, so `llama-swap-gaming-guard.service` has
  stopped strata and the API answers connection-refused until the game exits. Do
  not start strata by hand during a game. Steam and gamescope themselves run
  permanently here and are *not* the signal.
- Router `429 {"error":{"code":"llm_busy"}}` means a generation is already
  running (one slot). Wait; do not hammer it.
- Laya `inactive` is normal (socket-activated). The first decision request wakes
  it and may 502 because a cold start outlives the router's 25 s decision
  timeout — the second request succeeds.
- `disk` is `/mnt/storage`: weights live there, and a full disk breaks fetches.

## When you must wake something

Wake a service only when you intend to use it, and give the probe a real budget:

| Service | Idle stop | Cold start | Probe |
| :--- | :--- | :--- | :--- |
| Qwen3-TTS `:8181` | 900 s | ~15 s | `curl --max-time 60 …/health` |
| Laya `:8090` | 900 s | ~40 s | `curl --max-time 90 …/health` |
| Qwen-Image `:8282` | 900 s | minutes | `curl --max-time 600 …/health` |
| Parakeet `:8091` | always resident | ~1 s | `curl --max-time 10 …/health` |
| strata `:8085` | model unloads after 900 s | 1–5 min | a 1-token completion, `--max-time 600` |

Pre-warm a cold model before a caller with a short cap (SubZeroClaw's is 120 s)
runs against it: send one request with `"max_tokens": 1` and wait.

## Logs

```bash
journalctl -u strata --since "10 min ago" | tail -30
journalctl -u llm-decision-router --since "10 min ago" | tail -30
journalctl -u llama-swap-gaming-guard --since "10 min ago" | tail -20
```

**Confirm before:** restarting anything that would drop an in-flight generation —
`systemctl restart strata` unloads the model and kills the current request.

Truth: `hosts/eisen/llm-server.nix` (the stack and the guard) and `task infra:status:eisen` (the read); this page is the interpretation.
