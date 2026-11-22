// Actian — Director of Platform Engineering. Self-contained Typst.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 8.7pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.45em)
#set list(marker: text(fill: rgb("#3b2f6b"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#3b2f6b")
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
    #text(size: 10pt)[Platform & Knowledge-Graph Engineer · Linux, Go, Nix]
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
I build the layer that tells an organisation what it owns and whether a change is safe: a declarative
knowledge graph over code, hosts, modules, docs and tasks, an epistemics table that names which source
settles which claim, and gates that run the same check in CI and on the machine. Ten years of systems and
software, five of them owning a thirteen-host Linux fleet end to end. I have built this alone, at the
scale of one engineer: my graph has 38 host nodes, 330 module nodes, 250 tags and 1,772 edges, and it
answers "what touches what" without a grep. What I have not done is hire, structure or manage a platform
organisation, and I have not run Kubernetes or a Terraform estate. A director role needs both; this is the
honest starting position, not a gap discovered in month two.

#section("Platform & Knowledge Graph")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 3pt,
  [*Graph as the index* — 1,772 edges over 38 hosts, 330 modules, 250 tags, 79 docs and 63 skills; structure is a query, not a search],
  [*Lineage of a claim* — an epistemics table records which source settles which statement, so authority is compiled rather than argued],
  [*Ownership boundaries* — modules, profiles and leaves with imports running one direction; one name per file, proved by a registry check],
  [*Verification gates* — the same module gate in CI and on the host; a failed check leaves the previous generation running],
  [*AI-assisted operations* — agent skills with a compiled index, a turn ledger for coordination, and gates the agent must pass rather than promises it must keep],
  [*Telemetry* — job status, generation age, disk pressure and PSI every fifteen minutes; a page on any state other than ok],
  [*Data* — PostgreSQL with append-only events; content-addressed specifications; auditability by construction],
  [*Security* — SOPS/age, short-lived SSH certificates, default-deny, least privilege])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Built a declarative platform over thirteen Linux hosts: desired state in one repository, machines converge to it, no hand edits on a target.
- Wrote the knowledge graph that indexes hosts, modules, tags, docs and tasks — 1,772 edges — so a change can be scoped by query instead of by recollection.
- Added an epistemics table that states which artefact answers which question, which turned documentation from prose into a checked contract.
- Made every change pass a gate that runs in CI and on the host; rollback is a pointer to the previous generation, not a rebuild.
- Ran observability as a ledger: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state other than ok.
- Automated operations in Go, Python, Bash and Nix behind a single task surface, including Go services on PostgreSQL with append-only events.
- Provisioned bare metal with PXE and iVentoy through first configuration to rebuild.
- Treated the network as code — WireGuard, nftables default-deny, internal DNS, MTU faults found with tcpdump — and served web workloads behind nginx with TLS from an internal CA.
- Kept secrets per host with SOPS and age, access on short-lived certificates, privileges at the minimum.
- Priced and hedged weather derivatives and advised clients as internal risk manager.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Managed 10 MW of solar PV assets in a portfolio above USD 100 M, and built the models the decisions rested on.
- Ran software and IT administration for the company and its subsidiaries, supporting field technicians directly.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Held a director title with client-facing ownership of a pipeline above USD 100 M.
- Advised clients on cybersecurity software and risk management, translating technical risk for non-technical boards.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Measured heliostat inaccuracies with interferometry and wrote the C++ acquisition software.
- Wrote Python tooling for analysis and 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Led two frac crews carrying more than USD 3 M of contract volume per week, and owned crew safety training.

#section("Selected Projects")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 4pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform and graph]
    #linebreak()
    One flake declares thirteen NixOS hosts; the knowledge graph projects hosts, modules, tags, docs and
    tasks into 1,772 queryable edges, and the docs budget and prose gates run on the same repository.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    An immutable, content-addressed specification from one request: append-only events, a terminal
    interface and curl endpoints from one binary, persisted in PostgreSQL.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— data reporting]
    #linebreak()
    CISA's known-exploited catalogue as a time series in plain SVG, exposure clustered by remediation
    effort — compliance evidence generated rather than assembled.
  ],
  [
    #text(weight: "bold")[risk-calc] #text(size: 8pt, fill: muted)[— Go and pipelines]
    #linebreak()
    Green's theorem over stochastic polygons: a Go fuzzer generates shapes, a Nushell and Awk pipeline
    drives the computation.
  ])

#section("Skills")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Platform* — declarative configuration, graph queries, module boundaries, gates],
  [*Linux* — NixOS, systemd, cgroups/PSI, journald, tcpdump],
  [*Automation* — Go, Python, Bash, Nix; task surfaces and runbooks],
  [*Data* — PostgreSQL, append-only events, content addressing, REST],
  [*AI tooling* — agent skills, compiled indexes, turn ledgers, verification gates],
  [*Networking* — WireGuard, nftables, DNS, MTU, TLS/PKI],
  [*Cloud* — Oracle Cloud hosts, one AWS Lambda project; no Terraform estate],
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
