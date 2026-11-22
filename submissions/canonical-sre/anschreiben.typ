#set document(title: "Application — Canonical, Senior Site Reliability Engineer", author: "Matt Ji")
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
  Hiring team — Site Reliability Engineering \
  Home based — Worldwide
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Senior Site Reliability Engineer]

#v(4pt)
Dear Canonical team,

#v(2pt)
For five years I was the only operator of a thirteen-host Linux fleet, which is a good way to learn that operations has to be software. Everything I did twice became a script; everything I did at three in the morning became a check that ran before the next rollout. The result is a platform where a host is described, not configured, where a change enters through a pipeline that evaluates the same configuration it deploys, and where the telemetry that tells me something is wrong was written by the same person who has to act on it.

#v(2pt)
Your posting describes reliability work as a scientific discipline and as pure software, and that is the part I want to be held to. On my platform, observability is not a dashboard somebody bought: Gatus probes, a sentinel ledger recording job status, generation age, disk and PSI pressure every fifteen minutes, and a Go bridge that confirms an alert actually arrived. An alert that fires and never lands is worse than no alert, because it buys a false belief that someone is watching. The same reasoning runs through the rest: restores are verified rather than backup jobs counted, rollback is a task rather than a procedure in a wiki, and no host carries hand-edited state.

#v(2pt)
What I have not done: no Kubernetes, no kernel development, no Ceph or distributed storage internals, and thirteen hosts rather than a fleet of thousands. I have operated Linux deeply, including systemd, nftables, networking and storage, but I have consumed the kernel rather than patched it. Those are the gaps I would be closing in the first year.

#v(2pt)
I am based in Germany with permanent residence and a US passport, so worldwide remote needs no sponsorship and no relocation; travel for team sprints is fine. Native English, German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
