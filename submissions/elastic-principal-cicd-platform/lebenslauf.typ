#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Build systems and platform engineering — reproducible pipelines, Linux, automation]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Five years of building and running the pipeline that produced a thirteen-host fleet: pinned inputs, so the same commit and the same inputs yield the same system; a gate over the evaluated configuration, so a broken option fails a pipeline instead of a machine; one host per process under a memory guard, so a sweep of the fleet does not take the machine doing the sweeping down with it. The CI matrix is derived from the inventory, which means a new host is tested because it is registered, not because someone remembered to add it. Test orchestration at Elastic's scale, Bazel or Gradle pipelines, distributed build caches and Kubernetes runners are not mine; the letter says so plainly.]

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
#entry("Bountystash — Founder and sole operator", "2020 – 2025", (
  "Built the delivery pipeline for thirteen Linux hosts across three hardware generations: pinned inputs, reproducible output, rollback by generation",
  "Derived the CI matrix from the host inventory, so registration is what puts a host under test",
  "Gated every rollout on the evaluated configuration — modules and assertions — never on a compile that merely succeeded",
  "Kept fleet-wide checks from becoming self-harm: one host per process, a memory watchdog around sweeps, and batching instead of parallel enthusiasm",
  "Made the pipeline legible: generated docs, a task menu as the only entry point, runbooks for the procedures that bite",
  "Wrote the tooling in Python and Go — rollout, ledger, alerting bridge with delivery confirmation",
  "Owned the Linux underneath: systemd, cgroups, namespaces, PSI and disk pressure, boot and initrd on hardware that was bought, not rented",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially and owned the company's software and IT",
  "Built the financial models and operating reports that management made decisions from",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry",
))

#section("Projects")
#entry("nixconfig — a platform described once", "since 2023", (
  "A host registers once as a feature list; checks, task menu and docs are all generated from the same graph",
  "Tiered gates: repository hygiene in seconds, host evaluation per host, flake checks only where the machine can hold them",
  "Deployment, publishing and rollback are tasks, never edits made on a host",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Build and delivery] — reproducible builds from pinned inputs, evaluated-configuration gates, generation rollback, inventory-derived matrices \
#text(weight: "bold")[Nix] — flakes, module composition, overlays, dev shells, package definitions, remote builders \
#text(weight: "bold")[Linux] — systemd, cgroups, namespaces, PSI and disk pressure, boot and recovery, nftables, WireGuard \
#text(weight: "bold")[Automation] — Python, Go, Shell; gates, tasks, generated documentation, delivery-confirmed alerting \
#text(weight: "bold")[Not held] — Bazel, Gradle, distributed build caches, Kubernetes runners, CI at thousands of builds a day, Java ecosystem tooling \
#text(weight: "bold")[Languages and status] — English native, German C1 · German resident with permanent residence · remote across EMEA
