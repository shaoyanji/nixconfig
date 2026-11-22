#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Site reliability engineering — Linux, Python, declarative fleet operations]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[SRE who treats operations as software: a thirteen-host Linux fleet described in one declarative system, rolled out only through a gate that evaluates the same configuration it deploys, observed by telemetry written for the purpose and alerted through a bridge that confirms delivery. Python and Go for the tooling, systemd and nftables for the platform, restic with verified restores for the data. Open source is the working base, not a preference — NixOS, Gatus, restic, sops, Tailscale. Worldwide remote is the normal mode; quarterly travel is not an obstacle. Native English, German C1, US citizen with permanent German residence. Kubernetes, kernel development and distributed storage internals are not part of this record.]

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
  "Ran a thirteen-host Linux platform across three hardware generations and several sites, from procurement to decommissioning",
  "Wrote the automation in Python and Go: build and rollout tooling, a sentinel ledger, and an alerting bridge that confirms delivery",
  "Gated every deployment in CI against the evaluated configuration, so a bad change failed a pipeline instead of a production host",
  "Operated the network layer end to end: nftables rules, a tailnet with no public listener, certificates from an own SSH CA",
  "Built observability: Gatus probes plus a ledger recording job status, generation age, disk and PSI pressure every 15 minutes",
  "Backed up to NAS targets with restic and verified restores rather than counting successful runs",
  "Handled storage, capacity and upgrades on hardware that spanned a decade of generations",
  "Documented every procedure as a runbook and every decision as a note, so the platform did not depend on memory",
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
#text(weight: "bold")[Linux] — systemd, networking, nftables, namespaces, storage and capacity management, boot and recovery \
#text(weight: "bold")[Software] — Python, Go, Shell, Nix; tooling that replaces manual operations \
#text(weight: "bold")[Automation] — declarative configuration, drift prevention, CI gates, reproducible rollback \
#text(weight: "bold")[Observability] — probes, structured ledgers, metric analysis, alert delivery confirmation \
#text(weight: "bold")[Security] — sops/age, SSH certificate authority, least-privilege network, encrypted secrets in git \
#text(weight: "bold")[Not held] — Kubernetes, kernel development, Ceph or distributed storage internals, upstream maintainership \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence (Niederlassungserlaubnis) · available worldwide remote
