---
name: cpg
description: "chatplayground through one client, four lanes: one prompt to another model, one image, a four-lane graded round, or a whole picture book — and the two budgets they draw on."
version: 3.0.0
tags: [ai, chatplayground, images, advice, sampling, storybook, budget]
platforms: [linux, macos]
---

# cpg — one client, four lanes, two budgets

`cpg` is the fleet's chatplayground client, declared in
`modules/user/ai/hermes-user.nix`. Everything below drives that one binary: one
call, one answer, no server and no daemon.

It is a CLI call on purpose, not a provider. The endpoint takes exactly one
message of at most 15,000 characters ("Send only the new prompt. Conversation
history is not accepted."), while a hermes turn's system prompt plus tool schemas
is ~29,000 characters — so `--provider chatplayground` always falls through to
the next provider. Shelling out is the only shape that works.

Two budgets, and they are not interchangeable:

| Budget | Number | Read |
| :--- | :--- | :--- |
| prompts | 350/day, 4 concurrent compare slots | `cpg usage --json \| jq .usage.dailyQueries` |
| images | 100/day, reset 00:00 UTC | `entitlement.limits.imagesPerDay` − `usage.images.used` |

`unlimitedQueries: true` and `usage.images.remaining: "unlimited"` are the plan's
name, not the day. `cpg usage` is the authority on the plan; the catalog is not.

## Before any lane: session and counter

```bash
cpg status --json | jq -e '.authenticated'
cpg usage  --json | jq '{prompts: .usage.dailyQueries, images: .usage.images}'
cpg refresh     # prints "Successfully refreshed Clerk token!" on success
```

The session token lives 60 seconds and is minted from the stored `__client` cookie
in `~/.chatplayground/auth.json` (0600 — a rotating session, not a sops secret).
The hourly `chatplayground-refresh` timer keeps a live session warm and cannot
resurrect a dead one: re-harvest from a browser rather than minting a token by
hand. A 401, an `UNAUTHENTICATED` body or a bare `Sign in to continue` is
`cpg refresh` once and retry once; only a failed refresh needs the browser login
(`chatplayground-go login`).

## Lane 1 — text: one prompt, one answer

The lane for a question whose answer you will read once: review, a second opinion,
a draft of something you can check.

```bash
cpg chat -m gpt-6-luna -s advice-nix "A NixOS module sets services.foo.enable = true
but the unit starts before network-online.target. What breaks first?"
```

- Prints the reply and exits; status 1 on failure. `-s NAME` is the session: the
  thread lives server side and is mirrored to `~/.chatplayground/sessions/NAME.json`
  (0600). Reuse a name to continue a thread, a new name for a clean one.
- Output is ANSI-coloured; strip it before parsing or quoting:
  `| sed -e $'s/\x1b\[[0-9;]*m//g'`. A one-shot `cpg chat` writes bare text when
  stdout is not a TTY, which is why the pipelines below work.
- **The material goes in the prompt, not on stdin.** Piped stdin is read only
  when no prompt argument is given, so `git diff | cpg "review this"` sends
  `review this` alone and drops the diff. Inline it instead:
  `cpg -m deepseek-v4.1-flash "Review this diff for bugs. Ten lines max, no preamble.
  $(git diff)"`
- **15,000 characters is a wall, not a target.** The model cannot read files, fetch
  a URL or run a command. Summarise or split; never truncate silently.
- **Pick a different vendor from the model you are running on**, and stay with an
  id whose answers you have already judged. `premium_only` is a global flag, not an
  answer about this account: 10 of 11 premium ids answer
  `403 only available to active subscribers` on the lifetime pool, `gemini-3.8-flash`
  the exception. Ids exercised on this account: `gpt-6-luna`, `claude-haiku-5-5`,
  `deepseek-v4.1-flash`, `gemini-3.8-flash-l`, `kimi-k2.6`, `qwen3.7-plus`,
  `glm-5.3-flash`, `grok-4.7`.

The split that makes the lane worth its prompt: **the agent owns facts, the lane
owns voice.** A path, a version, a count — the agent verifies and puts it in the
packet; the lane gets "write this". A lane asked to recall facts writes confident
fiction. Ask for the shape you will consume ("three bullets", "JSON with keys
a,b"), and edit rather than adopt: the reply has no access to the repo.

`scripts/task/cpg-review.sh` behind `task agents:review:*` wraps the six lanes
that earn a prompt — `gate`, `plate`, `plan`, `schema`, `adversary`, `draft`.
`DRY=1` prints the packet and sends nothing; the packet is capped at 15,000 and
the script refuses rather than truncating.

## Lane 2 — image: one call, one PNG

```bash
cpg image --json -o "$HOME/Pictures/cpg/icon.png" \
  "a flat red panda icon, 2px outline, white background, 1024x1024"
```

Returns `{id,url,prompt,model,size,path}`; a failure prints
`{"error":"image generation failed with status 400: …"}` and exits 1, so a script
branches on the exit status. A 1024×1024 generation takes 13–16 s.

- Omit `-m`. The CLI resolves the first free image model from the live catalog;
  naming a retired id is a `400 The model is not supported`
  (`gpt-image-2` answers exactly that). Re-read the catalog instead of retrying:
  `cpg models --json | jq -r '.[] | select(.group == "image") | .id'`.
- Sizes: `1024x1024` (default), `1536x1024`, `1024x1536`, `auto`.
- **`-o` is the only way to get a file.** The returned URL is session-gated and a
  bare fetch answers 401. Write under `~/Pictures/cpg/` for anything a human will
  look at — a platform send takes a path, not a URL — and `/tmp` when the image is
  only input to the next step.
- **Spend generations only on what a model can do.** Crop, resize, grade, overlay
  and repeat locally. One composed prompt beats three variations; re-roll on a
  named defect ("the cube is off-centre"), never to shop for a better idea.
- Plan a batch as **20 plates, then a pause**. On 2026-11-10 a 26-plate batch in
  30 minutes answered `RATE_LIMITED` with 74 images unspent: the burst bucket is
  not in the payload, and a 429 with images left is that bucket, not the day.
- Not editing (the chat `-i` flag is vision input, not image-to-image), not
  typographic (spelling is the model's weakest case), not reproducible (the same
  prompt returns different pixels, so a diff means nothing).

An asset built for a site is not finished when the PNG exists: upload to
Cloudinary (`scripts/task/cloudinary.sh`), rebuild the manifest
(`task images:publish`), then deploy the pages (`scripts/task/pages-deploy.sh`
through `scripts/task/wrangler.sh`). A PNG committed to the repo is bytes nobody
can resize and every clone pays for; a hand-edited manifest is overwritten by the
next publish.

## Lane 3 — speculate: four lanes, one graded winner

`.agents/skills/cpg/scripts/speculate.sh` asks N cheap models the same question
in parallel, has Jev pick, and prints one answer. The agent spends context on the
winner instead of on four drafts.

```bash
.agents/skills/cpg/scripts/speculate.sh \
  "In two sentences: when should a NixOS module use mkDefault instead of mkForce?"
# → the winning answer, nothing else
# stderr: speculate: 4 lanes, Jev chose c0 (gpt-6-luna) p=0.94 m=0.88 [selected]
```

- `--json` → `{question,candidates,decision,winner:{label,model,text}}`; `--all`
  adds every lane plus `chosen`, for a verdict at p=0.65 / m=0.48 where the reader
  wants the other three answers.
- **A lane has no tools**: no filesystem, no clock, no repo, no memory of this
  conversation. `--context FILE` prepends the packet, and the packet is the whole
  world the model gets. Under 1,500 characters, facts only (no instructions),
  today's date and host when the question turns on them, what it cannot see
  (conventions, schema, audience). One packet per project, reused across rounds.
- **The ledger is the only durable answer to "which model writes this?"** Every
  graded round appends a JSONL row (`~/.local/state/cpg-speculate/winners.jsonl`,
  `--ledger PATH`, `--no-ledger` for experiments):
  `jq -r '[.label,.winner_model,.probability,.status]|@tsv' … | sort | uniq -c | sort -rn`.
- Jev grading is a Typesafe call of ~1 s, not a prompt, and its input is the
  candidates (2,000 characters each). `needs_review` is a draft signal, not a
  veto — read the `p=`/`m=` line before trusting a close winner.
- Default lanes: `gpt-6-luna`, `mimo-v2.6-pro`, `gemini-3.8-flash-l`,
  `deepseek-v4-pro` — different vendors on purpose; four models rarely fail the
  same way. A lane that 403s or times out is dropped and the round continues.
- Rounds, not prompts, are the unit to plan: 350/day ÷ 4 = 87 rounds, ~75/h; a
  burst of 12 rounds exhausts the ten-minute window, so space them.
- Run one for a design trade-off where a confident wrong answer is expensive, a
  diagnosis with several plausible causes, or naming. Not for anything needing
  tools, files or the web, and not for a long document — there is no chunking.

## Lane 4 — book: the image allowance, paced and resumable

`.agents/skills/cpg/scripts/storybook.py` spends generations on a book directory
that holds a manifest, one at a time, with a ledger so a killed run resumes
instead of re-spending.

```bash
cd ~/Documents/storybook/<book>
python3 …/.agents/skills/cpg/scripts/storybook.py budget
python3 …/storybook.py status
python3 …/storybook.py gen --spread s01      # 3 candidates, paced
python3 …/storybook.py run --limit 4         # next four spreads
python3 …/storybook.py choose --spread s01 --candidate 2
python3 …/storybook.py finalize              # finals/ + book.md
```

`STORYBOOK_DIR` overrides the project directory when the script is not run from
inside it. The manifest is the contract:

```json
{"title": "…", "style": "children's picture book illustration, 1950s British ink-and-wash, …",
 "model": "gpt-image-2.5-sunburst", "size": "1536x1024", "candidates": 3,
 "spreads": [{"id": "s01", "page": 1, "text": "…", "scene": "one moment, no text", "candidates": 3}]}
```

`style` is prepended to every `scene`. Keep character descriptions *in the style
block* — every generation is stateless, so a character not described is a
character reinvented. Plan the day, not the artefact: 100 generations, no
carry-over, and `budget` reads the counter on every call so it is correct on both
sides of midnight.

- **`--min-interval` is seconds between images.** 145 for a supervised burn-in,
  300–330 for a steady run (82 images over ~7.5 h). The hourly window is the
  server's; a burst is a 429 plus a retry, not a faster book.
- **Three images of one scene before any bulk run.** A wrong style block is in
  all 84 plates and the allowance cannot redo them.
- **First four spreads, viewed**, looking for the same three failures: character
  drift, text baked into the art, a composition with no room for the prose.
- Re-roll every flagged spread while budget remains; a named defect
  (`Toad's waistcoat changed colour`) is re-rollable, "make it nicer" is not.
- Detached, the printer takes an exclusive `flock` on `state/printer.lock`, so a
  second one exits instead of racing:

```bash
systemd-run --user --unit storybook-steady --collect \
  -p WorkingDirectory=$HOME/Documents/storybook/<book> \
  /usr/bin/env python3 …/storybook.py run --min-interval 320
systemctl --user stop storybook-steady
pgrep -af 'storybook[.]py' || echo clear   # a stop returns before the child does
```

A spread counts as done when a plate exists on disk, not when the ledger says so:
a ledger row outlives an archived style, and resuming from it silently skips pages.

`publish.py` prefers `finals/`, falls back to the chosen candidate, re-encodes
1400 px JPEGs and writes `site/READY` only when every spread has a plate — the
exit status is the contract, the partial `index.html` is a preview. Serve it on
its own port bound to the Tailscale address; do not mount it on `tailscale serve`,
because `frieren.<tailnet>.ts.net:443` belongs to nginx and a serve mount takes
the whole listener. The hand-written `storybook-serve` (8899) and
`storybook-pips-serve` (8898) units pin the project path on the pool,
`/Volumes/data/projects/storybook/<book>` — see `docs/storage-taxonomy.md`; plates
are not home storage.

Adapting, narrating and mixing are a second pass over a finished book:
`adapt.py` (one `speculate.sh` round per chunk of spreads, resuming from
`state/adapt-<lang>.json`), `compare.py` (a hand edition against a round, page by
page), `media.py` and `sfx.py` (offline piper speech, CC0 cues, a mixed bed).
Voices, cue placement, ducking and every trap that cost a run are in
`docs/storybook-audio.md`; the probe numbers that bound the allowance are in
`references/measured.md`.

## The loop: a validated command per turn

`scripts/task/cpg-loop.sh` (`task agents:loop:run`) turns these models into an
executor: one command per turn in the same YAML contract, refused against a deny
list (delete, push, service restart, decrypt, sudo, a pipe into a shell), run
under `timeout` in a scratch directory — inside `bwrap` when installed — with the
exit status and output tail fed to the next turn.

```bash
task agents:loop:run GOAL=/tmp/goal.md STEPS=6 VERIFY='test -s out.txt'
task agents:loop:run GOAL=/tmp/goal.md DRY=1                  # first packet, no cost
bash scripts/task/cpg-loop.sh --check-command 'rm -rf /'      # deny list, no cost
```

`stop: true` is a request, not a result: the run exits 0 only when `VERIFY=`
exits 0, and 4 with the goal unverified. One answered call costs about 7 of the
350 queries — about 50 turns a day — and it exits 6 rather than begin a turn the
counter cannot pay for. Ledger and per-turn actions land in
`~/.cache/cpg-loop/<goal-slug>/` beside a lock that makes a second run refuse.

A scheduled goal is not an ad-hoc one: the fleet's declarative path is
`services.agentScheduler.jobs` on frieren (`frieren-offload` skill), which is a
deploy. Until a goal earns a job, run it in a `tmux` session (`tmux` skill).

## Ask for YAML in a shape you name

Never "a schema" in prose. `scripts/task/llm-yaml.sh` cleans the reply (fence
lines, a leading "here it is" sentence, CRLF, a wrapping backtick) and parses it,
with `--map` rejecting a reply that is technically YAML because a bare scalar is
YAML. A `schema` or `adversary` answer that does not parse, or parses into the
wrong shape, exits 1: the shape is the contract, so "it looked right" is not a
result.

## Piping an answer into Jev

The reply is text and `jev-decide` reads text, so one model can write and the
classifier can score what it wrote. Keep the criteria about the *answer*
(`actionable`, `hedged`, `off_topic`), not the question:

```bash
cpg chat -m gpt-6-luna -s advice-review "Critique this plan in three bullets: …" \
  | jev-decide classify --provider typesafe \
      --text-file - --criteria /tmp/answer-quality.json
```

A low probability means "read it yourself", never "discard it". Route the lane
with `jevdecide`; a decision model never authorises a destructive action.

## When it fails, by lane

| Symptom | Cause | Move |
| :--- | :--- | :--- |
| `401`, `UNAUTHENTICATED`, `Sign in to continue` | 60 s session died | `cpg refresh`, retry once; then browser login |
| `522` / timeout on every call | `app.chatplayground.ai` is retired | the build, not the account: `web.chatplayground.ai` |
| `400 … The model is not supported` | the id was retired | re-read `cpg models --json`; never retry the id |
| `429`, `remaining` above zero | burst bucket or the ten-minute window | back off 60 s, 120 s, 240 s; a fourth failure is a spent window |
| `429 … daily limit of 100` | the day's images are gone | `cpg usage` says when it resets; there is no queue |
| `Message cannot exceed 15,000 characters` | prompt too large | shrink or split; do not retry |
| `403 only available to active subscribers` | a premium-only id | pick a free one |

Two failures are distinguishable before anything leaves the machine: a spent
allowance answers `429 … reached your daily limit`, an unreachable host answers
`lookup … no such host`. Do not plan a DNS outage as tomorrow's budget —
`cpg usage` cannot answer then, and the dashboard at `www.chatplayground.ai`
prints the same counters.

## Use it for, and not for

For: a design choice you are 60/40 on, adversarial review of your own diff or
plan, naming and wording, one image or a book of them, a differential on a
diagnosis, a shape the harness needs filled.

Not for: anything needing tools, the filesystem, the web or live host state;
secrets, tokens, private mail or personal data (the prompt goes to a third-party
web chat); a task you can do, or a question whose answer is in this repo;
authorization — a second model agreeing is not permission, and a destructive step
still goes through `confirm-before-destructive`.

Related: `jevdecide` (the grader and the router), `image-generate` (the local
Qwen endpoint, when the allowance is spent), `tmux` (a run that outlives the
shell).

Truth: `scripts/task/cloudinary.sh`, `taskfiles/images.yml` — the client and the publish lane; this page is the procedure.
