// Wolt — Staff Engineer, EU Infrastructure. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Wolt\\
EU Infrastructure

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff Engineer, EU Infrastructure]
#v(0.4cm)

Dear Wolt infrastructure team,

a compute platform is judged by what a product team can do without asking anyone. I have spent five years building that
property on a much smaller estate: thirteen Linux hosts declared as one repository, every input pinned, so provisioning is a
description rather than a sequence of remembered commands, and an upgrade is a rebuild instead of an edit to a running machine.
The same question your EU Compute team faces with namespaces and quotas, I answered with isolation by construction — a microVM
canary that runs untrusted work with capped CPU and memory, a read-only host mount and no route off the tailnet.

The honest part first, because this is a staff role and a wrong claim would surface in the first design review: I have not
operated production Kubernetes, I have not run AWS, and I have not used Terraform. My provisioning language is Nix, my cloud is
rented metal, and my multi-tenancy experience is one GPU with an explicit yielding rule rather than a fleet of schedulers. If the
EU Compute team needs someone who can reason about cluster upgrades and network policy from memory on day one, I am not that
hire, and I would rather say so here than in week two.

What I can bring is the part of the work that transfers intact. Self-service tooling with named arguments, validation, dry-run
plans and machine-readable output — so a team provisions safely without reading the implementation. Capacity and cost argued
from measurements rather than instinct: queue depth sized the build farm, PSI separated I/O starvation from memory pressure, and
cgroup accounting proved where CPU actually went. A telemetry loop that treats silence as failure, because on a distributed
platform the expensive incident is always the node that stopped reporting. And declarative change with a real rollback: every
generation records its parent, so recovery is a pointer to a known-good system.

On GPU work specifically, what I have is small but honest: one card serving chat, speech-to-text and text-to-speech, with
throughput and queue depth measured and contention resolved by an explicit rule about who yields. Scaling that to a shared fleet
is a scheduling, quota and observability problem, and it is the part of this role I would most want to learn from people who have
already run it.

I am a US citizen with permanent German residence, so Berlin needs no sponsorship, and German is C1 with English native.

A question I would bring to a first conversation: how does the platform currently discover that a GPU node is degraded but not
failing — the state where jobs complete slowly and nobody files a ticket? In my experience that is where utilisation quietly
disappears, and it is the cheapest thing to instrument before it becomes a capacity spend.

Kind regards,
#v(0.45cm)
Matt Ji
