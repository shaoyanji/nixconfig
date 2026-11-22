#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Linux systems engineering — kernel configuration, hermetic builds, fleet operations]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux systems engineer, not a kernel developer. Five years as the sole operator of a thirteen-host fleet taught the operating half of the kernel: boot and initrd, module loading, cgroups and namespaces, resource limits that surface as real failures, and kernel updates applied across a fleet without breaking it. Kernel configuration is code here, not a menu, and every build is hermetic — pinned inputs, the same result on every machine, rollback by generation. What is absent is the other half: no kernel patches, no upstream work, no driver development, no eBPF programs, no maintainership. Native English, German C1, US citizen with permanent German residence.]

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
  "Ran a thirteen-host Linux fleet across three hardware generations, including boot, initrd, module loading and recovery on machines that had to come back without a console",
  "Configured the kernel as code: options and modules declared in NixOS modules, reviewed in git, applied by rebuild rather than edited on a host",
  "Kept builds hermetic: pinned inputs, identical results across machines, every generation rollback-able to a known-good kernel",
  "Ran kernel and CVE updates as routine fleet work — rebuild, verify the evaluated state, roll out, keep the previous generation bootable",
  "Used cgroups and namespaces to bound services, and debugged the cases where a limit, a device or a module surfaced as an outage",
  "Built observability for the parts of the system userspace cannot see: kernel messages, OOM events, disk and PSI pressure at 15-minute resolution",
  "Automated operations in Python and Go: rollout tooling, a sentinel ledger, an alerting bridge that confirms delivery",
  "Documented recovery procedures as runbooks so a failed boot did not depend on one person's memory",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Owned the commercial side of 10 MW of solar PV assets and the IT administration of the company and its subsidiaries",
  "Built financial models and ran the software the business depended on",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Instrumented laboratory equipment through C++ applications and analysed measurement series in Python",
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
))

#section("Projects")
#entry("nixconfig — a fleet built from pinned inputs", "since 2023", (
  "One flake describes hosts, services and user roles; kernel and boot configuration included, not appended by hand",
  "A gate checks modules and assertions before rollout, so a bad kernel option fails a pipeline instead of a machine",
  "Reproducibility is the default: same inputs, same system, generations kept for rollback",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Kernel, operated] — configuration, modules, boot and initrd, recovery, cgroups, namespaces, resource limits, kernel messages and OOM analysis \
#text(weight: "bold")[Build and supply chain] — hermetic reproducible builds, pinned inputs, generation rollback, CVE and kernel updates across a fleet \
#text(weight: "bold")[Linux platform] — systemd, networking, nftables, storage and capacity, SSH certificate authority \
#text(weight: "bold")[Software] — Python, Go, Shell, Nix, C++ from research work \
#text(weight: "bold")[Not held] — kernel patch development, upstream contribution, driver or subsystem work, eBPF, silicon partner engagement, maintainership or team leadership \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence (Niederlassungserlaubnis) · remote from Germany
