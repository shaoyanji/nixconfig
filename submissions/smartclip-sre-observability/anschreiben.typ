// smartclip Europe — SRE, Observability & Internal Tools. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
smartclip Europe GmbH\\
Hamburg

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Site Reliability Engineer (f/m/d) — Observability & Internal Tools]
#v(0.45cm)

Dear Hiring Team,

an alert is only worth sending if it changes what someone does at three in the morning. That test has shaped how I
instrument systems: fewer signals, each one carrying a decision. For five years I ran thirteen Linux hosts from a
single declaration, with a telemetry loop that records job status, generation age, disk pressure and pressure
stall information every fifteen minutes and reports any state short of ok. Blindness counts as a fault there, not
as a quiet period, because a dashboard nobody queries is the same as no dashboard at all.

The diagnostic side matters as much as the signal. When something degrades I separate memory pressure from I/O
and CPU contention using cgroups and PSI, then trace the cause through journald, tcpdump and strace, and write the
cause and the recovery path down. That is where SLOs become real: not a number published monthly, but a question
you can answer from records when a release goes wrong and someone asks what changed and how to get back.

On tooling, I build the small internal tools that make a fleet operable: every routine operation behind one
command surface with named arguments and help text, so a colleague can drive it without reading the source; a Go
service with append-only events in PostgreSQL; a pipeline that turns a public vulnerability catalogue into a
weekly series. I prefer tools that can be read, exported and self-hosted, which is why my own stack is open source
end to end — Nix, Go, PostgreSQL, and a self-hosted git remote rather than a vendor console.

What I have not done is equally concrete: I have not operated Prometheus or Grafana in production, and I have not
administered Kubernetes. My instrumentation is home-built and deliberately small, so I know exactly what it
measures — but a team running a Prometheus/PromQL estate and a Grafana stack for others to consume would be
teaching me their tooling, and I would rather say that than discover it in the second interview.

What I bring is the part that takes longer to learn: deciding what deserves a signal, keeping the alert volume
low, tracing a failure to its cause rather than its symptom, and writing it down so the next incident is cheaper.
I am a US citizen with German permanent residence, no sponsorship needed; German is C1 and English is native. I
have worked fully remote for five years, so distributed collaboration is my default rather than an adjustment.

I would welcome a conversation about what smartclip currently measures and what keeps the on-call rotation awake.

Yours sincerely,
#v(0.5cm)
Matt Ji
