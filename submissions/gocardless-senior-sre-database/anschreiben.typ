// GoCardless (a Mollie company) — Senior SRE, Database Focus. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.85cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.35cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.35cm)
GoCardless #linebreak() Platform Engineering

#v(0.45cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer (Database Focus)]
#v(0.35cm)

Dear GoCardless Hiring Team,

your description puts the database estate at the centre of a payments platform, where a slow query becomes a customer-visible
incident. That framing is why the role interests me: for four years the work I have done is keeping a small production estate healthy
under exactly that constraint, with one person on call and no budget for an alert that cries wolf.

PostgreSQL is where my database work is real rather than adjacent. The mail archive on the fleet is Postgres with versioned
migrations, a restore I have rehearsed rather than assumed, statement timeouts set deliberately, and disk-pressure alerting wired into
the same sentinel that records job status, generation age and pressure stall every fifteen minutes. I read plans before adding
indexes, I have chased idle-in-transaction sessions and autovacuum lag on my own hardware, and I treat a backfill as a change with a
rollback plan rather than a query to run and hope about.

The surrounding reliability work has the same shape as your team's: infrastructure declared in code with pinned inputs, a change
counted only once a gate has read the built artefact back, secrets encrypted per host and authenticated through a certificate
authority, and patching ordered by the CISA KEV catalogue rather than by the loudest advisory. Services are Go and Python.
Observability is self-built — a ledger plus Gatus paging on any state that is not ok — which is the smaller equivalent of the Grafana
and Datadog work in your stack rather than experience with those tools.

The gap I cannot paper over is the specialty bar. Five or more years running PostgreSQL fleets with high availability, replication and
failover, Stolon or Cloud SQL, and major-version upgrades led end to end with minimal downtime: I have run one production Postgres
instance and its recovery path, not an estate, and I have never led a major-version migration. Terraform, GKE, Argo CD and Ruby are
also absent from my history; Nix is my infrastructure language and GitOps here is a flake and a task interface. I would be joining
strong on the reliability and incident side and learning the database depth from your team, which is worth saying before an interview
rather than during one.

On location, plainly: your Platform Engineering team sits in London, Riga and Lisbon, and I am in south-west Germany. I hold German
permanent residence and no UK right to work, so London is not open to me without a visa, and Lisbon would mean a relocation and a new
permit. I am asking whether the role can be held remotely from Germany, because that is your decision and not something I can settle in
a letter.

Kind regards,
#v(0.4cm)
Matt Ji
