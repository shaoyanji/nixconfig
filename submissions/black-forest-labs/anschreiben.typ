#set document(title: "Application — Black Forest Labs, MTS Infrastructure Security", author: "Matt Ji")
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
  Black Forest Labs \
  Infrastructure Security \
  Freiburg im Breisgau / Remote
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Member of Technical Staff, Infrastructure Security]

#v(4pt)
Dear Black Forest Labs team,

#v(2pt)
Your posting describes the tension I spent five years living inside: researchers need generous access to compute, production needs hard isolation, and both have to be true at the same time. On a thirteen-host fleet with no security team, I did not get to hand that trade-off to someone else. Secrets sat encrypted in the repository with sops and age, one key per host. Access was a short-lived SSH certificate from our own CA, not a key passed around. Services lived behind a WireGuard mesh with no public listener, with nftables rules at the edge and cgroups bounding what a workload could consume.

#v(2pt)
The part I would bring to a security role is the constraint that shaped those choices: security that stops the research is security that gets bypassed. So the controls were built into the path rather than bolted beside it — a change is a reviewed commit, a build is hermetic from pinned inputs, and what runs is what the gate checked. Audit came for free: a ledger every fifteen minutes, runbooks for every procedure, and history for every change. When something broke at the boundary, I was the person reading the messages, because there was nobody else.

#v(2pt)
The gaps are specific and worth naming. I have never held a security title, so threat modelling as a formal exercise, incident response drills, and compliance work such as SOC 2 or ISO 27001 are not in my record. My infrastructure is owned hardware rather than AWS and Kubernetes, and I have not secured an ML training fleet or the compute allocation that goes with it. What I have done is make a small platform defensible without slowing it down, which is the same problem at a different size.

#v(2pt)
On the practical side: I live in Gutach im Breisgau, about 25 minutes from your Freiburg lab, so this is not a remote application from another country — I can be in the room. I am a US citizen with permanent German residence, native English and German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
