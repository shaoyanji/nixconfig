# Storybook audio — narration, cues and the music bed

Moved out of the `.agents/skills/cpg-storybook` body when it passed its 400-line
budget. The skill is the run; this is the audio half: what the voices are, how
the cues are placed, and the measurement that picked the bed level.

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
- **Range belongs to the server.** `flake/cli.nix` builds `static-serve`, which
  answers it, so a master seeks; `python3 -m http.server` re-sent from byte zero.
  The 960 px web cut (7.3 MB for `pip`) stays a bandwidth saving, not a workaround.
- **A 28-spread narration is 4 minutes of clanker work, not 40 seconds.** One
  job, 29 lines: 4m04s wall for 528 s of speech at 134 wpm (`--length_scale
  1.5`).
- A spread whose wav is much longer than its words suggests is not a slow voice —
  measure `silencedetect` before inventing a `--length_scale` for it.

### Sound, for real

```bash
python3 …/sfx.py fetch --project $PWD     # 12 CC0 clips into audio/sfx/ + credits
python3 …/sfx.py cues  --project $PWD     # sfx.json: which clip sits on which page
python3 …/sfx.py music --project $PWD     # a 60 s CC0 music bed, audio/music/bed.wav
python3 …/media.py mix --project $PWD …   # picks up sfx.json and the bed by itself
```

The clips come from Freesound through the **Openverse** API filtered to `cc0`,
so a published book needs no licence argument — and `credits.json` plus
`site/sfx.html` are written anyway, because "CC0" is a claim about a file and a
credit line is what a reader can check. The shelf is twelve cues: river,
crickets, wind, owl, birdsong, page turn, glass chime, snow footsteps, wood
creak, fireplace, oars, small bell.

**The cue plan belongs to the book, not to the shelf.** `CUES` in `sfx.py`
numbers pages `s01`–`s10` and names one book's scenes; a second book that
inherits it puts crickets on a snowdrift. `sfx.py cues` therefore reads
`<book>/sfx.plan.json` first — `{sid: [[cue, at, gain], …]}`, the same shape as
`CUES`, hand-editable — and falls back to the built-in plan only when that file
is absent. A page turn is still appended to every spread but the first.

## The music bed, and the A/B

```bash
python3 …/sfx.py music --project $PWD
python3 …/sfx.py music --project ../other-book --source ../this-book/audio/music/bed.wav
python3 …/media.py mix --project $PWD --lang de --slug lantern          # both cuts
python3 …/media.py mix --project $PWD … --only music                   # bed tweak only
python3 …/media.py mix --project $PWD … --only music --music-gain 0.30 --spreads s01,s02 --out /tmp/aud
```

The third form is the audition: two spreads instead of a book, into a directory
of its own, so a level trial is 40 seconds of encoding and cannot be mistaken for
another edition by `publish.py`.

`mix` renders two books from one command: the cue-only cut and the same book
with the bed (`-music` suffix). Same narration, same cues, one variable — which
is what an A/B is. `publish.py` serves the music cut, links `mix.html` beside
it, and that page plays both with the measured difference between them.

A series should sound like a series: `--source` copies another book's shaped
bed and its credit instead of re-running the query and hoping for the same
top hit.

The bed is ducked by the narration itself rather than by a hand-drawn volume
envelope: `sidechaincompress` keyed on the voice, 3:1 above 0.05. Measured on
the lantern book's delivered web cut, 0.05–0.55 s in — a window with music and
cues but no words, so it isolates the bed:

| Gain | Pre-roll, s01 | Under the voice (1.2–3.2 s) |
| :--- | :--- | :--- |
| none (cues only) | −48.1 dBFS | −15.4 dBFS |
| 0.16 (shipped) | −36.4 dBFS | −15.4 dBFS |
| 0.22 | −33.8 dBFS | −15.3 dBFS |
| 0.30 | −31.1 dBFS | −15.4 dBFS |

The duck is what makes the last column flat: the bed is 16 to 25 dB under the
voice depending on the gain, and 0.0 dB of it survives under a word. So the gain
only decides how much is heard in the pauses, and one dial tunes the whole book.
The loop is per spread: the same pre-roll measured −34.0 / −34.3 / −34.8 / −35.1
at 0.22 on s07 / s14 / s21 / s28 of a 573 s book.

The default is **0.16**, chosen by the rule for a book read at bedtime: the bed
should be findable, not followable. Where the two failure modes are "too quiet"
(a listener turns it up, nothing is lost) and "too present" (a listener stops
playing it), a level picked without an ear in the loop goes low. `site/bed.html`
on the lantern serves both 0.16 and 0.30 on the same two spreads with the numbers
above, so the pick can be overturned in one command rather than an argument.

History, because both mistakes are cheap to repeat: gain 0.07 measured −42.8 dBFS
and a 6:1 duck erased it entirely; that reads as a hole, not a bed.
`mix-<lang>-<voice>.json` keeps both windows, so the numbers on `mix.html` are
measurements of the files the browser gets, not of the filter.

The masters are large — 129 MB for 28 spreads at crf 20, 40 MB for the 960 px
web cut — which is why the page serves the web cut and the A/B page does too.
