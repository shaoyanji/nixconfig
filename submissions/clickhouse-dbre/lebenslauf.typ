// ClickHouse — Database Reliability Engineer, Core (EMEA Remote). Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#3a2d1f"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#3a2d1f")
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
    #text(size: 9.8pt)[Reliability · Linux Internals · Performance Under Load]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Most of my work has been about a system's behaviour under load, and about being able to prove what happened
afterwards: thirteen Linux hosts from one declaration, a fifteen-minute telemetry loop over job status,
generation age, disk pressure and PSI, and diagnosis that separates memory pressure from I/O and CPU contention
using cgroups, journald and strace. I design for the pager rather than the dashboard — a change only lands if a
gate passes, and recovery is a pointer to the previous generation rather than a reconstruction at 3 a.m. I have
used PostgreSQL as a service backend (schema, indexes, append-only events) but I have not run ClickHouse or
operated a database fleet in production. Germany-based, German permanent residence as a US citizen, no
sponsorship needed.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux internals* — systemd, journald, cgroups/PSI, tcpdump, strace, nftables],
  [*Performance work* — pressure signals, I/O versus memory versus CPU, capacity over guesswork],
  [*Telemetry* — fifteen-minute ledger, alert routing, silence treated as a fault],
  [*Data* — PostgreSQL schema and queries, append-only events, time series],
  [*Declarative systems* — pinned inputs, rebuild as a path, rollback per generation],
  [*Automation* — Go, Python, Bash behind one task surface others can drive],
  [*Incidents* — cause before action, written postmortems without blame],
  [*Security* — SOPS/age per host, short-lived SSH certificates, default-deny])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts declaratively for five years; no hand edits on a target host, a documented rebuild path for each, and a rollback that is a pointer rather than a procedure.
- Built a telemetry loop recording job status, generation age, disk pressure and PSI every fifteen minutes, reporting any state short of ok, and treating blindness as a failure rather than as calm.
- Used cgroups and PSI to separate memory pressure from I/O and CPU contention before users reported degradation, turning a vague complaint into a measurable claim.
- Traced incidents with journald, cgroups, tcpdump and strace to a root cause, wrote the cause and the recovery path down, and kept the note beside the repository.
- Designed and ran a Go service with append-only events in PostgreSQL: schema with explicit indexes, queries that avoid table scans, and a terminal interface served from the same binary.
- Hardened hosts with nftables default-deny, SOPS/age-encrypted secrets per host and an SSH certificate authority issuing short-lived credentials.
- Isolated workloads in microVMs as declared guests and memory-capped systemd slices, so one saturated workload did not become an outage for the rest.
- Automated recurring operations in Go, Python and Bash behind one task surface with named arguments and help text, so a colleague could run it without reading the source.
- Kept a data pipeline that normalises a public vulnerability catalogue into a weekly series with stable schema, so downstream questions did not require re-derivation.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurements, telemetry reconciliation, deviation analysis.
- Replaced guesswork on missing sensor data with systematic reconciliation, and reported deviations in a form that passed audits.
- Ran software rollouts and updates across client systems and documented each one.
- Looked after software and IT administration for the company and its subsidiaries.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk management, with data models as the basis of each recommendation.
- Translated technical constraints into recommendations a non-technical board could act on.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies by interferometry and wrote the C++ application that spoke to the instrument.
- Wrote Python tooling for measurement analysis and 3D geometry, and evaluated the resulting series statistically.
- Worked inside fixed measurement campaigns where a result had to be reproducible, not merely plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.
- Led the crew's safety training and worked to procedures that tolerate no deviation.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry loop]
    #linebreak()
    A ledger checks job status, generation age, disk pressure and PSI, reports anything short of ok, and keeps
    what was measured when — the difference between an outage and a guess.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go plus PostgreSQL]
    #linebreak()
    Immutable, content-addressed specifications of requests, append-only events, and queries served from an index
    instead of a scan.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declaration as contract]
    #linebreak()
    One flake describes thirteen hosts, services, secrets, telemetry and a task surface; CI and the host run the
    same gate, so what is tested is what is deployed.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— data pipeline]
    #linebreak()
    CISA's exploited-vulnerability catalogue fetched, normalised and published as a time series, with exposure
    clustered by remediation effort.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— internal tooling]
    #linebreak()
    Every fleet operation behind one command surface with named arguments and help text, so a colleague can run
    it without reading the implementation.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving installers and first configuration, so a machine joins the declared fleet instead of
    being assembled by hand.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · based in Germany, EMEA remote without relocation]
