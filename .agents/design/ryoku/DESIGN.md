# DESIGN.md — Ryoku

Design system for surfaces built in the Ryoku aesthetic: a dark, editorial
"print for screens" look — warm ink on near-black paper, hairline rules instead of
boxes, a serif display face against a geometric sans, mono eyebrows, one signal
colour, and Japanese glyphs used as section ornaments.

**Read this file when** you are building a page, a document, a TUI skin or a slide
deck that should look like ryoku.dev. It describes *how the surface should look*;
it does not describe how to build software (that is `AGENTS.md`).

**Provenance.** Tokens in §2–§6 were extracted from the live stylesheets of
`ryoku.dev` (Ryoku 1.0 "Amaterasu" site, read 2026-10-31): CSS custom properties,
font stacks, clamps, radii, transitions. Rules marked *ported* are deliberate
extensions of observed behaviour, not values lifted from the site — they exist so
this file can drive new work without re-reading the source. Typography for the
desktop UI (Inter, Material Symbols) belongs to the Ryoku *desktop*, not to this
surface language; do not mix them in.

---

## 1. Visual Theme & Atmosphere

A gallery wall, not a dashboard. Pages are almost entirely empty black with
content pinned to a single 1240 px measure; structure is drawn with 1 px rules at
13 %, 26 % and 42 % of the ink colour, never with filled panels or shadows. A
faint paper grain sits over the whole canvas so the black reads as printed stock
rather than an OLED void.

Three voices run at once, and the tension between them *is* the aesthetic:

- **Editorial serif** (Fraunces) for anything that should be read as a statement.
- **Geometric sans** (Space Grotesk) for body, UI labels and numbers.
- **Monospace** (Space Mono), uppercase, wide-tracked, for eyebrows, counters,
  section numbers and metadata — the "catalogue card" voice.

Every section is announced like a museum label: a two-digit number, a short
English name, and one kanji set apart as ornament (`01 · See it running · 見`).
Copy is dry and first-person; the visual temperature is warm, dark, quiet and
expensive. Colour is almost monochrome: the ink itself carries a warm or cool
cast, and exactly one saturated **signal** colour is allowed, reserved for the
single most important action or the current edition.

Density is low at the page level (big vertical breathing room between sections)
and high inside a block (dense mono metadata rows separated by hairlines).

**Mood:** late-night studio, ink and metal, a museum catalogue for software.
Not: neon cyberpunk, not glassmorphism, not a SaaS marketing gradient.

## 2. Color Palette & Roles

Four editions share one structure and differ only in paper tint, ink cast and
signal. Ship **one** edition per surface; swapping edition must not change layout,
type or spacing.

### Semantic roles (structure is identical in every edition)

| Token | Role | Value |
| :--- | :--- | :--- |
| `--paper` | page canvas | edition paper |
| `--paper-raised` | the only raised surface (cards, wells, media beds) | edition raised |
| `--ink` | primary text, active rules, "bone" fill | edition ink |
| `--ink-dim` | secondary text, body copy in dense blocks | edition dim |
| `--ink-muted` | tertiary text, captions | edition muted |
| `--ink-faint` | disabled, timestamps, rule labels | edition faint |
| `--line-soft` | row separators inside a block | `color-mix(in srgb, var(--ink) 13%, transparent)` |
| `--line` | default border | `color-mix(in srgb, var(--ink) 26%, transparent)` |
| `--line-strong` | section top rules, focus, selected | `color-mix(in srgb, var(--ink) 42%, transparent)` |
| `--tint5` | hover wash | `color-mix(in srgb, var(--ink) 5%, transparent)` |
| `--tint10` | pressed / selected wash | `color-mix(in srgb, var(--ink) 10%, transparent)` |
| `--signal` | the one accent: primary CTA, live state, current edition | edition signal |
| `--notice` | warnings only | `#ce5e32` |

### Editions

