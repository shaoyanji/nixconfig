// trawa — Senior Platform Engineer. English letter, one page.
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
trawa #linebreak() Platform Team, Berlin HQ

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Platform Engineer]
#v(0.4cm)

Dear trawa team,

most platform engineers have never had to price a megawatt. I have, and that is the least common thing about this application:
six years of PPA models, weather-derivative hedges, gas storage and swing risk before five years of building the infrastructure
those models ran on. So when your product promises a company 30% off its electricity bill, I understand what has to be true for
that number to survive contact with a settlement period, a forecast error and a market that moves while the job is running.

The platform half I would bring as practice. My estate is declared rather than clicked: thirteen hosts from one repository with
pinned inputs and hermetic builds, secrets encrypted per host with sops and age, SSH credentials issued as certificates that
expire rather than keys that live in backups, default-deny between machines, and one gate that runs identically on a laptop, in
CI and on the host it is about to change. Delivery goes through a canary before anything that matters, rollback is a pointer,
and the reliability loop writes job state, generation age, disk and pressure every fifteen minutes and pages on a bad state and
on silence — the second alert matters more, because a monitor that dies quietly looks like a system with nothing to report.

Your stack is not mine and I will not pretend otherwise: my infrastructure is Nix on rented metal rather than Terraform on AWS,
my observability is a self-built ledger and gatus rather than Dash0 and Sentry, and my services are Go and Python rather than
TypeScript. What transfers is the part that takes longest to learn — knowing which exceptions deserve to exist, writing the
reason next to them, and making the safe path the short one so nobody has to be persuaded to take it. Terraform on AWS is a
syntax I have not used; the judgement about what to declare and why is not.

What I would want to change in the first months is what your 90-day goals describe: find the friction, fix the largest piece and
carry it from design to rollout. My version of that instinct is that a platform's adoption is a design property rather than a
communication problem, and the way to find friction is to watch where engineers go around the tooling rather than ask them.

One practical point: I am based near Freiburg, so a Berlin office most of the week is a relocation question rather than a
commute, and I would rather say that now than at offer stage.

One question I would ask early: when a team wants a new capability, how do you currently decide whether the platform should build
it, buy it, or leave it to them? That decision is where a platform either compounds or turns into a queue.

Kind regards,
#v(0.45cm)
Matt Ji
