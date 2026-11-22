#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.6cm, bottom: 1.6cm, left: 1.9cm, right: 1.9cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 11.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.70em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Declarative infrastructure, Go services, immutable data]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9.5pt)[Five years building and running production systems alone: a Go service that turns a request into an immutable, content-addressed document, and thirteen NixOS hosts declared in one flake. The declarative half is where the functional claim sits — a flake is a function from pinned inputs to a system, modules compose, options are typed, evaluation is lazy, and the expression CI evaluates is the expression the machine builds. Before that, four years of valuation and risk models for a solar portfolio above \$100M, where a wrong number reached a bank. No Haskell, Scala, OCaml, F\# or Clojure in production, and no property-based testing; both are named in the letter, not implied.]

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
#entry("Bountystash — Founder and engineer", "2020 – 2025", (
  "Built a Go service that records a request as an immutable, content-addressed specification; state is an append-only event log, so a job replays a month later and two people can agree on what was asked",
  "One binary serves HTML, JSON and a terminal UI; the specification is addressed by its own hash, not by a row someone edited",
  "Designed an immutable templating language in which a template cannot express a script, so an injection has nowhere to live",
  "Declared thirteen NixOS hosts in one flake: each host a feature list, each service a module, secrets encrypted per host, certificates from the fleet's own SSH certificate authority",
  "Made every host rebuildable from the commit; a broken definition fails the module gate in CI before it reaches a machine, and a generation rolls back in one command",
  "Wrote the telemetry the fleet reports on: job status, generation age, disk and PSI pressure every fifteen minutes, with alerting that confirms delivery",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Built yield and valuation models for a solar portfolio above \$100M that passed bank audits",
  "Headed asset management of 10 MW of PV plants, scoped due diligence on O&M projects, managed software and IT administration across subsidiaries",
))
#entry("Fraunhofer ISE — Research assistant", "2012", (
  "Measured heliostat imperfections with interferometry: C++ for the instrument, Python and Mathematica for analysis and 3D geometry",
))

#section("Selected projects")
#entry("nixconfig — thirteen hosts from one repository", "since 2023", (
  "Feature lists and modules instead of per-host install notes; pinned inputs, reproducible builds, rollback by generation",
  "Gates evaluate the same configuration the machine will build; secrets and certificates come from the same place",
))
#entry("fibtransponder — bounded work per step", "2026", (
  "A Fibonacci-radix state machine that streams a bitstream with bounded work per step; the corpus benchmark falsified the first detector design, so the shipped claim is smaller and the counter-example stays in the repository",
))
#entry("risk-calc — geometry as a risk model", "2026", (
  "Green's theorem over stochastic polygons: a Go fuzzer generates shapes, a Nushell and Awk pipeline drives the calculation, a Nix dev shell pins the toolchain",
))
#entry("kev-time, kelly-svg — vulnerability data as a patch order", "2026", (
  "CISA's exploited-vulnerability catalogue as a time series and as effort clusters, both static SVG and plain HTML, readable on a phone during an incident",
))

#section("How I work")
#text(size: 10pt)[
  - Write the measurement before the claim; when it falsifies the design, the claim gets smaller. \
  - Make the state a value: if it replays from a log or rebuilds from a commit, it does not need to be remembered. \
  - Name the gap first; a missing year of Haskell is cheaper to say in a letter than to discover in a review.
]

#section("Education")
#entry("University of Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Grade 1.8; neural networks, energy economics, technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Languages] — Go, Python, C++, C, Shell, Nushell, Awk, Erlang, Lua, Java, Kotlin, Nim \
#text(weight: "bold")[Declarative systems] — Nix, Nix flakes, NixOS modules and typed options, SOPS and age, SSH certificate authority, systemd, CI gates \
#text(weight: "bold")[Backend] — PostgreSQL, Redis, gRPC, REST, Kafka; append-only event logs, content addressing \
#text(weight: "bold")[Domain] — asset valuation, bank audit reporting, energy trading risk, options and hedging, gas storage, KEV and CVSS \
#text(weight: "bold")[Not in my record] — Haskell, Scala, OCaml, F\#, Clojure; Daml or Canton; blockchain systems; capital-markets market infrastructure; property-based testing \
#text(weight: "bold")[Status] — US citizen with German permanent residence · remote from CET with US-East overlap · available 2026-12-01
