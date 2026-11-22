// Enpal — Staff Platform Engineer (f/m/d). English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Enpal\\
Platform Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff Platform Engineer (f/m/d)]
#v(0.45cm)

Dear Platform Engineering team,

Enpal.One+ is solving a problem I have already lived from the other side of the meter. For four years I ran asset management
for a solar portfolio above USD 100M, and the hardest part was never the panels — it was trusting the telemetry. A string
that stops reporting still looks green on a dashboard that only counts what arrives, and the difference between those two
states is a year of yield and an argument with a bank. When your platform connects thousands of systems and optimises what
they buy and feed in, that same question is the product.

So the domain half of this role is not a metaphor for me. Yield and valuation models that satisfied auditors, O&M work that
followed from a deviation rather than a calendar, due diligence on projects as cover for project managers, and reporting to
banks and investors. I learned there that a number nobody can audit is a number nobody will lend against, and that a
regulated environment does not slow good engineering down — it forces the decisions you would have wanted to make anyway.

The platform half is what I have built since. Thirteen Linux hosts declared in one repository, hosts as feature lists and
services as modules, every input pinned, and every change through a gate that runs identically in CI and on the machine, so
a failed check leaves the previous generation serving and rollback is a pointer rather than a repair at 03:00. A
fifteen-minute ledger over job status, generation age, disk pressure and PSI pages when a service goes quiet. Operations
live behind one entry surface with named arguments and validation, so a developer can act without reading the
implementation or waiting for me, and the documentation is generated from the same source as the configuration so it cannot
drift. That last part is the platform-as-product argument in practice: the measure is whether someone ships without asking.

Where I would need to grow, plainly: I have not operated production Kubernetes, I have not written Terraform or Helm, and my
cloud experience is not Azure. My orchestration is systemd and my infrastructure as code is a flake, so the concepts —
declarative state, gated rollout, standardised pipelines, observability as a habit — are familiar while the tooling is not.
For a staff role that sets standards across teams, that gap matters, and I would rather spend the first months learning your
stack properly than pretend a flake is a Terraform module.

What I would bring on day one is the judgment about what to standardise and what to leave alone, plus the mentoring habit:
the best change I ever made to a team was a check that stopped a whole class of incident, and the second best was the
documentation that let someone else find it. I am based in Germany with permanent residence as a US citizen, German is C1
and English native, and Berlin hybrid works for me.

I would enjoy hearing which platform decision is currently hardest — build versus buy, or the boundaries between
self-service and guardrails.

Yours sincerely,
#v(0.5cm)
Matt Ji
