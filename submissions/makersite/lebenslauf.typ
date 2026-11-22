// Makersite — DevOps / Platform Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1d4a44"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1d4a44")
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
    #text(size: 9.8pt)[Platform Operations · Python Data Pipelines · CI/CD · Linux]
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
Ten years of work where a number has to be defensible: first yield and valuation models for a solar portfolio above
USD 100M, then five years running the Linux platform those numbers were produced on. The bridge between them is data
plumbing — several measurement feeds reconciled into one auditable series, with missing readings treated as an explicit
error budget instead of a quietly good month — and the habit of asking which source settles a claim rather than which
memory sounds confident.

The platform side is declared rather than hand-built: thirteen hosts as one repository, every input pinned, every service
a module, one gate that runs identically in CI and on the machine. Secrets are encrypted per host behind a certificate
authority issuing short-lived credentials, rebuilds come from a shared binary cache and remote builders, and a sentinel
writes job status, generation age, disk and PSI every fifteen minutes and pages on any state short of ok and on silence.
Python for pipelines and tooling, Go where a service must hold state, SQL where the answer is a query. I have not operated
Postgres or a managed cloud platform in production, and I will not claim otherwise.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Python* — pipelines, reconciliation, tooling, tests over canonical data],
  [*Data quality* — three feeds to one series, explicit error budgets],
  [*SQL and modelling* — reporting schemas, joins that survive review],
  [*CI/CD gates* — one check for CI and host, fast failure, dry runs],
  [*Linux operations* — systemd, cgroups, PSI, nftables, `strace`, `tcpdump`],
  [*Observability* — fifteen-minute ledger, paging on state and silence],
  [*Developer enablement* — one entry surface, validation, generated docs],
  [*Reproducibility* — pinned inputs, content addressing, rollback as a pointer])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Declared a thirteen-host Linux platform as one repository, with a documented rebuild path per host and no manual edits on a running machine.
- Wrote the Python pipelines and tooling, with tests over canonical data rather than mocks of it, so a number in a report and a number in the ledger could not disagree.
- Kept one gate identical in CI and on the host, so a change that passes is a statement about a real machine and a failed check leaves the previous generation serving.
- Made change reversible: every generation records its parent, so a rollback is a pointer rather than an incident under time pressure.
- Built the observability loop: job status, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, with history kept for the postmortem.
- Enabled other people instead of answering tickets: one task surface with named arguments, help text, dry-run plans and JSON output, so routine work needs no briefing.
- Generated documentation from the same source as the configuration, so a stale page is a build failure rather than drift discovered mid-incident.
- Reasoned about recovery explicitly: what must survive a restart, what may be rebuilt, and how long each of those takes.
- Diagnosed at the system layer: `strace` for syscall behaviour, cgroups and PSI to separate I/O starvation from memory pressure, `tcpdump` for MTU and fragmentation.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, including reconciliation across three measurement feeds into one auditable series.
- Built reporting that could be defended line by line to banks and investors, with every assumption documented next to its number.
- Owned the cost base and the budget, and explained variance rather than reporting an aggregate.
- Ran software rollouts across client systems and documented each one as a repeatable procedure.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[three-feed reconciliation] #text(size: 8pt, fill: muted)[— data]
    #linebreak()
    Measurement sources merged into one auditable series, missing readings surfaced as an error budget, and every
    reported figure traceable to its origin.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, pinned inputs, shared cache and remote builders, one per-host gate, rollback as a pointer.
    https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— enablement]
    #linebreak()
    Every operation behind one surface with validation and dry-run plans: the measure is whether a colleague ships
    without asking.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[generated references] #text(size: 8pt, fill: muted)[— knowledge]
    #linebreak()
    Docs and a queryable graph built from the same source as the system they describe, so the page cannot drift from
    what runs.
  ],
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— access]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host encrypted secrets, with default-deny
    network rules.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, resident in Germany, no sponsorship needed · remote from Gutach im Breisgau]
