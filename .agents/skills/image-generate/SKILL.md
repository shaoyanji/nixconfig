---
name: image-generate
description: Generate or edit images with Qwen-Image-2.1-Turbo on Eisen: OpenAI-compatible /v1/images/generations, the Turbo schedule, size rules, RGBA prompts, and reference-image edits.
---

# image-generate

**Runs on:** Eisen (service `qwen-image`, port 8282 loopback).
**Use when:** generating an image from a text prompt, editing an existing image, or producing an image with transparency (RGBA).
**Pick me over:** nothing else in the repo generates images. For text, use the LLM endpoint (`eisen.lan/v1`).

## Endpoints

```text
LAN:      http://eisen.lan/images/v1/images/generations   (nginx :80 -> 127.0.0.1:8282)
Tailnet:  https://eisen.<tailnet>.ts.net:8445/v1/images/generations
Health:   GET http://127.0.0.1:8282/health   (loopback only)
```

## Generate (text-to-image)

```bash
curl -s http://eisen.lan/images/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a lovely cat holding a sign that says qwen2.1", "size": "1024x1024", "n": 1, "response_format": "b64_json"}' \
  | python3 -c "import sys,json,base64; open('/tmp/out.png','wb').write(base64.b64decode(json.load(sys.stdin)['data'][0]['b64_json']))"
```

- `prompt`: the text description. Be concrete (subject, style, composition).
- `size`: `WIDTHxHEIGHT`, **both divisible by 32** (e.g. `1024x1024`, `1024x768`). Other sizes are rounded down to a multiple of 32.
- `n`: 1 (one generation at a time; the service serializes requests).
- `response_format`: `b64_json` (base64 PNG in the response) or `url` (a `data:` URL).

## The Turbo schedule is fixed — do not override it

The service always runs **8 steps, CFG 1.0, euler, `--sigmas qwen-image-2.1-turbo`**. This is the Turbo checkpoint's schedule. Do not ask for more steps or a different CFG — the Turbo weights are tuned for this schedule, and changing it degrades quality. If you need the 40-step base schedule, that is a different model (base Qwen-Image-2.1), not a parameter.

## Transparency (RGBA)

The model decides transparency from the prompt, not from a switch. Use this format:

> `This is an RGBA image with transparency. <your description>. The image has alpha channel and the background is transparent.`

Alpha is kept only in `.png` and `.webp` outputs; `.jpg` drops it.

## Editing (reference image)

Editing takes a reference image (`-r` + mmproj vision weights in the backend). The HTTP wrapper exposes text-to-image only in this version — for editing, call the `sd-cli` path directly on Eisen (see `hosts/eisen/qwen-image-server.py` for the exact flags) or ask for the editing endpoint to be wired.

## Cost / timing

- One generation at a time (the service serializes). A second concurrent request waits.
- First run after idle loads the weights (DiT 7.1 GiB + encoder 4.7 GiB + VAE 0.6 GiB); the encoder runs on CPU, the DiT on GPU (8 GB VRAM — the weights do not all fit in VRAM, so the split is CPU/GPU). Expect the first generation to be slower than later ones.
- Timeout: 900s per generation (nginx + wrapper). If a generation times out, check `journalctl -u qwen-image` — do not retry blindly (a retry re-runs the full generation).

## License

The Turbo checkpoint is Qwen Research License (research/eval only, non-commercial). Non-commercial use on this host is fine. The base Qwen-Image-2.1 (Apache-2.0) is the fallback if the license ever matters.

**Confirm before:** generating an image that would be published or shared with a third party (the license is non-commercial; confirm the use is non-commercial first).
