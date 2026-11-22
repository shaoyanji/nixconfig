// Black Forest Labs — Member of Technical Staff, Infrastructure Security. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#3b2f5e"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#3b2f5e")
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
    #text(size: 9.8pt)[Infrastructure Security · Linux Internals · Isolation · Secrets]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
      #linebreak()
      #text(size: 8.4pt)[Twenty minutes from the Freiburg lab]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Security work on infrastructure I also operate, which is the only version of the job I trust: a thirteen-host Linux fleet
declared as one repository, where identity is issued rather than stored, workloads are isolated by construction, and the
build path is pinned end to end. Access runs through a fleet certificate authority that mints short-lived SSH
credentials, secrets are encrypted per host with sops and age, and the network defaults to deny. A microVM canary boots
untrusted code with capped CPU and memory, a read-only host mount and no route off the tailnet, so a bad runbook is
contained instead of negotiated. Every change passes one gate identical in CI and on the machine, and every generation
records its parent, so a rollback is a pointer rather than an incident.

The diagnostics are kernel-adjacent: cgroups for isolation and accounting, PSI for pressure, `strace` for syscall
behaviour, `tcpdump` for an MTU that breaks on one path, systemd units and journald for what the machine actually did.
What I have not done is secure a cloud estate or a GPU cluster: no Kubernetes, no managed cloud security, no multi-tenant
accelerator infrastructure, and no security engineering title behind me. What I have is the same problems at thirteen
machines, solved and then operated.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Identity and access* — short-lived certificates, per-host secrets, default deny],
  [*Isolation* — microVMs, capped resources, read-only mounts, no egress],
  [*Linux internals* — systemd, cgroups, PSI, namespaces, `strace`, `tcpdump`],
  [*Secrets* — sops and age, per-host keys, nothing standing on disk],
  [*Supply chain* — pinned inputs, content-addressed builds, one gate],
  [*Change control* — dry-run plans, reviewable diffs, generations with parents],
  [*Detection* — fifteen-minute ledger, paging on state and on silence],
  [*Agents, used carefully* — tiered tool access, approval gates, attack surface])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran identity as a mechanism rather than a policy: a fleet certificate authority issuing short-lived SSH credentials, so access expires instead of accumulating and no key outlives the day it was needed.
- Encrypted secrets per host with sops and age, so a compromise of one machine yields nothing reusable against another.
- Isolated untrusted execution in a microVM canary: capped CPU and memory, read-only host mount, no route off the tailnet, and a documented rebuild path when the guest is discarded.
- Pinned the whole build path: inputs locked, outputs content-addressed, rebuilds served from a shared cache and remote builders, so the artefact that runs is the artefact that was built.
- Put one gate in front of every change, identical in CI and on the machine, with dry-run plans for anything destructive, so a mistake fails before it reaches a host.
- Kept every generation's parent, making rollback a pointer to a known-good system rather than a repair under pressure.
- Built detection that assumes silence is failure: job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and when a service stops reporting.
- Worked at the kernel boundary when it mattered: cgroup accounting to prove where CPU went, PSI to separate I/O starvation from memory pressure, `strace` to see what a process actually asked the kernel for.
- Ran LLM agents against this repository with tiered tool access per host and approval before anything destructive, which taught me where they help and how they are attacked.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data integrity for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Built models that survived bank review, where an unexplained variance was a finding rather than a rounding error.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— identity]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host encrypted secrets: no machine holds
    anything reusable if it is lost.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— isolation]
    #linebreak()
    Untrusted code runs with capped CPU and memory, a read-only host mount and no egress, so failure is contained rather
    than negotiated.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— supply chain]
    #linebreak()
    Thirteen hosts, pinned inputs, content-addressed rebuilds, one per-host gate, rollback as a pointer.
    https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— detection]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence itself.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— guardrails]
    #linebreak()
    Destructive operations behind named arguments, validation and dry-run plans, so the wrong thing fails before it
    touches a host.
  ],
  [
    #text(weight: "bold")[agent stack under gates] #text(size: 8pt, fill: muted)[— LLM security]
    #linebreak()
    Tiered tool access per host, claims before edits, approval before anything destructive, and a check that decides
    whether output counts.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[US citizen with German permanent residence: full right to work in the US and in Germany, no sponsorship either way · German C1 · English native · Gutach im Breisgau, twenty minutes from the Freiburg lab]
