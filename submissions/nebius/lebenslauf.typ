// Nebius — Senior/Staff Site Reliability Engineer (Server Infrastructure).
// Native English source replacing the ad-hoc PDF. Fleet lifecycle, observability, automation.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#22304a"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#22304a")
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
    #text(size: 9.8pt)[Site reliability engineer · Linux and bare-metal infrastructure]
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
I run a small fleet the way a large one has to be run: a machine arrives, gets its operating system over the network, joins a declared fleet,
is watched, and is rebuilt or retired without anyone logging in to edit it. Thirteen hosts, one flake, every input pinned, every host composed
from a feature list rather than a hand-written file. The difference between that and a cloud of ten thousand is capacity and the number of
failure modes you have already met — not the shape of the work, which is the same loop: declare, gate, deploy, watch, roll back.

Provisioning is where the loop starts. iVentoy runs as ProxyDHCP, TFTP and HTTP on the internal network with an ISO library behind it, so a
bare-metal box boots an installer or a rescue image with no media and no hands. NixOS then makes the installed machine a function of its
declaration, so provisioning is not a state to be reached once and defended but a repeatable output.

Observability is aimed at what fails first, not at what is easy to chart. Pressure stall information for IO, memory and CPU; job state and
generation age in a ledger every fifteen minutes; SMART and NVMe health, ZFS pool state, filesystem headroom; gatus checks that page when a
service stops answering. The alerting rule that earns its place is the second half of that sentence: paging on a state short of ok and on
silence, because a monitor that has quietly died is indistinguishable from a system with nothing to report.

The network is treated as a first-class source of evidence. Default-deny nftables between hosts, WireGuard and Tailscale for transit rather
than exposed ports, and packet-level diagnosis when a symptom crosses a boundary — an MTU fault isolated by path rather than guessed at from
the application's timeouts. Canaries before fleet rollouts: a KVM guest built from the same definitions as its host proves a configuration
so a bad change costs one guest instead of an estate.

What I have not done: I have not operated thousands of servers, and I have not run a GPU fleet. One host here serves inference on a GPU and
yields to a human playing games on it, which teaches you about load and contention but not about DCGM, GPU health telemetry or losing a card
in a rack of them. No SaltStack, no Terraform, no IPMI or Redfish in production. Kubernetes is familiar rather than deep. And I have built
health gates and alerts more often than I have owned formal SLOs for a cloud platform.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux systems* — systemd units, sockets, timers, cgroups, PSI, journald, nftables],
  [*Provisioning* — PXE ProxyDHCP/TFTP/HTTP with an ISO library; bare-metal installs on demand],
  [*Declarative fleet* — one flake, pinned inputs, hosts composed from feature lists],
  [*Automated operations* — typed task surface, dry runs, CI gate equal to the machine's gate],
  [*Observability* — pressure, disk, generation age and job state to a ledger every 15 minutes],
  [*Network* — default-deny nftables, WireGuard/Tailscale transit, MTU faults by path, tcpdump],
  [*Failure handling* — canary guest before fleet, rollback by pointer, one writer per process],
  [*Go and Python* — services, daemons and tooling with append-only state and tests in the tree])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Ran the whole server lifecycle by hand once, then automated it: PXE netboot for installs and rescue, a declared host definition for everything after, and a generation pointer as the rollback.
- Declared a thirteen-host fleet in one flake — pinned inputs, feature-list hosts, options with types and assertions — so a machine is produced by evaluation rather than edited after the fact.
- Gated every change with the same per-host module check in CI and on the machine, so a broken declaration fails as a red check and never reaches an installer.
- Deployed through a canary: a KVM guest built from the same modules proves a configuration before the fleet receives it.
- Built the evidence loop: job state, generation age, disk and PSI pressure to a ledger every fifteen minutes, paging on any state short of ok and on silence.
- Watched the hardware layer rather than the dashboard: SMART and NVMe health, ZFS pool state and scrubs, filesystem headroom, and a netboot path that is tested instead of assumed.
- Kept secrets and access declarative: sops-encrypted values with per-host age keys, host authentication through an own certificate authority, default-deny nftables between hosts.
- Wrote the services the fleet runs — Go daemons with append-only state, Python ingestion, PostgreSQL with migrations and a rehearsed restore — and one task surface with typed arguments, dry runs and JSON output.
- Served inference on a GPU host with a guard that yields the card when a human sits down at it, and watched the contention that produces.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- fibtransponder: a state machine streaming a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input; a corpus benchmark refuted the first detector design and the claim narrowed.
- tokenloom: a Rust workspace behind a pinned dev shell — piece table, ripple re-tokeniser, an acceptance test that holds the invariant.
- Diagnosed a path-specific MTU fault to the boundary that dropped the packet instead of raising the application's timeout ceiling, and wrote it down so the next person starts where the evidence ends.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, and managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it; verified the geometry independently rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Troubleshot equipment and process failures on site, in twelve-hour shifts, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— fleet]
    #linebreak()
    Thirteen hosts from pinned inputs; netboot installs; one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[iVentoy netboot] #text(size: 8pt, fill: muted)[— provisioning]
    #linebreak()
    ProxyDHCP, TFTP and HTTP with an ISO library: installer or rescue image without media.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— safety]
    #linebreak()
    A guest built from the host's own modules proves a change before the estate receives it.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    Typed arguments, dry-run plans, JSON output, one exit code per outcome — repeatable by design.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— service]
    #linebreak()
    Go and Python daemons, PostgreSQL with migrations, tsvector and GIN search, a rehearsed restore.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, remote in CET · available 01.12.2026]
