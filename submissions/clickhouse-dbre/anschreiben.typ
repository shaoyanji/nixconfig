// ClickHouse — DBRE, Core (EMEA Remote). English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
ClickHouse\\
Core Team — EMEA Remote

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Database Reliability Engineer, Core Team (EMEA Remote)]
#v(0.45cm)

Dear Hiring Team,

database reliability is mostly the discipline of answering three questions quickly: what is the system doing, why is
it doing that, and what do we do about it at 3 a.m. I have spent five years building systems where those answers
come from records rather than memory — thirteen Linux hosts described by one declaration, a fifteen-minute
telemetry loop over job status, generation age, disk pressure and pressure stall information, and diagnosis that
separates memory pressure from I/O and CPU contention instead of guessing at a remedy.

The performance side is where that discipline pays. PSI and cgroups tell me whether a host is short on memory,
thrashing on disk or simply out of CPU, which is a different answer for each and a different fix. A change lands
only if a gate passes, and recovery is a pointer to the previous generation rather than a procedure invented under
pressure. I have built services on PostgreSQL — schema with deliberate indexes, append-only event tables, queries
that do not scan — and I have run data pipelines where a broken schema breaks everything downstream, which teaches
you to treat data structures as contracts.

What I have not done, specifically: I have not operated ClickHouse, and I have not been a database reliability
engineer for a database fleet. My production databases are PostgreSQL as an application backend, not a
multi-tenant analytical store under load. Since Core team work is largely the hard part of ClickHouse itself —
performance, replication, failure modes at scale — that gap is the centre of this application rather than a
footnote. I would be joining to learn that system, not to repeat something I have already done.

What should transfer: Linux internals rather than abstraction — journald, cgroups, tcpdump, strace; a bias toward
measuring before changing; alerting that carries a decision instead of noise; and postmortems written without
blame, because a system that hides its failures cannot be improved. I also like the OSS posture: the work is
public, the arguments are technical, and correctness is discussed rather than announced.

I am based in Germany with German permanent residence as a US citizen, so there is no sponsorship question and no
relocation needed for an EMEA remote role. German is C1, English native. If a conversation would help, I would
like to hear which reliability problems the Core team is working on right now.

Yours sincerely,
#v(0.5cm)
Matt Ji
