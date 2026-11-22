#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Infrastructure security — boundaries, identity, secrets, hermetic builds]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Secured a thirteen-host Linux platform without a security team, which meant every boundary decision was mine: a mesh network with no public listener, nftables rules at the edge, secrets encrypted per host with sops and age, and an SSH certificate authority issuing short-lived access instead of long-lived keys. Built the same platform hermetically from pinned inputs, so what ran was what was reviewed, and kept an audit trail by default — a sentinel ledger every 15 minutes, runbooks for every procedure, git history for every change. Based in Gutach im Breisgau, about 25 km from the Freiburg lab. Not held: a security title, AWS and Kubernetes security, ML training fleets, formal threat modelling or compliance programmes. Native English, German C1, US citizen with permanent German residence.]

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
  "Owned the security posture of a thirteen-host Linux fleet end to end, with no dedicated security team and no vendor appliance",
  "Kept secrets encrypted in the repository with sops and age, one key per host, so a leaked artefact revealed nothing usable",
  "Ran an own SSH certificate authority: access was a short-lived certificate, not a shared key passed around",
  "Put every service behind a WireGuard mesh with no public listener, and wrote the nftables boundary rules at the edge",
  "Isolated workloads with cgroups and namespaces, and used PSI and disk pressure as the signal for when isolation was failing",
  "Built every system hermetically from pinned inputs, so the binary that ran was the one the gate had checked",
  "Kept an audit trail by construction: a 15-minute sentinel ledger of job status, generation age and pressure, plus runbooks and git history",
  "Automated the operations in Python and Go, including an alerting bridge that confirms delivery rather than assuming it",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially, including financial models and reporting that external parties relied on",
  "Ran the company's software and IT administration, including access to the systems where plant and financial data lived",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — a fleet that is reviewed before it runs", "since 2023", (
  "One flake describes hosts, services and user roles; every change is a reviewed commit, not an edit on a machine",
  "A gate checks modules and assertions before rollout, so an unsafe configuration fails a pipeline rather than a host",
  "Deployment and rollback are tasks; no host carries hand-edited state, which removes a whole class of drift",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Identity and access] — SSH certificate authority, short-lived credentials, per-host keys, least privilege by default \
#text(weight: "bold")[Secrets] — sops and age, encrypted secrets in git, key separation per host \
#text(weight: "bold")[Network] — WireGuard mesh, no public listeners, nftables rules, service segmentation \
#text(weight: "bold")[Isolation] — cgroups and namespaces, PSI and disk pressure as control signals \
#text(weight: "bold")[Supply chain] — hermetic reproducible builds, pinned inputs, rollback by generation \
#text(weight: "bold")[Audit] — structured ledgers, runbooks, reviewed history for every change \
#text(weight: "bold")[Not held] — security job title, AWS and Kubernetes security, ML training fleets, formal threat modelling, SOC 2 or ISO 27001 \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence · 25 km from the Freiburg lab
