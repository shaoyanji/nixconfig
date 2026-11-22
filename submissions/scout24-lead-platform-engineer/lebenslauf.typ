// Scout24 — Lead Platform Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2f3350")
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
    #text(size: 9.8pt)[Platform engineering · APIs for agents · SRE · Go & Python]
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
A platform is judged by the teams that use it, not by the team that builds it. I have spent five years on the far side of that
sentence, building shared capabilities for a thirteen-host fleet and then watching where engineers actually went: the paved road
won only where it was shorter than the workaround, so I optimised for that — one command with real help text, a dry run that
says what would change, and machine-readable output for the tooling that consumes it.

That last part is now the interesting edge. The interfaces I build are used by humans and by agents, which forces a discipline
that helps both: typed arguments instead of prose, validation before any side effect, JSON in and JSON out, and a stable contract
so a caller that is not reading documentation can still be correct. My fleet's task surface, its turn-log and archive APIs and
its MCP tool mounts are all built that way, because an agent that guesses is worse than an agent that fails.

Reliability is the other half. A fifteen-minute ledger records job state, generation age, disk and pressure, and pages on any
state short of ok and on silence, because a monitor that dies quietly looks exactly like a system with nothing to report. Rollback
is a pointer, deploys go through a canary first, and every incident I have handled ends as an entry in a runbook rather than as
memory.

What I have not done: run workloads on AWS or EKS, written TypeScript, CDK, Terraform or Pulumi, or owned a formal
SLI/SLO/error-budget programme at company scale. My reliability targets lived as gate thresholds and alert conditions in the
repository, which is the same discipline with less ceremony.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Platform APIs* — typed contracts, validation, dry runs, stable output],
  [*Agent interfaces* — MCP tool mounts and JSON surfaces an agent can call],
  [*Reliability* — ledger every fifteen minutes, paging on state and on silence],
  [*Delivery* — canary first, rollback as a pointer, one gate for CI and hosts],
  [*Declarative infrastructure* — pinned inputs, hermetic builds, rebuildable hosts],
  [*Automation* — Go and Python behind one validated task surface],
  [*Incident work* — runbooks written for the reader who is on call at 02:00],
  [*Docs* — generated from the same source as the configuration])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built the platform surface engineers used daily: one task entry point with named arguments, validation, dry-run plans and JSON output, so a routine change is a command and a wrong argument fails before it touches anything.
- Designed the interfaces for machine callers as carefully as for people: typed arguments, a stable JSON contract and MCP tool mounts, so an agent invokes the same operations a human does instead of improvising around them.
- Ran reliability as a closed loop: a fifteen-minute ledger of job state, generation age, disk and PSI, paging on any state short of ok and on silence, with thresholds living in the repository rather than in someone's memory.
- Made delivery reversible: deploys reach a canary guest before any host that matters, rollback is a pointer, and no change depends on a hand-run sequence that only one person knows.
- Declared infrastructure instead of scripting it: thirteen hosts from one repository, pinned inputs, hermetic builds, one gate per host that runs identically on a laptop, in CI and on the machine.
- Chose build versus buy deliberately, and wrote down why: Tailscale over a self-run overlay, gatus over a bespoke checker, and a self-hosted service where the data could not leave the building.
- Wrote Go and Python services with tests, including a single binary that serves an append-only event log, a terminal UI and HTTP endpoints from one contract.
- Turned incidents into permanent fixes: every escalation ended as a gate, a check or a runbook entry, so the same page did not arrive twice for the same reason.
- Documented for two audiences at once: the engineer making the change and the person on call who has to understand it at the
  worst possible moment.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem.

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, translating both directions between technical and commercial readers.
]

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis, then verified the geometry independently in Mathematica rather than trusting the first implementation.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, with a crew and a schedule depending on the answer.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— platform API]
    #linebreak()
    One validated surface with typed arguments, dry runs and JSON output, called by engineers and by agents from the same contract.
  ],
  [
    #text(weight: "bold")[agent tool mounts] #text(size: 8pt, fill: muted)[— machine callers]
    #linebreak()
    MCP mounts, a turn-log API and an archive API, so an agent acts through the operations a human uses.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative platform]
    #linebreak()
    Thirteen hosts, pinned inputs, hermetic builds, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only event log, terminal UI and HTTP endpoints from one binary and one specification.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A benchmark falsified the first design, so the claim narrowed rather than being defended.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · based in Gutach im Breisgau, Berlin on-site days a relocation question · available 01.12.2026]
