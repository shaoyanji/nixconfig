---
name: voice-loop
description: "The voice loop on eisen as one script: say text via Qwen3-TTS, hear audio via Parakeet (raw bytes, never multipart), or roundtrip both and get a pass/fail on the word overlap. Named speakers only — `default` is invalid."
version: 0.2.0
platforms: [linux]
metadata:
  hermes:
    tags: [voice, tts, stt, parakeet, qwen3-tts]
    related_skills: [stt, eisen-status]
---

# voice-loop

**Runs on:** eisen (Parakeet STT :8091, Qwen3-TTS :8181, both loopback-only behind nginx).
**Use when:** generating speech, transcribing it back, or proving the whole chain still works.
**Pick me over:** `stt` when the text-to-speech leg is involved; `eisen-status` when the question is whether the stack is up at all.

```bash
scripts/voice-loop.sh say "Reminder: the meeting moved to 15:30." -v aiden -o /tmp/x.wav
scripts/voice-loop.sh hear /tmp/x.wav
scripts/voice-loop.sh roundtrip "Ask not what your country can do for you"   # exit 1 if the loop does not close
```

`hear` calls the `stt` skill's script (`../stt/scripts/stt.sh`) so the raw-bytes
contract has one home; `roundtrip` says the text, transcribes the audio, and
scores the result by word overlap (default 0.6, `--min-overlap`). The threshold
exists because TTS is never word-identical to its own transcript — numbers,
punctuation and casing drift — while a wrong speaker or a wrong model fails hard.

## Endpoints

```text
STT   LAN http://eisen.lan/stt/transcribe     nginx :80 -> 127.0.0.1:8091
TTS   LAN http://tts.lan/v1/audio/speech      nginx :80 -> 127.0.0.1:8181
      tailnet https://eisen.<tailnet>.ts.net:8444/…
```

**STT: POST `/transcribe` takes raw audio bytes.** Multipart fails. Accepts any
ffmpeg-decodable format, 25 MB cap, 600 s timeout, CPU-only (the RX 5700 has no
ROCm, ONNX has no Vulkan path). Weights live in `/mnt/storage/parakeet`, code in
`hosts/eisen/parakeet.nix`.

**TTS: OpenAI-compatible `/v1/audio/speech`.** Named speakers only: `vivian`
(default), `serena`, `uncle_fu`, `ryan`, `aiden`, `ono_anna`, `sohee`, `eric`,
`dylan`. `default` is **not** a speaker — it answers `unknown speaker 'default'`,
and only after a cold start has already been paid for, which is why the script
rejects it before the network call.

## On-demand means asleep, not down

TTS, Laya and image generation idle-stop after 900 s and cold-start on the next
request (~15 s for TTS). The socket accepts immediately and the model loads
after it, so a 2 s probe proves nothing:

```bash
curl -s --max-time 60 http://tts.lan/health   # warm-up with a real budget
```

**Never poll `/health` in a loop or a monitor.** Each probe wakes the service and
defeats the idle saving. Socket state (`systemctl is-active qwen-tts.socket`) is
the liveness signal that costs nothing — that is what `task infra:status:eisen`
reports.

A streamed request is an open connection and is never cut off mid-audio; a
non-streamed one needs the generous timeout the script passes.

## The full loop

```text
audio → /stt/transcribe (raw bytes) → text → LLM (eisen.lan/v1) → reply
      → /v1/audio/speech (voice: aiden) → WAV
```

If transcription looks wrong, check the audio first (sample rate, clipping,
background noise) before blaming the model — and note that `stt.sh` normalizes
sample rate and channel count for exactly that reason.

**Confirm before:** playing generated speech to a third party, or sending a
transcription of private audio to an external service.

Truth: `hosts/eisen/TTS.md` and `hosts/eisen/parakeet.nix`; this page is the procedure.
