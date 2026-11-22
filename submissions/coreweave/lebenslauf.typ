// CoreWeave / Weights & Biases — Senior Data Platform Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2a3f6b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2a3f6b")
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
    #text(size: 9.8pt)[Data Pipelines · Telemetry Instrumentation · Storage Economics]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[US citizen · German permanent residence · English native, German C1]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I build pipelines that refuse to write a lie. Validation happens before the write, a failed batch leaves the previous
state intact, and a rerun produces the same rows rather than a second copy. Behind that sits a PostgreSQL schema with
versioned migrations and rehearsed restores, and in front of it telemetry every fifteen minutes over job state,
generation age, disk pressure and PSI, because a pipeline nobody instruments is a pipeline nobody can defend at 03:00.
Five years of that on a thirteen-host Linux fleet, plus eight years before it running valuation and risk models on a
solar portfolio, which is where the cost-per-unit reflex comes from. I have not run dbt, Dagster or Airflow in
production, I have not operated a multi-petabyte warehouse, and I have no data catalog or lineage system to show.
Python and Go throughout, SQL with query plans rather than hope.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Pipelines* — ingest, validate, transform, deliver; idempotent reruns],
  [*Data quality* — explicit error budgets, failing loudly over partial writes],
  [*Storage* — partitioning, retention as a decision, content addressing],
  [*Telemetry* — event schemas, fifteen-minute ledger, alert on state not on volume],
  [*Linux performance* — cgroups, PSI, disk and I/O pressure under load],
  [*PostgreSQL* — schema design, versioned migrations, rehearsed restores],
  [*Go and Python* — services, CLI surfaces, tests over canonical data],
  [*Operations* — gate identical in CI and host, rollback as a pointer])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built ingestion that validates before it writes: a bad batch leaves the previous state intact and reports why, so a partial load never becomes someone's Monday morning.
- Modelled data with identity rather than convention: exact hashes over canonical JSON and a quotient hash over reviewer-visible fields, which makes deduplication and audit properties of the schema.
- Ran PostgreSQL with versioned migrations and rehearsed restores, because an untested backup is a belief rather than a backup.
- Instrumented the platform end to end: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and on silence itself.
- Used cgroups and PSI to separate I/O starvation from memory shortage under load, and `tcpdump` and `strace` to explain a failure from packets and syscalls rather than from a restart.
- Kept a public data pipeline idempotent across source format changes: fetch, normalise, publish, rerun safely.
- Made retention and lifecycle explicit decisions with a number attached, instead of storage that grows because nothing was ever deleted.
- Wrote the Go service and the Python tooling behind all of it, with tests that fix expected behaviour rather than current output.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across meter, inverter and weather feeds, deviation analysis.
- Turned missing readings into an explicit error budget instead of a quietly good month, keeping history auditable for bank review years later.
- Built financial and valuation models that satisfied auditors, and documented each rollout across client systems.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, and implemented its analysis in Python with 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— data model]
    #linebreak()
    Append-only request lifecycle: exact hashes over canonical JSON, quotient hashes over reviewer-visible fields,
    append-only events. Identity is in the schema, not in a cleanup job.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    A fifteen-minute ledger over job state, generation age, disk and PSI that pages on any state short of ok, with a
    timeout on silence itself.
  ],
  [
    #text(weight: "bold")[energy telemetry] #text(size: 8pt, fill: muted)[— O3 Energy]
    #linebreak()
    Three feeds reconciled into one auditable series for a portfolio above USD 100M, with missing readings carried as
    a known error budget rather than smoothed away.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared infrastructure]
    #linebreak()
    Thirteen hosts, pinned inputs, one gate that runs identically in CI and on the machine, and a rollback that is a
    pointer to the previous generation.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— pipeline]
    #linebreak()
    A public catalogue fetched, normalised and published as a time series, rerunnable when the source changed shape
    mid-week.
  ],
  [
    #text(weight: "bold")[risk calculation engine] #text(size: 8pt, fill: muted)[— Swirl]
    #linebreak()
    A calculation engine for risk and valuation questions where every input is traceable, so a number from the model
    stays checkable rather than plausible.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[US citizen, no sponsorship needed · German permanent residence for an EU base · English native, German C1 · open to relocating to a US hub for the three office days]
