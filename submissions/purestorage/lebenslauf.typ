#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux storage and platform engineering — performance, capacity, reproducibility]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Engineer who has owned storage as an operational problem: capacity planned from measured pressure, restores verified rather than backup jobs counted, disk and PSI behaviour wired into telemetry so a slow system has a cause and not just a symptom. Ran a thirteen-host Linux fleet alone for five years, wrote the automation in Python and Go, and documented every procedure so the knowledge survived the person. Also spent four years on the commercial side of solar assets, building the financial models behind investment decisions — useful for a total-cost conversation, not a substitute for sales experience. Not held: French, production Kubernetes, Portworx or enterprise arrays, pre-sales or quota carrying. Native English, German C1.]

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
  "Owned storage and capacity for a thirteen-host platform: what to keep, where, how much, and what happens when it fills",
  "Backed up to NAS targets with restic and verified restores instead of counting successful runs",
  "Measured the system rather than guessing: disk usage, PSI pressure and job status recorded every 15 minutes and read when something slowed down",
  "Built hosts and services hermetically from pinned inputs, so a rebuild reproduced the same system and rollback was a generation, not a rebuild",
  "Designed the network boundary: a WireGuard mesh with no public listener, nftables rules at the edge, services segmented by purpose",
  "Wrote the tooling in Python and Go and the documentation alongside it — runbooks for every procedure, notes for every decision",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Managed 10 MW of solar PV assets commercially, including financial models over full asset lifetimes",
  "Ran the company's software and IT administration, including the systems where plant and financial data lived",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — infrastructure with a review trail", "since 2023", (
  "One flake describes hosts, services and user roles; every change is a reviewed commit",
  "A gate checks modules and assertions before rollout, so an unsafe change fails a pipeline rather than a host",
  "Publishing, deployment and rollback are tasks; no host carries hand-edited state",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Storage] — capacity planning from measured pressure, NAS targets, restic with verified restores, filesystem and disk health \
#text(weight: "bold")[Linux performance] — PSI, OOM, disk and memory pressure, systemd, cgroups and namespaces \
#text(weight: "bold")[Architecture] — network segmentation, WireGuard mesh, nftables, least-privilege access, hermetic builds \
#text(weight: "bold")[Communication] — runbooks, decision notes, technical writing, public repository \
#text(weight: "bold")[Economics] — financial models, yield and cost analysis, total-cost reasoning from four years of asset management \
#text(weight: "bold")[Not held] — French, production Kubernetes, Portworx or enterprise storage arrays, pre-sales, quota carrying \
#text(weight: "bold")[Languages and status] — English native, German C1, no French · German resident with permanent residence
