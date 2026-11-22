// Attio — Senior Platform Engineer. English letter, one page.
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
Attio\\
Platform Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Platform Engineer]
#v(0.45cm)

Dear Platform team,

your posting says the platform is a product and every engineer at Attio is its customer. I have run a smaller version of
that business for five years, and the only metric I ever trusted was whether someone shipped without asking me.

The platform I built is thirteen Linux hosts described in one repository, with three things that make it usable rather than
merely functional. First, one entry surface for every operation, with named arguments, help text and machine-readable
output, so an engineer can act without reading the implementation and a wrong argument fails before it touches a host.
Second, a gate that runs identically in CI and on the target machine, so a green build cannot mean something different from
a healthy machine, and a failing check leaves the previous generation serving. Third, documentation generated from the same
source as the configuration, so it cannot drift from the system it describes; the page about a host is built out of that
host.

Reliability is the other half, and I have held the pager for it. Job status, generation age, disk pressure and PSI every
fifteen minutes, paging on any state short of ok and timing out on silence itself, because the failure that hurts is the
one that stopped reporting. Deployments are generations with parents, which makes rollback a pointer rather than a repair
under pressure, and every incident that repeated twice became a check in the gate instead of a paragraph in a postmortem.
Toil went the same way: provisioning is netboot plus a declaration, secret rotation is a certificate authority handing out
short-lived credentials, and retention is a decision with a number attached.

Where I am honestly short is your stack, and it is most of the list. I have not run Kubernetes, Terraform or GCP in
production; my infrastructure as code is a Nix flake and my orchestration is systemd. I have not owned a Datadog or Splunk
installation, and I have run alerting that pages on state rather than a formal SLO and error-budget programme negotiated
with several service teams. Languages are Go and Python rather than TypeScript, with Rust only as reading. Those are the
parts I would be learning, and I would rather say so than have it discovered in a systems interview.

What I would bring on day one is judgment about what to make self-service and what to keep gated, the habit of turning
recurring failures into automation, and a bias toward the boring mechanism a colleague can debug at 02:00 over the clever
one that needs me. I also use AI heavily and check its output against requirements before anything reaches production,
which matters for a team building an AI-native architecture.

Two practical notes. Your posting lists Germany as an eligible location, which is where I am: I have German permanent
residence as a US citizen, so there is no sponsorship question and no relocation needed. And the published band of
EUR 105,000 to 125,000 is workable, so we can spend the conversation on the platform rather than on the number.

I would enjoy hearing which part of the platform currently costs your engineers the most time: the path from code to
production, the environment sprawl, or the on-call load.

Yours sincerely,
#v(0.5cm)
Matt Ji
