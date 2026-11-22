#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.7cm, bottom: 1.7cm, left: 2.0cm, right: 2.0cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 12pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.60em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux reliability, telemetry and Go tooling]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux systems administrator with ten years in operations, automation and reliability engineering. Ran thirteen servers across three hardware generations as one declarative fleet: a module per service, a feature list per host, every change a commit behind a gate, every previous state kept as a generation that can be rolled back. Built the telemetry because there was no monitoring budget: a sentinel job writing job status, generation age, disk and PSI pressure to a JSONL ledger every 15 minutes, Gatus endpoint checks, and a Go bridge that acknowledges an alert only once delivery is confirmed. Diagnoses incidents from that data and the logs before users report them. Works close to the kernel: cgroup limits per service, PSI as a first-class signal, systemd hardening, namespaces, nftables. Prometheus, Grafana, OpenTelemetry, Tempo, Loki, Kubernetes and database operations at scale are not part of this experience. Based in Germany, 100% remote available; US citizen with permanent German residence, no sponsorship needed. German C1, English native.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(10pt)
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
  #v(7pt)
]

#section("Experience")
#entry("Bountystash — Founder and sole operator", "2020 – 2025", (
  "Operated thirteen NixOS hosts across three hardware generations and several sites, from procurement through installation to steady state",
  "Described platform and services in one flake: a module per service, a feature list per host, every change a commit with a gate",
  "Kept every state as a generation with a tested path back, and gated CI on the same state that gets deployed",
  "Built the observability: a sentinel job writing job status, generation age, disk and PSI pressure to a JSONL ledger every 15 minutes",
  "Added Gatus endpoint checks and a Go bridge that acknowledges an alert only once delivery is confirmed, so silent notification failure is visible",
  "Ran services under systemd with cgroup memory and CPU limits, watching PSI for pressure before symptoms",
  "Configured network and firewall as code in nftables, with DNS and a WireGuard tailnet; no service exposed on a public socket",
  "Kept secrets in sops and age, issued short-lived certificates from an own SSH CA, and moved TLS onto an own CA",
  "Backed up with restic to NAS targets and validated restores rather than counting backup runs",
  "Wrote tooling in Shell, Python and Go, including ledger queries and the alerting bridge, and documented every procedure as a runbook",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Owned software and IT administration for the company and its subsidiaries",
  "Built financial models and managed 10 MW of solar PV assets",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Connected lab instruments through self-written C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies using interferometry",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8 (German scale); neural-network modelling",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Selected work")
#entry("nixconfig — a declarative fleet with gates", "since 2023", (
  "Module per service, feature list per host; a gate per host checks modules and assertions before anything deploys",
  "Sentinel ledger over job status, generation age, disk and PSI, with a Go alerting bridge that confirms delivery",
  "Services behind a tailnet with no public socket; certificates and keys issued by the own CA",
))
#entry("Self-hosted AI platform on owned hardware", "2024 – 2025", (
  "Model server, Go router and web front end on own machines, with no cloud dependency and no outbound connection in operation",
  "Each model lane isolated with its own limits and its own access path",
))

#section("Skills")
#text(weight: "bold")[Linux internals] — systemd hardening, cgroup limits, PSI, namespaces, nftables, PXE installs \
#text(weight: "bold")[Reliability] — generations and rollback, gated deploys, runbooks, incident diagnosis from data and logs \
#text(weight: "bold")[Telemetry] — JSONL ledger with 15-minute cadence, Gatus checks, Go alerting with delivery confirmation, restic with validated restores \
#text(weight: "bold")[Code] — Go, Python, Shell; git as single source; CI gates \
#text(weight: "bold")[Not present] — Prometheus, Grafana, OpenTelemetry, Tempo, Loki, Kubernetes, MySQL/PostgreSQL/Cassandra/ClickHouse operations \
#text(weight: "bold")[Status] — Germany based, 100% remote · US citizen with permanent German residence · German C1, English native
