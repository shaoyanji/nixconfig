// Anthropic — Staff+ Software Engineer, Data Infrastructure (Greenhouse 5114768008).
// Native English source replacing the Nix-built PDF. Durability, migrations, access, telemetry.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2a2a40"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2a2a40")
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
    #text(size: 9.8pt)[Data infrastructure engineer · PostgreSQL, migrations, restore drills, access control]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Data infrastructure fails in two directions, and I have worked both: the data has to come back, and only the right people and services may touch it.
Six years running a single-operator platform taught me that the second half is easier to claim than to prove, so I try to make access decisions explicit in
code and durability decisions something a scheduled job can fail.

Storage and state: PostgreSQL declared per service in the same tree that defines the service, with its role, database and settings generated rather than
edited on a host. Schema changes arrive as ordered migrations that either complete or leave the previous version running, so a failed step is a stopped
deploy and not a half-migrated database. The mail archive is the working example — a stored `tsvector` behind a GIN index for search, an upsert keyed on
`message_id` so a replayed message cannot become a second row, SQL endpoints generated from annotated queries, and fourteen months of real mail behind it.

Durability as a check: the backup drill starts an ephemeral PostgreSQL cluster, replays the dump into it with `psql`, then asserts the restored table count
and the rows of the core entities, on a timer after the backup window. A backup nobody has restored is a hypothesis, and a broken dump should be a failed
job the next morning rather than a surprise on the day someone needs the data. Storage growth is watched the same way: disk percentage for the root
filesystem, the Nix store and the data volume plus inode counts, with a threshold that degrades the host under a named reason before a write fails.

Access and integrity: no standing SSH keys, short-lived certificates from the fleet's own authority, per-host sops/age keys so one host cannot read another's
secrets, dedicated users and hardened systemd units per service instead of one account with root's reach. Write paths validate before they write, state that
must not be edited is append-only, and specifications are content-addressed so the same input produces the same hash. Every host change is a generation that
rolls back in one command, and a canary proves it before the fleet sees it.

Where I fall short of this posting: no BigQuery, BigTable, Airflow, dbt or Spark operations, no petabyte-scale object-store replication or disaster recovery
on GCS or S3, and no IAM or audit-logging design at thousands-of-users scale. My storage work is single-host and small-fleet, and I have led a team and set
direction for a platform, but not as a Staff engineer across several teams at once.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*PostgreSQL* — declared instances, roles and databases per service, settings from Nix],
  [*Migrations* — ordered and versioned, applied by the service, previous version kept on failure],
  [*Restore drills* — dump replayed into an ephemeral cluster, table and row counts asserted],
  [*Retention and growth* — disk and inode percentages per path, threshold with a named reason],
  [*Access control* — short-lived certificates, per-host keys, dedicated users per service],
  [*Integrity* — validate before write, append-only events, content-addressed specifications],
  [*Search and shape* — stored `tsvector` with GIN, upsert keys that survive replay],
  [*Telemetry* — PSI by resource, job state, generation age, page on bad state and silence])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Ran the whole platform as one person: thirteen hosts declared in one flake, each service a systemd unit with defined failure behaviour, every generation rollback-able in one command.
- Operated PostgreSQL as declared infrastructure — instance, role and database per service, settings generated so the connection details and the schema version move together.
- Applied schema changes as ordered migrations, with the previous version still running if a step fails; no hand-edited schema on a live host.
- Built the mail archive on that base: migrations, a stored `tsvector` behind a GIN index, an upsert keyed on `message_id`, and SQL endpoints generated from annotated queries.
- Scheduled backups and wired a restore drill that replays each dump into an ephemeral cluster and fails when restored tables or entity rows fall below the floor.
- Watched storage and load: disk percentages and inodes per path with a named degrade reason, PSI for IO, memory and CPU plus job state and generation age into a ledger every fifteen minutes, paging on bad state and on silence.
- Removed standing access instead of managing it: short-lived SSH certificates from the fleet CA, per-host sops/age keys, and per-service users with hardened units.
- Handled personal data with a documented retention window, an encrypted archive and no standing credentials, which is the part finance and governance teams ask about first.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- fibtransponder: a state machine streaming a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input.
- tokenloom: a Rust workspace with a piece table and a ripple re-tokeniser that touches only the changed span, plus an acceptance test that encodes the invariant.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series that fed financial reporting.
- Administered software and IT for the company and its subsidiaries; managed an international team and built the incentive structure tied to a live financial model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, software and risk, translating between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it; verified the geometry against an independent calculation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Troubleshot equipment and process failures on site in twelve-hour shifts, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Migrations, stored `tsvector` with GIN, upsert on `message_id`, fourteen months of real mail.
  ],
  [
    #text(weight: "bold")[restore drill] #text(size: 8pt, fill: muted)[— durability]
    #linebreak()
    Ephemeral cluster, dump replayed with `psql`, table and entity rows asserted on a timer.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    PSI, job state and generation age every fifteen minutes; pages on bad state and silence.
  ],
  [
    #text(weight: "bold")[sops and SSH CA] #text(size: 8pt, fill: muted)[— access]
    #linebreak()
    No standing keys: per-host age keys and short-lived certificates instead of an authorised_keys file.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— infrastructure as code]
    #linebreak()
    Thirteen hosts, pinned inputs, one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Typed arguments, dry-run plans, JSON output, one exit code per outcome.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[US citizen, no sponsorship needed · German permanent residence · German C1, English native · open to relocating to SF, Seattle or NYC and to 25% in-office · available from 01.12.2026]
