// Sourcegraph — Software Engineer, Platform [IC3]. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#7a2e2a"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#7a2e2a")
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
    #text(size: 9.8pt)[Platform Engineering · Fleet Orchestration · Linux Internals]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[German C1 · English native · US citizen, German permanent residence]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I write Go services and I run a fleet the way a control plane should: thirteen Linux hosts declared in one repository,
every instance a generation with a parent, every rollback a pointer rather than a repair, and every change through a
gate that runs identically in CI and on the machine. That is fleet orchestration with the API missing, so I built the
missing parts instead — one entry surface with named arguments and machine-readable output, a content-addressed store
where identical input lands on identical identity, telemetry every fifteen minutes, and a change path where a bad
release has a known way back. I have not operated Kubernetes, Terraform or a public cloud control plane; my platform
is bare metal, single region, and small. I debug distributed problems at the OS level — cgroups, PSI, MTU, `tcpdump`,
`strace` — before I reach for a dependency. Germany-based, happy to hold until 21:00 CET for EST overlap.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Go* — services, CLI surfaces, tests, content-addressed data models],
  [*Declarative orchestration* — pinned inputs, generations, rollback as a pointer],
  [*Linux internals* — systemd, cgroups/PSI, nftables, MTU and packet tracing],
  [*APIs and contracts* — stable JSON output, named arguments, idempotent operations],
  [*Reliability* — gate identical in CI and host, silence treated as a fault],
  [*Observability* — job status, generation age, disk and PSI, every fifteen minutes],
  [*Data* — PostgreSQL, append-only events, hashing, deduplication],
  [*Security* — SOPS/age secrets, SSH certificate authority, default-deny])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Wrote a Go service that models an append-only request lifecycle: PostgreSQL work versions, exact hashes over canonical JSON, a quotient hash over the fields a reviewer sees, and append-only events, with Go tests that fix the expected behaviour rather than the current output.
- Exposed the whole fleet as one command surface with named arguments, help text and machine-readable JSON, so a colleague or a script can drive it without reading the implementation.
- Declared thirteen Linux hosts in one repository: services, storage layouts, firewall rules, secrets and telemetry, with the rebuild path for each host written down.
- Made rollback structural: a change produces a new generation with a parent, so reverting is a pointer to the previous one rather than a repair under pressure.
- Gated every change with a check that runs identically in CI and on the target machine; a failing check leaves the previous generation serving.
- Traced faults at the OS level — `tcpdump` for MTU and fragmentation, `strace` for syscall behaviour, cgroups and PSI to separate I/O starvation from memory shortage.
- Built a telemetry loop recording job status, generation age, disk pressure and PSI every fifteen minutes, reporting any state short of ok.
- Ran workloads in declared microVMs and memory-capped systemd slices, so one exhausting process stayed a process and not an incident.
- Hardened hosts with nftables default-deny, per-host SOPS/age secrets and an SSH certificate authority issuing short-lived credentials.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Replaced guesswork on missing readings with an explicit error budget, keeping history complete enough to satisfy bank auditors years later.
- Ran software rollouts across client systems and documented each one.
- Looked after software and IT administration for the company and its subsidiaries.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Turned technical constraints into decisions a non-technical board could act on, in writing.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application that drove a heliostat interferometer and captured its measurements.
- Implemented the analysis from a published paraboloid paper in Python, including 3D geometry, and evaluated the series statistically.
- Worked inside fixed measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.
- Led the crew's safety training and worked to procedures that tolerate no deviation.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— fleet as declaration]
    #linebreak()
    Thirteen hosts, 1,400+ files, one flake: pinned inputs, per-host generations, secrets, telemetry and a task
    surface. Deployment is a rebuild, and the identity of every input is in the lock file.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service + data model]
    #linebreak()
    Append-only request lifecycle with exact hashes and quotient hashes over reviewer-visible fields, so
    deduplication and audit are properties of the schema.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— one entry surface]
    #linebreak()
    Every fleet operation behind one command surface with named arguments, help text and JSON output, validated so
    that a wrong argument fails before it touches a host.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry loop]
    #linebreak()
    Checks job status, generation age, disk pressure and PSI, reports anything short of ok, and keeps the record of
    what was measured when.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— streaming in Go]
    #linebreak()
    A streaming protocol implementation with Zobrist hashing and benchmarks, written to hold state correctly rather
    than to pass a demo.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving installers and first configuration, so a machine joins the declared fleet instead of
    being assembled by hand.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · Europe-based, available until 21:00 CET to hold the EST overlap]