| Edition | Paper | Raised | Ink | Dim / Muted / Faint | Signal |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Default** (warm) | `#000000` | `#0a0a0a` | `#cdc4ba` | `#b0a9a0` / `#958f87` / `#807a73` | `#ce5e32` rust |
| **NixOS** (periwinkle) | `#0b0c1b` | `#131527` | `#c4c6d2` | `#aaacb6` / `#90929d` / `#80828d` | `#9299d3` |
| **Void** (forest) | `#05110a` | `#0b1a12` | `#c1cac4` | `#a6afaa` / `#8d9590` / `#7c8580` | `#6daf8c` |
| **Fedora** (steel) | `#030f19` | `#081824` | `#bfc9d1` | `#a5aeb5` / `#8b949b` / `#7b848b` | `#6ea5cf` |

Rules of use:

- **No light theme.** The system is dark-only. The inverted state is a *band*:
  a block with `background: var(--ink)` and text `var(--paper)` (`.bone`). Use it
  at most once per page, for the closing CTA or a pull quote.
- **One signal per view.** Signal never decorates; it marks the single primary
  action, a live indicator, or the active edition tab. Links are ink with an
  underline, not signal.
- **Never introduce a second hue.** A new accent is an edition swap, not a new
  colour. Status colours (`--notice` rust) are the only exception and are limited
  to error/warning.
- **Text on signal** is `#000`, not paper — signal is bright enough to invert.

## 3. Typography Rules

| Role | Family | Fallback stack |
| :--- | :--- | :--- |
| Display | Fraunces Variable | `"Fraunces", ui-serif, Georgia, serif` |
| Sans / UI | Space Grotesk Variable | `"Space Grotesk", system-ui, sans-serif` |
| Mono / labels | Space Mono | `"Space Mono", ui-monospace, monospace` |
| JP ornament | Ryoku JP | `"Noto Sans JP", "Hiragino Sans", sans-serif` |

Hierarchy (fluid clamps; sizes are the observed scale, tracking is the rule):

| Level | Size | Family / weight | Tracking | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Hero statement | `clamp(3.6rem, 8vw, 5.75rem)` | Fraunces 300–400 | `-0.02em` | One per page. Sentence case. |
| Section display | `clamp(2.4rem, 1.6rem + 3.6vw, 4.6rem)` | Fraunces 400 | `-0.02em` | Opens a major section. |
| Sub-head | `clamp(2rem, 1.4rem + 2.4vw, 3.4rem)` | Fraunces 400 | `-0.01em` | Below a display, same block. |
| Card title | `clamp(1.6rem, 1.2rem + 1.8vw, 2.6rem)` | Fraunces 400 | `0` | |
| Lead paragraph | `clamp(1.2rem, 1rem + 0.9vw, 1.6rem)` | Space Grotesk 400 | `0` | First paragraph after a heading. |
| Body | `clamp(1.02rem, 0.95rem + 0.4vw, 1.28rem)` | Space Grotesk 400 | `0` | Line height 1.55–1.65. |
| Dense body | `clamp(1rem, 0.96rem + 0.2vw, 1.1rem)` | Space Grotesk 400 | `0` | Inside cards and tables. |
| Eyebrow / label | `0.75rem` *(ported)* | Space Mono 400 | `0.14em`, uppercase | Section number, category, status. |
| Micro / counter | `0.7rem` *(ported)* | Space Mono 400 | `0.2em`, uppercase | Indexes, "01 / 06", version tags. |
| JP ornament | `1em`–`2.5em` | Ryoku JP 400 | `0.16em` | Section mark; `aria-hidden`. |

Rules:

- **Serif is the voice, mono is the signage, sans is the reading text.** Never set
  a paragraph in Fraunces at body size; never set a headline in mono.
