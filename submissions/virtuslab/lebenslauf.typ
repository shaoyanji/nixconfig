#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Nix and Linux systems engineering — flakes, module systems, reproducible operations]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Five years of operating a thirteen-host fleet as a single Nix flake: one module per service, a feature list per host, pinned inputs, and a gate that checks modules and assertions before anything rolls out. The design decisions that matter in Nix are the ones about boundaries — what belongs in a module, what a host may compose, what the gate has to prove — and this fleet was rebuilt around them. Underneath sits Linux as an instrument: systemd, cgroups and namespaces, PSI and disk pressure, nftables, a WireGuard mesh, an own certificate authority. Python and Go for the tooling. Not held: kernel internals, eBPF or perf profiling, C and Rust interop, Python performance engineering. Native English, German C1.]

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
  "Ran thirteen Linux hosts across three hardware generations from one flake, with no hand-edited state on any machine",
  "Composed the flake around the module system: a module per service, a feature list per host, and option surface treated as a cost the gate pays for",
  "Pinned every input and kept builds reproducible, so the same inputs produced the same system and rollback was a generation rather than a rebuild",
  "Gated rollout on the evaluated configuration, so a bad option failed a pipeline instead of a machine",
  "Used Linux as an instrument: systemd units, cgroups and namespaces, PSI and disk pressure, boot and initrd behaviour on real hardware",
  "Built the network boundary in code: nftables rules, a WireGuard mesh with no public listener, DNS, and an own certificate authority with short-lived certificates",
  "Wrote the tooling in Python and Go: rollout helpers, a sentinel ledger, and an alerting bridge that confirms delivery",
  "Kept the repository legible: docs generated from the same graph that drives navigation, runbooks for every procedure, tasks instead of manual steps",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially and ran the company's software and IT administration",
  "Built financial models and turned operating data into decisions for management",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — a fleet described once", "since 2023", (
  "A host registers once as a feature list; a task menu and a docs pipeline are generated from the same graph",
  "Health checks, a job ledger and an agent turn log run on the platform they observe",
  "Publishing, deployment and rollback are tasks, never edits made on a host",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Nix] — flakes, module composition, option design, pinned inputs, reproducible builds, generation rollback \
#text(weight: "bold")[Linux] — systemd, cgroups, namespaces, PSI and disk pressure, boot and recovery, nftables, WireGuard \
#text(weight: "bold")[Automation] — Python, Go, Shell; gates, tasks, generated docs, delivery-confirmed alerting \
#text(weight: "bold")[Security] — own certificate authority, short-lived certificates, sops and age per host \
#text(weight: "bold")[Not held] — kernel internals or patching, eBPF, perf, valgrind, C/Rust interop, Python performance engineering \
#text(weight: "bold")[Languages and status] — English native, German C1 · German resident with permanent residence · open to B2B
