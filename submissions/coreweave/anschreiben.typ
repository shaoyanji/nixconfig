// CoreWeave / Weights & Biases — Senior Data Platform Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
CoreWeave\\
Weights & Biases, Data Platform

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Data Platform Engineer]
#v(0.45cm)

Dear Data Platform team,

everyone who has run a training run has met the moment where the loss curve and the logs disagree. That gap is the
product: instrumentation is a promise that someone will read the number later, and the pipeline is only as trustworthy
as its worst validation. I have spent five years building systems on that premise, and it is why this role is
interesting to me rather than merely adjacent.

Concretely, on ingestion I would rather fail than write half a batch. What I have built validates before it writes, so a
rejected load leaves the previous state intact and explains itself; a rerun produces the same rows rather than a second
copy, which matters more than throughput once a customer is querying yesterday's data. Under it sits PostgreSQL with
versioned migrations and rehearsed restores — a backup nobody has restored is a belief, not a backup. Retention is a
decision with a number attached, not the residue of never deleting anything.

On instrumentation, I have run a fifteen-minute ledger over job state, generation age, disk pressure and PSI that pages
on any state short of ok and times out on silence itself. Two habits came out of it that transfer directly to event
schemas: alert on state rather than on volume, so alerts don't cry wolf, and treat the absence of data as data, because
the failure mode of instrumentation is a dashboard that looks calm while nothing is reporting. At the OS level I use
cgroups and PSI to tell I/O starvation from memory shortage under load, and `tcpdump` and `strace` to explain a
disagreement between what a service logged and what it did.

What I have not done is worth stating as plainly: no dbt, Dagster or Airflow in production — my orchestration is a task
runner and systemd, which is honest but not the same tool — no multi-petabyte warehouse, and no catalog, lineage or
semantic layer. Those are the parts of this job I would be learning, and the reason I would want to join a team that has
already solved them rather than invent them alone at thirteen machines.

The location question should be settled early. This posting is US-based and I am in Germany today, so I will answer it
directly: I am a US citizen, there is no visa or sponsorship step, and relocating to a US hub for the three office days
is a logistics problem I am prepared to solve — not a permission problem. German permanent residence covers the
alternative if the team ever wants a European base. Either way, the time-zone overlap is mine to manage.

On the data side, my background before software is unusual and relevant: eight years running valuation and risk models
on a solar portfolio above USD 100M, where a number that could not be audited was a number nobody would lend against.
That is where I learned to care about lineage in practice, even without a lineage product.

Yours sincerely,
#v(0.5cm)
Matt Ji
