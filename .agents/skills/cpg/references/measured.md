# cpg — the measurements behind the rules

The `cpg` body states the rules; this file is the evidence, kept so a later reader
can tell a measured limit from a guessed one. Re-measure before relying on a
number older than the plan.

## The image allowance, probed on purpose

`.agents/skills/cpg/scripts/limit-probe.py` paces nothing: it issues generations
back to back, using the next missing candidate of each spread so the plates stay
usable, and records every response in `state/probe-<stamp>.jsonl` (rc, seconds,
the endpoint's own error text). It stops after three consecutive failures and
prints one JSON summary — attempted, ok, failed, the counter before and after,
the first refusal.

Measured 2026-11-07: 25 unpaced attempts, 21 plates, counter 78 → 100, then
`429 … daily limit of 100` within 1 s each. The daily counter is the only limit
this account enforced at that moment.

Measured 2026-11-10: a 26-plate batch in 30 minutes answered `RATE_LIMITED` with
74 images unspent — a burst bucket that is not in the payload.

The refusal is the result. A `429` before the counter reaches the allowance means
a window binds first; a failure only after the counter hits
`usage.images.limit` means the daily allowance does. Record either in an xs turn:
a limit that was never hit is a limit you cannot plan against.

## The budget payload

Measured on the lifetime plan, 2026-11-08:

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

Measured 2026-11-11 for prompts: `dailyQueryCap` 350, `compareSlots` 4.

## The premium ids, as this account answered them

2026-11-06: 10 of the 11 premium ids answered
`403 only available to active subscribers` — `gpt-6.1-sol`, `claude-sonnet-5-5`,
`claude-opus-5-5`, `kimi-k3`, `qwen3.8-max`, `glm-5.3` and two perplexity ids
among them. `gemini-3.8-flash` was the single exception that worked. A premium id
is a refusal in one second, not a slow call.

## Comparison runs, kept as procedure

`adapt.py` writes `script.<lang>.json` where a hand edition may already live, so
a comparison is a copy, not a destructive run:

```bash
cp script.de.json script.de.hand.json             # keep the hand edition
python3 …/adapt.py  --project $PWD --lang de      # writes script.de.json
python3 …/compare.py --project $PWD --lang de     # hand vs round, page by page
python3 …/compare.py … --html site/adapt.html     # the same, side by side
```

`compare.py` prints chars, sentence count and the flags that say where a reading
is needed: `longer ×1.44` / `shorter ×0.61` (length drift past a third),
`digits` (a read-aloud voice says "12" in the wrong language), `name:Kröte`
(a character word the glossary pins vanished from a page), `missing` / `empty`.
It does not rank the editions — which is better is a reading — and it compares the
files it is given, so a rerun never destroys the hand text it is judging.

Chunks matter: `speculate.sh` grades only the first 2000 characters of each lane,
so a whole-book prompt is judged on its opening and accepted on faith after that.
The previous chunk is carried into the next prompt so the voice does not restart
every seven pages.

Traps, all measured, for the sound pass: Openverse answers 403 without a
`User-Agent` and rate-limits anonymous callers; a Freesound hit returns the
preview mp3, not the original upload, which is what keeps the fetch keyless; the
title filter needs an avoid list (`City river ambience 2 (chatter)` is people,
not water); one-shots carry lead-in room tone, so cues are trimmed at download
and anchored where the recording peaks — a page turn lands on its plop, about
1.6 s before the cut; stacking cues needs `alimiter=limit=0.85`; `--synth-bed`
mixes a generated noise bed for a book with no sfx files.

`review.sh` is one review pass for a timer: it lists the spreads that have plates
but no choice, hands them to an agent with the judging order, and lets it
`choose`. A vision tool answering 429 means the pass judges nothing; it must
leave spreads unchosen and say so, never pick blind.
