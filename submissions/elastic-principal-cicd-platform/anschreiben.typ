#set document(title: "Application — Elastic, Principal CI/CD & Platform Engineer", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(14pt)

#text(size: 9pt)[
  Elastic \
  Principal CI/CD & Platform Engineer
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Principal CI/CD & Platform Engineer]

#v(4pt)
Dear Elastic,

#v(2pt)
A pipeline is judged by what it refuses to let through. Mine is built on that premise: inputs are pinned, so the same commit and the same inputs produce the same system; the gate evaluates the configuration — modules and assertions — rather than accepting a build that merely exited zero; and rollback is a previous generation, not a rebuild under pressure. The CI matrix is derived from the host inventory, so a new machine enters testing because it is registered, not because somebody remembered. Thirteen Linux hosts across three hardware generations were delivered that way for five years, by one person, with no hand-edited state on any of them.

#v(2pt)
Platform work for me has meant making the fast path the safe path. Fleet-wide checks run one host per process under a memory watchdog, because a sweep that takes down the machine running it is a self-inflicted outage. Gates are tiered by cost — repository hygiene in seconds, host evaluation per host, the expensive checks only where the machine can hold them — so people run the cheap one before they need the expensive one. Documentation is generated from the same graph as the task menu, because documentation that drifts teaches people to distrust the pipeline. Tools are Python and Go, and the Linux underneath is mine: systemd, cgroups and namespaces, PSI and disk pressure, boot and initrd on hardware that was bought rather than rented.

#v(2pt)
What I have not done is CI at your scale. I have not run thousands of builds a day, not built or tuned Bazel or Gradle pipelines, not operated distributed build caches or a Kubernetes runner fleet, and not worked in the Java ecosystem that Elastic's build depends on. What I bring is the part that transfers: a correct mental model of reproducibility and caching, a habit of measuring a pipeline before optimising it, and the willingness to learn your stack as it is rather than import mine. At principal level the useful contribution is judgement about where a pipeline should refuse, and where it should get out of the way.

#v(2pt)
Based in Germany, working remotely across EMEA without difficulty. Native English, German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
