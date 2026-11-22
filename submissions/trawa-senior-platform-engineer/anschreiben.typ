#set document(title: "Application trawa — Senior Platform Engineer", author: "Matt Ji")
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
  trawa \
  Platform Team \
  Berlin HQ
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application for Senior Platform Engineer]

#v(4pt)
Dear trawa team,

#v(2pt)
Your customers buy electricity, but what they actually depend on is a platform that prices, procures and balances it without fail. That is the part of trawa I understand from both sides: I studied renewable energy management at Freiburg, researched solar at Fraunhofer ISE, and spent four years steering 10 MW of PV assets, while for five years I ran the infrastructure that made the numbers real. Thirteen hosts, three hardware generations, every service a module, every change a commit, every state a generation I could roll back to.

#v(2pt)
Concretely: the check that runs in CI is the check that guards the rollout, so nothing reaches a machine unverified. Observability is a sentinel ledger written every 15 minutes with job status, generation age, disk and memory pressure, backed by endpoint checks and alerting that only counts as delivered when the message arrives. Backups run with restic to a NAS and I restore from them rather than reading job logs. Secrets sit in sops and age, host keys come from an own certificate authority with short-lived certificates, and no service is exposed publicly. When shell was not enough I wrote the tooling in Go or Python, and every procedure became a runbook, because a platform team whose knowledge lives in one head is a single point of failure.

#v(2pt)
What I do not have, stated plainly because a platform hire is expensive to get wrong: no production AWS, no Terraform or Spacelift, no Docker in production, no GitHub Actions, and no Postgres or ClickHouse at platform scale. My infrastructure as code is Nix and my cloud is a rack. I also fall short of your eight-year bar in the literal sense: five years as founder doing this work end to end, plus earlier engineering, is close but not the same as eight years in a titled platform role. What transfers is the judgement, not the CLI flags. And Berlin in person most of the week is a real move from the Black Forest, roughly 700 km; I would make it for this domain, and I would rather say that now than discover it in week three.

#v(4pt)
Kind regards

#v(18pt)
Matt Ji
