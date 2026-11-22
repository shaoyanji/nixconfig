// Makersite — DevOps / Platform Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Makersite GmbH\\
Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: DevOps / Platform Engineer]
#v(0.45cm)

Dear Makersite team,

a supply chain twin is only as good as the data feeding it, and its users only trust it as far as they can trace a number
back to a source. That is the problem I have spent most of my working life on from two directions: ten years building
yield, cost and reporting models for a solar portfolio above USD 100M, where every figure had to survive a bank's
question, and five years running the Linux platform those numbers were produced on.

The data side is pipelines and reconciliation. Three measurement feeds reduced to one auditable series, missing readings
treated as an explicit error budget rather than a quiet gap, and a rule that a reported number has exactly one origin.
Python for the pipelines, SQL where the answer is a query, tests against canonical data rather than mocks of it. I have
not operated Postgres in production — my relational work is modelling and reporting rather than database operation — and
I would rather say that now than have it surface in a design review.

The platform side is built so that other people do not have to be careful in the right way. Thirteen Linux hosts declared
as one repository, every input pinned, one gate that runs identically in CI and on the machine, so a green build is a claim
about a real host. Rebuilds come from a shared binary cache and remote builders, every generation keeps its parent so a
rollback is a pointer, and a sentinel writes job status, generation age, disk and PSI every fifteen minutes and pages on
any state short of ok and on silence. Developer enablement is the part I care about most: one task surface with named
arguments, validation and dry-run plans, so the answer to a routine request is a command and not a briefing.

Two honest boundaries besides Postgres: I have not run Terraform or a managed cloud platform, and there is no ISO
certification audit in my history. My infrastructure is declared NixOS on rented metal, which answers the same questions
with different machinery. What transfers to an audit is the discipline underneath it — access that expires instead of
accumulating, changes that are reviewable in a diff, secrets encrypted per host, and the recovery question asked in
advance rather than during the incident.

Why Makersite rather than another platform role: product lifecycle data is where a modelling mistake becomes a
sustainability claim a customer repeats to their own customers. I spent years on the side of that problem where the number
had to be defensible, and I would like to build the platform that keeps it that way.

I live in Germany on permanent residence as a US citizen, so the residency requirement is met without sponsorship, and I
am set up for remote-first work with German at C1 and English native.

One question I would ask early: when a customer disputes a figure in a twin, how far back can you trace it today — to the
ingesting job, to the source record, or only to the dataset version? The answer usually decides what the next quarter of
platform work has to be.

Kind regards,
#v(0.5cm)
Matt Ji
