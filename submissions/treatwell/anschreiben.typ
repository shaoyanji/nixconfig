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
What I have not done is your environment, and the list is specific: no AWS beyond reading, no Terraform or OpenTofu modules, no EKS or Helm at scale, no GitLab CI components, and observability from my own ledger and probes rather than Datadog, Prometheus or Grafana. Incident command in my case meant thirteen machines and one operator — a smaller-stakes version of the same discipline, which is to declare, communicate, fix and write it down. What transfers is the judgement the role is actually asking for: designing at service level, making a call and owning it when it turns out wrong, and treating every manual step as a defect with a deadline. The self-service idea is not foreign either — my task menu and generated documentation exist so that nobody has to ask me how the platform works.

#v(2pt)
I am a US citizen with permanent German residence and would relocate to the Netherlands for this role. I understand the highly skilled migrant route depends on the salary threshold and on Treatwell's status as a recognised sponsor, so I would rather ask than assume. Native English, German C1. The repository is public: github.com/shaoyanji/nixconfig

#v(4pt)
Yours sincerely,

#v(16pt)
Matt Ji
