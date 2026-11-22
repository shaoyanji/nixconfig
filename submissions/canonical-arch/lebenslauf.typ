// Canonical — Information Systems, Open Source Technical Architect (Greenhouse 4551832).
// Native English source replacing the Nix-built PDF. Facts only; no cloud or web claims.
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
    #text(size: 9.8pt)[Systems and security engineer · infrastructure as code · Linux operations]
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
Infrastructure is a repository or it is a rumour. For five years I have run a fleet the first way: one flake declares thirteen
hosts, each host a concatenated feature list, each service a module with a systemd unit and defined failure behaviour, secrets
sealed with sops behind a certificate authority that issues the host keys, and every server generation rolled back by pointer
rather than by memory. Rebuilds come from a shared binary cache and remote builders, so a host is a function of the repository
and of nothing local.

The same hosts build and serve the software I write: Go services behind an append-only event log, a task control plane with typed
arguments and dry runs, an email archive that classifies its own mail, and a sentinel that writes job status, generation age, disk
and pressure into a ledger every fifteen minutes and pages on silence as well as on failure. That last choice is deliberate — a
monitor that dies quietly is indistinguishable from a system with nothing to report.

Before software I was a risk analyst: covered-call hedging for client portfolios, yield models for a solar portfolio above
USD 100M, corporate liability frameworks, heliostat metrology at Fraunhofer ISE. That is where the incident habit came from. A
postmortem is not finished when the unit restarts; it is finished when the reason behind the reason has a gate standing in front
of it, and the check that caught the failure has joined the gate rather than a document.

What I have not done is the organisational half of this role. I have led technical direction — the gates, runbooks and rollback
decisions other people follow — not a team of SREs and data-centre engineers, and I have not run Ubuntu packaging for tens of
millions of devices or designed internet transit. I would rather write that here than have it found in month two.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Infrastructure as code* — one flake, hosts as feature lists, modules as services],
  [*Linux operations* — systemd units, secrets, certificate authority, binary cache],
  [*Incidents* — ledger and paging, postmortems that end in a structural check],
  [*Delivery* — canary first, rollback as a pointer, one gate for CI and machine],
  [*Automation* — Go and Python behind one validated task surface],
  [*Security* — sops, SSH CA, bug-bounty triage, threat modelling],
  [*Observability* — job state, generation age, disk and pressure every fifteen minutes],
  [*Writing* — docs generated from the configuration they describe])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Declared a whole fleet as one flake: thirteen hosts, each a feature list concatenated in order, each service a module, so option surface stays a cost a gate pays for instead of a copy-paste that drifts.
- Sealed every secret with sops and issued host keys from the fleet's own SSH certificate authority, so access is a short-lived certificate rather than a key someone copied.
- Served rebuilds from a shared binary cache and remote builders, and made rollback a pointer: every server generation returns to the previous one with one command.
- Ran the same per-host module gate in CI that a machine passes before it switches, driven by an inventory file, so a broken host definition fails before it reaches hardware.
- Wrote the services the fleet runs: Go behind an append-only event log, Python analysis and tooling, PostgreSQL for state, one task entry point with typed arguments, dry runs and JSON output for callers that are programs.
- Turned monitoring into a closed loop: a fifteen-minute ledger of job state, generation age, disk and PSI, with Gatus paging on any state short of ok and on silence.
- Architected a covered-call hedging strategy for client portfolios and audited bug bounty programmes, triaging reports against known-exploited lists rather than against enthusiasm.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Analysed corporate liability risk and built the internal risk management framework that the subsidiaries were then measured against.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem before it is a communication one.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating both directions between technical and commercial readers.
- Ran customer service and support, and devised the sales and marketing strategy for the sustainability practice.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Managed two frac crews carrying USD 3M+ of work per week, diagnosing equipment and process failures under time pressure with a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative fleet]
    #linebreak()
    Thirteen hosts from one flake, pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, called by people and by agents.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— classification]
    #linebreak()
    An archive that classifies its own mail, with a verdict written and closed rather than a folder nobody reads.
  ],
  [
    #text(weight: "bold")[Swirl Engine] #text(size: 8pt, fill: muted)[— Go and geometry]
    #linebreak()
    Polygon areas from random geometric data by Green's theorem, with a Go fuzzer generating the shapes that would break it.
  ],
  [
    #text(weight: "bold")[vulnerability operations] #text(size: 8pt, fill: muted)[— security]
    #linebreak()
    Triage of disclosed vulnerabilities against exploit status, patch availability and real exposure on the fleet.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#text(size: 8.4pt)[Thesis: intermittent renewable energy and weather patterns analysed through artificial neural networks — a time-cross-correlation method for wind velocity data.]
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau · available 01.12.2026]
