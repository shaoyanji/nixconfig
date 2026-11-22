#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux platform and telemetry engineering — storage, access control, reproducibility]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Engineer who has built the small version of this problem: a telemetry pipeline that writes structured records every fifteen minutes and is read when something is wrong, storage capacity planned from measured pressure rather than guesswork, access granted through short-lived certificates from an own CA, and an audit trail that exists because the system was built that way. Five years as the sole operator of a thirteen-host Linux fleet, with Python and Go for the tooling and hermetic builds underneath. Not held: Spark or distributed data processing, petabyte-scale data, cloud storage services, Staff+ scope across teams. Native English, German C1.]

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
  "Built a telemetry pipeline for a thirteen-host fleet: job status, generation age, disk and PSI pressure written to a JSONL ledger every 15 minutes",
  "Analysed that ledger in Python and Go and connected alerting to a bridge that only confirms delivery once the message arrives",
  "Owned storage end to end: what to keep, where, how much, and what happens at capacity; restores verified rather than backup runs counted",
  "Controlled access through an own SSH certificate authority with short-lived certificates, and kept secrets encrypted per host with sops and age",
  "Worked at the Linux performance layer under load: PSI, OOM events, disk pressure, cgroups and namespaces",
  "Built systems hermetically from pinned inputs, so the same inputs produced the same system and rollback was a generation",
  "Kept an audit trail by construction: reviewed commits, runbooks and decision notes for every procedure",
  "Automated operations in Python and Go instead of documenting manual steps",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially, including financial models and reporting that external parties relied on",
  "Ran the company's software and IT administration, including the systems where plant and financial data lived",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — declarative fleet with its own observability", "since 2023", (
  "One flake describes hosts, services and user roles; every change enters through a reviewed commit and a gate",
  "Health checks, a job ledger and an agent turn log run on the platform they observe",
  "Publishing, deployment and rollback are tasks; no host carries hand-edited state",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Data pipeline] — structured event records, JSONL ledger, scheduled collection, analysis in Python and Go \
#text(weight: "bold")[Storage] — capacity planning from measured pressure, NAS targets, restic with verified restores \
#text(weight: "bold")[Access and audit] — SSH certificate authority, short-lived credentials, sops/age, reviewed history \
#text(weight: "bold")[Linux performance] — PSI, OOM, disk and memory pressure, cgroups and namespaces, systemd \
#text(weight: "bold")[Reliability] — health-gated rollout, rollback by generation, hermetic builds, delivery-confirmed alerting \
#text(weight: "bold")[Not held] — Spark or distributed data processing, petabyte-scale data, cloud storage services, Staff+ scope across teams \
#text(weight: "bold")[Languages and status] — English native, German C1 · German resident with permanent residence
