// Celonis — Senior Software Engineer, Query Engine & Database Systems. English letter, one page.
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
Celonis SE\\
Process Query Engine — Core Squad

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Software Engineer, Query Engine & Database Systems]
#v(0.4cm)

Dear Celonis Process Query Engine team,

an interactive analytical engine over enterprise data is a latency and correctness problem settled at the storage layer —
which is where I have spent the last five years working. I built a Postgres archive whose hot tables answer envelope lookups
interactively while a full corpus sits behind the same API, a Go coordination service where concurrent agents claim work and
publish ordered turns with idempotent writes, and a fleet whose binaries are built deterministically so the artifact running
is the artifact the source describes.

The honest part, because this is a core-squad role and a wrong claim surfaces in the first code review: Go and Python are my
daily languages. My production C++ is real but dated — the last of it drove a heliostat interferometer at Fraunhofer ISE — I
have not shipped database engine internals, and I have not written Java. If the squad needs someone who can navigate a large
C++ codebase on day one, I am not that hire, and I would rather say so here than in week two.

What transfers intact is the engineering discipline an engine team actually lives on. Performance argued from measurement,
not instinct: cgroup accounting for CPU attribution, PSI to separate I/O starvation from memory pressure, `strace` when the
answer was below the application, queue depth observed before capacity was bought. Resource bounding under concurrent load —
capped microVMs and an explicit rule for who yields — is the same problem a query engine answers with per-operator memory
limits and spill policy, at a different layer of the stack. And determinism as an operating property: pinned inputs and
reproducible builds, so a failure bisect is a search over sources, not over environments.

On the role's specifics: process mining's engine serves analysts interactively over enterprise-sized sets, which makes
memory accounting and backpressure the features users never see and always feel — the exact shape of the telemetry loop I
run, where silence and slow-but-not-dead are the expensive states. I would grow the C++ and engine-internals half on the job
against mentors who have already shipped it.

I am a US citizen with permanent German residence, so Munich needs no sponsorship; office days there are workable by
arrangement. German is C1, English native — useful on a squad where the posting names German a plus.

A question I would bring to a first conversation: how does the engine account for memory across concurrent query operators —
per-operator budgets or a shared pool with admission control? That boundary is where tail latency is won.

Kind regards,
#v(0.45cm)
Matt Ji
