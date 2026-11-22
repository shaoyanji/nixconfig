// Anthropic — Staff+ Software Engineer, Data Infrastructure. English letter, one page.
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
Anthropic

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff+ Software Engineer, Data Infrastructure]
#v(0.32cm)

Dear Anthropic Data Infrastructure team,

your charter is data processing, storage and access that are trusted, fast and easy to use. Trusted is the word I can work from: I have spent six years
running a platform alone, where the only durable defence is that the data comes back and that access is decided in code rather than in habit.

The storage side is PostgreSQL declared in the same tree as the service that owns it, with the role, database and settings generated instead of edited on a
host. Schema changes are ordered migrations that either complete or leave the previous version running, so a failed step stops a deploy rather than leaving a
half-migrated database. My mail archive is the working example: a stored `tsvector` behind a GIN index, an upsert keyed on `message_id` so a replay cannot
become a second row, SQL endpoints generated from annotated queries, and real mail behind it rather than fixtures.

Durability is a scheduled check, not a claim. The backup drill starts an ephemeral PostgreSQL cluster, replays the dump into it with `psql`, and asserts the
restored table count and the entity rows, on a timer after the backup window; a broken dump is a failed job the next morning instead of a surprise on the day
someone needs the data. Growth is watched where it grows: disk and inode percentages per path, PSI for IO, memory and CPU, job state and generation age into a
ledger every fifteen minutes, with a page on a bad state and on silence.

Access follows the same rule. No standing SSH keys, short-lived certificates from the fleet's own authority, per-host sops/age keys so one host cannot read
another's secrets, and a dedicated user with a hardened unit per service rather than one account with root's reach. Personal mail sits in one database behind a sops-managed
role instead of scattered across inboxes, with no standing credentials.

What I have not done, so a first call does not have to discover it: no BigQuery, BigTable, Airflow, dbt or Spark operations, no petabyte-scale object-store
replication or disaster recovery on GCS or S3, and no IAM or audit-logging design at thousands-of-users scale. My storage work is single-host and small-fleet.
I have led a team and set technical direction for a platform, but not as a Staff engineer across several teams at once. The financial-pipeline and
access-control areas are where I would learn fastest, because both are versions of work I have already done at a smaller size.

Practical points: US citizen, so no sponsorship needed; based near Freiburg, Germany, and open to relocating to San Francisco, Seattle or New York and to the
25% in-office expectation. Available from 1 December. Target USD 405,000–440,000, anchored at the published band floor. The repository is public:
https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
