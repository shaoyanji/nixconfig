# Token Loom

A token-sculpting workbench. A client sends token-level edit operations over a
binary WebSocket; the server keeps the token stream in a chunked piece table,
re-tokenizes only the window an edit disturbed, runs six reactors over the diff,
and streams back a minimal token diff plus warnings whose lifecycle does not
flicker.

Built and measured on **clanker** (InstaBox: 4 vCPU EPYC, 8 GiB, Debian 13,
rustc 1.99). Nothing in this project was compiled on the workstation; the tree
travels as a tar and every `cargo` invocation happens on that box.

## Run

```bash
cargo run --release -p loom-srv          # http://127.0.0.1:8787/  (ws /ws)
cargo run --release -p loom-cli -- bench # 10k tokens, 1000 edits, histogram
cargo run --release -p loom-cli -- fuzz 300
cargo run --release -p loom-cli -- replay session
node web/smoke.mjs                       # wire-level end-to-end against a running server
node web/uitest.mjs http://127.0.0.1:8787/   # headless chromium over CDP (needs `ws` beside it)
```

Environment: `LOOM_PORT`, `LOOM_BIND`, `LOOM_DATA` (default `./session`, `off`
disables persistence), `LOOM_COALESCE_MS` (default 8).

## Measured numbers

`loom-cli bench`, release profile (thin LTO), 10 029 tokens / 12 564 bytes:

| Metric | Target | Measured |
| :--- | :--- | :--- |
| edit → diff latency, p99 | < 5 ms | **124–182 µs** over two runs (latest: p50 45, p90 76, max 340) |
| tokens re-tokenized per edit, median | < 2 % of doc | **0.07 %** |
| tokens re-tokenized per edit, p99 | < 10 % of doc | **0.20 %** |
| ripple bound hits | < 0.1 % of edits | **0 / 1000** |
| diff frame encode | no allocation | 6.0–7.4 µs/frame, reused buffer, 4096 → 4096 bytes |
| 6 reactors at 1000 batches/s, document growing | no queue depth, no drift | 1000 batches, 4000 shard events over 4 shards, 2000 reactions, **0 starved**, **0 span-creep** |

Acceptance tests (`cargo test --all --locked`, 17 tests):

- `incremental_eq_rebuild` — proptest, random documents and op sequences; the
  incremental token array equals a full rebuild byte for byte.
- `ripple_bounded` — no edit re-tokenizes more than the configured window, and
  ordinary word runs never force the over-budget widening.
- `replay_eq_snapshot` — snapshot@R + log R..N replays to exactly the live state
  at N; a snapshot at N replays to the same state with an empty log.
- `constraints_survive_a_restart` — a span planted before the snapshot and one
  planted after it both come back on the right bytes, having moved with an
  insert that landed ahead of them.
- `legacy_snapshot_still_loads` — a snapshot written before constraints were
  stored still opens, with an empty index rather than a refusal; so does the
  shape before the reactor bank was written down, with every reactor on.
- `corrupt_snapshot_is_refused` — a snapshot whose magic is followed by
  nothing readable stops the load instead of reading as an empty session, while
  the same bytes whole still open; the server refuses to start and names the
  file to move aside.
- `reactor_toggles_survive_a_restart` — a reactor switched off before the
  snapshot and one switched off after it both come back off, from a batch that
  moved no text.
- `flap_suppression` — ten breaks in one second produce one `RAISE`, one id, and
  one `CLEAR`.
- `constraint_follows_its_text_across_edits` — a span planted on a word stays on
  that word when text is inserted before it, inserted after it, and deleted
  before it.
- `protocol_roundtrip` — every frame type encodes and decodes losslessly, fuzzed,
  and a truncated prefix is refused.
- `latency_p99` — lives in the bench rather than `cargo test`, because CI noise
  is exactly what makes a wall-clock assertion useless; the bench exits non-zero
  when a target is missed (`--relax` reports without failing).

`node web/smoke.mjs` drives the release binary: HTTP routes, snapshot, insert →
diff, plant a constraint → `warning raise`, disable the reactor → `warning
clear`, `RESYNC` → fresh snapshot and the constraint list that has to ride it.

`node web/uitest.mjs` drives the page itself in headless chromium over the
DevTools protocol: click and shift-click selection, an insert arriving in the
rope view, a planted constraint raising a severity-3 warning, a warning click
selecting its span, the reactor switch clearing its warning and surviving a page
reload, the header pill reporting the reactor bank and the constraint count with
no edit to carry the frame, the constraint sidebar listing the planted span and
selecting it when clicked, split/merge/delete, and a scrolled window that stays
virtualization-sized — with no page exception during the run, and a screenshot
when asked for one.

## How it works

**Rope.** `loom-core::Rope` is a piece table whose pieces are token runs of at
most 256 tokens. Each chunk stores its text and the tokens that tile it, with
`byte_start` relative to the chunk; `chunk_id` is assigned on every reindex. An
edit splits the chunks straddling it, merges that short span into one working
buffer, applies the change, and re-splits if the result is too large. A chunk
mutation is expressed as a new `(flags, tag, text)` list and rebuilt from it, so
text and token offsets have no second copy to drift.

**Ripple.** `retokenize_window` takes the dirty token range and widens both edges
until the tokenizer calls each boundary *stable*. A boundary between two word
bytes is unstable (a merge may cross it); every other boundary is not, so one
expansion lands on the edge of the enclosing word run. The window is capped by
`lookahead × max_steps`; if a run is wider than that, the window is widened to
the run's edges anyway and the report says `truncated`, so the output stays
correct and the overrun is counted instead of hidden. The old and new token runs
are trimmed by common prefix and suffix, and only the middle is spliced, which is
what makes the emitted `DIFF` minimal.

