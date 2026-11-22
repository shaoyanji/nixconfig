#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Site reliability — Linux platforms, isolation, reproducible operations]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[SRE who ran a thirteen-host Linux platform alone for five years: isolated by default, described in one declarative system, changed only through a gate, and visible through telemetry written for the person on call. Secrets encrypted per host with sops and age, access issued as short-lived SSH certificates from an own CA, services behind a WireGuard mesh with no public listener. Builds hermetic from pinned inputs, rollouts health-checked, rollback by generation, every restore verified. Resident in Germany with permanent residence, so an EU-jurisdiction platform is the normal operating environment. Not held: Kubernetes, managed cloud infrastructure, Staff-level scope across teams, formal EU compliance programmes. Native English, German C1.]

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
  "Ran a thirteen-host Linux platform across three hardware generations, isolated from the public internet and from itself",
  "Described hosts and services declaratively; nothing changed on a machine outside a reviewed commit and a gated rollout",
  "Kept secrets encrypted in the repository with sops and age, one key per host, and issued access as short-lived SSH certificates from an own CA",
  "Put every service behind a WireGuard mesh with no public listener and wrote the nftables boundary rules at the edge",
  "Bound workloads with cgroups and namespaces, and watched PSI and disk pressure to catch isolation failing before a user did",
  "Built telemetry for the platform: Gatus probes plus a 15-minute ledger of job status, generation age, disk and PSI pressure",
  "Automated remediation where it was safe: runbooks became tasks, rollouts became pipelines, alerts were confirmed as delivered",
  "Verified restores with restic rather than counting backup runs, and kept every generation rollback-able",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially, including financial models and externally relied-on reporting",
  "Ran the company's software and IT administration, including access to the systems where plant and financial data lived",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — a fleet that is checked before it runs", "since 2023", (
  "One flake describes hosts, services and user roles; the gate checks modules and assertions before anything rolls out",
  "Health checks, a job ledger and an agent turn log run on the platform they observe",
  "Publishing, deployment and rollback are tasks; no host carries hand-edited state",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Reliability] — health-gated rollout, rollback by generation, verified restores, incident debugging without escalation \
#text(weight: "bold")[Isolation] — network segmentation, WireGuard mesh, nftables, cgroups and namespaces \
#text(weight: "bold")[Identity and secrets] — SSH certificate authority, short-lived credentials, sops and age per host \
#text(weight: "bold")[Observability] — probes, structured ledgers, PSI and disk pressure, alert delivery confirmation \
#text(weight: "bold")[Supply chain] — hermetic reproducible builds, pinned inputs, auditable change history \
#text(weight: "bold")[Software] — Python, Go, Shell, Nix; automation that removes manual operations \
#text(weight: "bold")[Not held] — Kubernetes, managed cloud infrastructure, Staff-level scope across teams, BSI C5 / ISO 27001 / SOC 2 \
#text(weight: "bold")[Languages and status] — English native, German C1 · resident in Germany with permanent residence (Niederlassungserlaubnis)
