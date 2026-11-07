---
name: cpg-storybook
description: Print a picture book through the image allowance — paced, resumable, budget-aware, and stopped before the lifetime generation cap.
version: 1.0.0
tags: [ai, chatplayground, images, creative, budget]
platforms: [linux, macos]
---

# cpg-storybook

A book directory holds a manifest; this skill spends image generations on it
one at a time, paced to the account's rate limit, with a ledger so a killed run
resumes instead of re-spending.

```bash
cd ~/Documents/storybook/<book>
python3 ~/Documents/nixconfig/.agents/skills/cpg-storybook/scripts/storybook.py budget
python3 …/storybook.py status
python3 …/storybook.py gen --spread s01        # 3 candidates, paced
python3 …/storybook.py run --limit 4           # next four spreads
python3 …/storybook.py choose --spread s01 --candidate 2
python3 …/storybook.py finalize                # finals/ + book.md
```

`STORYBOOK_DIR` overrides the project directory when the script is not run from
inside it.

## The budget is daily, and it resets quietly

Measured on the `unlimited` lifetime plan:

| Number | Value | Meaning |
| :--- | :--- | :--- |
| `limits.imageGenerations` | 100 | per day |
| `usage.imageGenerationsCount` | counts up | spent since 00:00 UTC |
| `usage.lastDailyImageDate` | date | the day the counter belongs to |
| rate | 25/1h, 250/1d | 25/h is the real pacing constraint |

2026-11-07, 00:05 UTC: the counter that had reached 100 read 98 after two
generations on the new date. Nothing in the entitlement says "daily" — the
`periodEnd` is 2146 and `unlimited.imageGenerations` is `false` — so a run that
crosses midnight sees `remaining` jump, and a run that plans as if it were
one-shot leaves most of a day unused.

Plan the *day*, not the artefact: 100 generations, 25 an hour, and no
carry-over. `budget` reads the counter every call, so it is correct on both
sides of midnight.

## Manifest

```json
{
  "title": "…",
  "style": "children's picture book illustration, 1950s British ink-and-wash, …",
  "model": "gpt-image-2.5-sunburst",
  "size": "1536x1024",
  "candidates": 3,
  "spreads": [
    {"id": "s01", "page": 1, "text": "…", "scene": "one moment, no text", "candidates": 3}
  ]
}
```

`style` is the consistency contract and is prepended to every `scene`. Keep
character descriptions *in the style block* (species, colour, clothes), because
each generation is stateless — a character not described is a character
reinvented.

## Pacing a wall-clock window

`--min-interval` is seconds between images. 25/h is 144 s floor.

- Burn-in (supervised): `145` — the first spreads arrive fast enough to judge.
- Steady: `300`–`330` — 82 images span ~7.5 h, which is how a 97-generation
  book fills a nine-hour slot instead of finishing in four.
- Leave the floor alone: the hourly window is the server's, and a burst is a 429
  plus a retry, not a faster book.

## Supervision checkpoints

1. **Three images of one scene before any bulk run.** If the style block is
   wrong, that error is in all 84 plates and the allowance cannot redo them.
2. **First four spreads, viewed.** Look for the same three failures: character
   drift, text/lettering baked into the art, and a composition that leaves no
   room for the prose.
3. **Every flagged spread, re-rolled while budget remains** — a named defect
   (`Toad's waistcoat changed colour`) is re-rollable; "make it nicer" is not.

## Running it detached, and restarting it

```bash
systemd-run --user --unit storybook-steady --collect \
  -p WorkingDirectory=$HOME/Documents/storybook/<book> \
  /usr/bin/env python3 …/storybook.py run --min-interval 320
systemctl --user stop storybook-steady
pgrep -af 'storybook[.]py' || echo clear   # a stop returns before the child does
```

The printer takes an exclusive `flock` on `state/printer.lock`, so a second
printer exits instead of racing for the hourly window. It also treats a spread
as done when a plate exists on disk, not when the ledger says so — a ledger row
outlives an archived style, and resuming from it silently skips pages.

`publish.py` builds the browsable book.

`review.sh` is one review pass for a timer: it lists the spreads that have
plates but no choice, hands them to an agent with the judging order, and lets it
`choose`. A vision tool that answers 429 means the pass judges nothing; it must
leave spreads unchosen and say so, never pick blind.

## Publishing a finished book

```bash
python3 …/storybook.py finalize      # finals/ + book.md
python3 …/publish.py --project $PWD  # site/index.html + web JPEGs
python3 -m http.server 8899 --bind <tailnet-ip> --directory site
```

`publish.py` prefers `finals/`, falls back to the chosen candidate, re-encodes
1400 px JPEGs (a 1536×1024 PNG per spread is 3 MB, so a book of them is a
download), and writes `site/READY` only when every spread has a plate — the
exit status is the contract, the partial `index.html` is a preview.

Binding the server to the Tailscale address is what keeps a demo on the tailnet:
no `0.0.0.0`, no `tailscale serve`, no firewall rule to forget.

