// Canonical — Rust Engineering Lead. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.32cm)
Canonical #linebreak() Rust engineering

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Rust Engineering Lead — Linux and Open Source]
#v(0.32cm)

Dear Canonical team,

your posting frames this as a systems problem with a language attached: Rust as the next foundation for firmware, tooling, boot and the
desktop, with Ubuntu as the best place to build it. My systems work has the same shape, in a smaller fleet — and my Rust is small, finished,
and measured rather than described.

Token Loom is the honest sample. A client sends token-level edits over a binary WebSocket; the server keeps the stream in a chunked piece
table, re-tokenises only the window an edit disturbed, runs six reactors over the diff, and streams back a minimal diff plus warnings whose
lifecycle does not flicker. The invariant the whole thing rests on is written down and held by a test: after any sequence of edits, the
incrementally maintained token array equals a full re-tokenisation of the bytes. Around it sit fuzz, replay, a five-millisecond socket gate,
and a separate machine for the measurement, because the workstation should not decide the number. The second half maps a byte stream onto a
Hilbert curve, so a byte range becomes a set of pixels with an exact bounding box; it allocates nothing per point, depends on nothing, and a
parity test compares it cell for cell against the JavaScript implementation that shipped first.

The deployment discipline is the part Canonical actually runs on. One flake declares thirteen hosts, each host a feature list, each service a
module with a systemd unit and written failure behaviour; inputs are pinned, builds are hermetic, the gate CI runs is the gate the machine
passes, a canary proves a change before the fleet, and a release is a pointer to the previous generation. Packaging, to me, is that same
property at a different scale: pinned inputs, reproducible output, provenance you can check.

What I have not done, stated before an interview can find it: I have not led a commercial Rust codebase or contributed upstream to Rust, I
have not maintained a package in Ubuntu or Debian, and I have no LXD, Juju, SnapD or Ubuntu Core experience and no kernel or bootloader
work. I read more Rust than I write. What carries the application is systems judgement — where Rust earns its borrow checker and where a
garbage-collected language is the better trade — plus the habit of proving a claim with a test or a benchmark instead of a paragraph.

I am based in Germany, home-based already, a US citizen with permanent German residence, so no sponsorship is needed, and I am glad to
travel for the twice-yearly sprints. I am targeting EUR 120,000 to 150,000 for a home-based contract, available from 01.12.2026.

Best regards,
#v(0.4cm)
Matt Ji
