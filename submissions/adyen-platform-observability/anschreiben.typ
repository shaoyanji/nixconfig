// Adyen — Senior Platform Engineer, Observability. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Adyen\\
Platform Engineering, Observability

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Platform Engineer - Observability]
#v(0.45cm)

Dear Observability team,

the line I would keep from your posting is the one about on-call: participation in the rotation, but a primary focus on
engineering solutions that stop alerts from firing in the first place. That is the only version of operations I have
enjoyed doing, and it is how my own fleet drifted from reactive to quiet.

The mechanism is unglamorous. A ledger checks job status, service reporting, generation age, disk pressure and PSI every
fifteen minutes and pages on any state short of ok, with a timeout on silence itself, because an instrument that stops
reporting is the failure nobody gets told about. Alerts are chosen for signal: one condition per check, a threshold with
a meaning, and no page whose answer would not change what someone does next. Then the part that actually removes toil:
every checklist item that failed twice becomes a check, every check joins the gate, and the gate runs identically in CI
and on the machine, so the same incident cannot return wearing a different hat.

For the deep-troubleshooting half of the role, the layer I trust is the kernel's. cgroups and PSI to attribute pressure
to I/O or memory instead of restarting a service and hoping; `tcpdump` to prove an MTU or fragmentation problem rather
than blame the network; `strace` where the syscall is the only honest witness; nftables rules read back from the running
system instead of assumed from the repository.

What I have not done is the centre of this job, and I would rather you hear it from me than infer it. I have not operated
Elasticsearch, OpenSearch, VictoriaMetrics, Prometheus or Grafana Tempo in production; my telemetry is hand-built against
a bespoke schema. I have not run workloads on Kubernetes. My environment is bare metal at thirteen hosts, not 1,500 with
a Kubernetes estate beside it, and multi-tenant quota management for a telemetry platform is a problem I have thought
about but not solved. The Linux instinct, the Go and Python tooling, the alerting philosophy and the automation habit
transfer; the data stores and the orchestrator would be new, and on a platform serving hundreds of product teams that is
a real ramp rather than a detail.

One practical matter, because your posting is explicit that Amsterdam is office-first. I am in Germany today and would
relocate for this; I am a US citizen with German permanent residence, so the Dutch route needs a permit sponsored by a
recognised employer, and I would want to confirm that with you early instead of assuming it. English is my native
language and German is C1, so the office is not the barrier — timing is.

I would like to talk about where your transformation is hardest: which pillar hurts most to operate, and whether the
guardrails or the data stores are the real constraint on self-service.

Yours sincerely,
#v(0.5cm)
Matt Ji
