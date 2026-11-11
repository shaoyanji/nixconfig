---
name: cpg-image
description: Generate images with `cpg image` — free GPT Image 2.5 models, a JSON result, no daemon. For icons, illustrations and product shots.
version: 1.1.0
tags: [ai, image, chatplayground, media]
platforms: [linux, macos]
---

# cpg-image

`cpg image` renders a prompt to PNG through chatplayground's image endpoint and
returns its CDN URL, plus the local file when you ask for one. One call, one
image: no server, no browser, no queue. The client is declared in
`modules/user/ai/hermes-user.nix`.

```bash
cpg image --json -o "$HOME/Pictures/cpg/icon.png" \
  "a flat red panda icon, 2px outline, white background, 1024x1024"
```

Result on stdout:

```json
{"id":"01a1ba8b-476a-7999-98a1-515d1e947e57",
 "url":"https://web.chatplayground.ai/api/files/01a1ba8b-801a-71eb-af21-f36ffbd6bf1c",
 "prompt":"a flat red panda icon…","model":"gpt-image-2.5-sunburst",
 "size":"1024x1024","path":"/home/devji/Pictures/cpg/icon.png"}
```

A failure prints `{"error":"image generation failed with status 400: …"}` and
exits 1, so a script can branch on the exit status. Measured 2026-11-08: a
1024×1024 generation takes 13–16 s.

## Models and sizes

The CLI omits `-m` safely: it takes the first free image model from the live
catalog. Two exist on 2026-11-08, both free — `gpt-image-2.5-sunburst` and
`gpt-image-2.5-flare`:

```bash
cpg models --json | jq -r '.[] | select(.group == "image") | .id'
```

Naming one is fine; naming a retired one is not, which is why the default is
resolved rather than hardcoded (`gpt-image-2` answers `400 The model is not
supported`).

Sizes: `1024x1024` (default), `1536x1024` wide, `1024x1536` tall, and `auto`.

## The allowance

`cpg usage` reads the account rather than the plan's marketing name:

```bash
cpg usage --json | jq '{images: .usage.images, prompts: .usage.dailyQueries}'
```

Measured 2026-11-11 on the lifetime pool: **100 images per day**, resetting at
00:00 UTC, and 350 prompts per day (`usage.dailyQueries`). `usage.images.remaining`
answers `"unlimited"` — that is the plan talking, not the day: the ceiling is
`entitlement.limits.imagesPerDay`, so count `imagesPerDay - usage.images.used`.

The burst bucket is not in the payload but it exists: on 2026-11-10 a batch of 26
plates in 30 minutes was answered `RATE_LIMITED` with 74 images still unspent.
Plan a batch as **20 plates, then a pause**, not one sweep.

- Read the count before a batch and between batches. A 429 with images left is
  the burst bucket: back off 60 s, then 120 s, then 240 s, and a fourth failure
  is a spent window, not a reason to keep retrying.
- Spend generations on what only a model can do. Cropping, resizing, colour
  grading, text overlays and repetition are local work for an image tool.
- One composed prompt beats three variations. Re-roll on a named defect ("the
  cube is off-centre"), never to shop for a better idea.
- A day of 100 is a book of plates or a set of product shots, not a slideshow.
  Say so before a project starts rather than at image 101.

## Where the file goes

- `-o PATH` downloads the PNG and is the only way to get a local file. The URL
  the endpoint returns is session-gated, so a bare fetch of it answers 401.
- For anything a human will look at, write under `~/Pictures/cpg/` and give the
  reply that path — hermes' platform send takes a file path, not a URL.
- `/tmp` is right when the image is merely an input to the next step.

## When it fails

- **401, `UNAUTHENTICATED`, or a bare `Sign in to continue`**: the session token
  lives 60 seconds and is minted from the stored `__client` cookie. Run
  `cpg refresh` first — it prints `Successfully refreshed Clerk token!` on
  success — then retry the call once. Only when the refresh itself fails is the
  session gone, which needs a real browser login (`chatplayground-go login`);
  the hourly `chatplayground-refresh` timer keeps a live session warm but cannot
  resurrect a dead one.
- **522, `error code: 522`, or a connection timeout on every call**:
  `app.chatplayground.ai` is retired and the API lives at
  `https://web.chatplayground.ai`. An old build of this client answers 522
  forever; that is the binary, not the account.
- `400 … The model is not supported`: the id was retired. Re-read the catalog
  with the `jq` above; do not retry the same id.
- `429`: read the body. `RATE_LIMITED` with `remaining` above zero is the hourly
  bucket — back off and retry; `remaining` at zero is the day, and
  `cpg usage --json | jq .usage.images` says when it resets. There is no queue.

## What it is not

- **Not editing.** The chat `-i` flag is for vision input, not for image-to-image.
- **Not typographic.** Ask for words only when you can afford a re-roll; spelling
  is the model's weakest case.
- **Not reproducible.** The same prompt returns different pixels, so a diff of
  two generations means nothing.

Related: `cpg-advice` (the text lane over the same client), `cpg-storybook`
(plates for a finished book).
