// Catawiki — Platform Engineer. Self-contained Typst.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 8.7pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.45em)
#set list(marker: text(fill: rgb("#8a1c1c"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#8a1c1c")
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
    #text(size: 10pt)[Platform & Developer-Experience Engineer · Linux, Go, Nix]
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
I build the layer that lets other engineers ship without touching infrastructure: a declared fleet, one
task surface as the front door, gates that run the same in CI and on the host, and telemetry that answers
"what changed" before anyone asks. Ten years of systems and software, five of them owning a thirteen-host
Linux fleet end to end. Cost is a design input for me, not a monthly surprise: ARM over x86, microVMs over
VMs, build cache instead of recompiling. What I have not done is run Kubernetes in production, write
Terraform or Ansible, or operate a Prometheus and Grafana stack. Those are the three bars in this advert I
do not clear yet, and the letter says so.

#section("Platform & Developer Experience")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 3pt,
  [*Self-service front door* — one task surface and a compiled index; engineers act without asking the platform owner],
  [*Gates, not reminders* — the same module check in CI and on the host; a failure leaves the previous generation running],
  [*Telemetry* — job status, generation age, disk pressure and PSI every fifteen minutes; a page on any state other than ok],
  [*Cost as a constraint* — ARM boards, microVMs, build cache and store substitution measured against a cheaper baseline],
  [*Declarative state* — hosts are functions of feature lists; no hand edits on a target, a rebuild is a described path],
  [*Knowledge as data* — a graph of 1,772 edges over hosts, modules, tags, docs and tasks; structure is a query, not a search],
  [*Reversibility* — rollback is a pointer to the previous generation, exercised rather than hoped for],
  [*Security by default* — SOPS/age, short-lived SSH certificates, default-deny, least privilege])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built a self-service platform over thirteen Linux hosts: desired state in one repository, machines converge to it, and nobody logs in to fix a host by hand.
- Made the task surface the only interface an operator needs for provisioning, checks, rollback and incident notes.
- Ran every change through a gate that executes in CI and on the host, so a red check never reaches production and rollback is a pointer move.
- Ran observability as a ledger: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state other than ok.
- Wrote the platform's index as a graph — 1,772 edges over hosts, modules, tags, docs and tasks — so impact is scoped by query.
- Automated operations in Go, Python, Bash and Nix, including Go services on PostgreSQL with append-only events.
- Provisioned bare metal with PXE and iVentoy through first configuration to rebuild.
- Treated cost as a design input: ARM over x86, microVMs over VMs, build cache and store substitution instead of recompiling.
- Ran the network as code — WireGuard, nftables default-deny, internal DNS, MTU faults found with tcpdump — and served web traffic behind nginx with TLS from an internal CA.
- Kept secrets per host with SOPS and age, access on short-lived certificates, privileges at the minimum.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Managed 10 MW of solar PV assets in a portfolio above USD 100 M, and built the models the decisions rested on.
- Ran software and IT administration for the company and its subsidiaries, supporting field technicians directly.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy, risk management and cybersecurity software.
- Owned a client-facing pipeline above USD 100 M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies with interferometry; wrote the C++ acquisition software and Python analysis tooling.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Led two frac crews carrying more than USD 3 M of contract volume per week, and owned crew safety training.

#section("Selected Projects")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    One flake declares thirteen NixOS hosts, nginx with TLS, an SSH CA, SOPS secrets and a task surface;
    CI and the host execute the same module gate, and the docs carry a line budget.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    An immutable, content-addressed specification from one request: append-only events, a terminal
    interface and curl endpoints from one binary, on PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— telemetry as reporting]
    #linebreak()
    CISA's known-exploited catalogue as a time series in plain SVG, exposure clustered by remediation
    effort: a recurring report an on-call engineer can read at 3 a.m.
  ],
  [
    #text(weight: "bold")[risk-calc] #text(size: 8pt, fill: muted)[— Go and pipelines]
    #linebreak()
    Green's theorem over stochastic polygons: a Go fuzzer generates shapes, a Nushell and Awk pipeline
    drives the computation.
  ])

#section("Skills")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Platform* — self-service surfaces, declarative configuration, gates, runbooks],
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Automation* — Go, Python, Bash, Nix; CI checks and delivery gates],
  [*Observability* — ledger health checks, alerting, incident notes; no Prometheus/Grafana stack],
  [*Networking* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Data* — PostgreSQL, append-only events, REST],
  [*Cloud* — Oracle Cloud hosts, one AWS Lambda project],
  [*Not held* — Kubernetes, Terraform/Ansible, GCP])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[MSc Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · 1.8/5.0]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[BSc Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.6pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · available for relocation to Amsterdam]
