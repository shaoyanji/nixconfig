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
cargo run --release -p loom-cli -- bench # edit → diff over a socket: the 5 ms gate
cargo run --release -p loom-cli -- bench --core # apply → ripple → encode alone: the floor
cargo run --release -p loom-cli -- fuzz 300
cargo run --release -p loom-cli -- replay session
node web/smoke.mjs                       # wire-level end-to-end against a running server
node web/uitest.mjs http://127.0.0.1:8787/   # headless chromium over CDP (needs `ws` beside it)
node web/retune.mjs http://127.0.0.1:8787/   # retune round trip, and whether the span keeps its identity
node web/window.mjs http://127.0.0.1:8787/   # the edit-to-diff target, gated; what the window costs and buys
```

Environment: `LOOM_PORT`, `LOOM_BIND`, `LOOM_DATA` (default `./session`, `off`
disables persistence), `LOOM_COALESCE_MS` (default 2).
`loom-cli bench` takes `--doc N` (for the socket run and `--core` alike),
`--window N` and `--relax`; `web/window.mjs`
reads `TARGET_MS` (the 5 ms it gates on) and reports what the window buys.
`scripts/bench-sweep.sh` runs the four-width sweep and fails when a verdict
differs from the table above.

## Measured numbers

`loom-cli bench`, release profile (thin LTO), 10 029 tokens / 12 564 bytes:

| Metric | Target | Measured |
| :--- | :--- | :--- |
| edit → diff over the socket, p99 | < 5 ms | **4.01 ms** (p50 3.14, max 4.22; 10 029 tokens, 2 ms window included) |
| core pipeline, p99 (no window) | — | **42 µs** on 10 k tokens, **99 µs** on 40 k (p50 28 / 84) — the floor under that number, not a target |
| tokens re-tokenized per edit, median | < 2 % of doc | **0.07 %** |
| tokens re-tokenized per edit, p99 | < 10 % of doc | **0.20 %** |
| ripple bound hits | < 0.1 % of edits | **0 / 1000** |
| diff frame encode | no allocation | 6.0–7.4 µs/frame, reused buffer, 4096 → 4096 bytes |
| 6 reactors at 1000 batches/s, document growing | no queue depth, no drift | 1000 batches, 4000 shard events over 4 shards, 2000 reactions, **0 starved**, **0 span-creep** |

Acceptance tests (`cargo test --all --locked`, 26 tests):

- `incremental_eq_rebuild` — proptest, random documents and op sequences; the
  incremental token array equals a full rebuild byte for byte.
- `ripple_bounded` — no edit re-tokenizes more than the configured window, and
  ordinary word runs never force the over-budget widening.
- `replay_eq_snapshot` — snapshot@R + log R..N replays to exactly the live state
  at N; a snapshot at N replays to the same state with an empty log.
- `constraints_survive_a_restart` — a span planted before the snapshot and one
  planted after it both come back on the right bytes, having moved with an
  insert that landed ahead of them.
- `constraint_removal_survives_a_restart` — a span taken out after the snapshot
  stays out across a restart while the document keeps every byte, a retune after
  it comes back as the rule it was last given, and the ids of the spans that
  remain do not move.
- `a_plant_with_no_edit_reaches_the_sidebar` — a plant sent through the
  coalescer arrives as a `CONSTRAINTS` frame with no diff beside it and no change
  to the rope, carrying the token its anchor resolves to; the same list is what a
  connecting page is handed, a retune keeps the span's id and length while the
  rule changes, and a removal empties the list on both paths.
- `a_retune_keeps_every_span_where_it_was` — twenty retunes of one span with a
  neighbouring span planted beside it: the ids, the anchors, the lengths and the
  resolved tokens all hold, the neighbour keeps its own rule, every retune bumps
  the revision, and the next plant takes a fresh id rather than one a retune
  handed out.
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
- `a_burst_inside_one_window_is_one_revision_and_one_diff` — ten ops inside one
  window cost one diff and one revision, with an ack for each of them and the
  whole burst inside that diff; the same ten sent across two windows cost two,
  and an idle socket is written nothing. The contrast is the point: counting one
  batch alone would still pass if the window coalesced nothing and the client
  merged the diffs itself.
- `a_delete_burst_and_a_retune_in_one_window_are_one_revision_and_one_diff` —
  two deletes and a retune sent as three separate messages inside one window cost
  one revision, one diff that carries *both* deleted tokens and reinserts
  nothing, and one list frame holding the retune's rule on the id the plant handed
  out, with the span's anchor and length unmoved. It found a real bug on the first
  run: the frame's span came from subtracting every later op's delta, so a delete
  that landed *behind* an earlier one was reported as one token instead of two.
  The client would have kept a token the server had dropped, and every later edit
  would have landed one token off. Positions now come from a walk of the batch's
  own splices (`to_pre`), which can err a token wide — the trim recovers the
  minimal diff — but never narrow.
- `every_diff_lands_on_the_server_rope` — a client list built only from the
  snapshot and the diff stream, driven through 48 random multi-op batches
  (inserts, deletes, merges, splits, annotations in one window), asserting after
  every batch that the list is the rope token for token. Tags are left out on
  purpose: the wire carries text and flags, and a client never learns a tag. It
  found a desync on the first run: the ripple widens to a stable boundary and can
  rewrite the token just *past* the batch's span, so a frame that stopped at the
  span left the page holding a stale token — `o` where the rope had `co` — and
  every later edit would have landed one token off. The frame now spans the union
  of what the batch named and what the ripple touched, mapped back into starting
  coordinates.
- `concatenated_frames_walk_from_their_own_lengths` — seven frame types written
  back to back into one message: each is found from the length of the one before
  it, and the lengths cover the message exactly, with every frame equal to what
  was written.
- `protocol_roundtrip` — every frame type encodes and decodes losslessly, fuzzed,
  and a truncated prefix is refused.
- `latency_p99` — gated in the bench rather than `cargo test`, because CI noise
  is exactly what makes a wall-clock assertion useless: `loom-cli bench` exits
  non-zero when the socket p99 misses (`--relax` reports without failing), and
  `web/window.mjs` applies the same target to the same segment from the browser.

`node web/smoke.mjs` drives the release binary: HTTP routes, snapshot, insert →
diff, plant a constraint → `warning raise`, disable the reactor → `warning
clear`, `RESYNC` → fresh snapshot and the constraint list that has to ride it,
then unplant it → the list empties, and a second `RESYNC` reports the empty
list rather than the span it was told to forget.

`node web/uitest.mjs` drives the page itself in headless chromium over the
DevTools protocol: click and shift-click selection, an insert arriving in the
rope view, a planted constraint raising a severity-3 warning, a warning click
selecting its span, the reactor switch clearing its warning, the header pill
reporting the reactor bank and the constraint count with no edit to carry the
frame, the constraint sidebar listing the planted span, selecting it when
clicked and marking its chips in the rope, retuning it in place and taking it
back out, the reactor switch surviving a page reload, split/merge/delete, and a
scrolled window that stays virtualization-sized — with no page exception during
the run, and a screenshot when asked for one.

`node web/redraw.mjs` measures the page rather than asserting it: ten thousand
tokens inserted in one op, then the body of the rope redraw two hundred times
unmarked and marked, at the top of the rope and in the middle, plus what a diff
costs a full constraint index.

`node web/retune.mjs` measures the retune path and checks the identity claim at
the same time. It plants a span, marks it, then retunes it sixty times through
the rule buttons, timing each step from the click by the frame's own arrival
stamp rather than by a polling loop. Identity is asserted where it could break:
the row element has to be the same node afterwards (a property set on it must
survive), the id it shows must not change, the anchor and the length must not
move, and the next plant has to take the next id — no run has broken any of the
four. The timings are op on the wire 0.1 ms, ack 3.3 ms (2 ms of which is the
coalescer window), the list frame the same 3.3 ms in the same message, andthe row repainted at 3.4 ms. Identity held 60/60 in the last run on the row element,
the id and the focus, with the span at `3t @ 0b` and the next plant taking 0, 1.
The first measurement of this was 9.4 ms and 51.8 ms, and the gap was not the
retune: the server queued both frames within
30 µs, and dropping one client write 15 ms into the round trip brought both to
15.4 ms. That is Nagle — an ack and a list frame are two small writes in a row,
and the second waited about 41 ms for the client to acknowledge the first. axum
leaves `TCP_NODELAY` unset on its accepted sockets, so setting it removed the
wait, and the two frames now arrive 0.1 ms apart.

The gate is one segment and one target: a socket write to the diff frame's
arrival, window included, under 5 ms. `loom-cli bench` measures it from Rust — it
starts the real server on a loopback port and speaks the real protocol, so the
number includes the coalescer instead of reporting under it — and
`node web/window.mjs` measures the same segment from the browser, where it also
reports what the window buys a burst. Same build, same box, `bench` at its
default 200 edits, one run each:

| window | edit → diff p99 | verdict |
| :--- | :--- | :--- |
| 1 ms | 3.01 ms | pass |
| **2 ms** | **4.09 ms** | **pass — the default** |
| 4 ms | 5.98 ms | fail |
| 8 ms | 9.33 ms | fail |

From the browser at 2 ms the same segment measured 3.47 ms over 60 edits, with
the diff sharing the ack's message in 60/60. The bench runs longer, so its p99
covers more of a tail that is real: 4.01 ms on the default run, 4.09 ms in this
sweep, and 4.38 and 5.49 ms on two runs over 1000 edits, by which point the
document has grown by 1000 tokens. Those two runs are the honest picture of the
margin: at 10 k tokens the tail sometimes crosses 5 ms, and the pipeline is not
what crosses it — the server's own apply → encode p99 on those runs was 0.28 ms
against a 2 ms window.

The default is 2 ms: the widest window that keeps end-to-end p99 under the 5 ms
target, and the gate says so rather than the prose — 4 ms and 8 ms are the same
measurement failing. A keystroke cadence merges nothing at any width, so a burst
is the only traffic the window is for, and a burst sent in one turn already
merges at 1 ms. The 8 ms default it shipped with added 6 ms to every edit and
merged nothing more than 2 ms does except a burst spread over several
milliseconds, which 2 ms splits into two batches. The edit's ack and its diff now
arrive in one message, so the script also reports that the ack already carries
the window: `the diff shared the ack's message in 60/60 edits`.

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