- Uppercase is reserved for mono labels. Never uppercase a serif heading.
- Wide tracking is a *function of the mono face*, not decoration on sans text.
- Numbers in metadata use tabular figures and a leading zero (`01`, `9 / 17`).
- Half-width separators only: `/`, `·`, `//`. No em-dash chains inside labels.
- Maximum two families per component. A mono label may sit above a serif headline;
  a sans sentence must not be nested inside a mono label.
- Copy voice: declarative, lowercase-friendly in labels, sentence case in
  headings, no exclamation marks, no marketing superlatives.

## 4. Component Stylings

### Buttons / actions

Two shapes only, both `border-radius: 2px`, `padding: 0.7em 1.15em`, mono
`0.75rem` uppercase `0.14em` tracking.

| Variant | Rest | Hover | Active |
| :--- | :--- | :--- | :--- |
| **Primary** (signal fill) | `background: var(--signal)`, `color:#000`, no border | signal at 90 % opacity | `tint10` over signal |
| **Ghost** (hairline) | transparent, `1px solid var(--line)`, `color: var(--ink-dim)` | `border-color: var(--ink)`, `color: var(--ink)`, `tint5` | `tint10` |
| **Bone** (inverted) | `background: var(--ink)`, `color: var(--paper)` | background `#fff` at 92 % | `--ink-dim` |

Transition is `var(--snap)` (90 ms) `--ease-out`. Never animate a button's size.

### Links

Ink colour, `text-decoration: underline`, `text-underline-offset: 3px`,
`text-decoration-thickness: 1px`. Hover raises the underline colour to full ink
and does not change the text colour. Inline links inside dense copy may drop the
underline and rely on `--ink` against `--ink-dim` — never use signal for a link.

### Cards, rows and "sheets"

Cards are not boxes. A card is a **row group**: a `1px` `--line` top rule, a mono
eyebrow, then content, with `--paper-raised` used only when the block must lift
off a photographic or media background. No border on all four sides unless the
card sits inside a hairline grid, and then the grid supplies the rules (collapsed
`1px`, never doubled).

The signature component is the **sheet row**: `display: grid`,
`grid-template-columns: 1fr auto`, separated by `--line-soft`, 12–16 px vertical
padding, mono label left, value right in ink. Use it for specs, changelogs,
package lists, key/value data.

### Inputs

Hairline box, `2px` radius, `--paper-raised` fill, mono placeholder at
`--ink-faint`, focus raises the border to `--line-strong` and adds **no glow** and
no outline colour change beyond the border. Labels are mono uppercase above the
field, never floating inside it.

### Navigation

A single horizontal mono strip, uppercase `0.12em`, items separated by `0.2rem`
gaps plus a `·` or `/` glyph. Active item is full `--ink`; inactive `--ink-muted`.
No pills, no rounded backgrounds, no icons unless the icon is a mono glyph.

### Tables

Headers: mono `0.75rem`, uppercase, `0.14em`, `--ink-muted`, with a
`--line-strong` rule beneath. Body: sans `--ink-dim`; numeric columns right
aligned with tabular figures. Row hover is `--tint5` on the whole row. Zebra
striping is forbidden.

### Media

Images sit in a `--paper-raised` well, uncropped, with `filter: grayscale(1)
contrast(1.05)` at rest; on hover or when marked active they return to full colour
with `--move`. Screenshots are framed by a `1px --line` edge, not a browser chrome
mock.

### Badges / state

A mono word plus a 6 px circular dot at 50 % radius: `● live`, `○ dormant`,
`◆ flagged`. Dot colour is `--signal` for live, `--ink-faint` for inert,
`--notice` for failing. No rounded-rectangle chips.

## 5. Layout Principles

| Token | Value |
| :--- | :--- |
| `--max` | `1240px` |
| `--gutter` | `clamp(1.15rem, 4vw, 3rem)` |
| `--section-y` | `clamp(1.75rem, 4vw, 3rem)` |
| `--s1…--s8` | `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64px` |

