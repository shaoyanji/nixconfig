---
name: cpg-image
description: Generate images with `cpg image` — free GPT Image 2.5 models, a JSON result, no daemon. For icons, illustrations and product shots.
version: 1.0.0
tags: [ai, image, chatplayground, media]
platforms: [linux, macos]
---

# cpg-image

`cpg image` renders a prompt to PNG through chatplayground's image endpoint and
returns its CDN URL, plus the local file when you ask for one. One call, one
image: no server, no browser, no queue.

```bash
cpg image --json -o "$HOME/Pictures/cpg/icon.png" \
  "a flat red panda icon, 2px outline, white background, 1024x1024"
```

Result on stdout:

```json
{"id":"cmw5h8w4q000rmt02e1c0hp4r","url":"https://cdn.chatplayground.ai/…png",
 "prompt":"a flat red panda icon…","model":"gpt-image-2.5-sunburst",
 "size":"1024x1024","path":"/home/devji/Pictures/cpg/icon.png"}
```

A failure prints `{"error":"image generation failed with status 400: …"}` and
exits 1, so a script can branch on the exit status.

## Models

The CLI omits `-m` safely: it resolves the first active, free image model from
the live catalog. Two exist on 2026-11-06, both free — `gpt-image-2.5-sunburst`
and `gpt-image-2.5-flare`. To see the current list:

```bash
cpg models --json | jq -r '.[] | select(.group == "image") | .id'
```

Naming one is fine; naming a retired one is not, which is why the default is
resolved rather than hardcoded (`gpt-image-2` answered `400 The model is not
supported`).

## Sizes

`1024x1024` (default), `1536x1024` wide, `1024x1536` tall.

## Where the file goes

- `-o PATH` downloads the PNG and is the only way to get a local file; without
  it you get the URL alone.
- For anything a human will look at, write under `~/Pictures/cpg/` and give the
  reply that path — hermes' platform send takes a file path, not a URL.
- `/tmp` is right when the image is merely an input to the next step.

## When it fails

- `400 … The model is not supported`: the id was retired. Re-read the catalog
  with the `jq` above; do not retry the same id.
- `401`: the session is gone, not slow. `cpg status --json` reports
  `authenticated`. A dead session needs a real browser login
  (`chatplayground-go login`); the hourly `chatplayground-refresh` timer only
  keeps a live one alive.
- `429` or a 5xx: wait, then retry once. Do not loop on a paid or rate-limited
  endpoint.

## What it is not

- **Not editing.** The chat `-i` flag is for vision input, not for image-to-image.
- **Not typographic.** Ask for words only when you can afford a re-roll; spelling
  is the model's weakest case.
- **Not reproducible.** The same prompt returns different pixels, so a diff of
  two generations means nothing.

Related: `cpg-advice` (the text lane over the same client).
