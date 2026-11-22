// Grafana Labs — Senior Full Stack Engineer, Databases - Analytics. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#0d4a6b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#0d4a6b")
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
    #text(size: 9.8pt)[Agent Context Systems · Retrieval & Provenance · Platform Backend]
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
I built and run the context layer a small fleet of AI agents works from, and the shape matches what this team is building: a
compiled inventory and epistemics table declare which source settles which claim, agents consume the compiled truth as
structured output instead of maintaining brittle context files, and provenance is a first-class column rather than a comment.
Retrieval is an API surface — a Postgres archive answers envelope and full-text queries interactively, a knowledge-graph
projection answers "what touches what" over Cypher, and a Go coordination service publishes ordered turns so concurrent agents
claim work without duplicating it.

The multi-tenant SaaS half of the role maps to the same problems at homelab scale: isolation enforced by construction
(capped microVM guests, read-only mounts, no egress), issued rather than standing access (fleet CA, short-lived credentials),
an audit ledger written every fifteen minutes that pages on bad state and on silence, and usage argued from measured queue
depth rather than guessed capacity. Daily languages are Go and Python with TypeScript for tooling and dashboards; cloud
production (AWS/GCP/Azure) I have not run — my cloud is rented metal and my IaC is Nix.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Agent context* — compiled authority tables, structured retrieval, no brittle context files],
  [*Provenance* — epistemics table: which source settles which claim, recorded per assertion],
  [*Retrieval APIs* — Postgres hot tables, full-text index, Cypher graph projections],
  [*Multi-agent coordination* — Go service: claims, ordered turns, idempotent writes],
  [*Tenant isolation* — capped guests, read-only mounts, no egress, issued access],
  [*Audit & telemetry* — fifteen-minute ledger, paging on state and on silence],
  [*Languages* — Go and Python daily; TypeScript for tooling and dashboards],
  [*Delivery* — one gate per change, dry-run plans, rollback as a pointer])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built the context system agents on the fleet consume: a compiled inventory, an epistemics table mapping claims to their
  authoritative source, and skill and note surfaces agents query rather than reciting prose.
- Built the retrieval layer: a Postgres archive behind an API with hot tables for interactive lookups, a full-text index, and
  a graph projection answering "what touches what" for change-scoping decisions.
- Wrote the Go coordination service agents share: claims on work items, ordered turn publication, idempotent writes so a
  retry is a no-op — the primitive a multi-agent workflow needs before it can be trusted.
- Enforced tenant-style isolation by construction: microVM guests with capped CPU and memory, read-only host mounts and no
  egress, so untrusted work runs inside explicit resource and network bounds.
- Built the audit loop the platform runs on: job state, generation age, disk and PSI every fifteen minutes, paging on any
  state short of ok and on silence, with history kept for postmortems.
- Operated an LLM-serving stack on a single GPU — chat, speech-to-text, text-to-speech — with throughput and queue depth
  measured and an explicit yielding rule under contention.
- Shipped agent-facing interfaces in daily use: structured output contracts, validated task surfaces with dry runs, and
  MCP-style tool surfaces agents call for mail, calendar, and system state.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one
  auditable series.
- Reported variance line by line, with every assumption documented next to its number.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis over its 3D geometry output.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[epistemics table] #text(size: 8pt, fill: muted)[— provenance]
    #linebreak()
    A compiled table declaring which source settles which claim and where the answer is filed; authority over word overlap.
  ],
  [
    #text(weight: "bold")[xs coordination] #text(size: 8pt, fill: muted)[— multi-agent]
    #linebreak()
    Go service where agents claim paths and publish ordered turns; idempotent by design, audited by a turn log.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— retrieval API]
    #linebreak()
    Postgres hot tables behind an API: interactive envelope lookups, full-text search, verdicts written once and closed.
  ],
  [
    #text(weight: "bold")[knowledge graph] #text(size: 8pt, fill: muted)[— graph queries]
    #linebreak()
    A projection of the fleet into Cypher: blast-radius, co-mention and chain queries for change scoping.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— audit ledger]
    #linebreak()
    Health written every fifteen minutes; paging on bad state and on silence; history kept for the postmortem.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts from one repository, pinned inputs, reproducible builds, one gate per change.
    https://github.com/shaoyanji/nixconfig
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, fully remote-ready]
