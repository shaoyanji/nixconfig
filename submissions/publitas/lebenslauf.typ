// Publitas — Senior IT Operations Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1f3f6b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#1f3f6b")
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
    #text(size: 9.8pt)[IT Operations · Identity and Access · Linux · Automation]
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
Five years running the operations for a fleet that is declared rather than configured: thirteen Linux hosts, every
service a module, every input pinned, every change through a gate that runs identically in CI and on the machine. Access
is the part I care most about and the part most companies do badly. Mine is issued, not stored: a fleet certificate
authority hands out short-lived SSH credentials, secrets are encrypted per host with sops, and nothing reusable survives
the session that needed it. A permission exists for a purpose and expires, which is a stronger control than a quarterly
review nobody reads.

The operational layer is a fifteen-minute loop rather than a dashboard: job status, generation age, disk pressure and PSI
written to a ledger, paging on any state short of ok and on silence itself. Every recurring question became a command,
every second failure became a check, and the runbooks and decision records live in the repository next to the
configuration they describe. I have not administered a Mac estate, an MDM, or an identity provider such as Okta or
Google Workspace, and I have not carried an audit.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Identity and access* — short-lived certificates, per-host secrets, default deny],
  [*Linux operations* — systemd, cgroups, PSI, nftables, `strace`, `tcpdump`],
  [*Declared infrastructure* — one repository, pinned inputs, generations],
  [*CI and gates* — identical check in CI and on the host, no drift],
  [*Telemetry* — fifteen-minute ledger, paging on state and on silence],
  [*Automation* — Python and Go over a validated task surface],
  [*Documentation* — generated from source, decisions recorded as text],
  [*Remote async* — written decisions, reviewable changes, owned outcomes])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran a thirteen-host Linux fleet declared as one repository: services, storage, firewall and secrets as modules, with a documented rebuild path per host and no manual edits on a running machine.
- Replaced standing credentials with issued ones: a fleet SSH certificate authority minting short-lived certificates, per-host encrypted secrets, and default-deny network rules.
- Kept every host on the same gate: the check that runs in CI runs on the machine, so a green build cannot disagree with a healthy host.
- Made change reversible: each generation records its parent, so a bad rollout is a pointer to the previous system rather than an incident under time pressure.
- Built the operations loop: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and when a service stops reporting.
- Turned support into self-service: one task surface with named arguments, help text and JSON output, so routine work needs no ticket and a wrong argument fails before touching a host.
- Wrote the tooling in Python and Go, with tests over canonical data rather than mocks of it.
- Kept the record where the work is: runbooks, policies and decisions as text in the repository, reviewable in the same diff as the change they explain.
- Diagnosed at the system layer: `strace` for syscall behaviour, cgroups and PSI to separate I/O starvation from memory pressure, `tcpdump` for MTU and fragmentation.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and reporting for a solar portfolio above USD 100M, including reconciliation across three measurement feeds.
- Ran software rollouts across client systems and documented each one, so the next rollout started from a written procedure.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.
- Coordinated projects across technical and commercial stakeholders.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Built measurement and analysis tooling in C++ and Python for a heliostat interferometer.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[Zero standing secrets] #text(size: 8pt, fill: muted)[— identity]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host encrypted secrets, so no machine holds
    anything reusable if it is lost.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared fleet]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, rollback as a pointer to the previous
    generation. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, with history kept
    for the postmortem.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— self-service]
    #linebreak()
    Routine operations behind one surface with validation and dry-run plans, so the answer to a request is a command and
    not a ticket.
  ],
  [
    #text(weight: "bold")[agent stack under gates] #text(size: 8pt, fill: muted)[— AI in practice]
    #linebreak()
    Agents dispatched to isolated worktrees with claims, tiered tool access per host, approval before anything
    destructive, and a written gate that decides the outcome.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— Python, classification]
    #linebreak()
    A local archive that classifies its own traffic and answers questions over the result, built to keep data on the
    machine that owns it.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[English native · German C1 · US citizen with German permanent residence: working remotely from Germany needs no Dutch permit; the highly skilled migrant route is available if Amsterdam-based work is ever wanted]
