// STACKIT / Schwarz Digits — (Senior) SRE, Control Plane. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
STACKIT / Schwarz Digits\\
Bad Friedrichshall, Baden-Württemberg

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: (Senior) Site Reliability Engineer, STACKIT Control Plane — GT2321]
#v(0.45cm)

Dear Hiring Team,

a control plane is judged by what happens on its worst day: whether the state of the system is known before
anyone touches it, whether a change can be traced to a decision, and whether the way back was designed rather
than improvised. That is how I have run systems for five years, at a smaller scale and with the same rules.

Concretely: thirteen Linux hosts described by one declaration, every change gated by a check that runs
identically in CI and on the machine, every rollback a pointer to the previous generation, so no rollout ever
stopped half-applied. A telemetry loop records job status, generation age, disk pressure and pressure stall
information every fifteen minutes and reports any state short of ok — blindness counts as a fault, not as a
quiet period. When something breaks I separate memory pressure from I/O and CPU contention with cgroups and PSI,
then trace the cause with journald, tcpdump and strace, and write it down so the next incident is cheaper.

What I have not done is equally specific: I have not operated a cloud control plane and have not administered a
Kubernetes cluster in production. I know what a control plane has to guarantee and I have built the smaller
version of that guarantee on my own fleet, but scale, multi-tenancy and upgrade paths across cluster versions
are work I would be learning here rather than repeating. If the role needs someone who has done exactly that on
day one, I am not that candidate. If it needs someone who brings the operating discipline and the automation
habit, and will learn the platform on top of it, that is the case I am making.

On the practical side: I live in Baden-Württemberg, roughly two hours from Bad Friedrichshall, and on-site days
in the region are a normal part of my week rather than a negotiation. I am a US citizen with German permanent
residence, so there is no sponsorship question. My salary expectation is 95,000 to 105,000 EUR, inside the
advertised range. German is C1 and English is native.

I would welcome a technical conversation about where the control plane's reliability work actually sits today.

Yours sincerely,
#v(0.5cm)
Matt Ji
