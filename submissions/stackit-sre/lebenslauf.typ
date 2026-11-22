// STACKIT / Schwarz Digits — (Senior) SRE, Control Plane (GT2321). Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#0d3b66"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#0d3b66")
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
    #text(size: 9.8pt)[Site Reliability · Declarative Platforms · Telemetry]
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
I run systems whose state is written down, checked before it changes and recoverable by pointer: thirteen Linux
hosts from one declaration, every change through a gate that runs identically in CI and on the host, every
rollback a reference to the previous generation. Reliability, for me, is a property you can read off the
configuration rather than a claim made during an incident. I am based in Baden-Württemberg, hold German permanent
residence as a US citizen, and am ready to work on site in the region.

What I have not done is equally specific: I have not operated a cloud control plane and have not administered a
Kubernetes cluster in production. The layer beneath it, and the habit of proving state before touching it, I have
built and run for five years.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, journald, cgroups/PSI, tcpdump, strace],
  [*Declarative infrastructure* — pinned inputs, reproducible rebuild, rollback per generation],
  [*Telemetry loops* — fifteen-minute ledger, alerting on any state short of ok],
  [*Failure tracing* — memory versus I/O versus CPU pressure, cause before action],
  [*Availability* — gates ahead of rollout, no half-applied change, tested recovery],
  [*Security* — nftables default-deny, SOPS/age per host, short-lived SSH certificates],
  [*Automation* — Go, Python, Bash, Nix behind one task surface],
  [*Documentation* — runbooks, incident notes, architecture decisions with reasons])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts declaratively for five years, with no hand edits on a target host and a documented rebuild path for each.
- Gated every change with a check that runs the same way in CI and on the machine; a failing check leaves the previous generation serving.
- Built a telemetry loop that records job status, generation age, disk pressure and PSI every fifteen minutes and reports any state short of ok, treating blindness as a failure case.
- Used cgroups and PSI to separate memory pressure from I/O and CPU contention before users noticed degradation.
- Traced incidents with journald, cgroups, tcpdump and strace to a cause, then wrote the cause and the recovery path down.
- Hardened hosts with nftables default-deny, SOPS/age-encrypted secrets per host and an SSH certificate authority issuing short-lived credentials.
- Isolated workloads in microVMs as declared guests and memory-capped systemd slices, so one failure stayed one failure.
- Provisioned bare metal over PXE and iVentoy from installer boot to first configuration, which turned a rebuild into a routine rather than an event.
- Ran a local inference platform on own hardware: several models behind a router, on-demand start, a guard that keeps heavy jobs from starving interactive requests.
- Automated recurring operations in Go, Python and Bash behind a single task surface anyone on the team could drive.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurements, telemetry reconciliation, deviation analysis.
- Replaced guesswork on missing sensor data with systematic reconciliation and reported deviations in a form that passed audits.
- Ran software rollouts and updates across client systems and documented each one, so a later question had an answer.
- Introduced mobile field capture, replacing paper records with structured data that could be queried.
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
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry loop]
    #linebreak()
    A ledger checks job status, generation age, disk pressure and PSI, reports anything short of ok, and keeps
    what was measured when.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform as code]
    #linebreak()
    One flake describes thirteen hosts, services, secrets, telemetry and a task surface; CI and the host run the
    same gate.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— one entry point]
    #linebreak()
    Every fleet operation behind one command surface with named arguments, so a colleague can run it without
    reading the implementation.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving an ISO library, installer boot and first configuration, so a machine joins the
    declared fleet instead of being assembled by hand.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    An immutable, content-addressed specification of a request: append-only events and a terminal interface from
    one binary, stored in PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— data product]
    #linebreak()
    CISA's exploited-vulnerability catalogue as a cleaned time series, exposure clustered by remediation effort.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · resident in Baden-Württemberg, on-site in the region by default]
