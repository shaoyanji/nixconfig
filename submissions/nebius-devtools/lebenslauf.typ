// Nebius — Senior Site Reliability Engineer (DevTools). Native English source, reproducing the submitted packet.
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
    #text(size: 9.8pt)[Site reliability · Build systems · Go & Python · Developer tooling]
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
Developer tooling is a product whose success metric is whether someone's problem is gone, not whether the pipeline ran. I have
spent five years running that loop on my own infrastructure, only smaller: one flake declares the fleet, builds are hermetic and
hash-pinned from a shared cache and remote builders, each host is a feature list and each service a module, and every generation
rolls back in a single command.

CI is a gate rather than a notification. The same per-host module check runs in CI and on the machine before a change switches,
so a broken definition fails in review instead of in production. For isolation I run microVMs behind a bridge with udev-attached
taps and NAT — cheap, disposable environments that keep Linux semantics — and access follows the same rule: short-lived
certificates from the fleet's own SSH CA, per-host sops/age keys, nothing long-lived on disk.

Operations is telemetry plus a human. A sentinel writes job status, generation age, disk and PSI to a ledger every fifteen minutes
and pages when a service goes quiet, with runbooks kept as text in the repository. I build the services too, in Go and Python with
PostgreSQL underneath, and I work with agent stacks daily: tiered tool access, approval gates before destructive actions, outputs
checked against requirements.

What I have not done: operated TeamCity, Artifactory or GitLab at scale, modified GitLab internals or written TeamCity plugins;
operated Java monoliths or Spring in production, since my JVM knowledge is language-level; run Kubernetes or Terraform, since my
orchestration is NixOS and systemd and my infrastructure code is the flake. My SRE/SWE split is nearer 60/40 than 50/50: Go and
Python services, not Java/Kotlin depth.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Build systems* — hermetic, hash-pinned, cached, reproducible artefacts],
  [*CI as a gate* — one check for review and for the machine before switch],
  [*Isolation* — microVMs behind a bridge, udev taps, NAT, disposable],
  [*Reliability* — ledger every fifteen minutes, paging on state and silence],
  [*Services* — Go and Python APIs, PostgreSQL, migrations, tests],
  [*Access* — SSH certificates and per-host sops/age keys, no standing secret],
  [*Unix depth* — systemd, cgroups, PSI, initrd, `strace`, `tcpdump`],
  [*Agent tooling* — MCP mounts, JSON task surfaces, approval gates])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Operated a NixOS fleet declared as one flake: hermetic hash-pinned builds from a shared cache and remote builders, each host a feature list, every generation rollback-able in one command.
- Ran the same per-host module gate in CI and on the machine, so a broken definition fails before it reaches production.
- Ran microVMs behind an isolated bridge with udev-attached taps and NAT, so test environments are disposable without losing Linux semantics.
- Held zero standing secrets: short-lived certificates from the fleet's own SSH certificate authority and per-host sops/age keys, so a host compromise yields nothing usable elsewhere.
- Wrote a sentinel that records job status, generation age, disk and PSI every fifteen minutes and pages when a service goes quiet rather than only when it reports failure.
- Built services in Go and Python with tests, PostgreSQL migrations and a content-addressed specification for the event log.
- Built an archive that ingests mail into PostgreSQL and classifies it, then serves itself over a tailnet API with a verdict workflow that records what was decided and by whom.
- Worked with agent stacks daily: tiered tool access, approval gates before anything destructive, outputs checked against requirements instead of trusted.
- Kept runbooks as text in the repository, so the person on call reads the same file the author did.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Analysed corporate liability risks and built the internal risk management framework.
- Designed a mobile app for enterprise employees hunting new project opportunities.
- Managed an international team and built an incentive structure tied to a real-time financial model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Managed a pipeline of USD 100M+ projects and ran customer service and support for clients.
- Advised clients on cybersecurity software and risk management.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Conducted research on heliostat imperfections using interferometry.
- Wrote the C++ application that interfaces with lab equipment, and the Python analysis and 3D geometry tooling with it.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, on twelve-hour shifts.
- Led safety training for crew members and worked on experimental projects.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— build system]
    #linebreak()
    The whole fleet in one flake: hermetic builds, shared binary cache, remote builders, one-command rollback, and the same
    per-host gate in CI as on the machine. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[email-archive] #text(size: 8pt, fill: muted)[— service]
    #linebreak()
    Mail ingested into PostgreSQL and classified, then served over a tailnet API with a verdict workflow that records decisions
    and who made them.
  ],
  [
    #text(weight: "bold")[microVM isolation] #text(size: 8pt, fill: muted)[— environments]
    #linebreak()
    Guests behind an isolated bridge with udev-attached tap devices and NAT, booted capped and read-only where it matters.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on a bad state and on silence.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only event log, terminal UI and HTTP endpoints from one binary and one contract.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A benchmark falsified the first design, so the claim narrowed rather than being defended.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— University of Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 8pt, fill: muted)[*Languages* — English native, German C1. *Tooling* — Go, Python, C++, Bash, SQL/PostgreSQL, Nix, systemd, git, sops, microVMs. Java at reading level, not operated in production.]

#v(4pt)
#text(size: 7.8pt, fill: muted)[US citizen with German permanent residence, no sponsorship needed for Germany · Gutach im Breisgau, remote or Germany location · available 01.12.2026]
