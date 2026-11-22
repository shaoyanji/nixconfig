// Black Forest Labs — MTS, Infrastructure Security. English letter, one page.
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
Black Forest Labs\\
Infrastructure

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Member of Technical Staff, Infrastructure Security]
#v(0.4cm)

Dear Black Forest Labs team,

the hardest security question in a research lab is not whether a boundary exists, but whether a researcher with a real
deadline will route around it. I have spent five years building the version where the safe path is also the short one:
thirteen Linux hosts declared as one repository, access issued rather than stored, workloads isolated by construction, and
one gate that runs identically in CI and on the machine.

Identity first, because that is where infrastructure drift hides. A fleet certificate authority mints short-lived SSH
credentials, so a permission exists for a purpose and expires. Secrets are encrypted per host with sops and age, so losing
one machine yields nothing reusable against another. The network defaults to deny. Nothing standing is the design goal,
not an audit finding cleared later.

Isolation is the part I would most want to work on with your infrastructure teams. I built a microVM canary for my own
automation because I did not trust it: capped CPU and memory, a read-only host mount, no route off the tailnet, so a bad
runbook runs where it cannot damage anything. Making that useful rather than merely safe meant deciding what a persistent
filesystem must guarantee and what a suspended instance remembers. At your scale the same questions arrive with GPU
clusters and model artifacts attached, and I would expect my first months to be spent reading your systems rather than
recommending changes to them.

Supply chain and detection are the other half. Every input is pinned and every output content-addressed, so the artefact
that runs is the artefact that was built; every generation records its parent, so rollback is a pointer. Detection assumes
silence is failure: job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and
when a service stops reporting.

On agents, since your posting asks for a clear-eyed view: a model with shell access is a new class of principal, it can be
prompt-injected by the data it reads, and the only reliable defence I have found is that the gate decides whether output
counts, not the model's confidence.

What I have not done, plainly: no cloud security at your scale, no Kubernetes, no GPU cluster, no multi-tenant serving, and
no security title behind me. My estate is thirteen machines and one GPU, secured as described above. What I would bring is
the habit the role wants most — dig into an unfamiliar system until it explains itself, then ship the change and operate it.

On location: I live in Gutach im Breisgau, twenty minutes from the Freiburg lab, so the office cadence your posting
describes is easy for me. The board lists the role as remote with Freiburg among the locations, while the description
refers to San Francisco; I would rather ask which office owns this requisition now than assume.

One question I would ask early: which boundary do you currently trust most on intuition rather than evidence? That is
usually where the next quarter of security work belongs.

Kind regards,
#v(0.45cm)
Matt Ji
