// trawa — Engineering Manager, Platform and Data Intelligence. Self-contained Typst.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 8.7pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.45em)
#set list(marker: text(fill: rgb("#0f5132"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#0f5132")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 7pt, below: 2pt)[
  #text(size: 9.6pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
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
    #text(size: 10pt)[Energy Data & Platform Engineer · MSc Renewable Energy Management]
  ],
  [
    #align(right)[
      #text(size: 8pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8pt)[matt\@bountystash.com · github.com/shaoyanji · bountystash.com]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
A decade across two halves of the same problem: energy markets and the systems that carry their data.
I hold an MSc in Renewable Energy Management from Freiburg, priced and hedged weather derivatives as an
internal risk manager, managed 10 MW of solar assets and a portfolio above USD 100 M, and spent the last
five years building the Linux platform underneath — thirteen hosts declared in one repository, telemetry
written to a ledger every fifteen minutes, releases that roll back by pointer. Go, Python and Nix are how
I make a pipeline repeatable. What I have not done is manage a team of engineers, and I have not run AWS
Terraform estates; both are stated before the first call.

#section("Energy & Data")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 3pt,
  [*Market data* — weather derivatives priced and hedged; volatility models on long-range weather series],
  [*Asset operations* — 10 MW solar PV, asset management over a portfolio above USD 100 M],
  [*Telemetry* — fifteen-minute ledger of job status, generation age, disk pressure and PSI; pages on any state other than ok],
  [*Data engineering* — PostgreSQL services with append-only event logs; Python analysis pipelines; SVG rendering without a chart library],
  [*Metering mindset* — billing-grade numbers come from records, not dashboards: the same discipline applies to invoicing data],
  [*Domain study* — MSc thesis on weather-pattern prediction and intermittency; neural networks on multi-decade series])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Sole engineer for a thirteen-host Linux fleet declared in one repository; every machine converges to the declaration, and no change reaches a host without a gate that runs in CI and on the host.
- Wrote telemetry as a ledger rather than a dashboard: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state other than ok — the record an incident review reads.
- Kept pipelines reproducible end to end in Go, Python and Nix: the same input produces the same output on any host, and a rebuild does not re-derive yesterday's decisions.
- Held services on PostgreSQL with append-only event logs, so historical state is auditable rather than overwritten.
- Provisioned bare metal with PXE and iVentoy through first configuration and rebuild; ran workloads inside systemd slices, cgroups and memory caps.
- Ran the network as code — WireGuard, nftables default-deny, internal DNS, MTU faults found with tcpdump — and served web workloads behind nginx with TLS from an internal CA.
- Made cost a design decision: ARM over x86, microVMs over VMs, build cache instead of recompiling.
- Built vulnerability reporting as data: CISA KEV as a time series, exposure clustered by remediation effort.
- Priced and hedged weather derivatives and advised clients as internal risk manager.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Managed 10 MW of solar PV assets inside a portfolio above USD 100 M: production data, contracts, counterparties and the reporting that turned them into decisions.
- Built the financial models behind those decisions in Python and spreadsheets that had to survive an audit.
- Ran software and IT administration for the company and its subsidiaries, supporting field technicians directly.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy, cybersecurity software and risk management across a pipeline above USD 100 M.
- Translated technical and market risk into language a non-technical board could act on.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies with interferometry and wrote the C++ acquisition software for the instruments.
- Wrote Python tooling for analysis and 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Led two frac crews carrying more than USD 3 M of contract volume per week, and owned the crew's safety training.
- Fixed chemical and equipment faults on site, under time pressure, without a second attempt.

#section("Selected Projects")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative platform]
    #linebreak()
    One flake declares thirteen NixOS hosts, nginx vhosts with TLS, an SSH CA, SOPS secrets and a task
    surface; CI and host run the same module gate.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service, Postgres]
    #linebreak()
    An immutable, content-addressed specification from one request: append-only events, a terminal
    interface and curl endpoints from one binary.
  ],
  [
    #text(weight: "bold")[Master's thesis] #text(size: 8pt, fill: muted)[— weather and volatility]
    #linebreak()
    Time cross-correlation of wind speeds and neural networks on long-range weather data; published
    through the University of Freiburg.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— data reporting]
    #linebreak()
    CISA's known-exploited catalogue as a time series in plain SVG — the kind of recurring report an
    operations team actually reads.
  ])

#section("Skills")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Energy* — market prices, derivatives, PPAs-adjacent asset economics, intermittency],
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Data* — PostgreSQL, append-only events, Python (pandas-era analysis), SQL],
  [*Automation* — declarative configuration, gates, Go, Python, Bash],
  [*Networking* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Observability* — ledger health checks, alerting, incident notes],
  [*Cloud* — Oracle Cloud hosts, one AWS Lambda project; no Terraform estate yet],
  [*Security* — SOPS/age, least privilege, KEV-driven vulnerability work])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[MSc Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1.8/5.0]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[BSc Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.6pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · no sponsorship required]
