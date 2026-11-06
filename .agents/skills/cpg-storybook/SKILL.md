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

## The budget is lifetime, not daily

Measured 2026-11-06 on the `unlimited` lifetime plan:

| Number | Value | Meaning |
| :--- | :--- | :--- |
| `limits.imageGenerations` | 100 | total, for the life of the plan |
| `usage.imageGenerationsCount` | counts up | spent so far |
| rate | 25/1h, 250/1d | the 1d figure is not a refill |
| `unlimited.imageGenerations` | `false` | explicitly not unlimited |

So a 100-image book is a **one-shot artefact**: there is no tomorrow's batch.
Read `budget` before every pass; the script refuses to generate once
`remaining` is 0. Never spend a generation on a test when a spread needs it.

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

`review.sh` is one review pass for a timer: it lists the spreads that have
plates but no choice, hands them to an agent with the judging order, and lets it
`choose`. A vision tool that answers 429 means the pass judges nothing; it must
leave spreads unchosen and say so, never pick blind.

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
