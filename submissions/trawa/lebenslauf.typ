// trawa — Senior Platform Engineer. Standalone English source.
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
    #text(size: 9.8pt)[Platform engineering · Declarative infrastructure · Reliability · Energy markets]
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
A platform is the part of engineering that decides how fast everyone else can move, and it earns its place only when the safe
path is also the short one. I spent five years building exactly that for a thirteen-host fleet: infrastructure declared rather
than clicked, secrets encrypted per host, credentials issued as certificates that expire instead of keys that live in backups,
one gate that runs identically on a laptop, in CI and on the machine it is about to change, and a canary guest that boots the new
kernel before production does.

The unusual part of my background is what sits underneath the platform. I spent six years pricing and managing energy: options
and hedging models on weather derivatives, risk-adjusted PPA models, gas storage and swing trading risk for a German energy
trader, and asset management for a solar portfolio above USD 100M. I know what a flexibility product has to do with a schedule,
what a forecast error costs a margin, and why an interface that is one settlement period too late is worthless. Building the
platform for a company whose product is energy is not an adjacent domain for me; it is where I was before I moved into
infrastructure.

The tools differ from yours and I will say so plainly: my infrastructure is Nix on rented bare metal rather than Terraform on
AWS, my observability is a self-built ledger and gatus rather than Dash0 and Sentry, and my services are Go and Python rather
than TypeScript. The discipline is the same — declared state, reviewed diffs, pinned inputs, reasoned exceptions — and Terraform
is the easier half of that trade to learn.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Declarative infrastructure* — one repository, pinned inputs, reviewable diffs],
  [*Delivery* — one gate for CI and hosts, canary first, rollback as a pointer],
  [*Security* — sops/age per host, certificate-based SSH, default-deny networks],
  [*Reliability* — fifteen-minute ledger, paging on bad state and on silence],
  [*Automation* — Go and Python behind one validated task surface],
  [*Cost and capacity* — the same declaration answers what a change will spend],
  [*Energy domain* — PPA, hedging, gas storage, flexibility and settlement],
  [*Adoption* — docs generated beside the config, help text that answers first])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Declared the whole estate instead of scripting it: thirteen hosts from one repository with pinned inputs and hermetic builds, so the same commit produces the same machine and a change arrives as a reviewable diff.
- Ran one gate for CI and for the machines, so a build that passes locally means something on the host, and drift shows up as a failing check rather than as an incident.
- Encrypted secrets per host with sops and age, each machine holding only its own key, and default-deny between hosts, so a compromised machine yields nothing usable against another.
- Built the reliability loop: job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence.
- Made delivery reversible: deploys reach a canary guest before production, rollback is a pointer, and no change depends on a sequence only one person knows.
- Automated recurring operations in Go and Python behind one task surface with named arguments, validation, dry-run plans and JSON output, so routine work is a command and a wrong argument fails early.
- Kept cost visible: capacity and spend decisions written down where the configuration lives, so a resize or a new host has a stated reason rather than an invoice arriving later.
- Documented for the reader who did not design it: generated references, runbooks for on-call, and an explanation next to every exception from the default.

#job("Senior Consultant and Risk Manager", "Bountystash (energy practice)", "Jun 2020 – Aug 2025")
- Built risk-adjusted PPA trading models and options and hedging strategies on weather derivatives for energy companies.
- Acted as in-house risk manager for a top German energy trader, including gas storage and gas swing trading models for EWE Trading.
- Modelled the economics that flexibility products sell into: forecast error, settlement periods, and the cost of being wrong about either.
- Advised clients holding land portfolios above USD 300M and audited bug bounty programmes alongside the risk work.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Managed an international team and built an incentive structure tied to a live financial model.

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, translating both directions between technical and commercial readers.
]

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis, then verified the geometry independently in Mathematica.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, one declaration, pinned inputs, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— developer experience]
    #linebreak()
    One validated surface with dry runs and JSON output, so a routine request is a command rather than a ticket.
  ],
  [
    #text(weight: "bold")[PPA and hedging models] #text(size: 8pt, fill: muted)[— energy]
    #linebreak()
    Risk-adjusted trading models and weather-derivative hedges, with every assumption documented beside its number.
  ],
  [
    #text(weight: "bold")[gas storage risk] #text(size: 8pt, fill: muted)[— energy]
    #linebreak()
    Storage and swing trading risk for a German energy trader, where the value is entirely in the timing.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only event log, terminal UI and HTTP endpoints from one binary and one contract.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · based in Gutach im Breisgau, Berlin office days a relocation question · available 01.12.2026]