Books live on the pool, `/Volumes/data/projects/storybook/<book>` (the
`projects/` tree in [`docs/storage-taxonomy.md`](../../../docs/storage-taxonomy.md)),
with `~/Documents/storybook` a symlink to it — 500 MB of plates is not home
storage. `readlink -f` the project dir before trusting a path: the symlink is
invisible to `pwd`, and a unit that pins `%h/Documents/...` keeps working while
an `rm -rf` of the home tree is not a backup. `storybook-serve` (8899) and
`storybook-pips-serve` (8898) run the demos from the canonical path.

## Narration: voices on clanker, mixing here

An English book is adapted first, then spoken, then mixed. The adaptation is a
`cpg-speculate` round in the target language landing as `script.<lang>.json`
(the same shape as `book.md`, one `id` per spread), because the pictures already
fix the count and the nouns: the translator's job is to sound German, not to
re-decide the page.

```bash
python3 …/media.py voices                       # the speech shelf and what each voice is
python3 …/media.py bakeoff  --project $PWD --lang de --line "<a line with umlauts>"
python3 …/media.py say      --project $PWD --lang de --voice de_DE-thorsten-high
python3 …/media.py mix      --project $PWD --lang de --voice de_DE-thorsten-high
```

`bakeoff` writes `site/voices.html` — every German voice on one line, in the
browser, because a voice is chosen by ear and a duration table cannot do it.
`say` synthesises every spread plus the title and pulls the wavs back;
`mix` puts narration over its plate with a slow zoom and a noise-derived river
bed, then concatenates. Outputs: `audio/<lang>/<voice>/`, `video/<book>.mp4`
(full) and `.web.mp4` (960 px, for a demo page).

**The speech is offline VITS on `clanker`, and that is deliberate.** piper is
minutes of CPU work with a file as the result, it spends no model quota, and
`instabox` already carries a job box with a 120-minute clock. This box keeps the
plates and runs `ffmpeg`. One job pushes every line, not one ssh per spread:
ten round trips is ten chances to lose the clock.

Measured on `de_DE-thorsten-high`, 2026-11-07:

| | |
| :--- | :--- |
| piper 1.8.0 from nixpkgs | `nix profile add nixpkgs#piper-tts`, substituted not built |
| voices | downloaded from `rhasspy/piper-voices` (the `.onnx` *is* the model) |
| `--length_scale 1.0` | 4.8 s for a 16-word spread — 200 wpm, a news bulletin |
| `--length_scale 1.5` | 6.2 s — about 150 wpm, the default here |
| sample rate | 22050 Hz on `high`, 16000 on `low`/`x_low`; mix normalises to 44.1 kHz |

Traps that cost a run:

- **A JSON string is not a shell string.** `json.dumps("müde")` is `"m\u00fcde"`,
  and piper reads the escape out loud: every umlaut word came back spelled letter
  by letter, at durations that looked like a broken model. Quote with
  `shlex.quote`, and read a duration that disagrees with the word count as a
  text bug before blaming the voice.
- **`amix` divides by its input count.** The first mix measured −22.7 dB mean
  against the −16 the narration was normalised to; `normalize=0` is required.
- **`http.server` has no Range.** A 28 MB master cannot be seeked until the whole
  file arrives, so the page points at the 960 px web cut (7.3 MB).
- A spread whose wav is much longer than its words suggests is not a slow voice —
  measure `silencedetect` before inventing a `--length_scale` for it.

Ambience is synthesised (`anoisesrc` → lowpass → fade), so nothing in a published
book is a licensed sample. Real SFX and a second language are open work.

## Probing the wall on purpose

```bash
python3 …/limit-probe.py --project $PWD --candidates 5 --attempts 40
```

`limit-probe.py` paces nothing. It issues generations back to back, using the
next missing candidate of each spread so the plates stay usable, and records
every response in `state/probe-<stamp>.jsonl`: rc, seconds, and the endpoint's
own error text. It stops after three consecutive failures and prints one JSON
summary — attempted, ok, failed, the usage counter before and after, and the
first refusal.

The refusal is the result. A `429` with a rate message before the counter reaches
the allowance means the hourly window binds first; a failure only after the
counter hits `limits.imageGenerations` means the daily allowance does. Record
either in an xs turn: a limit that was never hit is a limit you cannot plan
against.

Measured 2026-11-07, `gpt-image-2.5-sunburst`, unpaced: 25 attempts, 21 plates,
615 s, counter 78 → 100. The last three returned
`429 image generation failed with status 429: "You've reached your daily limit of
100 image generations"` within 1 s each — the quota refuses instantly, so a
probe that is out of budget costs seconds, not minutes. The daily counter binds
long before the 25/h window can (the burst ran at ~150/h and was never
throttled), and the entitlement's `250/1d` rate is not the number that stops a
run.

## Failure behaviour

- `401`: the session died. `cpg status --json`; this needs a browser login, not
  a retry loop.
- `400 … model is not supported`: the id was retired — re-read
  `cpg models --json` instead of retrying.
- `429`/5xx: one retry after 90 s, then the spread is left for the next pass.
- Empty candidate file: the ledger records `ok: false`, so the spread is retried
  on resume rather than counted as spent.

Related: `cpg-image` (single images and the failure table), `cpg-advice`
(the prompt budget), `cpg-speculate` (many cheap drafts, one graded winner).
