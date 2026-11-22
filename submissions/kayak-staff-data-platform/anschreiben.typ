#set document(title: "Application KAYAK — Staff Data Platform Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  KAYAK \
  Hiring Team, Data Platform \
  Berlin Office \
  Friedrichshain, Berlin
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application for Staff Data Platform Engineer]

#v(4pt)
Dear Hiring Team,

#v(2pt)
A data platform is judged by what its consumers can trust without asking. I have spent five years building the same property at a much smaller scale: thirteen Linux hosts where every service is declared, every change is a commit with a gate and a rollback, and the health of the whole system is written down every fifteen minutes rather than remembered. KAYAK's description of a shared foundation for analytics, machine learning and AI is the version of that problem with real stakes, and the part I want is the architecture, not the dashboards.

#v(2pt)
Two pieces of my work map directly. The first is an append-only event log where every request becomes an immutable, content-addressed specification, so the record stays reproducible instead of turning into a mutable row someone edits later. That is the same discipline data contracts and schema evolution demand: the record is the contract, and history is not negotiable. The second is the telemetry ledger. A Sentinel job writes job status, generation age, disk and PSI memory pressure into JSONL every fifteen minutes; Gatus probes endpoints; a Go bridge only confirms an alert once delivery is confirmed. On top of that, the whole platform lives in Git, with per-host feature lists, module gates and a rollback path for every generation, and CI runs the same gate the machines run.

#v(2pt)
What I have not done is the stack the role is built on. No Iceberg, Parquet or S3 lakehouse, no Trino or semantic layer, no Kafka or Flink with exactly-once semantics and consumer-lag management, no Airflow, no AWS in production, no Kubernetes operation, no Java. I have seven years of systems work rather than seven years of professional data engineering, and staff-level scope across many consuming teams is not the same as a thirteen-host fleet. I would rather say that here than have it discovered in a design review.

#v(2pt)
What I bring is the part that is harder to hire: someone who treats storage, schema and observability as one designed system, writes production Python and Go, and can explain a trade-off between latency, correctness and cost without a slide deck. I am willing to relocate to Berlin and to be in the office three days a week. The repository shows the work without polish: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
