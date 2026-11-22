// Miaplaza — Hands-on Engineering Manager, DevOps. Self-contained Typst.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 8.7pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.45em)
#set list(marker: text(fill: rgb("#14456b"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#14456b")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 7pt, below: 2pt)[
  #text(size: 9.6pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
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
    #text(size: 10pt)[Hands-on Infrastructure Lead · Linux & Platform]
  ],
  [
    #align(right)[
      #text(size: 8pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8pt)[matt\@bountystash.com · github.com/shaoyanji · bountystash.com]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Ten years of running systems and writing the software around them, five of those as the person who owned
a thirteen-host Linux fleet end to end. I work the way this role is written: half in the code, half in
the conditions that let other people do their best work. My teaching has been concrete rather than
ceremonial — safety training for a crew, instruction for field technicians instead of ticket forwarding,
runbooks and gates that make the right action the easy one. I have led people, but not software
engineers with performance reviews, and I have not run Kubernetes or GCP in production. Both are stated
here rather than discovered in month two.

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Sole engineer for a thirteen-host Linux fleet declared in one repository: every machine converges to the declaration, no hand edits on a target host.
- Built the platform the way a team would inherit it — a task surface, written runbooks and a gate that runs the same in CI and on the host, so a newcomer can act without asking me first.
- Made releases reversible: a failing check leaves the previous generation in place, and rollback is a pointer move rather than a rebuild at 2 a.m.
- Treated observability as a ledger before a dashboard: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state other than ok — the record that answers "what changed" in an incident review.
- Provisioned bare metal with PXE and iVentoy through first configuration and rebuild; held workloads inside systemd slices, cgroups and memory caps on ARM boards and microVMs.
- Ran the network as code: WireGuard between hosts, nftables default-deny, an internal DNS zone, MTU faults found with tcpdump.
- Served web workloads behind nginx with TLS from an internal CA and short-lived certificates; kept secrets per host with SOPS and age, least privilege by default.
- Wrote Go, Python and Bash tooling behind one task surface, including Go services on PostgreSQL with an append-only event log.
- Made cost a design decision: ARM over x86, microVMs over VMs, build cache instead of recompiling on every rebuild.
- Built vulnerability work as data (CISA KEV as a time series) and priced weather derivatives as internal risk manager.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Ran software and IT administration for the company and its subsidiaries, including workstations, network, Wi-Fi and the people using them.
- Supported field technicians and office staff directly, with instruction rather than ticket forwarding — the same principle as growing engineers: you cannot teach what you do not see.
- Built financial models and managed 10 MW of solar PV assets inside a portfolio above USD 100 M.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Held a director title with client-facing responsibility for a pipeline above USD 100 M.
- Advised clients on cybersecurity software and risk management, translating technical risk into decisions a non-technical board could take.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Led two frac crews carrying more than USD 3 M of contract volume per week — the first place I learned that a team's output is set by its brief, not its headcount.
- Ran the crew's safety training and certified new members, which is where my habit of teaching by demonstration rather than by memo started.
- Fixed chemical and equipment faults on site, under time pressure, with no second attempt.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies with interferometry and wrote the C++ acquisition software for the lab instruments.
- Wrote Python tooling for analysis and 3D geometry.

#section("Leadership & Teaching")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 3pt,
  [*Crew leadership* — two frac crews, weekly contract volume above USD 3 M, safety training owned end to end],
  [*Instruction* — field technicians and office staff taught directly, not routed to a queue],
  [*Written systems* — runbooks, task surfaces and gates that let someone else act without the author present],
  [*Feedback as data* — incidents reviewed from the ledger, with the cause written down rather than remembered])

#section("Selected Projects")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative fleet]
    #linebreak()
    One flake declares thirteen NixOS hosts, nginx vhosts with TLS, an SSH CA, SOPS secrets and a task
    surface; CI and host execute the same module gate.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    An immutable, content-addressed specification from one request: append-only events, a terminal
    interface and curl endpoints from a single binary, persisted in PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— vulnerability data]
    #linebreak()
    CISA's known-exploited catalogue as a time series in plain SVG, exposure clustered by remediation
    effort — the reporting an EM needs to prioritise security work.
  ],
  [
    #text(weight: "bold")[risk-calc] #text(size: 8pt, fill: muted)[— Go and pipelines]
    #linebreak()
    Green's theorem over stochastic polygons: a Go fuzzer generates shapes, a Nushell and Awk pipeline
    drives the computation.
  ])

#section("Skills")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Automation* — declarative configuration, gates, Go, Python, Bash],
  [*Networking* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Observability* — ledger health checks, alerting, incident notes],
  [*Bare metal* — PXE/iVentoy, rebuild, rollback by generation],
  [*Data* — PostgreSQL, append-only events, REST],
  [*Cloud* — Oracle Cloud hosts, one AWS Lambda project; GCP not yet operated],
  [*Security* — SOPS/age, least privilege, KEV-driven vulnerability work])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[MSc Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1.8/5.0]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[BSc Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.6pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · no sponsorship required]
