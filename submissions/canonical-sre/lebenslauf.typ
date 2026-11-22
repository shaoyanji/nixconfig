// Canonical — Senior Site Reliability Engineer (Greenhouse 3029798).
// Native English source replacing the database-built PDF. Fleet reliability, systemd lifecycle, telemetry, canaries.
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
    #text(size: 9.8pt)[Site reliability engineer · Python and Linux · fleet as code]
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
Reliability, for me, is a property the repository enforces rather than a virtue the operator has. One flake declares thirteen hosts; a
change either passes the same per-host evaluation in CI and on the machine or it never reaches hardware; a release is a pointer to the
previous generation, so the way back is a command rather than a procedure written under pressure. That is the whole thesis, and the rest
is detail.

The service lifecycle is where most incidents are decided. Units declare their dependencies and ordering, sockets and timers do the work
that a polling loop would otherwise do badly, and failure behaviour is written down instead of assumed: restart policy, start limits that
stop a crash loop from becoming a CPU fire, and a oneshot job whose exit status is the only evidence that the work finished. A socket that
accepts connections is not a green light; the sentinel asks whether the job ran, how old the generation is, and what the ledger says.

Telemetry is a recording with thresholds in the repository, not a wall of graphs. Job status, generation age, disk and PSI — pressure on
IO, memory and CPU — go to a ledger every fifteen minutes, and the alert fires on any state short of ok and on silence, because a monitor
that stops reporting is indistinguishable from a system with nothing to report. Thresholds are tuned against the noise they produce:
a page that arrives weekly for the same known condition gets fixed or removed, never muted in place.

Canaries are the deployment half of the same argument. A change is proven on a guest built from the same definitions as its host, under
one writer per process, before the fleet sees it; the fleet-wide default does not exist, so nobody can accidentally apply a change
everywhere at once.

What I have not done: no production OpenStack, Kubernetes or Ceph operations — isolation here is microVMs on KVM and orchestration is NixOS
and systemd. No eBPF or in-kernel tracing; the telemetry is PSI, a ledger and generated metrics. And nothing at the scale of hundreds of
customer clusters, which is the learning this role would provide.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Service lifecycle* — units, sockets, timers, ordering, restart and start limits],
  [*Telemetry* — ledger every fifteen minutes on state, age, disk and PSI],
  [*Alerting* — thresholds in the repository, paging on bad state and on silence],
  [*Deployment* — canary guest first, one writer per process, rollback by pointer],
  [*Linux* — kernel tracks and parameters, cgroups, nftables, tcpdump, journald],
  [*Python* — FastAPI and Flask services, PostgreSQL migrations, tooling],
  [*Infrastructure as code* — one flake, pinned inputs, hermetic builds, gates],
  [*Security* — sops per host, short-lived certificates from an own CA])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Ran a thirteen-host production fleet declared as one flake: inventory decides which hosts a change reaches, the gate CI runs is the gate the machine passes, and every generation rolls back with one command.
- Wrote the systemd layer deliberately: units with explicit ordering and dependencies, sockets and timers where a poller would have been worse, per-slice memory limits, and start limits that turned a crash loop into a stopped unit instead of a saturated machine.
- Built the telemetry loop instead of buying a dashboard: a sentinel writes job status, generation age, disk usage and PSI to a ledger every fifteen minutes, and a page fires on any state short of ok and on silence.
- Set the alerting thresholds from the noise they caused: a condition that paged weekly was either fixed or retired, never muted in place, and every incident ended as a check, a threshold or a runbook entry rather than a story.
- Deployed through a canary: a KVM guest built from the same definitions as its host proves a configuration before the fleet receives it, with one writer per process and no fleet-wide default that could apply a change everywhere at once.
- Wrote the Python and Go services behind it — FastAPI and Flask endpoints, PostgreSQL with migrations and a rehearsed restore, an IMAP ingestion and classification service, and one validated task surface with typed arguments, dry runs and JSON output.
- Kept access declarative: sops-encrypted secrets with per-host age keys, host authentication through an own certificate authority instead of shared user keys, default-deny nftables.
- Ran vulnerability work as a pipeline: the CISA KEV catalogue matched against what the fleet runs, ordered by exposure and effort.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— fleet as code]
    #linebreak()
    Thirteen hosts from one flake, pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— deployment]
    #linebreak()
    KVM guests from the same codebase as their hosts, isolated bridge, a canary between a change and the fleet.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, called by people and by agents.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— Python and PostgreSQL]
    #linebreak()
    IMAP ingestion and classification, tsvector and GIN search, an upsert keyed on message_id, a rehearsed restore.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A benchmark falsified the seed-only claim, so the claim narrowed rather than the measurement being explained away.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · CET/CEST · home-based in Gutach im Breisgau · available 01.12.2026]
