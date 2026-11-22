// Canonical — Lead Linux Kernel Engineer, Ubuntu (Greenhouse 6010955).
// Native English source replacing the Nix-built PDF. Kernel-adjacent facts only.
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
    #text(size: 9.8pt)[Linux systems and kernel-adjacent engineer · packaging · C and Go]
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
Ten years on Linux, the last five running a thirteen-host NixOS fleet from one flake. The kernel is a declared input there, not a
default: hosts whose NVIDIA drivers require it pin the 6.12 LTS track, desktops follow the latest stable, kernel modules and parameters
are set per host where the hardware needs them, and a canary guest built from the same definitions is booted before a change reaches a
real machine.

Packaging is the discipline that follows from that. Every service ships as a module with an explicit unit, socket or timer, its
dependencies named, and a build that never touches the network; a host definition that cannot evaluate fails in CI before it reaches
hardware, and a release is a pointer to the previous generation rather than a procedure someone remembers. The gate CI runs is the gate
the machine passes, which is the only reason either can be trusted.

Before the fleet: C++ instrument software at Fraunhofer ISE that captured and processed optical measurement data from a heliostat
interferometer, with the analysis and 3D geometry in Python; and four years of solar asset management, where a number without provenance
was a number I had to defend. On the vulnerability side I built tooling around the CISA KEV catalogue and audited bug-bounty programmes,
so advisories are read for what they require rather than for what the headline says.

What I have not done: I have not submitted patches to the Linux mainline, maintained Debian source packages or carried an Ubuntu kernel
through an SRU, designed a BSP or written a driver, and I have not led silicon or cloud partner engagements. Those are the learning this
role would provide; the delivery habit — turning a fuzzy problem into a declared, gated, reviewable process — is what I bring.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Kernel configuration* — track pinning per host, modules, parameters, canaries],
  [*Packaging* — module per service, named dependencies, builds without network],
  [*Release discipline* — evaluate, gate, switch, roll back by pointer],
  [*C and C++* — instrument software and measurement processing on Linux],
  [*Go and Python* — services, tooling and automation behind one task surface],
  [*Vulnerability work* — KEV catalogue tooling, triage by exposure],
  [*Operations* — systemd, cgroups and PSI, nftables, tcpdump, journald],
  [*Writing* — runbooks and design notes that survive the author leaving])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Declared a thirteen-host fleet in one flake: each host a feature list, each service a module with an explicit unit, socket or timer, dependencies named, and a build with no network access.
- Treated the kernel as a declared input: 6.12 LTS pinned on the hosts whose NVIDIA drivers require it, latest stable elsewhere, modules and parameters per host, and a canary guest booted before any rollout.
- Gated change in CI and on the machine with the same per-host evaluation, so a definition that cannot evaluate fails before hardware sees it; rollback is a pointer to the previous generation.
- Ran health as a recording rather than a dashboard: a sentinel writes job status, generation age, disk and PSI to a ledger every fifteen minutes and pages on any state short of ok and on silence.
- Wrote a Go service that turns a request into an immutable, content-addressed specification: exact hashes over canonical JSON, a quotient hash over the fields a reviewer sees, append-only events, tests in the tree.
- Built the mail archive on PostgreSQL: a generated tsvector with a GIN index for full-text search, SQL endpoints generated from annotated queries, and an upsert keyed on message_id.
- Kept secrets and access declarative: sops-encrypted values with per-host age keys, host authentication through an own certificate authority, default-deny nftables.
- Ran vulnerability work as a pipeline: the CISA KEV catalogue matched against what the fleet runs, ordered by exposure and effort, plus bug-bounty audits read against exploit status rather than severity prose.
]

#block(breakable: false)[
#job("External consultant", "EWE Trading", "2023", "Germany")
- Three-month PPA consulting engagement inside a trading organisation, working with people who did not report to me and who were entitled to disagree.
]

#block(breakable: false)[
#job("Freelance developer", "Landvest", "2021", "Germany")
- Built a no-code application for an investment platform, shipped to people who had never seen a terminal.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem before it is a communication one.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised clients on cybersecurity software and risk management, translating both directions between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ software for a heliostat interferometer that captured and processed optical measurement data on x86 Linux.
- Implemented the analysis from a published paraboloid paper in Python, including the 3D geometry tooling, then checked the result independently rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Worked on experimental projects with technologies from the engineering department, diagnosing equipment failures under time pressure in the field.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared fleet]
    #linebreak()
    Thirteen hosts, kernel tracks pinned per host, hermetic builds, sops secrets, SSH CA, one gate for CI and machine. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Immutable, content-addressed specifications: canonical JSON hashing, append-only events, terminal UI and HTTP from one binary.
  ],
  [
    #text(weight: "bold")[email-archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    tsvector and GIN full-text search, endpoints generated from annotated SQL, an upsert keyed on message_id.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A bounded-work state machine whose benchmark falsified its own seed-only claim; the claim narrowed instead of being defended.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[vulnerability operations] #text(size: 8pt, fill: muted)[— security]
    #linebreak()
    An exposure table and a 90-day method driven by KEV data, ordered by what is actually exploited.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1.8/5.0, 1.0 best]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[English native · German C1 · US citizen with German permanent residence, no sponsorship needed · happy to travel for the twice-yearly team events · available 01.12.2026]
