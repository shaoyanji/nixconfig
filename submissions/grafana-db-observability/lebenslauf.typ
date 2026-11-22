// Grafana Labs — Senior Full Stack Engineer, Database Observability. Native English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2f3350")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Go services · JavaScript interfaces · SQL · Telemetry that explains itself]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · +49 1733281570]
      #linebreak()
      #text(size: 8.4pt)[github.com/shaoyanji · linkedin.com/in/mattji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Observability is a reading problem before it is a metrics problem: the data is usually there, and what is missing is the
sentence that turns it into a decision. I have spent five years building that sentence for a thirteen-host fleet — job state,
generation age, disk and pressure every fifteen minutes, paging when a state is bad and when a service stops reporting at all,
because a monitor that dies quietly is indistinguishable from a system with nothing wrong.

On the interface side I build web UIs in plain JavaScript against Go services: tokenloom's workbench is a browser client speaking
a binary WebSocket protocol to a Rust service, with a token rope, a diff lane, a warning feed and a constraint index rendered
from a snapshot-plus-delta stream, at roughly two milliseconds end to end on a ten-thousand-token document. It is the same shape
of work as a query explorer: a stream of server frames, a view that has to stay honest under load, and an operator who needs to
see why something is slow rather than that it is.

The server side is Go and Python, with SQL underneath: an append-only event log served from one binary with HTTP endpoints, a
turn-log API and an archive API, and Postgres as the store for the parts that need one. I care about the boring guarantees —
timeouts, idempotency, a query plan that does not surprise you at ten times the data.

What I have not done: production React or TypeScript. My JavaScript is real and shipped, but the component model and typing
discipline your squad works in would be new to me, and so would Prometheus, Loki, Tempo or Grafana itself. Database *performance*
monitoring as a product is also new; my database work has been operating one, not helping thousands of customers understand
theirs.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Go services* — HTTP APIs, event logs, one binary per contract],
  [*JavaScript UI* — browser clients over WebSocket and JSON frames],
  [*SQL and Postgres* — schema, queries, the plans behind them],
  [*Telemetry* — ledgers, thresholds and alerts that name a cause],
  [*On-call* — runbooks written for 02:00, incidents ending as a gate],
  [*Testing* — fuzzers and benchmarks that can falsify a claim],
  [*Linux* — systemd, cgroups, PSI, `strace`, `tcpdump`],
  [*Writing* — design notes and docs generated beside the code])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built the telemetry that made a fleet legible: job status, generation age, disk and PSI every fifteen minutes, with paging on a bad state and on silence, and a dashboard that answers "what changed" before "is it up".
- Wrote Go and Python services with tests, including one binary that serves an append-only event log, a terminal UI and HTTP endpoints from a single contract.
- Built browser interfaces in plain JavaScript over WebSocket and JSON: live views that have to stay correct while frames arrive out of order, rather than screens that merely render.
- Kept Postgres honest: schema changes reviewed as migrations, queries measured against realistic row counts, and index choices justified rather than inherited.
- Made failure legible in the product rather than in the logs: errors carry what the operator needs to act on, and every incident ended as a gate, a check or a runbook entry.
- Ran the collection APIs other tools depended on — turn-log and archive endpoints — with pagination, stable JSON shapes and idempotent writes.
- Automated recurring operations in Go and Python behind one validated surface with dry runs, so a routine request is a command rather than a ticket.
- Carried the on-call: paging, diagnosis at the layer that caused the failure, and the follow-up that stopped the same page arriving twice.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Built the reporting people actually used: variance line by line, with every assumption next to its number.
- Administered software and IT for the company and its subsidiaries, including rollout, access and documentation.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, translating both directions between technical and commercial readers.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    A fifteen-minute ledger of job state, generation age, disk and PSI, paging on bad state and on silence, with history long
    enough to correlate an outage with what changed.
  ],
  [
    #text(weight: "bold")[tokenloom web] #text(size: 8pt, fill: muted)[— JavaScript UI]
    #linebreak()
    A browser workbench over a binary WebSocket protocol: rope, diff lane, warning feed and constraint panel driven by
    snapshot plus delta frames. https://github.com/shaoyanji
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    One binary serving an append-only event log, a terminal UI and HTTP endpoints, with a content-addressed specification.
  ],
  [
    #text(weight: "bold")[collection APIs] #text(size: 8pt, fill: muted)[— backend]
    #linebreak()
    Turn-log and archive endpoints with pagination, stable JSON and idempotent writes, consumed by agents as well as people.
  ],
  [
    #text(weight: "bold")[KEV exposure model] #text(size: 8pt, fill: muted)[— data]
    #linebreak()
    A public dataset turned into an ordered decision: time series, effort clusters, exposure per cluster.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, one declaration, one gate per host. https://github.com/shaoyanji/nixconfig
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— University of Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, eligible to work in Germany with no sponsorship · Germany, fully remote · available 01.12.2026]