**Batches.** Ops inside one 2 ms window are applied verbatim and retokenized
once afterwards. Retokenizing between ops would shift the indices the client's
next op refers to, so the op would land somewhere the user did not click. The
width is measured rather than inherited: 2 ms is the widest that keeps the
end-to-end edit-to-diff p99 under the 5 ms target, and a burst of ten ops sent
in one turn still becomes one revision at that width. The
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
connect, after a batch that planted or removed one, and after a resync — and the
sidebar lists each span with its rule, its token count and its byte anchor. A
plant moves no text, so the list cannot ride a diff: it is its own frame, which
is why a plant that raised no warning is still something the page can show.
Clicking an entry marks the chips the span covers now and selects them, andthe mark stays on while the rope is edited — a span that has outgrown its rule is
then visible as text rather than only as a count. The frame carries the token
each anchor covered when it was written, so the page keeps no byte index of its
own; a diff shifts that token with the text, which costs 1.8 µs for a full index
of 256 spans. The first version had the page keep a byte-offset table per token
and rebuild it on every diff, and measuring it settled the question: 29.5 ms p50
on a 40 323-token rope, once per edit, so a marked page stalled a frame whenever
it typed. With the mapping on the server the same marked redraw measures 1.1 ms
p50 against 1.0 ms unmarked, with 512 chips on screen. The `×` on an entry sends
a `CONSTRAINT_REMOVE` op naming the id the server handed out; ids are never
renumbered, or a warning that names one would point at a span it never described.
A marked entry is retuned in place by the rule buttons — a `CONSTRAINT_UPDATE`
that keeps the anchor, the length and the id, so the warning the old rule raised
keeps its identity instead of reading as a new problem. The panel keeps one row
per id and updates it where it stands, so a retune repaints text inside the same
element rather than rebuilding the list. A removal and a retune
move no text either, and both bump the revision so their log records outlive the
snapshot they follow.

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