**Batches.** Ops inside one 8 ms window are applied verbatim and retokenized
once afterwards. Retokenizing between ops would shift the indices the client's
next op refers to, so the op would land somewhere the user did not click. The
frame's span comes from the affine pre/post mapping; the retokenization seed
comes from the per-op splices shifted by later deltas, which stays exact even if
an op's offset had to be clamped. If a sender's offsets do not line up with the
document at all, that client gets a `SNAPSHOT` rather than a diff computed from
coordinates that do not correspond.

**Reactors.** Six of them (`bpe-a`, `bpe-b`, `wordpiece`, `regex-lexer`,
`constraint-check`, `stability`), each holding its own segmentation and re-lexing
only the batch window. Positions are stored per block of 256 spans, and a block's
start byte is the sum of the lengths of the blocks before it: an edit rewrites
the block it lands in and every later position moves for free, because it was
never stored. That is what keeps a batch at 1000/s from walking a 7k-span tail
per reactor. The pool runs `min(4, cpus)` shards; a shard whose queue (bound 32)
is full raises its starve flag and re-lexes the whole document on its next idle
moment, counting `starved` rather than dropping diffs. The header pill carries
that count next to the last batch window, so a shard that fell back to a
keyframe is visible from the page instead of only in the server's log. The same
frame carries the reactor bank and the session's constraint count, so a switch
thrown in another tab, and a span planted without raising, both show on the page
without waiting for a reload (`bank 5/6 · cons 1`). That frame rides a 250 ms
clock as well as the batches, so the pill is a readout of the session rather than
of the last edit: an idle page still sees a switch thrown elsewhere, and a test
waiting on it has nothing to nudge.

**Constraints.** A span is planted by token index, converted once to a byte
anchor, and shifted on every edit that lands before it, so it keeps pointing at
the text it was planted on. The session's index rides a `CONSTRAINTS` frame — on
connect, after a batch that planted one, and after a resync — and the sidebar
lists each span with its rule, its token count and its byte anchor. Clicking one
maps that anchor back to a token by walking the rope's own texts, so the
selection lands on what the span covers now, not on what it covered at plant
time.

**Warnings.** Identity is `(kind, reactor, span bucket)`, so a violation that
moves by a few tokens keeps its id. A re-raise inside 250 ms bumps `flap_count`
and sends nothing; absence starts a 500 ms quiet clock; a 100 ms ticker expires
cleared conditions even when no further edit arrives (disabling a reactor marks
its warnings absent immediately). Concurrent warnings are capped at 512, evicting
the oldest of the lowest severity first.

**Persistence.** Every applied batch is appended to `session.edits`
(length-prefixed bincode of the ops) and the rope is snapshotted to
`session.snap` (atomic rename) every 500 revisions or 5 s idle, and once at
startup when there is no snapshot yet — a log whose base document was never
pinned replays onto nothing. Startup loads the snapshot and replays the tail,
retokenizing after each record, because replay can only be right if the
incremental path was. Constraint ops ride the same log and the snapshot carries
the index, so a restart comes back with its spans on the bytes they were planted
on. Reactor toggles are session state too, so they ride both: the snapshot holds
the bank and the tail replays the switches thrown after it, and a batch that only
threw one bumps the revision so its record is not trimmed as already covered.
The `SNAPSHOT` frame carries the same bits, so a page that reloads draws the
server's bank instead of defaulting every switch to on. A snapshot that is
present but will not decode is not treated as a missing one: the loader refuses
it and the server exits naming the file, because starting over would append to a
log whose base document is gone.

## Deliberate choices and limits

- **The bench measures the core pipeline, not the coalescer.** Edit-to-diff with
  an 8 ms batcher cannot be under 5 ms on average: the batch window is a floor.
  The bench therefore times apply → ripple → diff encode, which is the part the
  pipeline can improve.
- **The constraint index is bucketed by anchor byte (128-byte blocks), not an
  interval tree.** Same query result for far less code; the cost is a scan per
  touched bucket, and the query errs wide where a token-width guess is needed.
- **The wire names a span in tokens; the server keeps a byte anchor.** Token
  indices are what a client has, but "token 40" is different text the moment
  anything is inserted before it, so the server converts once at plant time and
  shifts the anchor on every edit instead. Constraints stay put; re-tuning the
  token span as the document changes is not attempted.
- **Text travels inline in `DIFF`.** It has not been profiled as the bottleneck
  (a diff is tens of bytes), so the text-ref scheme stays unbuilt.
- **Locating a byte in a reactor's segmentation walks ~40 block lengths**, which
  is the price paid for never rewriting the tail. A skip list over blocks would
  make that logarithmic at the cost of a second structure to keep consistent.
- **Two toy vocabularies and a small WordPiece list.** They are small on purpose:
  the point is that `bpe-b` genuinely disagrees with `bpe-a` about segmentation.
- Thin LTO rather than fat: the box has four cores and a 120-minute run clock,
  and the measured numbers come from that same profile.
- No auth, no multi-user, no rich text, no ML inference — per the brief.

## Layout

```
crates/loom-core   rope, ops, ripple re-tokenizer, diff geometry
crates/loom-tok    BPE, WordPiece, delimiter lexer, vocab loader
crates/loom-react  reactor trait, shard pool, warning engine, constraints
crates/loom-wire   binary protocol (client frames are the ops themselves)
crates/loom-srv    session, coalescer, persistence, axum server
crates/loom-cli    bench, fuzz, replay
web/               index.html, loom.js (vanilla, virtualized rope view), smoke.mjs, uitest.mjs
vocabs/            bpe_a.json, bpe_b.json, wordpiece.json, delims.json
```
