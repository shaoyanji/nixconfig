// Adyen — GenAI Platform Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#0b4a3f"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#0b4a3f")
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
    #text(size: 9.8pt)[Platform Engineering · Developer Experience · Linux · AI Tooling]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[US citizen · relocation to Amsterdam supported by Adyen required]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Platform engineer who builds the surface other engineers work from, and then makes that surface impossible to
misuse. Five years of it in one public repository: thirteen Linux hosts declared rather than configured, every fleet
operation behind a single entry point with named arguments and validation, documentation generated from the same source
as the configuration, and CI running the identical per-host check the machine runs. Python is the working language for
services and APIs; Go where a long-lived process needs to hold state under concurrency. Observability is not a dashboard
I check but a ledger that pages on any state short of ok and times out on silence, because a system that stops reporting
is the failure that matters. I run LLM agents daily against this repository under gates I wrote — draft, verify against
requirements, human signs — which is hands-on work with agent workflows and evaluation, though not yet a production GenAI
platform for other teams. Kubernetes, Helm, Argo CD and vLLM I have not operated.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Platform capabilities* — one module registry, reused instead of rebuilt],
  [*Developer experience* — named arguments, help text, JSON output, fast failure],
  [*Python* — services, APIs, data pipelines, tests over canonical data],
  [*Linux* — cloud and on-prem, systemd, cgroups, PSI, nftables, `strace`],
  [*Observability* — job ledger, generation age, disk and PSI, journald, paging],
  [*Guardrails* — validation before action, dry-run plans, signed changes],
  [*Access control* — sops/age per host, SSH-CA short-lived credentials],
  [*Agent workflows* — dispatched panes, scheduled jobs, evaluation gates])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built platform capabilities other work reused rather than reimplemented: a module registry where a new service composes existing leaves, so the second team's problem is configuration, not engineering.
- Designed the developer surface: every operation behind one entry point with named arguments, `--help`, machine-readable output and a dry-run plan, so a wrong argument fails before it touches a host.
- Ran Python services and APIs in production on that platform, with tests against canonical data rather than mocks of it.
- Operated Linux on-premises and on rented metal: systemd units, cgroups for isolation, PSI for pressure, nftables for default-deny, `strace` and `tcpdump` when the answer was at the syscall or packet layer.
- Built the observability loop: job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence itself, with history kept for the postmortem.
- Enforced access control as a mechanism: per-host encrypted secrets, a fleet certificate authority issuing short-lived credentials, nothing reusable left on disk after a session.
- Set the standard for change: an identical gate in CI and on the host, so a green build cannot disagree with a healthy machine, and a failed check leaves the previous generation serving.
- Diagnosed cost and latency with data: cache pressure, builder capacity and storage retention turned into arguments with numbers rather than opinions.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M across three measurement feeds.
- Built reconciliation and deviation analysis so a missing reading surfaced as an explicit error budget, not a quietly good month.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— DevEx]
    #linebreak()
    One surface for every platform operation: named arguments, validation, dry-run plans, JSON output. The measure is
    whether a colleague acts without reading the implementation.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, rollback as a pointer to the previous
    generation. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on silence as well as on bad state.
  ],
  [
    #text(weight: "bold")[agent panes under gates] #text(size: 8pt, fill: muted)[— AI workflows]
    #linebreak()
    LLM agents dispatched to isolated worktrees with mandatory claims, then held to a written gate: the agent drafts,
    the check decides, a human merges.
  ],
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— governance]
    #linebreak()
    A fleet CA issuing short-lived SSH credentials and per-host encrypted secrets, so access expires instead of
    accumulating.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— Go, streaming]
    #linebreak()
    A streaming protocol implementation with Zobrist hashing and benchmarks, written to hold state correctly under
    concurrency.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[English native · German C1 · US citizen, currently on German permanent residence · relocating to Amsterdam or Madrid with employer-supported permit (highly skilled migrant route)]
