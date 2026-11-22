// Attio — Senior Platform Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f3350"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1f3350")
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
    #text(size: 9.8pt)[Developer Platform · Reliability · Toil Removal]
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
I build platforms on the assumption that the platform has users, and that its users are the other engineers. Five years of
that on thirteen Linux hosts: one declaration instead of hand-built machines, a gate that runs identically in CI and on the
target host, a generation per deployment with a parent so rollback is a pointer rather than a repair, and a fifteen-minute
ledger over job status, generation age, disk pressure and PSI that pages when a machine goes quiet. Every operation sits
behind one entry surface with validation and help text, and the documentation is generated from the same source as the
configuration, because a platform nobody can use without asking is a platform that did not ship. Go and Python for the
tooling. I have not run Kubernetes, Terraform or GCP in production, I have not owned a Datadog or Splunk installation, and
I have not run a formal SLO and error-budget programme with several service teams.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Platform engineering* — one surface, validation, self-service by default],
  [*Reliability* — alert on state, silence as fault, rollback by generation],
  [*CI/CD* — one gate for CI and host, inventory-driven matrix, fast feedback],
  [*Observability* — job ledger, generation age, disk and PSI, journald],
  [*Linux* — systemd, cgroups, PSI, nftables, `tcpdump`, `strace`],
  [*Automation* — Go, Python and Bash, tested rather than asserted],
  [*Access* — SSH certificate authority, short-lived credentials, no standing secrets],
  [*Incident practice* — postmortems that end in a gate, not in a paragraph])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Treated the fleet as a product: one entry surface for every operation, named arguments, help text and machine-readable output, so a colleague could act without reading the implementation or waiting for me.
- Gated every change with a check that runs identically in CI and on the target host, so a green build could not mean something different from a healthy machine, and a failing check left the previous generation serving.
- Built the observability the fleet actually ran on: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Ended incidents by mechanism rather than by memory: anything that failed twice became a check in the gate, so the same failure could not return wearing a different hat.
- Deployed by generation with a parent pointer, which made the rollback path a one-liner and removed the argument about whether to roll back.
- Reduced toil wherever it repeated: provisioning is netboot plus a declaration, secret rotation is a certificate authority issuing short-lived credentials, and retention is a decision with a number attached.
- Traced failures at the system layer: `strace` for syscall behaviour, cgroups and PSI to separate I/O starvation from memory shortage, `tcpdump` for MTU and fragmentation.
- Wrote the Go service and the Python tooling behind the platform, with tests that fix expected behaviour.

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
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— platform as product]
    #linebreak()
    Every fleet operation behind one surface with named arguments, validation and JSON output: the measure of the
    platform is whether an engineer ships without asking me.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself, with the record kept for the postmortem.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— infrastructure as code]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation.
  ],
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— access]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host age-encrypted secrets, so no host
    holds anything reusable if it is lost.
  ],
  [
    #text(weight: "bold")[generated documentation] #text(size: 8pt, fill: muted)[— developer experience]
    #linebreak()
    Docs built from the same source as the configuration, so hosts, modules, tasks and decisions are queried rather
    than remembered, and the page cannot drift from the system.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving installers and first configuration, so a machine joins the declared fleet instead of being
    assembled by hand.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · remote from Germany, which your posting lists as eligible]
