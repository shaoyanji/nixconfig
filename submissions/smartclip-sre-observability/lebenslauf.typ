#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Site reliability, Linux internals and self-built telemetry]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Linux systems administrator with ten years in operations, automation and security, including a research post at Fraunhofer ISE. Ran thirteen servers across three hardware generations as one declarative NixOS fleet: every service a module, every host a feature list, every change a commit with a gate and a rollback. Built the telemetry instead of buying it — a sentinel job writing job status, generation age, disk and PSI pressure to a JSONL ledger every 15 minutes, Gatus endpoint checks, and a Go bridge that confirms alert delivery before considering an alarm raised. Works close to the kernel: cgroup limits per service, PSI as a signal, systemd hardening, nftables, own SSH CA with short-lived certificates. Prometheus, Grafana and Alertmanager are not part of this experience. US citizen with permanent German residence; no sponsorship needed. Remote-first, occasional travel.]

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
  "Operated thirteen NixOS hosts across three hardware generations and several sites, from procurement through installation to steady state",
  "Described platform and services in one flake: every service a module, every host a feature list, every change a commit — no hand-edited machines",
  "Gated CI on the same state that gets deployed, kept every state as a generation, and rolled back by pointing at the previous one",
  "Wrote the observability: a sentinel job recording job status, generation age, disk and PSI pressure to a JSONL ledger every 15 minutes, plus Gatus endpoint checks",
  "Built a Go bridge that acknowledges an alert only once delivery is confirmed, so notification failure is visible rather than silent",
  "Ran services under systemd with cgroup memory and CPU limits, watched PSI for pressure before symptoms, and kept services off any public socket",
  "Wrote firewall and network policy as code in nftables, with DNS and a WireGuard tailnet; issuance ran through an own SSH CA with short-lived certificates",
  "Kept secrets in sops and age out of repositories and out of plaintext on disk; moved TLS onto an own CA rather than long-lived keys",
  "Served bare-metal installs over PXE from a local ISO archive, so a rebuild never depended on an outside package source",
  "Backed up with restic to NAS targets and validated restores rather than counting backup runs",
  "Automated Forgejo repository and metadata operations through task verbs hitting its REST API, with the token read from sops",
  "Wrote the runbooks, so operating the fleet was not knowledge held in one head",
))
#entry("O3 Energy — Asset Manager", "2016 – 2020", (
  "Owned software and IT administration for the company and its subsidiaries",
  "Built financial models and managed 10 MW of solar PV assets",
))
#entry("Fraunhofer ISE — Research Assistant", "2012", (
  "Researched heliostat inaccuracies using interferometry at the Institute for Solar Energy Systems",
  "Wrote C++ application software for lab instrument control and Python tooling for analysis and 3D geometry",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8 (German scale); neural-network modelling",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Selected work")
#entry("nixconfig — a declarative fleet with gates", "since 2023", (
  "Module per service, feature list per host; a gate per host checks modules and assertions before anything deploys",
  "Sentinel ledger over job status, generation age, disk and PSI, with a Go alerting bridge that confirms delivery",
  "Services behind a tailnet with no public socket; certificates and keys issued by the own CA",
))
#entry("Self-hosted AI platform on owned hardware", "2024 – 2025", (
  "Ran model server, router and web front end on own machines with no cloud dependency and no outbound connection in operation",
  "Wrote the router in Go and isolated each model lane with its own limits and its own access path",
))

#section("Skills")
#text(weight: "bold")[Linux internals] — systemd units and hardening, cgroup memory and CPU limits, PSI, namespaces, nftables, PXE installs \
#text(weight: "bold")[Infrastructure as code] — Nix and NixOS, modules per service, generations and rollback, gates in CI \
#text(weight: "bold")[Telemetry] — JSONL ledger with 15-minute cadence, Gatus checks, Go alerting with delivery confirmation, restic with validated restores \
#text(weight: "bold")[Security in delivery] — sops and age, own SSH CA, short-lived certificates, secrets out of repositories, no public sockets \
#text(weight: "bold")[Automation and code] — Shell, Python, Go; git as single source; Forgejo REST automation \
#text(weight: "bold")[Not present] — Prometheus, Grafana, Alertmanager, formal SLO and error-budget programmes, Kubernetes, AWS and GCP \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence · remote-first, travel available