- **Single measure.** One centred column at `--max`, gutter on both sides. Wide
  media may bleed to the gutter, never to the viewport edge, except a full-bleed
  band (plate) which is intentional and used once per page.
- **Hairline hierarchy, not nesting.** Sections are divided by `--line-strong`
  rules; subsections by `--line`; rows by `--line-soft`. Depth of nesting is read
  from rule weight, never from background colour stacking.
- **Spacing comes from the scale.** `--s*` only; a value off the scale is a bug.
  Section rhythm = `--section-y` above and below a rule.
- **Asymmetry inside symmetry.** A block may split into `1fr auto` or
  `minmax(0,1fr) minmax(0,0.6fr)`; it may not use arbitrary percentages.
- **Text measure** is 62–72 characters. Long-form blocks cap at ~68ch even though
  the grid is wider; whitespace on the right is the point.
- **Labels left, values right.** Metadata lives at the edges; prose lives in the
  measure.

## 6. Depth & Elevation

There are exactly four levels and none of them is a shadow.

| Level | Surface | How it reads |
| :--- | :--- | :--- |
| 0 | `--paper` | the page; everything rests on it |
| 1 | `--tint5` / `--tint10` | hover and selection wash on paper |
| 2 | `--paper-raised` | a well: card on media, input, media bed |
| 3 | `--ink` fill (bone band) | inversion; the highest emphasis in the system |
| — | overlay | `color-mix(in srgb, var(--paper) 62%, transparent)` medium, `88%` heavy |

- **No `box-shadow` anywhere.** Elevation is rule weight, tint, and paper tint.
- **No `backdrop-filter`.** A sticky bar is `--paper` at 88 % opacity plus a
  bottom `--line`; blur is a different design language.
- **Grain is the only texture:** a low-opacity paper-grain image tiled over the
  canvas. *Ported:* `pointer-events: none`, viewport-fixed, `z-index` below
  content. Keep opacity low enough that body text contrast is unaffected (target
  ≥ 7:1 for `--ink` on `--paper`).
- **Motion is short and linear-ish:** `--snap: 90ms` for colour/border,
  `--move: 170ms` for opacity/transform, `--swap: 210ms` for content swaps.
  Easing: `cubic-bezier(.215,.61,.355,1)` (out) and
  `cubic-bezier(.25,.46,.45,.94)` (quad). Nothing bounces, nothing springs,
  no parallax on text.

## 7. Do's and Don'ts

**Do**

- Keep the page 90 % paper. Empty space is the layout.
- Announce every section with `NN · Name · 漢` and a `--line-strong` rule above.
- Let one serif statement carry the page; everything around it is mono signage.
- Use a single signal colour and spend it on one element per view.
- Set metadata in mono, uppercase, wide-tracked, right-aligned values.
- Reach for a hairline before reaching for a fill.

**Don't**

- No gradients, no glows, no neon, no `drop-shadow`, no glass blur.
- No rounded-rectangle chips, pills or 12 px radii — `2px` or `50%` (dot) only.
- No second accent colour, no rainbow syntax-style palettes.
- No icons where a mono word would fit; no emoji in headings.
- No light mode, no forced-light fallback, no white sections.
- No uppercase serif, no mono paragraphs, no tracking on body text.
- No fake browser chrome, device frames or "dashboard" cards with three stats.
- No pill-shaped status badges, no zebra tables, no 700-weight body text.
- Never use the kanji as the only label — it is ornament, always paired with
  English, always `aria-hidden`.

## 8. Responsive Behavior

| Breakpoint | Behaviour |
| :--- | :--- |
| `< 640px` | gutter drops to `1.15rem`; hero at 3.6rem; every sheet row collapses to stacked label-over-value; nav becomes a horizontal scroller (no hamburger drawer). |
| `640–1024px` | two-column splits become `1fr`; media wells go edge-to-edge inside the gutter; `--section-y` at its floor. |
| `> 1024px` | measure caps at `1240px`; two-column blocks allowed; sticky mono sub-nav appears on long documents. |
| `> 1600px` | nothing grows except margins. The measure does not stretch. |

