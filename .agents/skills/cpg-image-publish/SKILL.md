---
name: cpg-image-publish
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
description: "Generate via cpg, upload to Cloudinary, deploy to pages."
metadata:
  hermes:
    tags: [cpg, image, publish, cloudinary, cloudflare-pages]
    related_skills: [cpg, image-generate, eisen-service-reachability]
---

# cpg-image-publish — image generation and publishing pipeline

Class of work: generate one image via the cpg chatplayground client, upload it to
Cloudinary, rebuild the `published/urls.tsv` + `manifest.json`, and deploy to
Cloudflare Pages (bountystash-assets.pages.dev). This is the recurring image
publish workflow (nightly slots, wallpapers, plates).

The base `cpg` skill covers Lane 2 (image generation) and the publish lane at
overview level. This skill carries the operational procedures, gotchas, and
workarounds that cost time on repeat runs.

## Routing preference (standing rule)

Use the cpg image route first. The eisen Qwen API (`image-generate` skill) is a
backup only — use it only when cpg is not viable and eisen is verified online
(`eisen-service-reachability` skill). Do not power on eisen and do not assume
it is online; verify reachability before calling it.

## Step 1 — authenticate

```bash
cpg status --json | jq -e '.authenticated'
cpg usage  --json | jq '{prompts: .usage.dailyQueries, images: .usage.images}'
cpg refresh   # once, if not authenticated
```

The Clerk token lives 60 seconds. A 401 / `UNAUTHENTICATED` / `Sign in to continue`
gets one `cpg refresh` and one retry; a failed refresh needs browser login
(`chatplayground-go login`).

## Step 2 — generate (Lane 2)

```bash
cpg image --json -o "<out.png>" "<concrete subject and style prompt>"
```

- Omit `-m`; the CLI resolves the first free image model from the live catalog.
  `cpg models --json | jq -r '.[] | select(.group == "image") | .id'`
- Sizes: `1024x1024`, `1536x1024`, `1024x1536`, `auto`. A 1024×1024 generation
  takes 13–16 s.
- `-o` is the only way to get a file. The returned URL is session-gated (401 on
  bare fetch), so upload to Cloudinary before reporting the URL.
- Returns `{id,url,prompt,model,size,path}`; failure exits 1.
- Not editing, not typographic, not reproducible — same prompt returns different
  pixels.

## Step 3 — rate limiting (429)

A `429 RATE_LIMITED` can arrive with images still left in the daily allowance —
that is the burst bucket or the ten-minute window, not the day.

- Read `retryAfterMs` from the error body and wait that window before retrying.
  Fixed backoffs (60 / 120 / 240 s) are only a fallback.
- A fourth failure is a spent window; stop and read `cpg usage`.
- `429 … daily limit of 100` means the day's images are gone; no queue.
- `429 … reached your daily limit` vs `lookup … no such host` are distinguishable
  before anything leaves the machine.

## Step 4 — upload to Cloudinary

```bash
bash scripts/task/cloudinary.sh upload <file> --public-id assets/<rel>
```

- Credentials come from sops `CLOUDINARY.{NAME,API.KEY,API.SECRET}` via
  `scripts/task/cloudinary.sh` — no interactive login, same rights unattended.
- The Cloudinary delivery URL carries the resize (one upload serves card,
  thumbnail, retina hero). A failed upload is reported, not fatal — the PNG stays
  on disk and a later publish sends it.

## Step 5 — rebuild manifest (`task images:publish`)

```bash
task images:publish
```

- Copies accepted plates into `/Volumes/data/pics/generated/published/`, uploads
  each to Cloudinary, writes `published/urls.tsv`, rebuilds `manifest.json`.
- Idempotent per pass; `DRY=1` counts, `FORCE=1` skips merges, `REUPLOAD=1`
  re-sends.
- The manifest is the contract — a hand-edited manifest is overwritten by the
  next publish.

## Step 6 — deploy to Cloudflare Pages (pitfall: wrangler PATH)

```bash
bash scripts/task/pages-deploy.sh /Volumes/data/pics/generated/site-dist \
  --project-name=bountystash-assets --branch=main
```

**Pitfall:** `scripts/task/images-publish.sh` runs `pages-deploy.sh` directly and
fails with "wrangler is not on PATH and nix could not resolve it" — unlike
`image-daily.sh`, which wraps the deploy in `nix-shell -p wrangler`. Ensure
`wrangler` is available before the deploy step:

```bash
nix-shell -p wrangler --run "bash scripts/task/pages-deploy.sh <dir> \
  --project-name=bountystash-assets --branch=main"
```

- `pages-deploy.sh` waits until the deployment's own pages.dev hostname serves
  `/` (wrangler prints "complete" before the asset manifest attaches — that early
  exit is not proof of success).
- `wrangler login` is an OAuth device grant whose token lives five minutes and
  cannot refresh in an unattended shell; use `CLOUDFLARE.API.TOKEN` from sops
  via `scripts/task/wrangler.sh`.

## Verification

- Confirm the new asset appears in `published/manifest.json` and
  `published/urls.tsv`.
- Confirm the pages.dev hostname serves the image (HTTP 200).
- A PNG committed to the repo is bytes nobody can resize — never commit the
  render; publish the Cloudinary delivery URL instead.

Related: `cpg` (overview), `image-generate` (eisen Qwen backup), `bountystash`
(Cloudflare Pages control), `prove-it-works` (verify against real artifact).

Truth: `scripts/task/images-publish.sh`, `scripts/task/pages-deploy.sh`,
`taskfiles/images.yml` — the publish lane; this page is the procedure.
