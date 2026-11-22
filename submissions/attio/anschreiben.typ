#set document(title: "Application — Attio, Senior Platform Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji
]

#v(14pt)

#text(size: 9pt)[
  Attio \
  Hiring team — Platform Engineering \
  London
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Senior Platform Engineer]

#v(4pt)
Dear Attio team,

#v(2pt)
I built a platform for thirteen hosts and treated it as a product with exactly one user: me, at three in the morning, six months after I wrote the thing. That constraint produced the habits your posting describes — one module per service, a feature list per host, a gate that checks the configuration before it goes anywhere, and observability built in rather than added after the first incident.

#v(2pt)
The part of your description I recognise most is platform as something a team owns rather than something a team consumes. On my fleet, publishing, deployment and rollback are tasks; nobody edits a host. Rollout happens only through a pipeline that evaluates the same configuration it deploys, so drift shows up as a failed check instead of a mystery. Observability is on the same platform it observes: probes, a sentinel ledger recording job status, generation age, disk and PSI pressure every fifteen minutes, and a Go alerting bridge that confirms delivery — an alert that fires but never arrives is worse than no alert, because it buys a false belief that someone is watching.

#v(2pt)
What I have not done, plainly: no Kubernetes, no Terraform, no AWS platform ownership, and a fleet of thirteen hosts rather than a multi-tenant platform serving many teams. My declarative work is Nix, not HCL, and the scale is small. I would rather name that in the first letter than have it surface in a system design interview.

#v(2pt)
I am based in Germany with permanent residence, so a remote European arrangement needs no sponsorship; I am a US citizen, native English speaker, German C1. The repository is public and unglamorous: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
