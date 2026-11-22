#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Platform engineering, Linux operations and automation]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux systems engineer with ten years in operations and automation, including a research station at Fraunhofer ISE and four years steering solar assets. Ran thirteen servers across three hardware generations as declared infrastructure: every service a module, every host a feature list, every change a commit. The CI gate and the rollout gate are the same gate, and every state is kept as a generation that can be rolled back. Observability means a sentinel ledger every 15 minutes on job status, generation age, disk and memory pressure, plus endpoint checks and alerts that are only marked delivered when they arrive. Secrets live in sops and age; host keys come from an own certificate authority with short-lived certificates. Writes Go and Python when shell is not enough. No production AWS, Terraform, Spacelift, Docker or GitHub Actions. German C1, English native.]

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
#entry("Bountystash — Founder", "2020 – 2025", (
  "Ran thirteen NixOS hosts across three hardware generations and several sites, including procurement, installation and commissioning",
  "Declared the whole estate in a flake: every service a module, every host a feature list, every change a commit",
  "Made the CI gate and the rollout gate the same check, so an unverified change could not reach a machine",
  "Kept every state as a generation and rolled back to the previous one rather than repairing a fault forward",
  "Wrote a sentinel job recording job status, generation age, disk and PSI pressure to a JSONL ledger every 15 minutes",
  "Checked endpoints with Gatus and tied alerting to a Go bridge that confirms delivery, not intent",
  "Backed up with restic to a NAS and performed restores instead of inspecting backup jobs",
  "Managed secrets with sops and age and host keys through an own CA with short-lived certificates",
  "Built services in Go and Python, including a router for model requests and operational tooling",
  "Documented every procedure as a runbook and a repository task, so operations did not depend on one person",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Steered 10 MW of solar PV assets and built the financial models behind them",
  "Ran software and IT administration for the company and its subsidiaries",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Researched heliostat inaccuracies with interferometry at the Institute for Solar Energy Systems",
  "Wrote C++ application software for laboratory instruments and Python tooling for analysis and 3D geometry",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8 (German scale); modelling with neural networks",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Projects")
#entry("nixconfig", "since 2023", (
  "Declared the fleet in one flake with a module per service and a gate per host, so the option surface stays a check instead of copy-paste",
  "Added a sentinel ledger of job status, generation age, disk and PSI pressure, plus a Go bridge with delivery confirmation",
  "Ran a self-hosted AI platform on own hardware: model server, Go router, access only over the tailnet",
))

#section("Skills")
#text(weight: "bold")[Systems] — NixOS and Debian-family, systemd, resource limits, boot configuration, reproducible installs \
#text(weight: "bold")[Networking] — nftables, DNS, WireGuard, segmentation, packet-level debugging with tcpdump and ss \
#text(weight: "bold")[Reliability] — JSONL ledger, Gatus, delivery confirmation, restic, tested restores, rollback per generation \
#text(weight: "bold")[Security] — sops, age, own SSH certificate authority, short-lived certificates, no exposed service \
#text(weight: "bold")[Automation] — shell, Python, Go, Git as the only source, CI gates \
#text(weight: "bold")[Not present] — AWS, Terraform, Spacelift, Docker, Kubernetes, GitHub Actions, Postgres/ClickHouse at scale \
#text(weight: "bold")[Languages] — German C1, English native
