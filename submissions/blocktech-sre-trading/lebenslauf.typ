// BlockTech — Senior SRE, Trading Infrastructure. Self-contained Typst.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 8.7pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.45em)
#set list(marker: text(fill: rgb("#7a1f2b"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#7a1f2b")
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
    #text(size: 10pt)[Linux Reliability Engineer · Derivatives & Bare Metal]
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
Two threads that this role needs at once. The first is pricing: I built an algorithm for options trading and
hedging on weather derivatives, ran it as an internal risk manager, and modelled the volatility that drove
it. The second is the machine underneath: thirteen Linux hosts built from bare metal, declared in one
repository, with every change gated and every rollback a pointer move. I read system state from a ledger —
job status, generation age, disk pressure, PSI — rather than from a dashboard, and I have run it around the
clock. I have not worked in a colocation cage next to an exchange, have not tuned a kernel for microsecond
latency, and do not write Rust. Those are the honest edges of this application.

#section("Trading & Reliability")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 3pt,
  [*Derivatives* — options pricing and hedging on weather, as an engine and as a risk function],
  [*Risk* — volatility models on multi-decade weather series; hedging decisions with real money behind them],
  [*Bare metal* — PXE/iVentoy provisioning, first boot, rebuild, no hypervisor between me and the hardware],
  [*Low-level state* — cgroups, PSI, systemd slice limits, journald, tcpdump for MTU and path faults],
  [*24/7 posture* — a page on any state other than ok, fifteen-minute ledger, incident notes written down],
  [*Automation* — Go, Python, Bash and Nix behind one task surface; gates instead of runbook memory],
  [*Network* — WireGuard, nftables default-deny, private DNS, TLS from an internal CA],
  [*Data* — PostgreSQL with append-only events; content-addressed specifications])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built and operated a thirteen-host Linux fleet from bare metal: provisioning over PXE and iVentoy, first configuration, rebuild, and no hand edits on a running host.
- Held every change to a gate that runs in CI and on the host; a failed check leaves the previous generation running, and rollback is a pointer move.
- Ran telemetry as a record: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state other than ok.
- Diagnosed failures with journald, cgroups and tcpdump across host, unit and time boundaries, and wrote cause and remedy into the repository.
- Wrote Go, Python and Bash tooling behind one task surface, including Go services on PostgreSQL with an append-only event log.
- Kept workloads inside limits: memory caps per systemd slice, cgroups, PSI as the load signal, ARM boards and microVMs on scarce RAM.
- Ran the network as code: WireGuard between hosts, nftables default-deny, an internal DNS zone, MTU faults found rather than guessed.
- Hardened access with SOPS/age secrets per host, short-lived SSH certificates and TLS from an internal CA; privileges at the minimum.
- Made cost and latency a design decision: ARM over x86 where it fit, microVMs over VMs, build cache instead of recompiling on every rebuild.
- Priced and hedged weather derivatives and advised clients as internal risk manager.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Managed 10 MW of solar PV assets in a portfolio above USD 100 M, and built the financial models the decisions rested on.
- Ran software and IT administration for the company and its subsidiaries, supporting field technicians directly.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy, risk management and cybersecurity software.
- Owned a client-facing pipeline above USD 100 M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies with interferometry; wrote the C++ acquisition software and Python analysis tooling.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Led two frac crews carrying more than USD 3 M of contract volume per week, and owned crew safety training.
- Fixed equipment faults on site under time pressure, with no second attempt.

#section("Selected Projects")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[risk-calc] #text(size: 8pt, fill: muted)[— pricing engine]
    #linebreak()
    Green's theorem over stochastic polygons: a Go fuzzer generates shapes, a Nushell and Awk pipeline
    drives the computation — the same shape as pricing a path-dependent claim.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— bare-metal fleet]
    #linebreak()
    One flake declares thirteen NixOS hosts, nginx with TLS, an SSH CA, SOPS secrets and a task surface;
    CI and the host run the same module gate.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    An immutable, content-addressed specification from one request: append-only events and a terminal
    interface from one binary, on PostgreSQL.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— bounded work]
    #linebreak()
    A Fibonacci-radix state machine processing a bitstream with bounded work per step — latency measured,
    not assumed.
  ])

#section("Skills")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Systems* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Trading* — options and derivatives pricing, hedging, volatility models],
  [*Automation* — Go, Python, Bash, Nix; gates and runbooks],
  [*Bare metal* — PXE/iVentoy, rebuild, rollback by generation],
  [*Network* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Data* — PostgreSQL, append-only events, REST],
  [*Cloud* — Oracle Cloud hosts, one AWS Lambda project],
  [*Not held* — Rust, kernel latency tuning, exchange colocation])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[MSc Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1.8/5.0]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[BSc Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.6pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · no sponsorship required]
