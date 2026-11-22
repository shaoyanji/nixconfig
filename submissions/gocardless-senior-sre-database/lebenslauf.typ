// GoCardless (a Mollie company) — Senior SRE, Database Focus (Greenhouse 8385160).
// Native English source replacing the Nix-projected PDF. Database evidence kept, gaps named.
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
    #text(size: 9.8pt)[Site reliability engineer · PostgreSQL in production · Linux operations]
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
Database work is where I have been least able to bluff, because a restore is either rehearsed or it is a hope. The mail archive I
run is PostgreSQL with versioned migrations, a restore path I have actually walked, statement timeouts set deliberately, and
disk-pressure alerting wired into the same sentinel that records job state and pressure stall every fifteen minutes. I read a plan
before I add an index, I have chased idle-in-transaction sessions and autovacuum lag on my own hardware, and I treat a backfill as a
change with a rollback plan rather than a query to run and see.

Around the database sits the reliability work: one flake declares thirteen hosts, each a feature list, each service a module with a
systemd unit and defined failure behaviour; secrets are sops-encrypted per host behind a certificate authority; a change counts only
once a gate has read the built artefact back; and a canary proves a configuration before the rest of the fleet receives it. Go and
Python carry the services and the automation, including a single validated task surface with typed arguments, dry runs and JSON.

On-call has been mine alone, which is a hard teacher about noise. The sentinel pages on any state short of ok and on silence, because
a monitor that dies quietly looks exactly like a system with nothing to report, and every incident I have handled ended as a gate or a
runbook entry rather than as memory.

What I have not done is the specialty bar this role sets: five or more years running PostgreSQL fleets with HA, replication and
failover, Stolon or Cloud SQL, and major-version upgrades led end to end. I have run one production PostgreSQL instance and its
recovery path, not an estate, and I have never led a major-version migration. Terraform, GKE, Argo CD, Prometheus and Grafana are
also outside my tool history; Nix is my infrastructure language and the ledger is my observability. The database depth would be the
learning, and the reliability and incident habits are what I would bring on day one.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*PostgreSQL* — versioned migrations, rehearsed restore, statement timeouts, backups],
  [*Query and capacity* — plans before indexes, autovacuum lag, idle-in-transaction],
  [*Reliability* — ledger every fifteen minutes, paging on bad state and on silence],
  [*Incidents* — mitigation first, then root cause, ending in a gate or a runbook],
  [*Declarative infrastructure* — one flake, pinned inputs, hermetic builds, rollback],
  [*Secrets and access* — sops per host, short-lived certificates from an own SSH CA],
  [*Automation* — Go and Python behind one validated task surface],
  [*Security* — KEV-driven patching ordered by exposure, threat modelling])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Ran the fleet's PostgreSQL instance end to end: versioned migrations applied by the same task interface that deploys everything else, a restore rehearsed rather than assumed, statement timeouts and connection limits set deliberately, disk pressure alerted before it becomes an outage.
- Built the mail archive on PostgreSQL: mail ingested, classified and queryable, served over a tailnet API with a verdict workflow that records what was decided and by whom — the archive answers questions about its own contents instead of being a folder of files.
- Read query plans before touching indexes, chased idle-in-transaction sessions and autovacuum lag, and treated every backfill as a change with a rollback plan.
- Declared thirteen hosts as one flake: each host a concatenated feature list, each service a module with a systemd unit and written failure behaviour, so option surface stays a cost a gate pays rather than a copy that drifts.
- Held zero standing secrets: sops-encrypted values with per-host age keys, and SSH access as short-lived certificates issued by the fleet's own authority.
- Served rebuilds from a shared binary cache and remote builders, and made rollback a pointer — every server generation returns to the previous one with one command.
- Ran the same per-host module gate in CI that a machine passes before switching, driven by an inventory file, so a broken definition fails before it reaches hardware.
- Wrote the services behind it in Go and Python: an append-only event log, a single task entry point with typed arguments, dry runs and JSON output, and a sentinel writing job status, generation age, disk and PSI to a ledger every fifteen minutes with Gatus paging on bad state and on silence.
- Architected a covered-call hedging strategy for client portfolios and audited bug bounty programmes, triaging against known-exploited lists rather than impressions.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Built the financial models and operated ten megawatts of solar PV, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Analysed corporate liability risk and built the internal risk management framework the subsidiaries were then measured against.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem before it is a communication one.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Managed a project pipeline above USD 100M and advised commercial clients on energy strategy, cybersecurity software and risk.
- Ran customer service and support, and devised the sales and marketing strategy for the sustainability practice.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Led safety training for the crew and diagnosed equipment and process failures under time pressure, with a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail ingested into PostgreSQL and classified, versioned migrations, a rehearsed restore, served over a tailnet API.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, migrations included.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative fleet]
    #linebreak()
    Thirteen hosts from one flake, pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[vulnerability operations] #text(size: 8pt, fill: muted)[— security]
    #linebreak()
    Triage against the CISA KEV catalogue, ordered by real exposure on the fleet rather than by advisory volume.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A benchmark falsified the first design, so the claim narrowed rather than being defended.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#text(size: 8.4pt)[Thesis: intermittent renewable energy and weather patterns analysed through artificial neural networks — a time-cross-correlation method for wind velocity data.]
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no UK right to work · based in Gutach im Breisgau, CET · available 01.12.2026]
