---
name: voice-loop
description: The voice loop on Eisen — Parakeet Redux speech-to-text (POST raw audio bytes, not multipart) plus Qwen3-TTS text-to-speech (named speakers; `default` is invalid). Covers the STT → LLM → TTS loop end to end.
---

# voice-loop

**Runs on:** Eisen (Parakeet STT :8091, Qwen3-TTS :8181, both loopback-only, exposed via nginx).
**Use when:** transcribing speech, generating speech, or running the full voice loop (speak → transcribe → LLM → speak).
**Pick me over:** `stt` (transcription only) when you need the full loop including TTS, or `parakeet` internals when you need the endpoint contract.

## Speech-to-text (Parakeet Redux)

```text
LAN:  http://eisen.lan/stt/transcribe   (nginx :80 -> 127.0.0.1:8091)
Direct: http://127.0.0.1:8091/transcribe  (loopback only)
```

**Endpoint contract: POST `/transcribe` takes RAW audio bytes in the request body.** Multipart/form-data FAILS (ffmpeg chokes on the MIME body). Send the bytes directly:

```bash
# Correct: raw bytes
curl -s http://eisen.lan/stt/transcribe \
  -H "Content-Type: audio/wav" --data-binary @clip.wav

# WRONG: multipart (fails)
# curl -F "file=@clip.wav" http://eisen.lan/stt/transcribe
```

- Accepts WAV (and other ffmpeg-decodable formats). 25 MB cap, 600s timeout.
- CPU-only (RX 5700 has no ROCm, ONNX has no Vulkan path). Real-speech test passed (exact transcription, 2.64s).
- Weights in `/mnt/storage/parakeet` (NOT the Nix store). Code: `hosts/eisen/parakeet.nix` + vendored `parakeet-transcribe.py` + `parakeet-server.py`.

## Text-to-speech (Qwen3-TTS)

```text
LAN:  http://tts.lan/v1/audio/speech   (nginx :80 -> 127.0.0.1:8181)
Tailnet: https://eisen.<tailnet>.ts.net:8444/…
```

OpenAI-compatible `/v1/audio/speech`. Named speakers: `vivian` (default), `serena`, `uncle_fu`, `ryan`, `aiden`, `ono_anna`, `sohee`, `eric`, `dylan`.

**`default` is NOT a valid speaker** (errors `unknown speaker 'default'`). Use `aiden` (or another named speaker) when no speaker is specified.

```bash
curl -s http://tts.lan/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3-tts", "input": "Hello, this is a test.", "voice": "aiden", "response_format": "wav"}' \
  -o /tmp/tts.wav
```

Zero-shot cloning registers via the runtime's voice registry (see `hosts/eisen/TTS.md`).

## The full loop

```text
Microphone / audio file
  → POST /stt/transcribe (raw bytes) → text
  → LLM (eisen.lan/v1, e.g. Kolibri or Qwen) → reply text
  → POST /v1/audio/speech (voice: aiden) → WAV
  → Speaker / audio file
```

- Keep each step's output small (the LLM reply should be short — long replies make long audio).
- If transcription is wrong, check the audio first (sample rate, clipping, background noise) before blaming the model.
- If TTS fails with `unknown speaker`, you passed `default` or a misspelled name — use one of the named speakers above.

**Confirm before:** playing generated speech to a third party or sending a transcription containing private audio to an external service.
