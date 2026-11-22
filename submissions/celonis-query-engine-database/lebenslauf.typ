// Celonis — Senior Software Engineer, Query Engine & Database Systems. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#0d4a6b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#0d4a6b")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Systems Programming · Query & Storage Surfaces · Linux Performance]
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
I build systems that answer questions over data quickly and prove their numbers. The daily languages are Go and Python; C++
is real but dated — the last production C++ I wrote drove a heliostat interferometer and its analysis at Fraunhofer ISE. The
systems work is current: a Postgres archive behind a query API where hot tables serve interactive lookups, a Go coordination
service where concurrent agents claim work and publish ordered turns, and a fleet of Linux hosts built deterministically so
the binary running is the binary the source describes — the property engine teams want from their build and test loop.

Performance is a measurement discipline, not a preference: cgroup accounting to show where CPU went, PSI to separate I/O
starvation from memory pressure, `strace` and `tcpdump` when the answer sits below the application, queue depth observed
before capacity is bought. Resource bounding under concurrent load is the same problem a query engine solves with memory
limits and spill policy — I have enforced it at the OS layer with capped microVMs and an explicit rule for who yields.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Systems languages* — Go and Python daily; C++ at Fraunhofer ISE, modern standard exposure],
  [*Concurrency* — claims, ordered turns, single-writer ledgers in a Go service],
  [*Storage & query* — Postgres hot tables behind an API; graph projections read over Cypher],
  [*Linux performance* — cgroups, PSI, `strace`, `tcpdump`, memory pressure analysis],
  [*Determinism* — pinned inputs, reproducible builds, rebuild as the upgrade path],
  [*Resource bounding* — capped CPU and memory, explicit yielding under contention],
  [*Measurement* — fifteen-minute telemetry ledger, capacity argued from queue depth],
  [*Delivery* — one gate per change, identical in CI and on the machine, rollback a pointer])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built a Postgres-backed archive serving interactive queries: hot tables for the common access path, a full-text and
  envelope index, and an API surface that keeps storage decisions behind the interface.
- Wrote the coordination service in Go that a fleet of agents shares: concurrent claims on work items, ordered turn
  publication, and idempotent writes so a retried action is a no-op rather than a duplicate.
- Ran thirteen Linux hosts as one deterministic build: inputs pinned, derivations shared through a cache and remote
  builders, so the artifact deployed is the artifact the source describes — reproducibility as an operating property.
- Bounded resources under concurrent load: microVM guests with capped CPU and memory, and a GPU yielding rule that decides
  explicitly which workload waits when two need the card.
- Diagnosed performance from evidence: cgroup accounting for CPU attribution, PSI to distinguish I/O starvation from memory
  pressure, `strace` for syscall-level answers, `tcpdump` when the question was on the wire.
- Kept a fifteen-minute measurement ledger over the estate — job state, generation age, disk pressure, PSI — so capacity and
  reliability are argued from recorded numbers and silence itself pages.
- Replaced standing access with issued access: a fleet certificate authority, short-lived credentials, per-host secrets —
  correctness for the sensitive path enforced by construction.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one
  auditable series.
- Reported variance line by line, with every assumption documented next to its number.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis over its 3D geometry output.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— storage & query]
    #linebreak()
    Postgres hot tables behind a tailnet API: envelope lookups interactive, verdicts written once and closed, full-text
    search over the corpus.
  ],
  [
    #text(weight: "bold")[xs coordination] #text(size: 8pt, fill: muted)[— concurrency]
    #linebreak()
    Go service where agents claim paths and publish ordered turns; idempotent by design so retries do not duplicate work.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— determinism]
    #linebreak()
    Thirteen hosts from one repository, pinned inputs, shared cache and remote builders: the running artifact is the built
    artifact.
    https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— measurement]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; paging on bad state and on silence, history kept for the
    postmortem.
  ],
  [
    #text(weight: "bold")[microVM guests] #text(size: 8pt, fill: muted)[— resource bounds]
    #linebreak()
    Capped CPU and memory, read-only host mounts, no egress: concurrent untrusted work runs inside explicit limits.
  ],
  [
    #text(weight: "bold")[task surface] #text(size: 8pt, fill: muted)[— interfaces]
    #linebreak()
    Every operation behind named arguments, validation, dry runs and JSON output — the interface others build on.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, Munich presence by arrangement]
