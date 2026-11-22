#set document(title: "Matt Ji — CV", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 1.4cm, bottom: 1.4cm, left: 1.7cm, right: 1.7cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 9.5pt, fill: rgb("#111827"), lang: "en", hyphenate: false)
#set par(leading: 0.5em, justify: true)

#align(center)[
  #text(size: 19pt, weight: "bold")[Matt Ji]
  #v(1pt)
  #text(size: 9pt, fill: rgb("#4b5563"))[Platform engineering — Linux, model serving, declarative operations]
  #v(2pt)
  #text(size: 8.5pt, fill: rgb("#374151"))[Am Burgerhof 4, 79261 Gutach im Breisgau, Germany • matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji]
]
#v(6pt)
#line(length: 100%, stroke: 0.5pt + rgb("#d1d5db"))

#v(6pt)
#text(size: 9pt)[Platform engineer who runs a modest GenAI stack as production infrastructure: speech synthesis, speech recognition and image generation served behind OpenAI-compatible endpoints, with a router, on-demand model loading and a guard that yields to other workloads when resources are tight. Underneath sits a thirteen-host declarative Linux fleet — hermetic builds, health-gated rollouts, rollback by generation, telemetry every 15 minutes. Python and Go for the tooling. What is not in this record: Kubernetes, vLLM at fleet scale, GPU cluster scheduling, payments experience. Native English, German C1, US citizen with permanent German residence, open to relocating to Amsterdam or Madrid.]

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
  "Ran a thirteen-host Linux platform across three hardware generations, from procurement to decommissioning",
  "Served models behind OpenAI-compatible endpoints: Qwen3-TTS for speech, Parakeet for transcription, Qwen-Image for generation",
  "Built the serving layer around the models: a router, on-demand loading, and a guard that yields compute to other workloads instead of starving them",
  "Kept transport honest: raw bytes for audio rather than multipart, because the encoding overhead showed up in latency",
  "Described hosts and services declaratively, gated rollout on the evaluated configuration, and kept every generation rollback-able",
  "Built telemetry for the platform and the workloads on it: Gatus probes plus a 15-minute ledger of job status, disk and PSI pressure",
  "Wrote the tooling in Python and Go, including an alerting bridge that confirms delivery instead of assuming it",
  "Bound services with cgroups and namespaces, and debugged the cases where a limit surfaced as an outage",
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
#entry("nixconfig — declarative fleet with workloads on top", "since 2023", (
  "One flake describes hosts, services and roles; the model-serving stack is one service among them, not a special case",
  "A gate checks modules and assertions before rollout, so a configuration error fails a pipeline rather than a machine",
  "Health checks, a job ledger and an agent turn log run on the platform they observe",
))

#section("Education")
#entry("Albert-Ludwigs-Universität Freiburg — M.Sc. Renewable Energy Management", "2011 – 2014", ("Final grade 1.8; modelling with neural networks, energy economics and technology assessment",))
#entry("Colorado School of Mines — B.Sc. Petroleum Engineering", "2006 – 2010", ("GPA 3.2",))

#section("Skills")
#text(weight: "bold")[Model serving] — OpenAI-compatible endpoints, router, on-demand loading, resource guards, latency measurement \
#text(weight: "bold")[Linux platform] — systemd, cgroups and namespaces, nftables, networking, storage, SSH certificate authority \
#text(weight: "bold")[Delivery] — hermetic builds, pinned inputs, health-gated rollout, rollback by generation \
#text(weight: "bold")[Observability] — probes, structured ledgers, PSI and disk pressure, alert delivery confirmation \
#text(weight: "bold")[Software] — Python, Go, Shell, Nix; tooling that replaces manual operations \
#text(weight: "bold")[Not held] — Kubernetes, vLLM at fleet scale, GPU cluster scheduling and MIG, payments domain, Argo CD \
#text(weight: "bold")[Languages and status] — English native, German C1 · US citizen with permanent German residence · willing to relocate to Amsterdam or Madrid
