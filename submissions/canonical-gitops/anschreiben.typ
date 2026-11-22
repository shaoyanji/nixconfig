#set document(title: "Application — Canonical, Senior Site Reliability / GitOps Engineer", author: "Matt Ji")
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
  Canonical \
  Hiring team — Information Systems \
  Home based — Worldwide
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Senior Site Reliability / GitOps Engineer]

#v(4pt)
Dear Canonical team,

#v(2pt)
Automation-first is easy to claim and hard to prove, so here is the proof: for five years I was the only operator of a thirteen-host Linux fleet, and the repository was the only way anything changed. Hosts and services were described, not configured; publishing, deployment and rollback were tasks; and a change entered through a pipeline that evaluated the same configuration it deployed. Nothing was edited on a machine, which meant drift surfaced as a failed check rather than as an incident.

#v(2pt)
That is the discipline your Information Systems team describes for systems used across a very large Ubuntu population, and it scales by construction rather than by effort. GitOps, in my experience, is less about a sync tool than about refusing the side door: if the only path to production is a commit that passes a gate, the fleet cannot quietly diverge. The same reasoning shapes the rest of my work — Python and Go for tooling that removes the manual step, telemetry written by the person who has to act on it, restores verified rather than backups counted, and a Go bridge that only confirms an alert once it has actually arrived.

#v(2pt)
The gaps, before you find them: no Kubernetes and no ArgoCD in production, and thirteen hosts rather than a fleet measured in millions. My declarative work is Nix, not Helm charts. I have operated Linux deeply — systemd, networking, nftables, storage, certificates — but not at the scale this team manages, and I have not maintained an upstream project at Canonical's level.

#v(2pt)
I am based in Germany with permanent residence and a US passport, so remote work from Germany needs no sponsorship. Native English, German C1. The repository is public and unglamorous: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
