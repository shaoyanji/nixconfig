#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Platform engineering for energy — Linux infrastructure, telemetry, Go and Python automation]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Two careers that rarely meet. Four years managing solar PV assets commercially — financial models, operating data, the numbers behind an energy business — then five years operating a thirteen-host Linux fleet as one declarative system, with telemetry, automated rollouts and Python and Go tooling written to remove the manual step. The energy side knows what the platform is for; the platform side knows how to keep it running and how to prove it. Not held: AWS at depth, Terraform, distributed services at company scale, eight years of platform work. Native English, German C1, US citizen with permanent German residence, open to relocating to Berlin.]

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
  "Owned infrastructure, shared tooling and developer experience for every service on it — the same remit a platform team has, at the smallest possible headcount",
  "Gated every deployment in CI against the evaluated configuration, so a bad change failed a pipeline instead of a customer-facing host",
  "Built the observability layer: Gatus probes plus a ledger recording job status, generation age, disk and PSI pressure every 15 minutes",
  "Wrote the automation in Python and Go: rollout tooling, ledger analysis, and an alerting bridge that confirms delivery",
  "Treated cost and capacity as engineering inputs: small hosts, measured pressure, upgrades planned from data rather than gut feel",
  "Secured the platform end to end: sops/age secrets, an own SSH certificate authority, services behind a tailnet with no public listener, nftables on the edge",
  "Verified restores with restic instead of counting backup runs",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially: financial models over full asset lifetimes, yield and cost analysis, reporting to management",
  "Turned operating data into decisions — performance against plan, deviations, and what they meant for the asset",
  "Ran the company's software and IT administration, including the systems where plant data accumulated",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — declarative fleet, checked before it exists", "since 2023", (
  "One flake describes hosts, services and user roles; a host registers once as a feature list and a gate pays for the option surface",
  "Health checks, a job ledger and an agent turn log run on the platform they observe",
  "Publishing, deployment and rollback are tasks; no host is edited by hand",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Energy] — commercial management of 10 MW solar PV, financial models, yield and cost analysis, operating-data reporting \
#text(weight: "bold")[Platform] — declarative configuration, CI gates, health-checked rollout, rollback by generation, developer tooling \
#text(weight: "bold")[Observability] — probes, structured ledgers, PSI and disk pressure, alert delivery confirmation \
#text(weight: "bold")[Linux] — systemd, cgroups and namespaces, networking, nftables, storage, SSH certificate authority \
#text(weight: "bold")[Software] — Python, Go, Shell, Nix; tooling that replaces manual operations \
#text(weight: "bold")[Not held] — AWS at depth, Terraform/HCL, distributed services at company scale, eight years of platform work \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence · willing to relocate to Berlin
