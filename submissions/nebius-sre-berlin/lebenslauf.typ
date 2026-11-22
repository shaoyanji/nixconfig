// Nebius — Senior Site Reliability Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f3a5f"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1f3a5f")
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
    #text(size: 9.8pt)[Unix Internals · Network Reliability · Bare-Metal Operations]
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
When a service misbehaves, I start at the syscall and work upward: `strace` for what a process actually asked the
kernel, cgroups and PSI to separate I/O starvation from memory shortage, `tcpdump` for MTU and fragmentation before
anyone blames the network, nftables rules read back from the running system instead of trusted from the repository.
Five years running that on thirteen bare-metal Linux hosts, declared in one repository rather than tended by hand:
pinned inputs, a gate identical in CI and on the machine, rollback as a pointer to the previous generation, and a
fifteen-minute ledger over job status, generation age, disk pressure and PSI that pages when a machine goes quiet. Go
for the services and tooling. I have not run Kubernetes, Docker or Helm in production, I have not used Ansible, Salt or
Terraform, and my compute is thirteen hosts rather than a GPU fleet.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Unix internals* — systemd, cgroups, PSI, signals, file descriptors, `strace`],
  [*Network stack* — nftables, WireGuard, MTU and fragmentation, `tcpdump`],
  [*Performance* — pressure attribution, disk I/O, memory limits, load testing],
  [*Bare-metal telemetry* — fifteen-minute ledger, alert on state not volume],
  [*Go* — services, CLI surfaces, tests over canonical data],
  [*Reproducible builds* — pinned inputs, hermetic output, content addressing],
  [*Change control* — gate identical in CI and host, rollback by generation],
  [*Operations* — coverage where there is no TTY, recovery paths written down])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen bare-metal Linux hosts as one declaration: services, storage, firewall, secrets and telemetry as modules, no manual edits on a running machine.
- Diagnosed faults from the kernel side: `strace` for syscall behaviour, `tcpdump` to prove an MTU or fragmentation problem, cgroups and PSI to attribute latency to I/O or memory instead of restarting and hoping.
- Built the ledger the fleet runs on: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Kept changes fault-tolerant by construction: a gate that runs identically in CI and on the host, a generation per deployment with a parent, and rollback as a pointer rather than a repair at 03:00.
- Made builds hermetic: pinned inputs in a lock file, outputs in a content-addressed store, so a rebuild months later yields the same artefact rather than something that merely compiles.
- Hardened the network layer with nftables default-deny, a WireGuard mesh, an own DNS zone and an SSH certificate authority issuing short-lived credentials.
- Ran workloads in declared microVMs and memory-capped systemd slices, so one exhausting process stayed a process.
- Wrote the Go service and the Python tooling behind it, with tests that fix expected behaviour.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Turned missing readings into an explicit error budget instead of a quietly good month, keeping history auditable for bank review.
- Ran software rollouts across client systems and documented each one.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, implemented its analysis in Python with 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— health ledger]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself: a bare-metal fleet whose failures are noticed by the machine, not by a customer.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— reproducible fleet]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation.
  ],
  [
    #text(weight: "bold")[network hardening] #text(size: 8pt, fill: muted)[— stack]
    #linebreak()
    nftables default-deny, WireGuard mesh, own DNS zone, SSH certificate authority with short-lived credentials, and
    MTU work proven with `tcpdump` rather than guessed.
  ],
  [
    #text(weight: "bold")[pressure triage] #text(size: 8pt, fill: muted)[— Linux]
    #linebreak()
    cgroups and PSI to attribute latency to I/O or memory, and memory-capped slices so a leak costs a process rather
    than a node.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only request lifecycle with exact hashes over canonical JSON, so identity and audit are schema properties
    rather than an inference.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving installers and first configuration, so a machine joins the declared fleet instead of being
    assembled by hand.
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
