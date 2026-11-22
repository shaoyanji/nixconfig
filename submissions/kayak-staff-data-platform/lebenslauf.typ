#set document(title: "Matt Ji — Curriculum Vitae", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Platform engineering, telemetry and distributed storage]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Systems engineer with ten years in production infrastructure, storage and telemetry, including a research station at Fraunhofer ISE. Builds platforms as code: thirteen Linux hosts in one declarative flake, every service a module, every change a commit with a gate and a rollback path. Designed an append-only, content-addressed event log, and a telemetry ledger that writes job status, generation age and memory pressure every 15 minutes and only marks an alert delivered when delivery is confirmed. Works in Python, Go, SQL and Bash. No production Iceberg, Parquet, Kafka, Flink, Trino, Airflow, AWS or Kubernetes: the data-platform stack is the gap, not the systems reasoning. English native, German C1.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(5pt)
  #text(size: 10.5pt, weight: "bold", fill: rgb("#1f2937"))[#kind]
  #v(1pt)
  #line(length: 100%, stroke: 0.4pt + rgb("#e5e7eb"))
  #v(2pt)
]

#let entry(title, when, bullets) = block(breakable: false, width: 100%)[
  #par[
    #text(weight: "bold")[#title]
    #if when != "" [#text(size: 8.5pt, fill: rgb("#4b5563"))[ — #when]]
  ]
  #if bullets != () [
    #v(1pt)
    #block(inset: (left: 10pt, top: 0pt, bottom: 0pt))[
      #for bullet in bullets [- #bullet]
    ]
  ]
  #v(3pt)
]

#section("Experience")
#entry("Bountystash — Founder", "2020 – 2025", (
  "Designed an append-only event log with content-addressed, immutable specifications, so every request stays reproducible instead of becoming a mutable record",
  "Built the telemetry ledger for the fleet: a Sentinel job writes job status, generation age, disk and PSI memory pressure to JSONL every 15 minutes",
  "Probed endpoints with Gatus and routed alerts through a Go bridge that only confirms delivery when the message actually arrives",
  "Ran thirteen Linux hosts across three hardware generations and several sites, with per-host role declarations instead of hand-made accounts",
  "Held the whole platform as code in Git: every host a feature list, every service a module, every change a gate and a rollback",
  "Tuned services with systemd options and per-service resource limits; no service listened on a public interface",
  "Automated operational work, analysis and deploy chains in Python, Go and Bash",
  "Backed data up with restic to a NAS and restored it to prove the backup, rather than trusting the job",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Owned software and IT administration for the company and its subsidiaries",
  "Built financial models and managed a portfolio of 10 MW solar PV assets",
  "Led an international team and designed an incentive structure tied to a real-time financial model",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
  "Wrote C++ applications to drive lab instruments and Python tools for analysis and 3D geometry",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Projects")
#entry("nixconfig", "since 2023", (
  "Declared the fleet in one flake so the option surface stays a gate instead of copy-and-paste between hosts",
  "Ran the same per-host module gate in CI as on the machines, plus a ledger of job status, generation age and pressure",
  "Operated a self-hosted AI platform on own hardware: local model serving, a Go router, model switching on demand, access only over the tailnet",
))

#section("Skills")
#text(weight: "bold")[Languages] — Python, Go, SQL, Bash, C, C++ \
#text(weight: "bold")[Data systems] — event-log modelling, append-only storage, content addressing, PostgreSQL, MySQL, schema reasoning \
#text(weight: "bold")[Telemetry] — ledger design, JSONL, Gatus probes, alert delivery confirmation, PSI and capacity signals \
#text(weight: "bold")[Platform] — Git as the only source, declarative modules, gates per host, rollback per generation, CI \
#text(weight: "bold")[Linux] — systemd hardening, resource limits, packaging, boot configuration, storage and restic restores \
#text(weight: "bold")[Not yet] — Iceberg, Parquet, Kafka, Flink, Trino, Airflow, AWS, Kubernetes, Java \
#text(weight: "bold")[Availability] — relocation to Berlin workable, three days on site acceptable
