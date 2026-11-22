// Workato — Senior Infrastructure Engineer (PostgreSQL DBA), REQ 2960. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.32cm)
Workato

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Infrastructure Engineer (PostgreSQL DBA), REQ 2960]
#v(0.32cm)

Dear Hiring Manager,

the role you describe is the one part of infrastructure where I have been the only person on call, so I learned it from the failure side: a database is not
healthy because it answers queries, it is healthy because someone has proved the data comes back. My PostgreSQL is declared per service in the same tree as
the application — instance, role and database created by definition, settings generated rather than typed into a host — and the schema it holds is the
closest thing I have to a design argument.

That schema is the mail archive: an ordered set of migrations, a generated `tsvector` over subject, sender and body behind a GIN index, `message_id` as the
upsert key so a redelivered message cannot become a second row, and a classifier table whose primary key is `(message_id, classifier)` so two classifiers
can disagree and both verdicts stand. The SQL endpoints are generated from annotated queries, which keeps the API surface and the schema from drifting
apart without anyone noticing.

Durability is a scheduled check, not a sentence in a runbook. A job dumps each database; a second job starts an ephemeral PostgreSQL cluster, replays the
dump into it with `psql`, then asserts the restored table count against a floor and the row counts of the core entities. If the dump is broken, the drill
fails the next morning rather than on the day someone needs the data. Backups are declared too — `postgresqlBackup` on the archive host, `pg_dump` in the
stack — and disk and inode headroom per path are watched with a named degrade reason instead of a failed write.

What I have not done, so it is not a surprise later: no streaming replicas, no failover, no PgBouncer in front of the database, and no Aurora or RDS beyond
reading how they behave. I have not run a major-version upgrade with `pg_upgrade` or logical replication, my largest table is gigabytes rather than the
multi-terabyte partitioned tables this role tunes, and I have not carried a database on-call rotation at company scale. My infrastructure-as-code is Nix
rather than Terraform or Ansible, though the habit transfers: typed arguments, dry-run plans, one exit code per outcome. What I bring is the operator's
half — careful schema, migrations that stop instead of half-finishing, drills that fail loudly, and the discipline of writing down what the evidence showed.

Practical points: based near Freiburg and open to relocating to Berlin, Frankfurt or Munich; US citizen with German permanent residence, so no sponsorship
needed; German C1, English native; available from 1 December. My target is EUR 130,000–150,000. The repository is public:
https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
