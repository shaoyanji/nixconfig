// n8n — infrastructure packet (live req: Staff Platform Engineer, Agentic Engineering). English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#7a1f3d"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#7a1f3d")
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
    #text(size: 9.8pt)[Linux Infrastructure · Isolated Job Execution · Self-Hosted Deployment]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[German C1 · English native · US citizen with German permanent residence]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
Self-hosted software lives on someone else's machine, and the deployment instructions are the contract. I have spent five
years on the other side of that contract: thirteen Linux hosts declared in one repository, services as modules, every
input pinned, deployment as a rebuild rather than an edit, and rollback a pointer to the previous generation. Jobs run
bounded and isolated — a declared microVM for the work that must not touch anything else, memory-capped systemd slices for
the coarse case — and a ledger reports job status, generation age, disk pressure and PSI every fifteen minutes, because
a run that leaves state behind shows up as a capacity problem before it shows up as a bug. Go for the services and
tooling, Python and Bash for the rest. I have not run Docker or Kubernetes in production (my hosts are NixOS), and I have
not worked in a TypeScript codebase.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Linux* — systemd, cgroups, PSI, nftables, `tcpdump`, `strace`],
  [*Job execution* — bounded runs, isolation, resource limits, cleanup],
  [*Deployment* — declared hosts, pinned inputs, rebuild instead of edit],
  [*CI/CD* — one gate for CI and host, inventory-driven matrix],
  [*Reliability* — generations with parents, rollback by pointer, canary],
  [*Telemetry* — fifteen-minute ledger, alert on state not volume],
  [*Go and Python* — services, CLI surfaces, tests over canonical data],
  [*Operations* — runbooks as tooling, secrets as data, short-lived access])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Kept thirteen Linux hosts in one declaration: services, storage, firewall, secrets and telemetry as modules, with a written rebuild path per host and no manual edits on a running machine.
- Ran scheduled work as bounded jobs rather than background processes: each one gets a window, a memory cap and an owner, and teardown is the same declaration that created it.
- Isolated the work that must not touch anything else in a declared microVM guest with its own kernel boundary, so a single job could not read its neighbour's state.
- Built the ledger the fleet runs on: job status, generation age, disk pressure and PSI every fifteen minutes, paging on any state short of ok and timing out on silence itself.
- Gated every change with a check that runs identically in CI and on the target host, so a green build cannot mean something different from a healthy machine.
- Deployed by generation with a parent pointer, so recovery is a rollback to a known system and every rollout has a way back that does not depend on who shipped it.
- Documented the deployment path from the same source as the configuration, so an outsider can install it without reading the implementation.
- Hardened the boundary with nftables default-deny, per-host SOPS/age secrets and an SSH certificate authority issuing short-lived credentials.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Turned missing readings into an explicit error budget instead of a quietly good month, keeping history auditable for bank review.
- Ran software rollouts across client systems and documented each one.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer, implemented its analysis in Python with 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[bounded job runner] #text(size: 8pt, fill: muted)[— execution]
    #linebreak()
    Scheduled work with a window, a memory cap and a named owner, torn down by the declaration that created it, so a
    failed run cannot quietly consume the machine for a week.
  ],
  [
    #text(weight: "bold")[microVM isolation] #text(size: 8pt, fill: muted)[— sandbox]
    #linebreak()
    A guest that boots for one bounded job with its own kernel boundary, which is the cheapest way to say that this
    code may not touch anything else.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and on silence
    itself.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— self-hosted deployment]
    #linebreak()
    Thirteen hosts, pinned inputs, one per-host gate under a memory guard, and rollback as a pointer to the previous
    generation.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Every fleet operation behind one surface with validation and help text, so an operator cannot improvise a
    half-step and a wrong argument fails before it reaches a host.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— bare metal]
    #linebreak()
    PXE and iVentoy serving installers and first configuration, so a machine joins the declared fleet instead of being
    assembled by hand.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · Berlin hybrid or remote from Germany]
