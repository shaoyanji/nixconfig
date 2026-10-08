---
name: stt
description: "Speech-to-text via voxtype (numtide). Transcribe audio files to text headlessly; push-to-talk daemon for live dictation. Runs from nix shell github:numtide/llm-agents.nix#voxtype when not installed."
version: 0.1.0
author: Shaoyan Ji (shaoyanji)
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [STT, Speech-to-Text, Transcription, Voxtype, Voice]
    related_skills: [reasonix]
---

# stt — speech-to-text with voxtype

Convert speech to text with [voxtype](https://github.com/numtide/voxtype) (numtide, v1.1.0): push-to-talk voice-to-text for Linux, optimized for Wayland (works on X11). Two interfaces matter:

- **Agents:** `voxtype transcribe <FILE>` — audio file in, transcript out. Works headless (no display needed). This is the primary interface for scripts and agents.
- **Humans:** `voxtype daemon` — hold-hotkey (default `SCROLLLOCK`) dictation that types/clipboard-pastes the result.

## When to use

- Transcribing recordings, meeting audio, voice memos, podcasts, or call recordings into text
- Turning any speech audio into a searchable/check-in-able document (feed the text into `qmd`/notes afterwards)
- Live dictation on the desktop via the push-to-talk daemon

## Availability

`voxtype` may **not** be on PATH. Check first:

```bash
command -v voxtype
```

Fallback straight from numtide's flake (no install needed):

```bash
nix shell github:numtide/llm-agents.nix#voxtype --command voxtype --version
```

## Usage

### Transcribe a file (primary interface)

```bash
voxtype transcribe /path/to/audio.wav
```

Fallback form when not installed:

```bash
nix shell github:numtide/llm-agents.nix#voxtype \
  --command voxtype transcribe /path/to/audio.wav
```

Input must be **WAV, 16 kHz, mono PCM**. Convert anything else with ffmpeg first:

```bash
ffmpeg -i in.mp3 -ar 16000 -ac 1 -c:a pcm_s16le /tmp/in.wav
voxtype transcribe /tmp/in.wav
```

The transcript is printed to stdout (rc 0 on success; transcription errors —
missing model, bad API key — exit non-zero with the reason on stderr).

Verified 2026-10-08 on frieren (headless): `jfk.wav` (11 s, 16 kHz mono) →
*"And so my fellow Americans, ask not what your country can do for you, ask
what you can do for your country."* — whisper
`base.en`, local mode, ~18 s on CPU. (Full quote returned correctly;
runtime scales roughly with audio length on CPU.)

### Engines & models

```bash
voxtype info engines      # compiled engines; whisper is active by default
voxtype info models       # model catalog per engine + which are installed
voxtype info devices      # audio capture devices
```

- Engines: `whisper` (default), `parakeet`, `moonshine`, `sensevoice`,
  `paraformer`, `dolphin`, `omnilingual`, `cohere`, `openvino`, `soniox`.
  Switch: `voxtype config set engine <NAME>`.
- Default model: whisper `base.en` (147 MB — download once with
  `voxtype setup --download --model base.en`).
- Models live in `~/.local/share/voxtype/models/`; config in
  `~/.config/voxtype/config.toml` (`voxtype config set <key> <value>`
  preserves comments; daemon needs `systemctl --user restart voxtype`).

### Remote mode gotcha (Groq/OpenAI-compatible APIs)

`whisper.mode` is `local | remote | cli`. In `remote` mode voxtype calls
`<endpoint>/v1/audio/transcriptions` **itself** — so the configured endpoint
must NOT include `/v1`:

```bash
voxtype config set whisper.remote_endpoint https://api.groq.com/openai
voxtype config set whisper.remote_api_key  gsk_...
```

Symptoms: `404 ... /v1/v1/audio/transcriptions` = endpoint has a trailing
`/v1`; `401 Invalid API Key` = rotate the key. Falling back to local mode:

```bash
voxtype config set whisper.mode local
```

### Live dictation (human interface)

```bash
voxtype                     # run the push-to-talk daemon
voxtype status               # idle/recording/transcribing state (Waybar)
voxtype record start|stop    # drive recording from keybindings/scripts
voxtype meeting              # continuous meeting transcription mode
voxtype configure            # interactive config TUI
```

Daemon install: `voxtype setup systemd` (user service). Output chain types
into the focused window via `wtype` (Wayland) / `ydotool` (X11), falling
back to clipboard (`wl-copy`/`xclip`). In headless shells none apply —
use `transcribe`, which needs no display.

## Notes

- First local run downloads the model (147 MB `base.en`); it is cached in
  `~/.local/share/voxtype/models/`.
- `transcribe` honors the active engine/mode from config; `--engine <NAME>`
  overrides the engine per call.
- No GPU on frieren: local whisper is CPU-only (measured ~1.6× realtime on
  `base.en`). Remote mode is faster once a valid API key is configured.
- Part of numtide's flake (`github:numtide/llm-agents.nix`), same source as
  the `reasonix` skill.
