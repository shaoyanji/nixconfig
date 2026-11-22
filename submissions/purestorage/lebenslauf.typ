// Pure Storage — Senior Systems & Storage Engineer.
// Native English source. No JD existed for this requisition in the repository; the letter speaks to
// the stated pillars (Linux depth, storage performance, declarative fleet management) and claims nothing more.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2f3350")
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
    #text(size: 9.8pt)[Systems and storage engineer · Linux performance · declarative fleet]
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
Storage is the subsystem where a wrong assumption costs you a night, so I have built my practice around measuring it instead. My fleet keeps
a deliberate taxonomy across local disk, a NAS and object tiers: each tier has a stated purpose, a backup path and a retention policy, and
restores are rehearsed rather than believed. Alerts fire on disk pressure and on failed jobs, and because a backup nobody restored is a
rumour, the restore test is part of the schedule rather than a task for the week before an audit.

Performance work I do from the pressure signals upward. PSI tells me whether tasks are actually stalling on IO, memory or CPU, and that
distinction is the difference between adding capacity and fixing the thing that is slow; cgroup limits make the noisy neighbour visible
before it becomes the incident. I read the numbers before I change a tunable, and when a benchmark contradicts me I narrow the claim
instead of the measurement — fibtransponder's seed-only collision detector was falsified by its own benchmark and the claim was rewritten,
not defended.

The fleet underneath is declared once: thirteen NixOS hosts from one flake, each host a feature list, each service a module with a systemd
unit and defined failure behaviour, kernel track and parameters pinned per host where the hardware requires it. Inputs are pinned,
builds are hermetic, secrets are sealed with sops behind a certificate authority that issues the host keys, and a release is a pointer to
the previous generation rather than a procedure. The same gate runs in CI and on the machine, so a definition that cannot evaluate never
reaches hardware, and a canary guest proves a change before the rest of the fleet sees it.

What I have not done: I have not administered an enterprise array — no FlashArray, no SAN fabric, no multipath, no NVMe-oF, and no vendor
escalation path carried at 24/7. My storage scale is thirteen hosts and a PostgreSQL archive, not petabytes behind a controller pair.
That is the learning I would take on; the measurement discipline and the declarative method are what I bring.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Storage operations* — tiering, snapshots, retention, rehearsed restores],
  [*Performance* — PSI on IO, memory and CPU, cgroup limits, capacity budgets],
  [*Linux* — systemd, cgroups, journald, nftables, tcpdump, kernel pinning],
  [*Declarative fleet* — one flake, feature lists, modules, pinned inputs],
  [*Change control* — evaluate, gate, canary, switch, roll back by pointer],
  [*Databases* — PostgreSQL, migrations, statement timeouts, recovery path],
  [*Automation* — Go and Python behind one validated task surface],
  [*Security* — sops per host, short-lived certificates, default-deny])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Kept a stated storage taxonomy across local disk, NAS and object tiers, each with a purpose, a backup path and a retention rule, so growth and deletion were decisions rather than accidents.
- Automatised backups and made the restore a scheduled test: a backup is verified by restoring it, not by watching the job turn green.
- Watched pressure rather than utilisation: PSI on IO, memory and CPU in a ledger every fifteen minutes, paging on any state short of ok and on silence, because a monitor that stops reporting looks like a quiet system.
- Set cgroup limits per service slice so a runaway process starved itself instead of the box, and read the stall numbers before touching a tunable.
- Declared thirteen NixOS hosts in one flake: host as feature list, service as module with an explicit unit and written failure behaviour, kernel track and parameters pinned per host.
- Made delivery reversible: pinned inputs, hermetic builds, a shared binary cache, and rollback as a pointer to the previous generation.
- Gated change with the same per-host evaluation in CI and on the machine, and proved a configuration on a canary guest before the fleet.
- Ran PostgreSQL for the application database and the mail archive: migrations, statement timeouts, connection limits, and a recovery path walked rather than assumed.
- Wrote the services behind it in Go and Python, including a single task surface with typed arguments, dry runs and JSON output for callers that are programs.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Analysed corporate liability risk and built the internal risk management framework the subsidiaries were then measured against.
- Managed an international team and built an incentive structure tied to a live financial model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating both directions between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Diagnosed equipment and process failures in the field under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative fleet]
    #linebreak()
    Thirteen hosts from one flake, pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— measurement]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail ingested and classified, tsvector and GIN search, an upsert keyed on message_id, a rehearsed restore.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A benchmark falsified the seed-only claim, so the claim narrowed rather than the measurement being explained away.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, called by people and by agents.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— isolation]
    #linebreak()
    KVM guests from the same codebase as their hosts, isolated bridge, a canary standing between a change and the fleet.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, Germany · available 01.12.2026]
