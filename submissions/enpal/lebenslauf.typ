// Enpal — Staff Platform Engineer (f/m/d). Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#8a5a1e"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#8a5a1e")
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
    #text(size: 9.8pt)[Energy Assets · Platform Architecture · Fleet Telemetry]
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
Two things usually sit in different people: knowing what a fleet of energy assets costs when a string stops reporting, and being able
to build the platform that notices. I have both. Four years running asset management for a solar portfolio above USD 100M —
plant telemetry, the O&M work it triggered, bank-audited valuation models — and five years since building the platform that
carries it: thirteen Linux hosts declared in one repository, a gate identical in CI and on the machine, rollback as a pointer,
and a fifteen-minute ledger over job status, generation age, disk pressure and PSI that pages when a service goes quiet. I
have not run production Kubernetes, Terraform, Helm or Azure; my orchestration is systemd and my infrastructure as code is a
flake. I would be joining to bring the energy domain and the reliability judgment, and to learn the stack the rest of your
organisation already agrees on.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Energy domain* — asset economics, yield and valuation models, O\&M, audits],
  [*Platform architecture* — declared hosts, pinned inputs, generations],
  [*Linux* — systemd, cgroups/PSI, nftables, `tcpdump`, `strace`],
  [*Telemetry* — fifteen-minute ledger, alert on state not volume],
  [*Automation* — Go, Python, Bash behind one validated entry surface],
  [*Standards* — one gate for CI and host, generated docs, review culture],
  [*Cost and trade-offs* — retention as a decision, capacity measured],
  [*Leadership* — international team, mentoring, design review])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Kept thirteen Linux hosts in one declaration: services, storage, firewall, secrets and telemetry as modules, with a written rebuild path per host and no manual edits on a running machine.
- Made the platform self-service rather than heroic: every operation behind one entry surface with named arguments, help text and machine-readable output, so a developer runs it without reading the implementation or asking me.
- Gated every change with a check that runs identically in CI and on the target machine, so a failed gate leaves the previous generation serving and a green build means something.
- Built the telemetry loop the fleet runs on: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Treated documentation as a product surface: generated from the same source as the configuration, so hosts, modules, tasks and decisions are queried rather than remembered.
- Used cgroups and PSI to attribute latency to I/O or memory, and `tcpdump` and `strace` to prove a fault instead of restarting around it.
- Wrote the Go service and Python tooling behind the data model: append-only events, exact hashes over canonical JSON, tests that fix expected behaviour.
- Set the engineering bar by review and by mechanism: a change that failed twice became a check, and the check joined the gate.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Headed asset management of a solar portfolio above USD 100M, including the operation of 10 MW of PV plants.
- Built yield and valuation models that satisfied bank auditors, and ran due diligence on O&M projects as cover for project managers.
- Reconciled meter, inverter and weather feeds into one auditable series, turning a dead sensor into a known error budget rather than a good month.
- Worked with clients, banks and deal brokers across a dozen projects of USD 4–5M each, and built the internal risk framework.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, and implemented its analysis in Python with 3D geometry.
- Measured optical imperfections in campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[energy telemetry] #text(size: 8pt, fill: muted)[— O3 Energy]
    #linebreak()
    Three feeds reconciled into one auditable series for a portfolio above USD 100M, with missing readings carried as
    a known error budget instead of smoothed into a good month.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— health ledger]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself: the same question a plant operator asks, asked of servers.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared platform]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— developer experience]
    #linebreak()
    Every fleet operation behind one surface with validation and help text, so a colleague cannot improvise a
    half-step and a wrong argument fails before it reaches a host.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— data model]
    #linebreak()
    Append-only request lifecycle with exact hashes over canonical JSON, so identity and audit are schema properties
    rather than an inference.
  ],
  [
    #text(weight: "bold")[risk calculation engine] #text(size: 8pt, fill: muted)[— Swirl]
    #linebreak()
    A calculation engine for risk and valuation questions where every input is traceable, so a number from the model
    stays checkable rather than plausible.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · Berlin hybrid, relocation by agreement]
