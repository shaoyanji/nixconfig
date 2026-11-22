// ScorePlay — Senior Platform / SRE Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
ScorePlay\\
Platform team

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Platform / SRE Engineer]
#v(0.45cm)

Dear Maxime and the Platform team,

media platforms are storage businesses with a video player attached. Once an asset is in, it has to stay
retrievable, verifiable and affordable for years, and every shortcut at ingest shows up later as a migration. That
is the shape of problem I have worked on: I designed a content-addressed store for an append-only service, where
the same input always lands on the same identity, so deduplication and retention became properties of the design
rather than a cleanup task someone remembers to run.

The operational side is where I have the most practice. Thirteen Linux hosts described by one declaration, every
change through a gate that runs identically in CI and on the machine, every rollback a pointer to the previous
generation, and telemetry every fifteen minutes over job status, generation age, disk pressure and pressure stall
information — because on a storage platform the first warning is usually capacity, not latency. PSI and cgroups
let me tell I/O starvation apart from memory shortage instead of restarting something and hoping.

What I have not done, precisely: I have not operated a 15 PB multi-region estate, and I have not built BYOS
deployments into customer clouds. My scale is a fleet, single region, and I have never had to reason about
cross-region replication lag or egress economics at that size. Those are the problems where your team's judgment
lives, and I would be joining to learn them rather than to repeat what I already know.

What should transfer is the cost instinct and the automation habit: treat retention as a decision with a number
attached, measure capacity instead of assuming it, and put routine work behind a tool a colleague can run without
reading the source, so the team spends its hours on the hard incidents rather than the repetitive ones. Event-driven
pipelines are familiar territory too — ingest, normalise, publish, and make reruns idempotent when a source changes
shape.

I am based in Germany with permanent residence as a US citizen, so there is no sponsorship question for a remote
European role; German is C1 and English is native. I would welcome a conversation about what the 15 PB figure looks
like going forward — where it grows fastest, and what it costs to keep it honest.

Yours sincerely,
#v(0.5cm)
Matt Ji
