#set document(title: "Application — Adyen, Senior Platform Engineer GenAI", author: "Matt Ji")
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
  Adyen \
  GenAI Platform team \
  Amsterdam / Madrid
]

#v(14pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(6pt)
#text(weight: "bold")[Application — Senior Platform Engineer, GenAI]

#v(4pt)
Dear Adyen team,

#v(2pt)
Most platform engineers have read about model serving. I run one: speech synthesis, transcription and image generation behind OpenAI-compatible endpoints, with a router in front, models loaded on demand, and a guard that gives compute back when something else needs it. It runs on the same thirteen-host Linux fleet I operate, described in one declarative system, so inference is a workload on a platform rather than a special case bolted onto one.

#v(2pt)
That last part is the argument for this role. An internal GenAI platform succeeds when a product team can ask for a model endpoint and get something reliable without becoming infrastructure specialists — which means the hard parts sit with the platform team: resource limits that hold, rollout that does not take the service down, telemetry that says whether latency moved because of the model or because of the host, and a rollback that works at the moment it is needed. I have built all of those at small scale, including the unglamorous details: raw bytes for audio instead of multipart, cgroup bounds that fail loudly, a ledger that records what happened every fifteen minutes, and an alerting bridge that confirms delivery rather than assuming it.

#v(2pt)
The gaps, plainly: no Kubernetes, no vLLM or comparable serving at fleet scale, no GPU cluster scheduling with MIG or device plugins, and no payments-domain experience. My declarative work is Nix, not Helm and Argo CD. I have also not operated at Adyen's transaction volume, and I would be learning the compliance constraints of a regulated environment rather than arriving with them.

#v(2pt)
One practical point: the role is office-first in Amsterdam or Madrid, and I live in Germany. I am willing to relocate for it — I would rather say that in the first letter than have it discovered at offer stage. I am a US citizen with permanent German residence, native English and German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(18pt)
Matt Ji
