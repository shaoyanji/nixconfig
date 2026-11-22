// Adyen — Senior Platform Engineer, Observability. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1b4d3e"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1b4d3e")
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
    #text(size: 9.8pt)[Telemetry Platforms · Linux Performance · Automation that Removes Toil]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[US citizen · German permanent residence · English native, German C1]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I build the part of a platform that decides whether an incident is a page or a paragraph in a postmortem: a
fifteen-minute ledger over job status, generation age, disk pressure and PSI, alerting on state rather than on volume,
treating silence as a fault. Behind it, thirteen Linux hosts described in one repository, a gate identical in CI and on
the machine, rollback as a pointer to the previous generation, and cgroups and PSI used to tell I/O starvation from
memory shortage under load. Every checklist item that failed twice became a check, which is how the same incident stops
recurring. I have not run Elasticsearch, Prometheus, VictoriaMetrics or Grafana Tempo in production, I have not operated
Kubernetes, and my fleet is bare metal at thirteen machines rather than 1,500. Go and Python throughout, and a strong
preference for engineering alerts out of existence instead of answering them.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Telemetry* — event schemas, fifteen-minute ledger, alert on state],
  [*Linux* — cgroups, PSI, nftables, `tcpdump`, `strace`, MTU and fragmentation],
  [*Automation* — Go and Python tools behind one validated entry surface],
  [*Reliability* — gate identical in CI and host, rollback as a pointer],
  [*Self-healing* — bounded restarts, memory-capped slices, declared microVMs],
  [*Storage* — retention as a decision, content addressing, disk pressure],
  [*Incident response* — signal over volume, postmortems that end in a gate],
  [*Declarative infrastructure* — pinned inputs, per-host generations])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built the health ledger the fleet runs on: job status, service reporting, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Chose signal over volume deliberately: one condition per check, thresholds with a meaning, and no alert whose page would not change what someone does next.
- Turned recurring incidents into mechanism: every repeated checklist item became a check, every check became part of the gate, and the gate runs identically in CI and on the machine.
- Used cgroups and PSI to separate I/O starvation from memory shortage under load, and `tcpdump` to prove MTU and fragmentation problems rather than guess at them.
- Ran self-healing in the narrow sense that survives scrutiny: bounded restart policies, memory-capped systemd slices, declared microVMs, and a canary host before the fleet.
- Kept retention and lifecycle as explicit decisions with a number attached, so storage pressure arrives as a known curve instead of a surprise.
- Wrote the tooling in Go and Python behind one entry surface, with named arguments and help text, so an operator cannot half-run an operation.
- Made rollback structural: a generation keeps its parent, so returning to a known-good system is a pointer rather than a repair at 03:00.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across meter, inverter and weather feeds, deviation analysis.
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
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— health ledger]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself, with the history kept so a postmortem has evidence.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— toil removal]
    #linebreak()
    Every recurring operation behind one surface with named arguments and validation, so a wrong argument fails before
    it touches a host and a human cannot improvise a half-step.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared fleet]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and a rollback that is a pointer to the
    previous generation.
  ],
  [
    #text(weight: "bold")[pressure triage] #text(size: 8pt, fill: muted)[— Linux]
    #linebreak()
    cgroups and PSI to attribute latency to I/O or memory, `tcpdump` for MTU and fragmentation, `strace` where the
    syscall is the only honest witness.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— data model]
    #linebreak()
    Append-only request lifecycle with exact hashes over canonical JSON, so identity and audit are schema properties
    rather than an inference.
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
#text(size: 7.8pt, fill: muted)[US citizen, no sponsorship needed in the US · German permanent residence · English native, German C1 · ready to relocate to Amsterdam]
