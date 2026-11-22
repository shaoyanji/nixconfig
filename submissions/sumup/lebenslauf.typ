// SumUp — Senior DevOps Engineer, Fleet / Cloud Infrastructure, Berlin.
// Native English source replacing the Nix-built PDF. No cloud or web claims.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2f3350")
#let muted = rgb("#5c6b7a")
#let section(t) = block(above: 8pt, below: 2pt)[
  #text(size: 9.8pt, weight: "bold", fill: accent, tracking: 0.07em)[#upper(t)]
  #v(-3pt)
  #line(length: 100%, stroke: 0.5pt + rgb("#c3ced8"))
]
#let job(title, org, when, where) = block(above: 4pt, below: 1pt)[
  #grid(columns: (1fr, auto),
    [#text(weight: "bold")[#title] #text(fill: muted)[— #org]],
    [#text(size: 8pt, fill: muted)[#when]])
  #v(-2pt)
  #text(size: 8pt, fill: muted)[#where]
]

#grid(columns: (1fr, auto),
  [
    #text(size: 19pt, weight: "bold", fill: accent)[Matt Ji]
    #v(-2pt)
    #text(size: 9.8pt)[Platform and reliability engineer · declarative infrastructure · Go]
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
Infrastructure is a repository or it is a rumour. For five years I have run a fleet the first way: one flake declares thirteen
hosts, each host a concatenated feature list, each service a module with a systemd unit and defined failure behaviour, secrets sealed
with sops behind a certificate authority that issues the host keys, and every generation rolled back by pointer rather than by
memory. A change is reviewable before it is applied, and the gate CI runs is the gate the machine passes before it switches — which
is the promise a Terraform plan makes, kept in a different tool.

The same hosts build and serve the software I write: Go services behind an append-only event log, a task control plane with typed
arguments and dry runs, an email archive in PostgreSQL that classifies its own mail, and a sentinel that writes job status,
generation age, disk and pressure into a ledger every fifteen minutes and pages on silence as well as on failure. MicroVM guests run
from the same codebase as their hosts, and a canary proves a configuration before the rest of the fleet sees it.

Before software I was a risk analyst: covered-call hedging for client portfolios, yield models for a solar portfolio above
USD 100M, and ten megawatts of solar PV operated and modelled. Financial work taught me the constraint that shapes platform work —
documentation, access control and an auditable trail are the job, not the paperwork afterwards.

What I have not done is the stack half of this role as written: I have not run production EKS or implemented a service mesh, I have
not designed Terraform modules consumed by other teams, my AWS work is not hands-on EC2, VPC and IAM ownership at scale, and I have
not led a PCI DSS or SOC2 programme. The layer underneath — Linux, systemd, networking, secrets, rollback, telemetry — is where my
depth is, and Kubernetes is the gap I would close first.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Declarative infrastructure* — one flake, hosts as feature lists, services as modules],
  [*Linux and systemd* — kernel tracks pinned per host, units with written failure behaviour],
  [*Delivery* — canary before fleet, rollback as a pointer, one gate for CI and machine],
  [*Secrets and access* — sops per host, short-lived certificates from an own SSH CA],
  [*Reliability* — ledger every fifteen minutes, paging on bad state and on silence],
  [*Automation* — Go and Python behind one validated task surface],
  [*Virtualisation* — KVM microVM guests, isolated bridge, udev-attached taps and NAT],
  [*Writing* — runbooks and docs generated from the configuration they describe])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Declared a whole fleet as one flake: thirteen hosts, each a feature list concatenated in order, each service a module, so option surface stays a cost a gate pays for instead of a copy that drifts.
- Pinned the kernel track and kernel parameters per host, and wrote restart and failure behaviour into the unit rather than into someone's memory of what usually happens.
- Ran KVM microVMs behind an isolated bridge with udev-attached taps and NAT, with a canary host proving a configuration before the rest of the fleet received it.
- Held zero standing secrets: sops-encrypted values with per-host age keys, and SSH access as short-lived certificates issued by the fleet's own authority.
- Served rebuilds from a shared binary cache and remote builders, and made rollback a pointer — every server generation returns to the previous one with one command.
- Ran the same per-host module gate in CI that a machine passes before switching, driven by an inventory file, so a broken host definition fails before it reaches hardware.
- Wrote the services the fleet runs: Go behind an append-only event log, Python for analysis and tooling, PostgreSQL for state, one task entry point with typed arguments, dry runs and JSON output for callers that are programs.
- Closed the monitoring loop: a fifteen-minute ledger of job state, generation age, disk and PSI, with Gatus paging on any state short of ok and on silence.
- Architected a covered-call hedging strategy for client portfolios and audited bug bounty programmes, triaging against known-exploited lists rather than impressions.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Built the financial models and operated ten megawatts of solar PV, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Analysed corporate liability risk and built the internal risk management framework the subsidiaries were then measured against.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem before it is a communication one.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Managed a project pipeline above USD 100M and advised commercial clients on energy strategy, cybersecurity software and risk.
- Ran customer service and support, and devised the sales and marketing strategy for the sustainability practice.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Led safety training for the crew and diagnosed equipment and process failures under time pressure, with a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declarative platform]
    #linebreak()
    Thirteen hosts from one flake, pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[email archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail ingested into PostgreSQL and classified, served over a tailnet API with a verdict workflow that records who decided what.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, called by people and by agents.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— virtualisation]
    #linebreak()
    KVM guests from the same codebase as their hosts, isolated bridge, a canary standing between a change and the fleet.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarks]
    #linebreak()
    A benchmark falsified the first design, so the claim narrowed rather than being defended.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#text(size: 8.4pt)[Thesis: intermittent renewable energy and weather patterns analysed through artificial neural networks — a time-cross-correlation method for wind velocity data.]
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · based near Freiburg, prepared to relocate for office-first Berlin · available 01.12.2026]
