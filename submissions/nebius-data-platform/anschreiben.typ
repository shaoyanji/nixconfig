// Nebius — Senior SRE, Data Platform. English letter, one page.
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
Nebius

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer, Data Platform]
#v(0.32cm)

Dear Nebius Data Platform team,

your platform is the company's source of truth: one multi-tenant YTsaurus ecosystem carrying roughly ten petabytes of compressed data across five
hundred servers, with financial pipelines and training datasets depending on it. The part of that problem I have already practised is the part where
the data has to come back: PostgreSQL declared in the same tree as the service that owns it, schema changes applied as versioned migrations, backups scheduled and then restored into a throwaway cluster, and durability treated as something a drill proves rather than something a dashboard implies.

Concretely, my mail archive runs on that base — migrations applied in order, a stored `tsvector` behind a GIN index for search, an upsert keyed on
`message_id` so a replayed message cannot become a second row, and SQL endpoints generated from annotated queries. Backups are a scheduled job plus a restore drill that replays the dump into an ephemeral PostgreSQL cluster and asserts the restored table count and entity rows, because a backup nobody has restored is a hypothesis. On the growth side, a sentinel
records disk percentage for root, the Nix store and the data volume plus inode counts, and degrades the host with a named reason when a path crosses
its threshold instead of waiting for a write to fail. Pressure stall information, job state and generation age go into the same fifteen-minute
ledger, and the page fires on a bad state and on silence.

The rest is operational habit: a thirteen-host fleet from one flake, a per-host evaluation gate so a service and the database behind it are reviewed
and rolled back together, short-lived SSH certificates instead of standing keys, and one-command rollback because the previous generation is still in
the store. Integrity comes from the write path — validate before write, append-only state, content-addressed specifications.

What I have not done, so a first call does not have to find it: no YTsaurus, Hadoop, Spark, ClickHouse or Kafka operations, no production Kubernetes
at five-hundred-server scale, no operator development, no multi-petabyte cluster, and no formal capacity planning for a multi-tenant platform. My
storage work is single-host and small-fleet, and the platform's Go operators and diagnostic tooling are where I would expect to spend my first months.

Practical points: based near Freiburg, open to Berlin or fully remote across Europe, no sponsorship needed as a US citizen with German permanent
residence, German C1 and English native. My target is EUR 140,000–155,000. The repository is public:
https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
