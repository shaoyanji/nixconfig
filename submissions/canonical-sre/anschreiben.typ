// Canonical — Senior Site Reliability Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.32cm)
Canonical #linebreak() Cloud operations

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer]
#v(0.32cm)

Dear Canonical team,

your description calls automation a software engineering problem rather than something to hack until it works, and says operations should be
driven by metrics and code. That is the only way I have run a fleet, so let me be concrete about what it looks like.

One flake declares thirteen hosts. A change either passes the same per-host evaluation in CI and on the machine, or it never reaches
hardware; a release is a pointer to the previous generation, so rollback is a command rather than a procedure written during an incident.
The systemd layer is where I spend the care: units with explicit ordering and dependencies, sockets and timers where a polling loop would be
worse, per-slice memory limits, and start limits that turn a crash loop into a stopped unit instead of a saturated machine. A unit that
accepts connections is not evidence that the work finished, and most false green I have seen came from treating it as though it were.

Telemetry is a recording with thresholds kept in the repository, not a wall of graphs. A sentinel writes job status, generation age, disk and
PSI — pressure on IO, memory and CPU — to a ledger every fifteen minutes, and the page fires on any state short of ok and on silence,
because a monitor that stops reporting looks exactly like a quiet system. Thresholds are argued with the noise they produce: a page that
arrives weekly for a known condition gets fixed or retired, never muted in place. Deployment follows the same logic — a canary guest built
from the same definitions as its host proves a configuration before the fleet sees it, one writer per process, and no fleet-wide default
that could apply a change everywhere at once.

Python carries my services and tooling: FastAPI and Flask endpoints, PostgreSQL with migrations and a rehearsed restore, an IMAP ingestion
and classification service, and the task interface that builds and checks the fleet. I am comfortable in a substantial codebase; I am not a
CPython internals person.

What I do not bring, stated plainly: no production OpenStack, Kubernetes or Ceph operations — isolation here is microVMs on KVM and the
orchestrator is NixOS and systemd. No eBPF or in-kernel tracing, so the telemetry is PSI, a ledger and generated metrics rather than probes.
And nothing at the scale of hundreds of customer clusters, which is what I would be learning.

I am based in Germany on CET, a US citizen with permanent German residence, glad to travel for the twice-yearly sprints. I am targeting EUR
120,000 to 150,000, available from 01.12.2026.

Kind regards,
#v(0.4cm)
Matt Ji
