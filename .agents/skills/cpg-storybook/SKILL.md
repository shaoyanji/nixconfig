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

Measured on the lifetime plan, 2026-11-08 (`cpg usage` reads `/api/me` now):

| Number | Value | Meaning |
| :--- | :--- | :--- |
| `entitlement.limits.imagesPerDay` | 100 | per day |
| `usage.images.used` | counts up | spent since 00:00 UTC |
| `usage.images.periodEnd` | timestamp | 00:00 UTC of the next day |
| rate | none published | the old `/api/usage` 25/h is gone |

The earlier payload carried an hourly image rate and a `lastDailyImageDate`
field; the account answers neither now, and four generations issued back to back
ran at 13–15 s each with no 429. Pacing keeps a nightly job polite — it no longer
dodges a throttle, because there is none to dodge.

Plan the *day*, not the artefact: 100 generations and no carry-over. `budget`
reads the counter every call, so it is correct on both sides of midnight.

### When `cpg usage` cannot answer

The dashboard at `www.chatplayground.ai` (subscription page) prints the same
counters: chat turns draw from a credit pool priced per model by `creditWeight`,
images from the daily 100. A chunk of `adapt.py` is four chat turns — noise —
while a book is the whole day's images, so the image counter is the constraint.

The two failures are distinguishable before anything leaves the machine: a spent
allowance answers `429 … reached your daily limit`, an unreachable host answers
`lookup … no such host`. Read the dashboard before planning a DNS outage as
tomorrow's budget.

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
nix run --builders "" .#cli.serve.static-serve -- -dir site -addr <tailnet-ip>:8899
```

`publish.py` prefers `finals/`, falls back to the chosen candidate, re-encodes
1400 px JPEGs (a 1536×1024 PNG per spread is 3 MB, so a book of them is a
download), and writes `site/READY` only when every spread has a plate — the
exit status is the contract, the partial `index.html` is a preview.

Binding the server to the Tailscale address is what keeps a demo on the tailnet:
no `0.0.0.0`, no firewall rule to forget. The address is a port, and it is easy
to mistype: 8899 and 8898 get typed as 8099 and 8098, and a wrong port reads as
a dead server rather than a typo.

Do not mount the books on `tailscale serve`: `frieren.<tailnet>.ts.net:443`
belongs to nginx (`hosts/frieren/reverse-proxy.nix`), and a serve mount takes the
whole listener, so the portal and every vhost behind that name answer with the
book. `frieren.lan` is not a way round it — it resolves to a link-local address
these servers do not bind. A served book gets its own port.

Books live on the pool, `/Volumes/data/projects/storybook/<book>` (the
`projects/` tree in [`docs/storage-taxonomy.md`](../../../docs/storage-taxonomy.md)),
with `~/Documents/storybook` a symlink to it — 500 MB of plates is not home
storage. `readlink -f` the project dir before trusting a path: the symlink is
invisible to `pwd`, and a unit that pins `%h/Documents/...` keeps working while
an `rm -rf` of the home tree is not a backup. `storybook-serve` (8899) and
`storybook-pips-serve` (8898) are hand-written user units over that path, and both
were disabled on 2026-11-07 because nothing was reading them; `systemctl --user
enable --now` one to bring a book back.

## Narration, sound and the music bed

An English book is adapted, then spoken, then mixed:

```bash
python3 …/media.py voices                      # the speech shelf and what each voice is
python3 …/media.py bakeoff --project $PWD --lang de --line "<a line with umlauts>"
python3 …/media.py say     --project $PWD --lang de --voice de_DE-thorsten-high
python3 …/sfx.py fetch|cues|music --project $PWD   # CC0 clips, cue plan, 60 s bed
python3 …/media.py mix     --project $PWD --lang de --voice de_DE-thorsten-high
```

Speech is offline VITS (piper) on `clanker` and spends no model quota; `mix` runs
here and renders the cue-only cut plus a `-music` cut, which is the A/B.
`--source ../other-book/audio/music/bed.wav` makes a series sound like a series.

Voices, cue placement, the duck measurement, the bed gain and every trap that
cost a run are in [`docs/storybook-audio.md`](../../../docs/storybook-audio.md).

## Adapting a book that is longer than one round

```bash
python3 …/adapt.py --project $PWD --lang de --chunk 7 \
  --title "Die Laterne, die stromabwärts fuhr" --subtitle "…"
```

`adapt.py` runs one `cpg-speculate` round per chunk of spreads and merges the
winners into `script.<lang>.json`. Chunks matter: `speculate.sh` grades only the
first 2000 characters of each lane, so a whole-book prompt is judged on its
opening and accepted on faith after that. The previous chunk is carried into the
next prompt to keep the voice from restarting every seven pages, and the
chunk→winner map in `state/adapt-<lang>.json` makes a rerun resume rather than
re-spend.

The round needs `cpg`. `CHATPLAYGROUND_BASE_URL` is read by `chat.go` and is worth
setting only if the host answers `/api/chat/azure`; the catalog, image and
entitlement paths hardcode `app.`.

Traps, all measured: Openverse answers 403 without a `User-Agent` and rate-limits
anonymous callers; a Freesound hit returns the preview mp3, not the original
upload, which is what keeps the fetch keyless; the title filter needs an avoid
list (`City river ambience 2 (chatter)` is people, not water); one-shots carry
lead-in room tone, so cues are trimmed at download and anchored where the
recording peaks — a page turn lands on its plop, about 1.6 s before the cut;
stacking cues needs `alimiter=limit=0.85`; `--synth-bed` mixes a generated noise
bed for a book with no sfx files.

A second language is open work: the harness takes `--lang` and a voice per
language, and only German has a script.

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

The refusal is the result. A `429` before the counter reaches the allowance would
mean a rate window binds first; a failure only after the counter hits
`usage.images.limit` means the daily allowance does. Record either in an xs turn:
a limit that was never hit is a limit you cannot plan against.

Measured 2026-11-07: 25 unpaced attempts, 21 plates, counter 78 → 100, then
`429 … daily limit of 100` within 1 s each — the daily counter is the only limit
this account enforces.

## Comparing an adaptation with a hand-written edition

`adapt.py` writes `script.<lang>.json` where a hand edition may already live, so
a comparison is a copy, not a destructive run:

```bash
cp script.de.json script.de.hand.json             # keep the hand edition
python3 …/adapt.py  --project $PWD --lang de      # writes script.de.json
python3 …/compare.py --project $PWD --lang de     # hand vs round, page by page
python3 …/compare.py … --html site/adapt.html     # the same, side by side
```

`compare.py` prints chars, sentence count and the flags that say where a reading
is needed: `longer ×1.44` / `shorter ×0.61` (length drift past a third), `digits`
(a read-aloud voice says "12" in the wrong language), `name:Kröte` (a character
word the glossary pins vanished from a page), `missing` / `empty`. It does not
rank the editions — which is better is a reading — and it compares the files it
is given, so a rerun never destroys the hand text it is judging.

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
