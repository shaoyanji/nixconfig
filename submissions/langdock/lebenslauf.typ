// Langdock — Senior Systems Software Engineer (Linux & HPC). Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#173a2e"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#173a2e")
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
    #text(size: 9.8pt)[Linux Systems · Isolation · Go · Runtime Infrastructure]
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
I write systems software and then operate it, which is the part of the job that decides whether it was good. Five years
of Linux at the layer below the application: a thirteen-host fleet declared as one repository and rebuilt from a shared
binary cache with remote builders, so a rebuild is a computation and not a ceremony. Isolation is where I have spent the
most time — a microVM canary that boots on demand with capped CPU and memory, a read-only host mount and no route off the
tailnet, so untrusted runbook code runs somewhere that cannot damage anything. Beside it a single-GPU inference stack
serving chat, speech-to-text and text-to-speech, where throughput, queue depth and the moment the card has to be yielded
to something else are measured rather than assumed. Go for the long-lived services, Python for the tooling, and `strace`,
cgroups and PSI when the answer is genuinely at the kernel boundary. What I have not operated is HPC at fleet scale: no
Slurm or MPI cluster, no RDMA fabric, no multi-tenant accelerator scheduler, and no multi-cloud Kubernetes.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux internals* — processes, scheduling, cgroups, PSI, nftables, `strace`],
  [*Isolation* — microVMs with capped resources, read-only mounts, no egress],
  [*Go* — long-lived services, streaming, concurrency, benchmarks],
  [*Runtime infrastructure* — pinned inputs, content-addressed builds, caching],
  [*Inference serving* — single-GPU stack, throughput, queue depth, yielding],
  [*Telemetry* — fifteen-minute ledger, paging on state and on silence],
  [*Failure reasoning* — idempotency, retries, recovery, explicit guarantees],
  [*Measurement* — hypotheses first, then profiling, then the effect of the change])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts declared as one repository, with rebuilds from a shared binary cache and remote builders, so the cost of a change was compute rather than human attention.
- Built the isolation layer for untrusted code: a microVM canary booting on demand with capped CPU and memory, a read-only host mount, and no route off the tailnet, so a bad runbook could be tried without touching the host.
- Ran a single-GPU inference stack for chat, speech-to-text and text-to-speech, and measured what it does under load: tokens per second, queue depth, and contention with a workload that has to take the card back.
- Kept long-running work correct through failure: explicit ordering and idempotency where a retry could otherwise double-count, and recovery paths for a process that dies mid-task.
- Owned the resource argument: cgroups and PSI to separate I/O starvation from memory pressure, `strace` for syscall behaviour, `tcpdump` for MTU and fragmentation.
- Built the telemetry loop the fleet runs on: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and on silence.
- Wrote the services in Go and the tooling in Python, with tests over canonical data and a gate that runs identically in CI and on the host.
- Kept every change reversible: each generation records its parent, so a bad rollout is a pointer rather than an incident.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Turned missing readings into an explicit error budget instead of a quietly good month, and documented every rollout.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible rather than plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— isolation]
    #linebreak()
    An on-demand microVM with capped CPU and memory, a read-only host mount and no egress, built so untrusted code can
    run where failure is contained rather than negotiated.
  ],
  [
    #text(weight: "bold")[single-GPU inference stack] #text(size: 8pt, fill: muted)[— serving]
    #linebreak()
    Chat, speech-to-text and text-to-speech behind one card, with throughput and queue depth measured and a yielding rule
    for contention.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— runtime]
    #linebreak()
    Thirteen hosts, pinned inputs, cache and remote builders, one per-host gate, rollback as a pointer to the previous
    generation. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— Go, streaming]
    #linebreak()
    A streaming protocol implementation with Zobrist hashing and benchmarks, written to hold state correctly under
    concurrency rather than to pass a demo.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, history kept for
    the postmortem.
  ],
  [
    #text(weight: "bold")[build farm] #text(size: 8pt, fill: muted)[— distributed compute]
    #linebreak()
    Remote builders and a shared cache under one gate, so a fleet-wide sweep is a queue with a memory guard rather than a
    pile of parallel rebuilds.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Berlin or remote from Germany]