- **One latency gate, and it is the socket one.** The bench used to time
  apply → ripple → encode and quote that as edit-to-diff (124–182 µs) while
  checking a target measured elsewhere: two instruments disagreeing about what the
  words meant. `loom-cli bench` now starts the server on a loopback port and times
  send → diff frame — the same segment `web/window.mjs` times from the browser,
  against the same 5 ms — so a regression in either shows up as the same failing
  number. The pipeline alone is `bench --core`: the floor under that number, and
  no gate of its own, because a target the core meets while the socket misses says
  nothing about an editor.
- **The target is measured, and beyond 10 k tokens it is marginal.** The first
  measurements said 10 029 tokens held at 3.70 ms while 40 k and 100 k did not,
  and part of that was structural: every position lookup summed a chunk's tokens
  instead of reading its text length, so `byte_of_token` was O(tokens) and an edit
  went through it several times; and the token array a batch materializes for the
  send path and the reactors was grown from zero. Both are fixed, and the fix is
  measured interleaved against a build with the old rope, three rounds each,
  server time per edit at 100 154 tokens (median): ops 85 → 56 µs, ripple
  473 → 177 µs, materialize 321 → 269 µs, end-to-end p50 3.93 → 3.52 ms. The p99
  did not follow it down, and the reason is not the pipeline: apply → encode p99
  is 0.5–1.7 ms against a 2 ms window, and cutting the reactor pool from four
  shards to three halved that server p99 (668–806 → 361–456 µs) while the
  end-to-end number went from 4.6–5.0 to 5.0–5.5 ms. At 200 edits the socket p99
  is 4.01 ms at 10 k, 4.1–5.2 at 40 k and 4.1–4.3 at 100 k; at 600–1000 edits the
  tail widens to 5.3–7.0 ms at 40 k while 10 k stays at 4.4–5.5. A 40 k document
  measuring worse than a 100 k one is the tell: what is left is the round trip and
  the timer on a four-core box, not the diff. The gate passes at the size it was
  measured at, and is reported rather than hidden everywhere else.
