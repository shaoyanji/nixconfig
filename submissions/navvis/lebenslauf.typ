// NavVis — Senior Linux Platform Engineer. Native English source, reproducing the submitted packet.
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
    #text(size: 9.8pt)[Linux platform · OS lifecycle · systemd & packaging · Reproducible builds]
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
I build and ship Linux platforms one layer below the application. In my fleet a host is a declarative feature list, the system
image is built reproducibly from that list, every service is a systemd unit with explicit failure behaviour, and a generation
rolls back with a single command when an update goes wrong. The same per-host gate that CI runs is what a machine passes before
it switches, which is the discipline behind shipping software several times a quarter without a manual checklist.

The systems work I am proudest of is the boundary rather than the feature: a CUDA node whose driver and userspace versions are
pinned together, where I patch around library behaviour when a newer stack breaks a model and measure latency and queue depth
instead of trusting a green service; and a microVM sandbox that boots capped, mounts read-only and fails closed, which is the
same shape as a device image even though the hardware is a server.

What I have not done is the device-specific half of this role: no Debian or Ubuntu image ownership, no production C++ beyond an
earlier lab-equipment application, and no ROS, V4L2, LiDAR or ARM device fleet. I would learn that from your Embedded Software
team, and I would rather say so here than let the first month say it for me.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*OS lifecycle* — image built from a declaration, pinned, rebuildable],
  [*Services* — systemd units with explicit failure and restart behaviour],
  [*Packaging* — mine is Nix; the model is pinned inputs and hashed outputs],
  [*Release* — one gate for CI and machines, rollback as a pointer],
  [*Kernel boundary* — modules, parameters, initrd, `strace` across it],
  [*Drivers* — NVIDIA generations, evdi, Mesa-level breakage diagnosed],
  [*Telemetry* — fifteen-minute ledger, paging on bad state and on silence],
  [*Python and C++* — pipelines and tooling; instrument software at Fraunhofer])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Declared and operated a NixOS fleet from one flake: each host a feature list, each service a module, so option surface stays a gate rather than a copy-paste.
- Made rebuilds reproducible through a shared binary cache and remote builders, with every server generation rollback-able by a single command.
- Gated infrastructure changes with inventory-driven CI and a per-host module check, so a broken host definition fails before it reaches a machine.
- Wrote a sentinel job that records job status, generation age, disk and PSI pressure every fifteen minutes and alerts when a service stops reporting.
- Kept out-of-tree modules working across driver generations: NVIDIA legacy packages pinned per host, evdi for a dock, kernel parameters set per machine and the reason recorded beside each exception.
- Diagnosed at the layer that caused the failure — initrd contents, a module that would not load, journald for what the kernel said before it gave up.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Analysed corporate liability risks and built the internal risk management framework.
- Designed a mobile app for enterprise employees hunting new project opportunities.
- Managed an international team and built an incentive structure tied to a real-time financial model.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Managed a pipeline of USD 100M+ projects.
- Devised sustainability sales and marketing strategies.
- Advised clients on cybersecurity software and risk management.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Conducted research on heliostat imperfections using interferometry.
- Wrote the C++ application that interfaces with the lab equipment, and the Python analysis and 3D geometry tooling with it.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, twelve-hour shifts on a busy site.
- Built spreadsheets for the engineering department and worked on experimental projects using newly developed technology.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    The whole fleet in one flake: each host a feature list, each service a module, secrets encrypted with sops and host keys
    issued by the fleet's own SSH certificate authority. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job status, generation age, disk and PSI pressure every fifteen minutes, alerting on a bad state and when a service stops
    reporting at all.
  ],
  [
    #text(weight: "bold")[CUDA node] #text(size: 8pt, fill: muted)[— driver boundary]
    #linebreak()
    Driver and userspace pinned together, breakage patched at the library layer, latency and queue depth measured rather than
    assumed from a green service.
  ],
  [
    #text(weight: "bold")[microVM sandbox] #text(size: 8pt, fill: muted)[— image]
    #linebreak()
    A small image that boots capped, mounts read-only and fails closed — the shape of a device image on server hardware.
  ],
  [
    #text(weight: "bold")[risk engine] #text(size: 8pt, fill: muted)[— Go]
    #linebreak()
    Green's Theorem area computation with a stochastic polygon fuzzer, containerised on Nix flakes for reproducible builds.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— research]
    #linebreak()
    A benchmark falsified the first detector design, so the claim narrowed rather than being defended.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— University of Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 8pt, fill: muted)[*Languages* — English native, German C1. *Tooling* — Nix/NixOS, systemd, Python, Go, C++, Bash, sops, git, Grafana-style dashboards replaced by a self-built ledger.]

#v(4pt)
#text(size: 7.8pt, fill: muted)[US citizen with German permanent residence, no sponsorship required · Gutach im Breisgau, Munich three days on site a relocation question · available 01.12.2026]
