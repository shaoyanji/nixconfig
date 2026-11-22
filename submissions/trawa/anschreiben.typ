#set document(title: "Application — trawa, Senior Platform Engineer", author: "Matt Ji")
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
  Platform team \
  Berlin
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Senior Platform Engineer]

#v(4pt)
Dear trawa team,

#v(2pt)
For four years I sat on the customer side of the spreadsheet your product replaces: managing 10 MW of solar PV assets commercially, building the financial models, reading the yield data and explaining deviations. Then I spent five years building the platform those numbers run on — a thirteen-host Linux fleet as one declarative system, with telemetry, gated rollouts and Python and Go tooling. Most platform engineers have never had to defend an asset's economics; most energy people cannot read a pressure stall. I have done both, and trawa is one of the few companies where that combination is the job rather than a curiosity.

#v(2pt)
On the platform side, the work maps onto what your Platform team owns. I have run infrastructure, shared tooling and developer experience at once, with a headcount of one: change only through a pipeline that evaluates the same configuration it deploys, health-checked rollout, rollback by generation, and observability written by the person who has to act on it at three in the morning. Cost and capacity were engineering inputs, not afterthoughts — small hosts, measured pressure, upgrades planned from the ledger rather than from a feeling. An alert that fires and never arrives is worse than no alert, because it buys a false belief that someone is watching.

#v(2pt)
The gaps are specific. My infrastructure runs on owned hardware, so there is no deep AWS practice; my declarative work is Nix, not Terraform; my distributed-systems experience is thirteen hosts, not services at company scale; and I have around five years of platform work rather than the eight the posting asks for. What I bring instead is a domain the role sits inside: I know what a flexible asset, a procurement contract and a yield curve mean for the software that manages them.

#v(2pt)
The role is in Berlin most of the week and I live near Freiburg, so relocating is part of the answer, not an assumption — I would rather say that here than at offer stage. I am a US citizen with permanent German residence, native English and German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