- **The gate's verdict is checked on a schedule, not re-read.**
  `.github/workflows/bench.yml` runs `scripts/bench-sweep.sh` every Monday: the
  four window widths above, each compared with this README's table, two attempts
  per width so one noisy run is a footnote. A verdict that changed fails the job
  and prints the p99 beside it, because a gate whose answer moved is a fact to
  look at rather than a paragraph to trust.
- **A snapshot is never packed, so packing cannot hurt one.** It is written before
  the packing loop, as its own message: measured as one transport frame carrying
  one loom frame at 10 029 tokens (42 665 bytes, 0.77 ms from connect), 40 125
  tokens (170 657 bytes, 2.46 ms) and 100 154 tokens (425 944 bytes, 6.41 ms). No
  cap and no chunking, because a client cannot draw a rope before its last token
  arrives: splitting would add reassembly to a cost that is the bytes.
- **Several frames ride one socket message.** A batch that produces an ack, a
  diff and a list frame is three small writes, and the client used to handle them
  as three events. Both sides now treat a message as a sequence: the server drains
  what is already queued for that client into one write (capped at 64 KiB, and a
  burst of ten ops measured 12–13 frames in one message), and a frame is
  self-delimiting, so clients walk the buffer instead of being told where each
  frame ends (`decode_server_at` on the server side, `decodeAll` in each web
  script). Measured effect: the retune ack and its list frame went from 0.1 ms
  apart to 0.0, one write and one client wake-up per batch saved, and the
  single-edit p99 unchanged at 3.70 ms — the latency win was `TCP_NODELAY`, not
  this. It is built because the atomicity is real: a client can no longer see an
  ack without the list it made true. The bug it introduced first was mine — the
  page's new reader passed a `Uint8Array` to `DataView`, which Chromium refuses,
  so every frame was dropped while the socket still read `live`; `uitest.mjs`'s
  "no page exceptions" check and the empty rope caught it.
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
index.html         the landing page GitHub Pages serves: what this is, and its numbers
web/               index.html, loom.js (vanilla, virtualized rope view), smoke.mjs, uitest.mjs, redraw.mjs, retune.mjs, window.mjs
vocabs/            bpe_a.json, bpe_b.json, wordpiece.json, delims.json
LICENSE            MIT
```

## License

MIT — see [`LICENSE`](LICENSE).
