// Flox — Member of Technical Staff, Core Systems.
// Native English source replacing the ad-hoc PDF. Systems programming, dev environments, reproducibility, CLI.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1e3a34"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1e3a34")
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
    #text(size: 9.8pt)[Systems and developer-tooling engineer · hermetic builds · CLI]
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
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I build the layer a developer actually touches: a shell that has the toolchain already pinned, a CLI whose output another program can
parse, and a build that does not depend on the machine it ran on. Three years of running a NixOS fleet taught me that the environment is
the product — when `nix develop` gives the same shell to me, to CI and to an agent, half the class of "works on my machine" stops existing
as a question.

Systems programming is where the interesting part lives. A text editor is a data structure problem before it is a feature list: the piece
table decides how a document is stored, and re-tokenising only what changed is what keeps a keystroke under a millisecond instead of
re-walking the file. I have written that in Rust, a bounded-work state machine in Go, a C++ instrument driver at Fraunhofer, and a Go
fuzzer that generates adversarial geometry so the maths either holds or fails loudly.

The CLI is an interface with a contract, not a script with flags. Typed arguments, a dry-run plan before the destructive path, JSON on
request, an exit code that means something, no state hidden between runs. That discipline is what lets automation — including agents —
drive the same commands a human does, which is how my own fleet is operated.

Reproducibility is the property I test for rather than assume: pinned flake inputs, builds in the sandbox with the network closed, a
content-addressed store, and a result served from a cache so a rebuild is a lookup. The same commit produces the same paths, which makes
"it worked yesterday" a diff to read instead of a mystery to reproduce.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Systems programming* — Rust, Go, C++: data structures, bounded work, no GC pauses in the hot path],
  [*Developer environments* — pinned dev shells, identical locally, in CI and for agents],
  [*Reproducibility* — hermetic builds, content-addressed store, cache hits as the normal case],
  [*CLI tooling* — typed arguments, dry runs, JSON output, exit codes as the contract],
  [*Cross-platform* — one declaration evaluated for Linux and Darwin, per-system inputs locked],
  [*Testing* — acceptance tests holding an invariant, property fuzzing, benchmarks that can refute],
  [*Packaging* — flakes, overlays, module options and assertions, sources pinned by the lock],
  [*Operations* — sentinel ledger, alert thresholds, canary before fleet, rollback by pointer])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Built bountystash as one Go binary carrying a CLI, a TUI, a REST surface and PostgreSQL behind the same command, so a request becomes an immutable, content-addressed specification with append-only events rather than mutable rows.
- Declared a thirteen-host fleet in one flake: every input pinned, every service a module, `nix develop` producing the same toolchain for a human, CI and an agent.
- Kept builds hermetic — sandboxed, network closed, cache-served — so a rebuild is a lookup and a generation is a pointer that rolls back in one command.
- Wrote the operator CLI as a task plane: typed arguments, dry-run plans, JSON and TOON output, one exit code per outcome, so the same path runs the same way twice and automation needs no special case.
- Ran the reliability loop on the same fleet: job status, generation age, disk and PSI to a ledger every fifteen minutes, paging on bad state and on silence.
- Packaged the services themselves: PostgreSQL with migrations, a mail archive with tsvector and GIN search, Go and Python daemons.
- Kept a written record of every architectural decision in the repository, because the reason is the part that does not survive in the code.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- tokenloom: a Rust cargo workspace behind a pinned dev shell — a piece table editor core, a ripple re-tokeniser that touches only the changed span, and a Hilbert-indexed bridge to image data; `tests/acceptance.rs` holds the invariant and a 5 ms gate keeps a keystroke honest.
- fibtransponder: a state machine that streams a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input.
- Swirl engine: polygon areas from random geometric samples by Green's theorem, with a Go fuzzer generating adversarial shapes and a Nushell pipeline carrying the numerics past what the compiler-first path allowed.
- Each project ships a flake: pinned inputs, a dev shell, a check target, and the same commands on Linux and macOS.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team and an incentive structure tied to a live model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then checked the geometry independently in Mathematica instead of trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Diagnosed equipment and process failures in the field under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[tokenloom] #text(size: 8pt, fill: muted)[— Rust]
    #linebreak()
    Piece table, ripple re-tokeniser, Hilbert bridge; acceptance test as the invariant, 5 ms gate. Workspace pinned by a dev shell.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— environments]
    #linebreak()
    Thirteen hosts from pinned inputs; hermetic builds; overlays; one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— CLI]
    #linebreak()
    Typed arguments, dry-run plans, JSON and TOON output, one exit code per outcome — drivable by a human or an agent.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— single binary]
    #linebreak()
    Go CLI/TUI with REST and PostgreSQL behind one command; append-only events; content-addressed specs.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— systems]
    #linebreak()
    Bounded work per step, and a corpus benchmark that refuted the first detector design, so the claim narrowed.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · remote, US hours from Germany · available 01.12.2026]
