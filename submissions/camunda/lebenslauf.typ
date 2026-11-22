// Camunda — Senior Site Reliability Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f4553"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1f4553")
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
    #text(size: 9.8pt)[Site Reliability · Linux Systems · Telemetry · Governed Automation]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[German C1 · English native · US citizen, German permanent residence]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I run systems the way a reviewer would want them run: every host declared, every change gated, every release a
generation with a parent, every rollback a pointer. Thirteen Linux hosts over five years, telemetry every fifteen
minutes on job status, generation age, disk pressure and PSI, and on-call where the first useful signal was usually
the one nobody had instrumented. I use AI heavily and do not let it authorise anything: it drafts, it proposes, it
explains a failure — and a check written against the requirement disposes, because the failure mode is not a bad
model, it is a person who accepted a confident answer. I have not run Kubernetes in production, I have not written
Terraform, and I have not operated Prometheus or Grafana; my observability is bespoke and my orchestration is Nix. I
am direct about that because a Senior SRE interview would find it in ten minutes anyway.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — systemd, journald, cgroups/PSI, nftables, tcpdump, strace],
  [*Reliability* — gate identical in CI and host, rollback as a pointer],
  [*Observability* — fifteen-minute ledger, silence treated as a fault],
  [*Automation* — Go, Python, Bash behind one validated entry surface],
  [*Incident response* — bounded changes, written runbooks, postmortems with a gate],
  [*AI with accountability* — proposals validated against requirements, human decides],
  [*Declarative config* — pinned inputs, per-host generations, secrets as data],
  [*Data* — PostgreSQL, append-only events, hashing, idempotent reruns])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts declaratively: services, storage layouts, firewall rules, secrets and telemetry in one repository, with a written rebuild path per host.
- Gated every change with a check that runs identically in CI and on the target machine, so a failed check leaves the previous generation serving and a bad release has a known way back.
- Built a telemetry loop every fifteen minutes over job status, generation age, disk pressure and PSI, reporting any state short of ok and keeping the record of what was measured when.
- Tuned for signal rather than volume: one condition per check, thresholds that mean something, and silence treated as blindness instead of calm.
- Used cgroups and PSI to separate I/O starvation from memory shortage, and `tcpdump` and `strace` to explain a failure from packets and syscalls rather than from a restart.
- Wrote runbooks as executable procedures — a task per operation with named arguments and help text, validated so a wrong argument fails before it touches a host.
- Isolated workloads in declared microVMs and memory-capped systemd slices, so a runaway process stayed a process and not an incident.
- Wrote the Go service behind it: append-only events, exact hashes over canonical JSON, tests that fix expected behaviour.
- Hardened hosts with nftables default-deny, per-host SOPS/age secrets and an SSH certificate authority with short-lived credentials.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Replaced guesswork on missing readings with an explicit error budget, keeping history auditable years later.
- Ran software rollouts across client systems and documented each one.
- Looked after software and IT administration for the company and its subsidiaries.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Turned technical constraints into written decisions a non-technical board could act on.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and implemented its analysis in Python, including 3D geometry.
- Worked inside fixed measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.
- Led the crew's safety training and worked to procedures that tolerate no deviation.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry loop]
    #linebreak()
    A ledger over job status, generation age, disk and PSI every fifteen minutes, paging only when state is short of
    ok, and keeping the history that makes a postmortem possible.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— runbooks as code]
    #linebreak()
    Every recurring operation behind one surface with named arguments, help text and JSON output: the runbook is
    executable, and a wrong argument fails before it reaches a host.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declaration as contract]
    #linebreak()
    Thirteen hosts, one flake, pinned inputs: deployment is a rebuild, identity is in the lock file, and reverting is
    a pointer to the previous generation.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only request lifecycle with exact and quotient hashes, so deduplication and audit are schema properties
    rather than a background job's guess.
  ],
  [
    #text(weight: "bold")[AI-assisted change review] #text(size: 8pt, fill: muted)[— workflow]
    #linebreak()
    AI drafts configuration, scripts and documentation; each artefact is read and checked against the running system
    before it can reach a production path, and the human signs the result.
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
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · 100% remote from Germany, on-call and async collaboration across time zones]
