#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Site reliability and GitOps — Linux, Python, declarative operations]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[SRE who runs infrastructure the way an information-systems team should: Git as the only source of truth, hosts and services described rather than configured, rollout only through a pipeline that evaluates the same configuration it deploys, rollback as a task instead of a procedure. Five years as the sole operator of a thirteen-host Linux fleet, with Python and Go tooling written to remove the manual step entirely, observability built into the platform, and every restore verified. Native English, German C1, US citizen with permanent German residence, working remotely from Germany. Kubernetes, ArgoCD and fleet management at Canonical's scale are not part of this record.]

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
  "Ran a thirteen-host Linux platform across three hardware generations as one declarative system, from procurement to decommissioning",
  "Kept Git as the only source of truth: one module per service, one feature list per host, no hand-edited state on any machine",
  "Gated every deployment in CI against the evaluated configuration, so a bad change failed a pipeline instead of a host",
  "Wrote the automation in Python and Go: rollout tooling, a sentinel ledger, and an alerting bridge that confirms delivery",
  "Operated the network layer end to end: nftables rules, a tailnet with no public listener, certificates from an own SSH CA",
  "Built observability: Gatus probes plus a ledger recording job status, generation age, disk and PSI pressure every 15 minutes",
  "Backed up to NAS targets with restic and verified restores rather than counting successful runs",
  "Documented every procedure as a runbook and every decision as a note, so operations did not depend on memory",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Owned the commercial side of 10 MW of solar PV assets and the IT administration of the company and its subsidiaries",
  "Built financial models and ran the software the business depended on, including the systems where plant data accumulated",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — declarative fleet, checked before it exists", "since 2023", (
  "One flake describes hosts, services and user roles; a host registers once as a feature list and a gate pays for the option surface",
  "Health checks, a job ledger and an agent turn log run on the same platform they observe",
  "Publishing, deployment and rollback are tasks; no host is edited by hand",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[GitOps] — Git as the single source of truth, declarative configuration, drift prevention, rollback by commit \
#text(weight: "bold")[CI/CD] — pipelines as the only path to production, gates on evaluated state, reproducible builds \
#text(weight: "bold")[Linux] — systemd, networking, nftables, storage and capacity management, boot and recovery \
#text(weight: "bold")[Software] — Python, Go, Shell, Nix; tooling that removes manual operations \
#text(weight: "bold")[Observability] — probes, structured ledgers, metric analysis, alert delivery confirmation \
#text(weight: "bold")[Security] — sops/age, SSH certificate authority, least-privilege network, encrypted secrets in git \
#text(weight: "bold")[Not held] — Kubernetes, ArgoCD, fleet management at millions of machines, upstream maintainership \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence (Niederlassungserlaubnis) · remote from Germany
