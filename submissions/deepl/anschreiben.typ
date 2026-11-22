#set document(title: "Application — DeepL, Staff SRE Sovereign Cloud", author: "Matt Ji")
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
  DeepL \
  Sovereign Markets — Platform team \
  Munich / Germany remote
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Staff Site Reliability Engineer, Sovereign Cloud]

#v(4pt)
Dear DeepL team,

#v(2pt)
Sovereignty is a legal promise that only survives if the engineering holds it. Data residency is the easy part; the harder part is a platform that is genuinely separate — its own boundaries, its own access paths, its own telemetry — and stays that way on a Friday night when nobody is watching. I spent five years building exactly that at a much smaller scale: a thirteen-host Linux platform with no public listener, secrets encrypted per host with sops and age, access issued as short-lived certificates from our own CA, and every change entering through a gate rather than through someone's shell.

#v(2pt)
The habits that make a sovereign environment trustworthy are the ones I had to build because there was no one else to do it. Nothing is edited on a machine. Every build is hermetic from pinned inputs, so what runs is what was reviewed. Rollout is health-checked and rollback is a task, not a procedure. Telemetry exists because the person on call needs to know whether a service is slow because of the model or because of the host — probes, a fifteen-minute ledger, pressure metrics, and an alerting bridge that confirms delivery instead of assuming it. When something breaks at three in the morning, I am used to being the person who reads the messages, not the one who pages someone else.

#v(2pt)
The gaps, plainly: no Kubernetes, no managed cloud infrastructure — my platform runs on owned hardware — and no Staff-level scope, in the sense of setting technical direction across several teams or mentoring engineers. I have also not carried a formal EU compliance programme such as BSI C5 or ISO 27001 through an audit, though I have kept an audit trail as a matter of habit rather than as a project. What I bring is the operating discipline a sovereign platform needs, and German residency with permanent residence, so the jurisdiction question is settled.

#v(2pt)
I am based in Germany and work remotely without difficulty; I am a US citizen with permanent German residence, native English and German C1. The repository is public and unglamorous: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
