#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Infrastructure engineering — bare-metal Linux, least privilege, telemetry]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Infrastructure engineer who kept thirteen bare-metal Linux hosts running for five years with no cloud to fall back on and no team to escalate to. Access was a short-lived certificate from an own CA, never a shared key. Secrets were encrypted per host with sops and age. Every service sat behind a WireGuard mesh with no public listener, with nftables at the edge. Telemetry closed the loop: a ledger every fifteen minutes, probes, and an alerting bridge in Go that confirms delivery. Rollback was a task, restores were verified, and runbooks meant a failure at night did not depend on memory. Native English, German C1, US citizen with permanent German residence. Not held: Kubernetes and cloud infrastructure, company-scale on-call rotation, crypto exchange operations.]

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
  "Ran thirteen bare-metal Linux hosts across three hardware generations, from procurement and PXE installation to decommissioning",
  "Issued access as short-lived SSH certificates from an own certificate authority, so no long-lived key was ever shared",
  "Encrypted secrets per host with sops and age, keeping keys separate from the ciphertext and the ciphertext in git",
  "Put every service behind a WireGuard mesh with no public listener and wrote the nftables boundary rules at the edge",
  "Closed the telemetry loop: Gatus probes plus a ledger every 15 minutes recording job status, generation age, disk and PSI pressure",
  "Confirmed alert delivery through a Go bridge rather than assuming it, and treated an unconfirmed alert as no alert",
  "Kept incident recovery boring: rollout gated on the evaluated configuration, rollback by generation, restores verified with restic",
  "Documented every procedure as a runbook and every decision as a note, so a 3am failure did not depend on memory",
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
#entry("nixconfig — a fleet that is reviewed before it runs", "since 2023", (
  "One flake describes hosts, services and user roles; every change is a reviewed commit",
  "A gate checks modules and assertions before rollout, so an unsafe change fails a pipeline rather than a host",
  "Publishing, deployment and rollback are tasks; no host carries hand-edited state",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Bare metal] — provisioning, PXE, boot and recovery, storage and capacity, hardware generations \
#text(weight: "bold")[Least privilege] — SSH certificate authority, short-lived credentials, per-host key separation \
#text(weight: "bold")[Secrets] — sops and age, encrypted in git, keys held apart from ciphertext \
#text(weight: "bold")[Network] — WireGuard mesh, no public listeners, nftables boundaries, DNS, segmentation \
#text(weight: "bold")[Telemetry] — probes, 15-minute ledger, PSI and disk pressure, delivery-confirmed alerting \
#text(weight: "bold")[Resilience] — gated rollout, rollback by generation, verified restores, runbooks \
#text(weight: "bold")[Not held] — Kubernetes, cloud infrastructure, company-scale on-call rotation, crypto exchange operations \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence
