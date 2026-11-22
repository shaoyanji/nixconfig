// Nebius — Senior SRE, Data Platform (Greenhouse 5040676101).
// Native English source replacing the Nix-built PDF. PostgreSQL, migrations, restore drills, storage.
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
    #text(size: 9.8pt)[Site reliability engineer · PostgreSQL operations, migrations, restore drills]
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
A data platform is the company's source of truth, so the interesting question is not whether the service is up but whether the data is
recoverable. I have run stateful services on that principle: PostgreSQL declared in the same tree as the service that owns it, backups scheduled
and then actually restored, and durability treated as a property you prove in a drill rather than read off a green dashboard.

The databases are NixOS-managed instances, one per service, each with its own role and database created by declaration, so a rebuild reproduces
the database server rather than documenting it. Schema changes arrive as versioned migrations that run in order and either complete or leave the
previous version in place; the mail archive applies its migrations, generates its search column as a stored `tsvector` behind a GIN index, and
upserts on `message_id` so a replayed message cannot become a second row. Application settings are generated from Nix rather than edited on the
host, which means the connection details and the schema version move together.

Backups exist as a scheduled job and as a drill that restores: a module starts an ephemeral PostgreSQL cluster, replays the dump into it, and
then asserts the restored table count and the rows of the core entities, because a backup nobody has restored is a hypothesis. It runs on a timer
after the backup window, so a broken dump is a failed job the next morning rather than a surprise on the day someone needs the data.

Storage growth is watched where it grows. A sentinel records disk percentage for the root filesystem, the Nix store and the data volume, plus inode
counts, and degrades the host with a named reason when a path crosses its threshold rather than waiting for a write to fail. Pressure stall
information for IO, memory and CPU goes into the same fifteen-minute ledger, job state and generation age alongside it, and the alert fires on a bad
state and on silence.

Integrity is the other half. Write paths validate before they write, state that must not be edited is append-only, specifications are
content-addressed so the same input produces the same hash, and every change to a host is a generation that rolls back in one command. I have also
kept a fourteen-month archive of real mail that classifies its own messages, which is a useful test of all of the above: the data is not synthetic,
the volume grows, and a bad migration would be visible immediately.

What I have not done: no YTsaurus, Hadoop, Spark, ClickHouse or Kafka operations, no Kubernetes at five-hundred-server scale and no operator
development, no multi-petabyte cluster, and no formal capacity planning for a multi-tenant platform. My storage work is single-host and small-fleet.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*PostgreSQL* — declared instances, roles and databases per service, tuned per host],
  [*Migrations* — versioned and ordered, applied by the service, never edited in place],
  [*Restore drills* — dump replayed into an ephemeral cluster, table and row counts asserted],
  [*Storage growth* — disk and inode percentages per path, threshold with a named reason],
  [*Telemetry* — PSI by resource, job state, generation age, page on bad state and silence],
  [*Integrity* — validate before write, append-only state, content-addressed specs],
  [*Search and shape* — stored `tsvector` with GIN, upsert keys that survive replay],
  [*Operations* — one flake, per-host evaluation gate, rollback by pointer])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Operated PostgreSQL as declared infrastructure: one instance per service, roles and databases created by definition, settings generated from Nix so configuration and schema version move together.
- Applied schema changes as versioned migrations that run in order, with the previous version still in place if a step fails — no hand-edited schema on a running host.
- Built the mail archive on that base: migrations, a stored `tsvector` behind a GIN index for full-text search, an upsert keyed on `message_id`, and SQL endpoints generated from annotated queries.
- Scheduled backups and wired a restore drill: an ephemeral PostgreSQL cluster, the dump replayed into it, and a job that fails when the restored table count or the entity rows fall below the floor.
- Watched storage where it grows: disk percentages for root, Nix store and data volume plus inodes, with a threshold that degrades the host under a named reason before a write fails.
- Made a bad state visible: pressure stall information for IO, memory and CPU into a ledger every fifteen minutes with job state and generation age, paging on bad state and on silence.
- Kept the write path honest — validated before insert, append-only event log, content-addressed specifications — so a retry cannot invent a second row or a second fact.
- Declared the fleet from one flake with a per-host evaluation gate, so a service change and the database it depends on are reviewed and rolled back together.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- fibtransponder: a state machine streaming a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input.
- tokenloom: a Rust workspace with a piece table and a ripple re-tokeniser that touches only the changed span, plus an acceptance test that encodes the invariant.
- Diagnosed a path-specific MTU fault to the boundary that dropped the packet instead of raising an application timeout, and wrote the path down so the next diagnosis starts where the evidence ends.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it; verified the geometry independently rather than trusting the first implementation.
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
    Migrations, stored `tsvector` with GIN, upsert on `message_id`, fourteen months of real mail behind it.
  ],
  [
    #text(weight: "bold")[backup drill] #text(size: 8pt, fill: muted)[— durability]
    #linebreak()
    Replays every dump into a throwaway PostgreSQL cluster and fails the job when the restored tables or rows fall short.
  ],
  [
    #text(weight: "bold")[storage ledger] #text(size: 8pt, fill: muted)[— growth]
    #linebreak()
    Root, Nix store and data volume plus inodes; a threshold that degrades with a named reason.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    PSI, job state and generation age every fifteen minutes; pages on bad state and on silence.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— the fleet]
    #linebreak()
    Thirteen hosts, pinned inputs, one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Typed arguments, dry-run plans, JSON output, one exit code per outcome — maintenance without improvisation.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, open to Berlin or remote across Europe · available immediately]