- Tap targets ≥ 40 px even though the visual control is a hairline.
- Fluid type is `clamp()`-only; never a JS resize hook, never a `vw`-only size.
- Rule weight stays `1px` at every breakpoint (use `0.5px` on 2× only if it
  renders as a true hairline; otherwise keep 1 px).
- Grain stays viewport-fixed so it does not scale with content *(ported)*.
- Respect `prefers-reduced-motion`: all `--snap/--move/--swap` durations collapse
  to `0.01ms`; hover colour changes stay.

## 9. Agent Prompt Guide

### Portable token block

```css
:root{
  --paper:#000; --paper-raised:#0a0a0a;
  --ink:#cdc4ba; --ink-dim:#b0a9a0; --ink-muted:#958f87; --ink-faint:#807a73;
  --line-soft:color-mix(in srgb,var(--ink) 13%,transparent);
  --line:color-mix(in srgb,var(--ink) 26%,transparent);
  --line-strong:color-mix(in srgb,var(--ink) 42%,transparent);
  --tint5:color-mix(in srgb,var(--ink) 5%,transparent);
  --tint10:color-mix(in srgb,var(--ink) 10%,transparent);
  --signal:#ce5e32; --notice:#ce5e32;
  --f-display:"Fraunces",ui-serif,Georgia,serif;
  --f-sans:"Space Grotesk",system-ui,sans-serif;
  --f-mono:"Space Mono",ui-monospace,monospace;
  --f-jp:"Noto Sans JP","Hiragino Sans",sans-serif;
  --radius:2px; --max:1240px;
  --gutter:clamp(1.15rem,4vw,3rem); --section-y:clamp(1.75rem,4vw,3rem);
  --s1:4px; --s2:8px; --s3:12px; --s4:16px; --s5:24px; --s6:32px; --s7:48px; --s8:64px;
  --snap:90ms; --move:.17s; --swap:.21s;
  --ease-out:cubic-bezier(.215,.61,.355,1); --ease-quad:cubic-bezier(.25,.46,.45,.94);
}
```

Swap `--paper`, `--paper-raised`, the four ink steps and `--signal` for another
edition (§2). Change nothing else.

### Quick reference

- Paper `#000` · ink `#cdc4ba` · signal `#ce5e32` · rules at 13/26/42 % ink.
- Display Fraunces 300–400, `-0.02em`; body Space Grotesk 400, 1.55 line height;
  labels Space Mono uppercase, `0.14em`.
- Radius `2px`. No shadows. Grain overlay. 1240 px measure. 4→64 spacing scale.

### Prompts that produce this look

- "Build a single-column 1240 px page on `#000` with a Fraunces hero at
  `clamp(3.6rem,8vw,5.75rem)`, Space Grotesk body at 1.02–1.28 rem, and every
  section opened by a `1px` rule at 42 % ink plus a Space Mono eyebrow
  `01 · Section · 見`. One rust `#ce5e32` primary button. No shadows, 2 px radii."
- "Restyle this component list as sheet rows: mono uppercase label left, ink value
  right, 13 % ink rule between rows, 12 px vertical padding, hover wash 5 % ink."
- "Add a closing 'bone' band: background `#cdc4ba`, text `#000`, one mono eyebrow
  and one Fraunces sentence, full-bleed, `--section-y` padding."

### Self-check before shipping

1. Is there exactly one signal-coloured element in view?
2. Is every rule on the 13/26/42 % ink ladder, and `1px`?
3. Is there a shadow, a gradient, a blur, or a radius above 2 px anywhere?
4. Does every section carry `NN · English · 漢`?
5. Is body copy `--ink-dim` (not full ink) and are all labels mono uppercase?
6. Does the page still read at 360 px wide with the measure collapsed?
