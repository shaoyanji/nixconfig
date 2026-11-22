// GitLab — Senior Staff SRE, Hosted Runners. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#8c3a1e"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#8c3a1e")
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
    #text(size: 9.8pt)[Go · Workload Isolation · Fleet Operations · Linux Internals]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[US citizen · German permanent residence · English native, German C1]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I write Go and I run the machines it talks to. Five years of thirteen bare-metal Linux hosts as one declaration:
workloads isolated in declared microVMs and memory-capped systemd slices, a gate identical in CI and on the machine,
rollback as a pointer to the previous generation, and a telemetry loop over job status, generation age, disk pressure
and PSI every fifteen minutes. Resource cleanup is a design rule rather than an afterthought, because a fleet that leaks
a slice per run becomes a fleet that cannot accept the next job. Faults get traced from the kernel outward: `strace` for
what a process asked for, cgroups and PSI to separate I/O starvation from memory shortage, `tcpdump` to prove an MTU or
fragmentation problem. I have not operated Kubernetes in production, I have not run an autoscaling cloud fleet, and my
scale is thirteen machines rather than thousands of runner workers.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Go* — services, CLI surfaces, streaming, concurrency, tests],
  [*Isolation* — declared microVMs, memory-capped slices, per-job boundaries],
  [*Linux* — systemd, cgroups, PSI, signals, `strace`, file descriptors],
  [*Networking* — nftables, WireGuard, MTU and fragmentation, `tcpdump`],
  [*Fleet operations* — pinned inputs, generations, rollback by pointer],
  [*Telemetry* — job state ledger, alert on state not volume, silence as fault],
  [*CI* — one gate for CI and host, inventory-driven matrix, fast feedback],
  [*Change safety* — canary before fleet, bounded rollout, written recovery])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Wrote a Go service that models an append-only job lifecycle: PostgreSQL work versions, exact hashes over canonical JSON, append-only events, and tests that fix expected behaviour rather than current output.
- Isolated every workload in a declared microVM or a memory-capped systemd slice, so a runaway build cost one process and never the host that was also serving something else.
- Made resource cleanup structural: slices and guests are declared with their limits, torn down by the same mechanism that created them, and a leaked unit shows up in the telemetry rather than in next week's capacity review.
- Built the fleet ledger: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Deployed by generation with a parent pointer, so recovery is a rollback to a known system rather than a repair under pressure, and every rollout has a way back that does not depend on the person who shipped it.
- Gated every change with a check that runs identically in CI and on the target host, so a green build cannot mean something different from a healthy machine.
- Traced failures from the kernel outward: `strace` for syscall behaviour, cgroups and PSI to attribute latency to I/O or memory, `tcpdump` to prove MTU and fragmentation.
- Automated the recurring work into one validated command surface, so an operator cannot improvise a half-step.

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
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself: the difference between a fleet that reports and one that merely runs.
  ],
  [
    #text(weight: "bold")[isolation design] #text(size: 8pt, fill: muted)[— execution]
    #linebreak()
    Untrusted workloads in declared microVMs with their own kernel boundary, plus memory-capped slices for the
    coarser cases, and teardown owned by the same declaration.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— Go, streaming]
    #linebreak()
    A streaming protocol implementation with Zobrist hashing and benchmarks, written to hold state correctly under
    concurrency rather than to pass a demo.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— fleet as code]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation.
  ],
  [
    #text(weight: "bold")[pressure triage] #text(size: 8pt, fill: muted)[— Linux]
    #linebreak()
    cgroups and PSI to attribute latency to I/O or memory, and `tcpdump` where the network is blamed before it is
    measured.
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
#text(size: 7.8pt, fill: muted)[US citizen, no sponsorship needed for a US role · German permanent residence · English native, German C1 · open to a US or German contract, with Germany my current base]
