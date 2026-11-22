// Mozilla — Staff Software Engineer, Tools & Systems. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#3d2a4a"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#3d2a4a")
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
    #text(size: 9.8pt)[Developer Tooling · Build Systems · Linux Internals · Open Source]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[German C1 · English native · US citizen with German permanent residence]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I build the tools other engineers use to ship, and I keep them honest with a gate that runs the same way everywhere. Five
years of it in public: a repository that declares thirteen Linux hosts, a task plane that replaces a drawer of shell
scripts, documentation generated from the same source as the configuration, and CI that runs the identical per-host check
the machine runs. Underneath that, the parts a build system lives or dies on: pinned inputs, content-addressed outputs, a
rebuild that produces the same artefact months later, and a rollback that is a pointer rather than a repair. Diagnostics
start at the kernel — cgroups, PSI, `strace`, `tcpdump` — because a tool that cannot explain itself on a bad day is not a
tool. Go and Python on the tooling side. I have not worked in a browser-scale C++ or Rust codebase, I have not run
Terraform, and my cloud is bare metal rather than a managed platform.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Developer tooling* — one entry surface, validation, help text, JSON output],
  [*Build systems* — pinned inputs, hermetic output, content addressing],
  [*CI/CD* — one gate for CI and host, inventory-driven matrix, fast feedback],
  [*Linux* — systemd, cgroups, PSI, nftables, `tcpdump`, `strace`],
  [*Observability* — job ledger, generation age, disk and PSI, journald],
  [*Automation* — Go, Python, Bash, tests over canonical data],
  [*AI-assisted development* — drafts gated against requirements, human signs],
  [*Open source* — public repository, docs as a build artefact, reproducible setup])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built a task plane so fleet work stopped being remembered shell history: every operation behind one surface with named arguments, help text and machine-readable output, so a colleague acts without reading the implementation.
- Made builds hermetic by construction: inputs pinned in a lock file, outputs addressable by content, so a rebuild months later yields the same artefact rather than something that merely compiles today.
- Gated every change with a check that runs identically in CI and on the target host, and drove it from an inventory so a fleet-wide sweep evaluates one host per process under a memory guard.
- Generated the documentation from the same source as the configuration, so hosts, modules, tasks and decisions are queried rather than remembered and the page cannot drift from the system.
- Built the telemetry loop the platform runs on: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence.
- Used that data to decide rather than to decorate: capacity curves, cache misses and builder pressure became arguments with numbers attached.
- Diagnosed problems at the system layer: `strace` for syscall behaviour, cgroups and PSI to separate I/O starvation from memory shortage, `tcpdump` for MTU and fragmentation.
- Wrote the Go service and Python tooling behind all of it, and kept the whole repository public as the working sample.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Turned missing readings into an explicit error budget instead of a quietly good month, keeping history auditable for bank review.
- Ran software rollouts across client systems and documented each one.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, implemented its analysis in Python with 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— developer experience]
    #linebreak()
    Every fleet operation behind one surface with named arguments, validation and JSON output: the measure is whether a
    colleague ships without asking, and whether a wrong argument fails before it touches a host.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— reproducible builds]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[generated documentation] #text(size: 8pt, fill: muted)[— knowledge system]
    #linebreak()
    Docs, a task surface and a knowledge graph built from the same source as the configuration, so a stale page is a
    build failure rather than a slow drift.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself, with the history kept for the postmortem.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— Go, streaming]
    #linebreak()
    A streaming protocol implementation with Zobrist hashing and benchmarks, written to hold state correctly under
    concurrency rather than to pass a demo.
  ],
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— security]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host encrypted secrets, so no machine
    holds anything reusable if it is lost.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · remote from Germany, the location this posting names]
