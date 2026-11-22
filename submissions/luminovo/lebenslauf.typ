// Luminovo — Senior/Staff Platform Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2a2f6b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2a2f6b")
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
    #text(size: 9.8pt)[Platform Engineering · Developer Experience · Reproducible Builds]
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
Platform work is the craft of making the correct path the short one. Five years of it in one public repository: thirteen
Linux hosts declared rather than configured, every input pinned, every service a module, and one gate that runs identically
in CI and on the machine, so a broken host definition fails before it deploys rather than after. Rebuilds come from a
shared binary cache and remote builders; a rollback is a pointer to the previous generation; secrets are encrypted per host
behind a certificate authority that issues short-lived credentials. A sentinel writes job status, generation age, disk and
PSI every fifteen minutes and pages on any state short of ok and on silence.

The other half is developer experience, which I treat as a product: one task surface with named arguments, help text,
dry-run plans and JSON output, so a colleague acts without reading the implementation, and a wrong argument fails before it
touches a host. Go for services that hold state, Python for tooling and data work, SQL where a question is answered by a
query. I have not written Rust in production and will not claim it; my systems code is Go and Python, with C and C++ from
earlier work.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*CI/CD* — one gate for CI and host, inventory matrix, fast failure],
  [*Reproducible builds* — pinned inputs, content addressing, shared cache],
  [*Developer experience* — one entry surface, validation, dry-run plans],
  [*Observability* — fifteen-minute ledger, paging on state and on silence],
  [*Linux* — systemd, cgroups, PSI, nftables, `strace`, `tcpdump`],
  [*Services* — Go, Python, SQL, tests over canonical data],
  [*Data work* — reconciliation across feeds, explicit error budgets],
  [*Agents as infrastructure* — claims, gates, tiered access, review])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Declared a thirteen-host fleet as one repository, with a documented rebuild path per host and no manual edits on a running machine.
- Kept the gate identical in CI and on the host, so a green build cannot disagree with a healthy machine and a failed check leaves the previous generation serving.
- Built rebuilds from a shared binary cache and remote builders, and ran fleet-wide sweeps as one host per process under a memory guard, because CI capacity is a real constraint and not an infinite pool.
- Gave every change a parent, so a bad rollout is a pointer to the previous generation rather than an incident at the wrong hour.
- Designed the developer surface: named arguments, help text, JSON output and dry-run plans, so routine work needs no ticket and no memory of the last time.
- Generated the documentation from the same source as the configuration, so a stale page is a build failure instead of a slow drift somebody finds during an incident.
- Built the telemetry loop: job status, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, history kept for the postmortem.
- Wrote services in Go and tooling in Python, with tests over canonical data rather than mocks of it.
- Ran agents against the repository as infrastructure rather than autocomplete: isolated worktrees, claims before edits, tiered tool access per host, approval before anything destructive.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality for a solar portfolio above USD 100M: three measurement feeds reconciled into one auditable series, with missing readings treated as an explicit error budget.
- Built the yield and valuation models behind the portfolio, and explained variance line by line rather than in aggregate.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, pinned inputs, shared cache and remote builders, one per-host gate, rollback as a pointer.
    https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— developer experience]
    #linebreak()
    Every operation behind one surface with validation and dry-run plans: the measure is whether a colleague ships
    without asking.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, history kept for
    the postmortem.
  ],
  [
    #text(weight: "bold")[generated documentation] #text(size: 8pt, fill: muted)[— knowledge]
    #linebreak()
    Docs, a task surface and a knowledge graph built from the source, so the page and the system cannot drift apart.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— Go, streaming]
    #linebreak()
    A streaming protocol implementation with Zobrist hashing and benchmarks, written to hold state correctly under
    concurrency.
  ],
  [
    #text(weight: "bold")[build farm] #text(size: 8pt, fill: muted)[— capacity]
    #linebreak()
    Remote builders and a shared cache under one gate, with per-host processes capped so a sweep cannot exhaust the
    machine it runs on.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, inside two hours of CET]
