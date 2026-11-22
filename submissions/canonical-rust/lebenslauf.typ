// Canonical — Rust Engineering Lead, Linux and Open Source (Greenhouse 5833620).
// Native English source replacing the database-built PDF. Rust claims limited to what the tree shows.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2f3350")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when, where) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
  #v(-2pt)
  #text(size: 8pt, fill: muted)[#where]
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Systems engineer · Rust and Go · Linux tooling · declarative deployment]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.5pt + accent)

#section("Profile")
My Rust work is small, finished, and measured rather than described. Token Loom is a token-sculpting workbench: a client sends token-level
edits over a binary WebSocket, the server keeps the stream in a chunked piece table, re-tokenises only the window an edit disturbed, runs
six reactors over the diff, and streams back a minimal diff plus warnings whose lifecycle does not flicker. The invariant the whole system
rests on is stated in the crate and held by a test — after any sequence of edits, the incrementally maintained token array equals a full
re-tokenisation of the bytes — and the ship gate is a socket round trip at five milliseconds, with fuzz and replay behind it.

The second half of that project is the part I find more interesting: a byte stream read as an image through a Hilbert curve. A curve of
order n visits every cell of a 2^n square exactly once, so byte d is the pixel d2xy(order, d) and a byte range becomes a set of pixels
with an exact bounding box. The crate builds typed span algebra on three test-held properties, allocates nothing per point, and depends on
nothing; a parity test compares it cell for cell against the JavaScript implementation that shipped first, rather than trusting a comment.

Underneath that sits the deployment discipline Canonical runs on: one flake declares thirteen hosts, each host a feature list, each service
a module with a systemd unit and written failure behaviour; inputs are pinned, builds are hermetic, the gate CI runs is the gate the machine
passes, and a release is a pointer to the previous generation rather than a procedure. Packaging is not paperwork to me — pinned inputs,
reproducible output and provenance you can check are the same property at three scales.

What I have not done: I have not led a commercial Rust codebase or contributed upstream to Rust, I have not maintained a package in Ubuntu
or Debian, and I have no LXD, Juju, SnapD or Ubuntu Core experience and no kernel or bootloader development. I read more Rust than I write,
and the systems depth behind it is Go, C and C++, Python and Bash.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Rust* — piece tables, incremental re-tokenisation, typed span algebra, no-dep crates],
  [*Correctness* — invariants as tests, fuzz and replay, differential parity checks],
  [*Performance* — a five-millisecond socket gate, tracing to split a round trip],
  [*Linux tooling* — systemd, cgroups and PSI, journald, nftables, tcpdump],
  [*Declarative deployment* — one flake, feature lists, hermetic builds, rollback],
  [*Packaging* — pinned inputs, reproducible output, provenance, gates],
  [*Go and Python* — services, automation, one validated task surface],
  [*Measurement* — a benchmark that falsified its own claim, so the claim changed])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Built Token Loom in Rust: a chunked piece table over a token stream, a ripple re-tokeniser that touches only the window an edit disturbed, six reactors over the diff, and a wire format for minimal diffs.
- Held the system's central invariant by test rather than review — incremental state equals a full rebuild after any edit sequence — and put fuzz, replay and a socket-level latency gate around it, measured on a separate box because the workstation should not decide the number.
- Wrote the Hilbert-curve image bridge: bytes as pixels, spans with exact bounding boxes, typed arithmetic with three test-held properties, zero allocation per point and no dependencies.
- Built a second service in Rust on tokio and axum — a broadcast fan-out to every open stream — deliberately as a comparison against the Go prototype, because the dependency surface is part of the engineering judgement.
- Declared thirteen NixOS hosts in one flake: host as feature list, service as module with an explicit unit and written failure behaviour, kernel track and parameters pinned per host.
- Made delivery reversible: pinned inputs, hermetic builds from a shared binary cache, a per-host gate shared by CI and the machine, a canary guest before the fleet, and rollback as a pointer.
- Kept zero standing secrets: sops-encrypted values with per-host age keys, and SSH access as short-lived certificates from the fleet's own authority.
- Ran the reliability loop: a sentinel writes job status, generation age, disk and PSI to a ledger every fifteen minutes and pages on any state short of ok and on silence.
- Operated PostgreSQL for the application database and the mail archive — migrations, statement timeouts, a recovery path walked rather than assumed — and wrote the Go and Python tooling behind it.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem before it is a communication one.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating both directions between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Diagnosed equipment and process failures in the field under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[tokenloom] #text(size: 8pt, fill: muted)[— Rust workspace]
    #linebreak()
    Piece table, ripple re-tokenisation, Hilbert image bridge, four crates and acceptance tests holding the invariant.
  ],
  [
    #text(weight: "bold")[turns runtime] #text(size: 8pt, fill: muted)[— Rust versus Go]
    #linebreak()
    The same broadcast read path in tokio and axum, written to compare dependency surfaces rather than to win an argument.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative fleet]
    #linebreak()
    Thirteen hosts from one flake, pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— measurement]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    Its own benchmark falsified the seed-only claim, so the claim narrowed instead of the measurement being explained away.
  ],
  [
    #text(weight: "bold")[email archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail ingested and classified, tsvector and GIN search, an upsert keyed on message_id, a rehearsed restore.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · home-based in Gutach im Breisgau, seeks no relocation · available 01.12.2026]
