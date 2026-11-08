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

The allowance has a second place to read it: the dashboard at
`www.chatplayground.ai`, on the subscription page. Read by hand on 2026-11-07 at
14:00 UTC, on this account:

| Row | Value | Pays for |
| :--- | :--- | :--- |
| Plan | Lifetime · RedemptionActive · never expires | nothing is metered by the plan itself |
| Credits | 257 / 99,999 · resets 2026-11-15 | **chat turns**, charged at the model's `creditWeight` — live weights are in `cpg models --json`, and the client's fixture prices a basic model at 1 and an advanced one at 5 |
| Images today | 100 / 100 · resets 00:00 UTC — 01:00 local, this host is UTC+1 | **image generations only**, one per call whatever the model; this is the counter that stops a book |

That middle label is an inference, and it is the only one the account supports:
the catalog hangs a `creditWeight` on every model and nothing else on the account
is priced per model, while no page on the site documents a credit at all. The
dashboard prints the pool without a unit, so read it as the request budget and
treat a model's weight as what one message draws from it.

The practical reading for this skill: an `adapt.py` chunk is four chat turns, a
round of four chunks is sixteen — noise against 99,999 — while one book of three
candidates per spread is 84 image calls and the whole day's 100. Credited turns
are never the constraint here; the image counter is.

Two questions that page answers when the client cannot:

- **A dead host is not an empty allowance.** That day `app.chatplayground.ai`
  answered NXDOMAIN while the dashboard showed an active lifetime plan, a live
  session (`cpg status` → `authenticated: true`, credential age under an hour)
  and images that were simply spent. The two failures do not look alike before
  anything leaves the machine: a spent allowance is an HTTP `429 … reached your
  daily limit`, an unreachable host is `lookup … no such host`. Reading the
  dashboard first is what keeps a DNS outage from being planned as if it were
  tomorrow's budget.
- **The reset is 00:00 UTC, not local midnight.** At UTC+1 the new allowance
  starts at 01:00, so a run planned for "tonight" has an hour more than the
  clock on the wall suggests — or an hour less, depending on which side of it
  you are sitting.

The dashboard is the fallback, not a second source of truth: it is a page read
by hand, the client is the JSON the scripts consume, and while both answered
they agreed with each other.

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

Do not fix that by mounting the books on `tailscale serve`.
`frieren.<tailnet>.ts.net:443` belongs to nginx — it is the fleet portal,
declared in `hosts/frieren/reverse-proxy.nix` and proxying to loopback — and a
serve mount on 443 takes the whole listener away from it, so the portal and
every vhost behind that name answer with the book instead. `frieren.lan` is not
a way round it either: the name resolves to a link-local IPv6 address, which
these servers do not bind. A book that is served at all gets its own port, and
the port is the whole address.

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

The round needs `cpg`. On 2026-11-07 `app.chatplayground.ai` answered
**NXDOMAIN** from two independent networks (`www.chatplayground.ai` still served
200, so this is the API host being withdrawn, not a resolver fault) and the
lantern adaptation was written in the agent instead. Everything except the model
call was proved with stand-ins on `PATH` — a fake `cpg` printing one chunk's JSON
and a fake `jev-decide` choosing `c1` — which exercised the prompt, the four
lanes, the parse, the merge and the resume in `state/adapt-<lang>.json`.

`CHATPLAYGROUND_BASE_URL` is read by `chat.go`, but the catalog, the image path
and the entitlement call hardcode `app.`; a base-URL switch only helps if the
host answers `/api/chat/azure`. On 2026-11-07 `web.chatplayground.ai` answered
`/api/models` 200 and `/api/chat/azure` 404, so the chat route had moved too and
the switch bought nothing. Check that host before
planning a round.

Traps, all measured:

- **Openverse answers 403 without a `User-Agent`** and rate-limits anonymous
  callers, so requests are spaced and the UA says who is asking.
- What it returns for a Freesound hit is the **preview mp3**, not the original
  upload. Fine for a CC0 sound, and it is what makes the fetch keyless.
- **The title filter needs an avoid list.** The top CC0 result for "river
  ambience" is `City river ambience 2 (chatter)` — people, not water.
- **One-shots carry lead-in room tone.** A page turn placed at 0.12 s measured
  −27.9 dB at the head of the page: the sound arrived late. Download-time
  `silenceremove` plus a cue position that matches where the recording actually
  peaks is the fix.
- **A page turn peaks at its plop, not its rustle.** The cue carries a negative
  `at` (−1.6 s) and lands on the cut, which is where a page actually turns.
- **Stacking cues needs a limiter.** Beds at 0.06–0.12 and one-shots at 0.20–0.40
  against narration normalised to −16 LUFS put the first mix at −0.9 dB peak;
  `alimiter=limit=0.85` keeps the ceiling while the mean stays −16.7.
- `--synth-bed` still mixes the generated noise bed, for a book with no sfx files.

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

Measured 2026-11-07 on the old endpoint, `gpt-image-2.5-sunburst`, unpaced: 25
attempts, 21 plates, 615 s, counter 78 → 100, the last three answering
`429 … "You've reached your daily limit of 100 image generations"` within 1 s
each. Measured again on 2026-11-08, four unpaced generations ran at 13–15 s with
no refusal at all: the daily counter is the only one this account enforces.

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
