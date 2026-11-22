// Wolt — Staff Engineer, EU Infrastructure. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#0d4a6b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#0d4a6b")
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
    #text(size: 9.8pt)[Compute Platform · Declarative Fleet Automation · GPU Operations]
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
I build compute foundations other people run their work on, and I keep them legible: thirteen Linux hosts declared as one
repository, every service a module, every input pinned, every change through a gate that runs identically in CI and on the
machine. Upgrades are a rebuild rather than an edit, so there is no drift to reconcile; rollback is a pointer to the previous
generation. Isolation is enforced by construction — a microVM canary with capped CPU and memory, a read-only host mount and no
route off the tailnet — which is the same question a multi-tenant compute platform answers with namespaces, quotas and
scheduling policy.

Developer enablement is the part I care about most: a single task surface with named arguments, validation, dry-run plans and
JSON output, so a colleague provisions work without reading the implementation and a wrong argument fails before it reaches a
host. Telemetry is a closed loop rather than a dashboard: job status, generation age, disk pressure and PSI every fifteen
minutes, paging on bad state and on silence, with capacity and cost argued from those numbers.

GPU work is real but small: one card serving chat, speech-to-text and text-to-speech, where throughput and queue depth are
measured and contention is handled by an explicit yielding rule. What I have not run is production Kubernetes or AWS —
Kubernetes not at all, AWS not as an operator — and Terraform I have not used; my provisioning language is Nix and my cloud is
rented metal. That is the honest position for a role whose core requirement is deep experience with both.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Declarative fleets* — one repository, pinned inputs, rebuild as the upgrade],
  [*Isolation* — microVMs, capped resources, read-only mounts, no egress],
  [*Developer enablement* — one entry surface, validation, dry runs, JSON],
  [*Telemetry* — fifteen-minute ledger, paging on state and on silence],
  [*GPU operations* — single-card serving, throughput, queue depth, yielding],
  [*Linux* — systemd, cgroups, PSI, nftables, `strace`, `tcpdump`],
  [*Automation* — Go and Python over a validated task surface],
  [*Cost and capacity* — retention and build capacity argued with numbers])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran a thirteen-host compute estate as one declaration: services, storage, firewall and secrets as modules, rebuilt from a shared cache and remote builders, with no manual changes on a running machine.
- Isolated untrusted workloads by construction: a microVM canary with capped CPU and memory, a read-only host mount and no route off the tailnet.
- Built the developer surface other work depended on: named arguments, validation, dry-run plans and machine-readable output, so provisioning is a command rather than a ticket and a wrong argument fails early.
- Made capacity a measured argument: fleet-wide sweeps run one host per process under a memory guard, and build capacity is sized from observed queue depth rather than guessed.
- Ran a single-GPU inference stack for chat, speech-to-text and text-to-speech, measuring tokens per second and queue depth, with an explicit rule for what yields when a second workload needs the card.
- Kept one gate in front of every change, identical in CI and on the machine, so a green build is a statement about a real host and a failure leaves the previous generation serving.
- Built the telemetry loop the estate runs on: job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and when a service stops reporting.
- Replaced standing access with issued access: a fleet certificate authority, short-lived SSH credentials, per-host sops/age secrets, default-deny between hosts.
- Diagnosed at the system layer: cgroup accounting to prove where CPU went, PSI to separate I/O starvation from memory pressure, `strace` and `tcpdump` when the answer was below the application.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Reported variance line by line, with every assumption documented next to its number.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— compute foundation]
    #linebreak()
    Thirteen hosts, pinned inputs, shared cache and remote builders, one per-host gate, rollback as a pointer.
    https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— self-service]
    #linebreak()
    Every platform operation behind one surface with validation and dry-run plans: the measure is whether a colleague ships
    without asking.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— isolation]
    #linebreak()
    Capped CPU and memory, a read-only host mount, no egress: untrusted code runs where failure is contained.
  ],
  [
    #text(weight: "bold")[single-GPU serving] #text(size: 8pt, fill: muted)[— GPU]
    #linebreak()
    Chat, speech-to-text and text-to-speech behind one card, with throughput and queue depth measured and a yielding rule for
    contention.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, history kept for the
    postmortem.
  ],
  [
    #text(weight: "bold")[build farm] #text(size: 8pt, fill: muted)[— capacity]
    #linebreak()
    Remote builders and a shared cache under one gate, sized from observed queue depth, with per-host processes capped.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, Berlin relocation possible by arrangement]
