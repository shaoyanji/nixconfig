// Workato — Senior Infrastructure Engineer (PostgreSQL DBA), REQ 2960, Greenhouse 8842211002.
// Native English source replacing the Nix PDFs. PostgreSQL, migrations, archive schema, restore drills.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2b2f4a"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2b2f4a")
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
    #text(size: 9.8pt)[Infrastructure and database engineer · PostgreSQL, migrations, restore drills]
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
The databases I run are the ones I declared myself, which means nobody handed me a cluster and nobody else is on call for it. PostgreSQL is provisioned per
service in the same tree as the service: instance, role and database created by definition, settings generated from Nix instead of edited on a host, so a
rebuild reproduces the server rather than documenting what someone once typed into it.

Schema is code. Changes arrive as ordered migration files that the service applies; a failed step leaves the previous version running, so a bad deploy is a
stopped deploy rather than a half-migrated database. The mail archive is the working example and my best answer to a schema review: a stored generated
`tsvector` over subject, sender and body behind a GIN index, an upsert keyed on `message_id` so a redelivered message cannot become a second row, SQL
endpoints generated from annotated queries rather than hand-written duplication, and an enum-backed classifier table keyed on `(message_id, classifier)` so
two classifiers can disagree and both verdicts stand.

Durability is checked, not assumed. A scheduled job dumps each database; a second job — a drill, `modules/services/postgres-backup-drill.nix` — starts an
ephemeral PostgreSQL cluster, replays the dump into it with `psql`, then asserts the restored table count against a floor and, for the application database,
the row counts of its core entities. A broken dump fails the drill the next morning instead of surfacing on the day someone needs the data. Backups are also
declared: `services.postgresqlBackup` on the host that holds the archive, `pg_dump` in the stack definition, and disk headroom watched so a full volume
cannot silently stop writes.

Operations are instrumented like the rest of the fleet. A sentinel writes disk percentage for the root filesystem, the Nix store and the data volume plus
inode counts every fifteen minutes, degrades the host with a named reason when a path crosses its threshold rather than waiting for a write to fail, and
pages on a bad state and on silence. Pressure stall information, job state and generation age sit in the same ledger.

Where I fall short of this posting, plainly: my PostgreSQL is single-node by design — no streaming replicas, no failover, no PgBouncer in front of it, no
Aurora or RDS beyond reading their documentation. I have not run a major-version upgrade with `pg_upgrade` or logical replication, my largest table is
gigabytes rather than the multi-terabyte partitioned tables this role tunes, and I have not carried a database on-call rotation at company scale. My
infrastructure-as-code is Nix, not Terraform or Ansible. Those are the gaps, stated here rather than found in a first call.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*PostgreSQL* — declared instances, roles and databases per service, settings from Nix],
  [*Migrations* — ordered and versioned, applied by the service, previous version kept on failure],
  [*Schema design* — generated `tsvector` with GIN, upsert keys, enum-backed classifier rows],
  [*Restore drills* — dump replayed into an ephemeral cluster, table and row counts asserted],
  [*Query shape* — annotated SQL endpoints, generated instead of duplicated by hand],
  [*Backups* — `postgresqlBackup`, `pg_dump`, and a drill that proves the dump is usable],
  [*Observability* — disk and inode percentages per path, PSI, job state, page on silence],
  [*Automation* — typed task arguments, dry-run plans, one exit code per outcome])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Operated PostgreSQL as declared infrastructure: one instance per service, role and database created by definition, connection details generated so configuration and schema version move together.
- Wrote and applied ordered migrations for the archive; a failed step leaves the previous version running rather than a half-migrated database.
- Designed the archive schema around search and idempotency: generated `tsvector` over subject, sender and body with a GIN index, `message_id` as the upsert key, and a classifier table whose primary key allows two verdicts to stand side by side.
- Generated the SQL endpoints from annotated queries, so the API surface and the schema cannot drift apart silently.
- Built the restore drill: ephemeral PostgreSQL cluster, dump replayed with `psql`, restored table count against a floor and entity row counts asserted, on a timer after the backup window.
- Declared backups and dumps in the stack (`postgresqlBackup`, `pg_dump`) and watched disk and inode headroom per path, with a named degrade reason instead of a failed write.
- Ran the thirteen-host NixOS fleet the database lives on: pinned inputs, a per-host evaluation gate, rollback by generation, short-lived SSH certificates and per-host SOPS keys.
- Read plans when search got slow, and fixed the cause in the schema or the index rather than adding a timeout.

#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- Go services and CLI tooling for telemetry and operations, plus Python and Bash for checks and analysis.
- tokenloom: a Rust workspace with a piece table and a ripple re-tokeniser that touches only the changed span, plus an acceptance test that encodes the invariant.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, software and risk.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— schema]
    #linebreak()
    Generated `tsvector` with GIN, upsert on `message_id`, classifier rows that can disagree.
  ],
  [
    #text(weight: "bold")[restore drill] #text(size: 8pt, fill: muted)[— durability]
    #linebreak()
    Ephemeral cluster, dump replayed with `psql`, table count and entity rows asserted.
  ],
  [
    #text(weight: "bold")[migrations] #text(size: 8pt, fill: muted)[— change control]
    #linebreak()
    Ordered files applied by the service; a failed step leaves the old version serving.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Disk and inode percentages per path, PSI, job state, page on bad state and on silence.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— infrastructure]
    #linebreak()
    Thirteen hosts, pinned inputs, one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
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
#text(size: 7.8pt, fill: muted)[US citizen with German permanent residence, no sponsorship needed · German C1, English native · open to relocating to Berlin, Frankfurt or Munich · available from 01.12.2026]
