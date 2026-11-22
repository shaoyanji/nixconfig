#set document(title: "Application — Treatwell, Senior Platform Engineer, Platform Core", author: "Matt Ji")
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2.2cm))
#set text(font: ("Libertinus Serif", "DejaVu Sans"), size: 10pt, fill: rgb("#111827"), lang: "en")
#set par(leading: 0.58em, justify: true, spacing: 1.1em)

#text(size: 9pt, fill: rgb("#374151"))[
  #text(weight: "bold", size: 10pt, fill: rgb("#111827"))[Matt Ji] \
  Am Burgerhof 4, 79261 Gutach im Breisgau, Germany \
  matt\@bountystash.com • +49 1733281570 • github.com/shaoyanji/nixconfig
]

#v(12pt)

#text(size: 9pt)[
  Treatwell \
  Platform Core \
  Workable reference 359BA205E3
]

#v(12pt)
#align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[22 November 2026]]

#v(4pt)
#text(weight: "bold")[Application — Senior Platform Engineer, Platform Core]

#v(4pt)
Dear Treatwell,

#v(2pt)
A platform core has one job that matters: the teams above it should be able to ship without thinking about it. I built that for thirteen Linux hosts over five years, and the discipline it forced is the part that transfers. Inputs are pinned, so a commit reproduces a system. The gate evaluates the configuration — modules and assertions — instead of accepting a build that exited zero. Rollback is a previous generation, measured in minutes. The CI matrix comes from the inventory, so a machine is tested because it is registered, not because somebody remembered to add it.

#v(2pt)
Telemetry was the other half, and the lesson there was that an alert is a delivery problem before it is a monitoring problem. A fifteen-minute timestamped ledger, probes from outside, and a Go bridge that counts a failure as reported only once delivery is confirmed. Pressure, disk and generation age are checked because they move before an outage does. Maintenance that people skip — certificate rotation, backup restores — is automated and, in the case of restores, actually exercised. All of it is described in one repository, with the documentation generated from the same graph as the task menu, because a platform nobody can read is a platform nobody trusts.

#v(2pt)
What I have not done is your environment. I have not run workloads on AWS, not operated Kubernetes, not written Terraform, and not carried a marketplace's traffic or a multi-tenant data model. My scale was thirteen machines and one operator, which teaches judgement about cost and refusal but not about queueing under load. What I would bring is the habit the role needs at senior level: measure the pipeline before changing it, make the safe path the fast path, and treat every manual step as a defect with a deadline.

#v(2pt)
I am a US citizen with permanent German residence and would relocate to the Netherlands for this role. I understand the highly skilled migrant route depends on the salary threshold and on Treatwell's status as a recognised sponsor, so I would rather ask than assume. Native English, German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(16pt)
Matt Ji
