#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Platform engineering — declarative infrastructure, CI/CD, observability]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Platform engineer who treats infrastructure as a product with users, not as a pile of servers. Ran a thirteen-host fleet across three hardware generations as one declarative system: a module per service, a feature list per host, and a gate that checks modules and assertions before anything rolls out. Built the observability layer as well — probes, a 15-minute JSONL ledger, a Go alerting bridge that confirms delivery — because a platform nobody can see is a platform nobody can trust. Native English, German C1, US citizen with permanent German residence, based in Germany. Kubernetes, Terraform and AWS at platform scale are not part of this record.]

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
  "Built and ran a thirteen-host platform across three hardware generations and several sites, from procurement to decommissioning",
  "Described every service and host declaratively; one module per service, one feature list per host, no hand-edited state on any machine",
  "Gated rollout in CI: the same evaluated configuration was checked, built and deployed, so drift was a failed pipeline rather than a surprise at 3am",
  "Wrote the observability layer: Gatus probes, plus a sentinel ledger recording job status, generation age, disk and PSI pressure every 15 minutes",
  "Analysed that ledger in Go and Python and connected alerting to a Go bridge that only confirms delivery once the message actually arrives",
  "Secured the platform end to end: sops/age secrets, an own SSH certificate authority, services behind a tailnet with no public listener, nftables on the edge",
  "Backed up to NAS targets with restic and verified restores instead of counting successful backup runs",
  "Documented every procedure as a runbook so operational knowledge did not live in one person's head",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Owned the commercial side of 10 MW of solar PV assets and the IT administration of the company and its subsidiaries",
  "Built financial models over full asset lifetimes and turned operating data into decisions rather than reports",
  "Ran the software the company depended on, including the systems where plant data accumulated",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — a fleet that is checked before it exists", "since 2023", (
  "One flake describes hosts, services and user roles; one host registers once as a feature list, and option surface is what a gate pays for",
  "Health checks, a job ledger and an agent turn log run as services on the same platform they observe",
  "Publishing, deployment and rollback are tasks, never edits made on a host",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Platform] — declarative configuration, immutable hosts, module composition, drift prevention, rollback \
#text(weight: "bold")[CI/CD] — pipelines as the only path to production, gates on evaluated state, reproducible builds \
#text(weight: "bold")[Observability] — probes, structured ledgers, metric and log analysis, alert delivery confirmation \
#text(weight: "bold")[Languages] — Go, Python, Shell, Nix; C++ from research work \
#text(weight: "bold")[Operations] — Linux, systemd, networking, nftables, sops/age, SSH CA, restic with verified restores \
#text(weight: "bold")[Not held] — Kubernetes, Terraform/HCL, AWS platform ownership, multi-tenant platform at company scale \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence (Niederlassungserlaubnis), no sponsorship needed
