// Catapult Sports — Senior DevOps Engineer. Self-contained: no external data files.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 8.7pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.45em)
#set list(marker: text(fill: rgb("#14456b"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#14456b")
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
    #text(size: 10pt)[Senior Linux & Platform Engineer]
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
Ten years of operating and writing software. I run a thirteen-host Linux fleet that is declared in a
repository: every machine converges to that declaration, a change passes a gate in CI and on the host or
it does not ship, and rollback is a pointer to the previous generation. I provision bare metal myself,
treat the network as part of the system, and read state from a ledger rather than a dashboard. Go,
Python and Bash are working languages, not resume lines. The one thing I will not claim is production
Kubernetes: containers have been pinned build environments for me, not a platform I have run.

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Sole engineer for a thirteen-host Linux fleet held as one declaration; no hand edits on a target host, and a rebuild is a described path rather than a ritual.
- Provisioned bare metal end to end with PXE and iVentoy: first configuration, service bring-up and rebuild, so a new machine costs a declaration and a boot, not an afternoon.
- Treated the network as code: WireGuard between hosts, nftables default-deny, an internal DNS zone, and MTU or path-MTU faults found with tcpdump instead of guessed at.
- Made releases atomic: the same module gate runs in CI and on the host; a failing check leaves the previous generation in place, and rollback is a pointer move.
- Served web workloads behind nginx with TLS from an internal certificate authority and short-lived certificates, never long-lived keys copied by hand.
- Kept observability as a ledger: job status, generation age, disk pressure and PSI every fifteen minutes, with a page on any state other than ok — the same record that answers "what changed" during an incident.
- Held workloads inside limits: systemd slices with memory caps, cgroups, PSI as the load signal, ARM boards and microVMs running on scarce RAM.
- Made cost a design constraint rather than a monthly surprise: ARM over x86, microVMs over VMs, build cache and store substitution instead of recompiling on every rebuild.
- Wrote Go, Python and Bash tooling behind a single task surface, including Go services backed by PostgreSQL and an append-only event log.
- Kept secrets per host with SOPS and age, least privilege by default, and TLS issued from a private CA rather than a shared secret.
- Built vulnerability work as data: the CISA KEV catalogue as a time series, exposure clustered by remediation effort, in plain SVG.
- Priced and hedged weather derivatives, and advised clients as internal risk manager.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Ran software and IT administration for the company and its subsidiaries: workstations, network, Wi-Fi, and the people using them.
- Supported users directly — field technicians and office staff — with instruction instead of ticket forwarding.
- Built financial models and managed 10 MW of solar PV assets inside a portfolio above USD 100 M.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on cybersecurity software and risk management.
- Managed a project pipeline above USD 100 M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies with interferometry and wrote the C++ acquisition software for the lab instruments.
- Wrote Python tooling for analysis and 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Led two frac crews carrying more than USD 3 M of contract volume per week, and ran the crew's safety training.
- Fixed chemical and equipment faults on site, under time pressure and without a second attempt.

#section("Selected Projects")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative fleet]
    #linebreak()
    One flake declares thirteen NixOS hosts, nginx vhosts with TLS, an SSH certificate authority,
    SOPS-encrypted secrets and a task surface. CI and the host execute the same module gate.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Turns a request into an immutable, content-addressed specification: append-only events, a terminal
    interface and curl endpoints from one binary, persisted in PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— vulnerability data]
    #linebreak()
    CISA's known-exploited catalogue as a time series in plain SVG, with exposure clustered by effort.
  ],
  [
    #text(weight: "bold")[risk-calc] #text(size: 8pt, fill: muted)[— Go and pipelines]
    #linebreak()
    Green's theorem over stochastic polygons: a Go fuzzer generates shapes, a Nushell and Awk pipeline
    drives the computation.
  ])

#section("Skills")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Automation* — declarative configuration, gates, Go, Python, Bash],
  [*Networking* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Observability* — ledger-based health checks, alerting, PSI, incident notes],
  [*Bare metal* — PXE/iVentoy provisioning, rebuild, rollback by generation],
  [*Data* — PostgreSQL, append-only events, REST],
  [*Cloud* — Oracle Cloud hosts, one AWS Lambda project],
  [*Security* — SOPS/age, minimal privileges, vulnerability data (KEV)])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[MSc Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1.8/5.0]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[BSc Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.6pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · no sponsorship required]
