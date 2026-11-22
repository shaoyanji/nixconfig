#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.5cm, bottom: 1.5cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.58em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Platform engineering — reproducible infrastructure, automated gates, telemetry that reaches a human]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Five years owning the platform underneath a thirteen-host estate: pinned inputs so a commit reproduces a system, a gate over the evaluated configuration rather than an exit code, rollback as a previous generation, and telemetry that is only counted once delivery is confirmed. The platform was the product and the customer was me, which removes every excuse: no hand-edited state, no undocumented procedure, no alert that fires into nothing. Linux underneath is an instrument rather than a slogan — systemd, cgroups, namespaces, pressure and disk as leading signals. Not held: AWS or any cloud provider at production scale, Kubernetes, Terraform, and a multi-tenant marketplace's traffic. The letter concedes those plainly.]

#let section(kind) = block(breakable: false, sticky: true, width: 100%)[
  #v(6pt)
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
  #v(4pt)
]

#section("Experience")
#entry("Bountystash — Founder, platform owner and sole operator", "2020 – 2025", (
  "Owned the internal platform for thirteen Linux hosts across three hardware generations: installation, network, services, accounts, updates, backups",
  "Kept the platform reproducible: pinned inputs, the same commit producing the same system, rollback measured in minutes rather than nights",
  "Gated every change on the evaluated configuration — modules and assertions — so a bad option failed a pipeline and not a customer",
  "Built the telemetry loop: a 15-minute timestamped ledger, external probes, and a Go alert bridge that reports success only once delivery is confirmed",
  "Treated pressure and disk as product signals: PSI, memory and generation age checked because they move before an outage does",
  "Automated the maintenance people skip: updates, certificate rotation, backup restores actually exercised",
  "Held the security boundary in code: nftables, a WireGuard mesh with no public listener, own certificate authority with short-lived certificates, sops and age per host",
  "Wrote the tooling in Python and Go and generated the documentation from the same graph, so the platform explained itself",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets and owned the company's software and IT",
  "Turned operating data into the reports management decided from",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Worked in a shared research environment where machines served people who were not administrators",
))

#section("Projects")
#entry("nixconfig — a platform described once", "since 2023", (
  "A host registers once as a feature list; checks, task menu and documentation are generated from that same graph",
  "Tiered gates by cost: seconds for repository hygiene, per-host evaluation, expensive checks only where the machine can hold them",
  "Self-hosted services behind open interfaces, including model serving with on-demand loading and a compute guard",
))

#section("How I work")
#text(size: 9.5pt)[
  - Describe, then change: nothing edited by hand on a machine, every change reviewed where it is declared. \
  - Measure before optimising: a pipeline's cost is observed, not assumed. \
  - Write it down: a runbook per procedure, so the platform does not depend on one person's memory.
]

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Platform] — reproducible builds, evaluated-configuration gates, generation rollback, inventory-derived CI matrix, cost-tiered checks \
#text(weight: "bold")[Telemetry] — timestamped ledger, probes, delivery-confirmed alerting, PSI and disk pressure as leading indicators, generation age \
#text(weight: "bold")[Linux] — systemd, cgroups, namespaces, boot and recovery, nftables, WireGuard, own CA with short-lived certificates \
#text(weight: "bold")[Code] — Python, Go, Shell; internal tooling, bridges, reports, generated documentation \
#text(weight: "bold")[Not held] — AWS or any cloud provider in production, Kubernetes, Terraform, Kafka, multi-tenant marketplace traffic \
#text(weight: "bold")[Languages and status] — English native, German C1 · German permanent residence (US citizen) · relocation to the Netherlands required
