---
name: stt
description: "Speech-to-text, one command: scripts/stt.sh transcribes a file locally with voxtype or on eisen's always-resident Parakeet (raw bytes, not multipart). Covers engines, models, and the packaged voice-dictate path."
version: 0.2.0
author: Shaoyan Ji (shaoyanji)
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [STT, Speech-to-Text, Transcription, Voxtype, Voice]
    related_skills: [voice-loop, reasonix]
---

# stt — speech to text

`scripts/stt.sh` is the procedure; this page is the why.

```bash
scripts/stt.sh clip.m4a            # auto: local voxtype if installed, else eisen
scripts/stt.sh --server clip.m4a   # force the always-resident Parakeet on eisen
scripts/stt.sh --local clip.m4a    # force voxtype; fetches it from numtide's flake if absent
scripts/stt.sh --out notes.txt clip.m4a
```

stdout is the transcript and nothing else, so `stt.sh a.mp3 > notes.txt` feeds
qmd or a document directly; diagnostics go to stderr.

## What the script guarantees

- **Any decodable audio in.** It always re-encodes to 16 kHz mono PCM with
  ffmpeg. A 44.1 kHz stereo upload is both the "garbled speech" bug and a way to
  cross the 25 MB cap on audio that would fit converted.
- **Two probes, two budgets.** It checks the TCP port with a 2 s budget (an off
  host should cost 2 s, not a minute), then `/health` with 60 s — the socket
  accepts immediately and the ONNX sessions load after it, so a 2 s health probe
  reports "up" on a server that then fails the request.
- **The cap is reported, not hidden.** Over 25 MB (~26 min of 16 kHz mono wav)
  it says so and asks for a split instead of returning a server error.

Eisen's endpoint takes **raw bytes** in the body; `multipart/form-data` fails
because ffmpeg chokes on the MIME body. The script uses `--data-binary` and
`--fail-with-body`, so a 4xx prints its reason rather than being mistaken for a
transcript. For the text-to-speech leg and the whole loop, see `voice-loop`.

## Local engine (voxtype)

[voxtype](https://github.com/numtide/voxtype) (numtide) is the local option:
push-to-talk dictation for Linux, optimized for Wayland.

```bash
voxtype transcribe FILE   # audio in, transcript out; works headless
voxtype                   # push-to-talk daemon: hotkey → types into the focused window
voxtype status            # idle / recording / transcribing (Waybar)
voxtype info engines      # whisper (default), parakeet, moonshine, sensevoice, …
voxtype info models       # catalog per engine, and which are installed
```

Input must be WAV 16 kHz mono PCM, which is what the script hands it. First local
run downloads the model (`base.en`, 147 MB) into
`~/.local/share/voxtype/models/`; measured on frieren's CPU, `base.en` runs about
1.6× realtime.

**Remote mode gotcha.** `whisper.mode` is `local | remote | cli`; in `remote`
mode voxtype calls `<endpoint>/v1/audio/transcriptions` itself, so the endpoint
must not include `/v1` — `404 .../v1/v1/...` means it does:

```bash
voxtype config set whisper.remote_endpoint https://api.groq.com/openai
voxtype config set whisper.remote_api_key  gsk_...
```

**The quality bar for dictation on this fleet** is not the transcribe path but
`modules/profiles/voice-dictate.nix`: a packaged `voice-dictate` that records
with `pw-record` on a hotkey, transcribes through Groq (sops key, cached in
tmpfs), and types the result with `wtype`, with `--fail-with-body` so an error
body is never typed into the focused window. Read it before writing another
record-and-paste script.

## Server alternative: Parakeet on eisen

Always resident (CPU-only ONNX, ~1 GB), LAN `http://eisen.lan/stt`, direct
`http://127.0.0.1:8091/transcribe`. One transcription at a time, 600 s timeout.
It exists only on generations built after 2026-10-17 (`parakeet-stt.service`);
`task infra:status:eisen` reports whether it is up without waking anything.

Truth: `modules/user/ai/default.nix` and `hosts/eisen/parakeet.nix`; this page is the procedure.
