// ScorePlay — Senior Platform / SRE Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2b2440"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2b2440")
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
    #text(size: 9.8pt)[Platform Engineering · Media Storage · Telemetry]
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
I build platforms whose state is declared, gated and recoverable, and I have spent my working life on the
unglamorous part of media and energy data: volume, retention, integrity and the cost of keeping bytes that matter.
Thirteen Linux hosts described by one flake, a change gate identical in CI and on the machine, rollback as a
pointer to the previous generation, telemetry every fifteen minutes on job status, generation age, disk pressure
and PSI. I have not operated a 15 PB multi-region estate or built BYOS deployments; my storage work is
single-region and deliberately small. What transfers is the operating discipline and the habit of asking what a
byte costs. Germany-based with permanent residence, German C1, English native.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, tcpdump, strace],
  [*Storage* — content-addressed layouts, retention and lifecycle, disk pressure as a signal],
  [*Telemetry* — fifteen-minute ledger, alert routing, silence treated as a fault],
  [*Declarative platforms* — pinned inputs, rebuild as a path, rollback per generation],
  [*Automation* — Go, Python, Bash behind one task surface others can drive],
  [*Data pipelines* — ingest, normalisation, stable schemas, idempotent reruns],
  [*Security* — SOPS/age per host, short-lived SSH certificates, default-deny],
  [*Cost awareness* — capacity measured rather than assumed, retention decided not drifted])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts declaratively for five years: storage layouts, services, firewall rules and secrets declared in one repository, with a documented rebuild path per host.
- Designed a content-addressed storage model for an append-only service: immutable, hashed specifications, PostgreSQL indexes, and a retention story that never depended on a human remembering to delete something.
- Built a telemetry loop recording job status, generation age, disk pressure and PSI every fifteen minutes, reporting any state short of ok, and treating blindness as a failure rather than as calm.
- Used cgroups and PSI to catch disk and memory pressure before users noticed, distinguishing I/O starvation from memory shortage rather than guessing at a remedy.
- Gated every change with a check that runs identically in CI and on the machine; a failed check leaves the previous generation serving, so a bad release has a known way back.
- Hardened hosts with nftables default-deny, SOPS/age-encrypted secrets per host and an SSH certificate authority issuing short-lived credentials.
- Isolated workloads in microVMs as declared guests and memory-capped systemd slices, so one runaway process did not become a platform incident.
- Automated recurring operations in Go, Python and Bash behind one task surface with named arguments and help text.
- Kept a public data pipeline idempotent: fetch, normalise, publish, and rerun safely when a source changed shape mid-week.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurements, telemetry reconciliation, deviation analysis.
- Replaced guesswork on missing sensor data with systematic reconciliation, keeping history complete enough to audit years later.
- Ran software rollouts and updates across client systems and documented each one.
- Looked after software and IT administration for the company and its subsidiaries: workstations, network, Wi-Fi, applications.

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
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— content-addressed store]
    #linebreak()
    Immutable, hashed specifications of requests with append-only events: the same input always lands on the same
    identity, which makes deduplication and retention a property of the design.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry loop]
    #linebreak()
    A ledger checks job status, generation age, disk pressure and PSI, reports anything short of ok, and keeps
    what was measured when.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declaration as contract]
    #linebreak()
    One flake describes thirteen hosts, services, secrets, telemetry and a task surface; CI and the host run the
    same gate, so what is tested is what is deployed.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— pipeline]
    #linebreak()
    A public vulnerability catalogue fetched, normalised and published as a time series, rerunnable when the source
    format changed.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— internal tooling]
    #linebreak()
    Every fleet operation behind one command surface with named arguments and help text, so a colleague can run it
    without reading the implementation.
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
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Germany-based, remote across Europe]
