// Elastic — Principal Software Engineer I, CI/CD (Platform Engineering Productivity), req 8267186.
// Native English source replacing the Nix-projected PDF. Evidence first, gaps named.
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
    #text(size: 9.8pt)[Platform engineer · CI/CD and release gates · supply chain integrity]
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
The rule from the first commit of my repository is that a change is not finished until a gate has read the built artefact back. That
repository is the CI, the CD and the release process for a thirteen-host fleet, and the gate is the same one in CI and on the machine:
a host definition that cannot evaluate never reaches hardware, and a release is a pointer to a generation rather than a sequence
someone remembers at three in the morning.

The pipeline is hermetic by construction rather than by policy. Every input is pinned, every build happens in the Nix sandbox, and
gates run with the builders switched off, so a check can never quietly spend the build budget it exists to protect. Sweeps that do
need to build are dispatched one host per process under an out-of-memory watchdog, because an unbounded fleet sweep is how a CI box
takes down the machine it is measuring. Deploys are single-writer by design: one host per process, no fleet-wide default, and a dry
plan before any apply. Those gates are cheap to obey, which is why they are obeyed.

Supply chain is where most of the recent work sits. Secrets are sops-encrypted per host with an age key cut from the host's SSH key,
machines authenticate through a certificate authority instead of shared user keys, and self-hosted inputs are pinned per host path so a
path cannot silently refetch different code. Vulnerability work is a scheduled pipeline over the CISA KEV catalogue matched against
what the fleet actually runs, ordered by exposure and effort. Content-addressed store paths give provenance for free; what does not
exist here is the org-wide policy layer that makes those guarantees legible to hundreds of engineers.

What I do not bring, stated plainly: no Buildkite, no Argo CD, no production Kubernetes — isolation here is a certificate authority and
a module boundary rather than namespaces and quotas, and GitOps is a flake and a task interface rather than a controller watching a
cluster. I have directed work without managing people: standards, design review and a task surface that others adopted voluntarily,
but not a team of engineers with quarterly goals. The step from fleet scale to org scale is the learning this role would provide.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*CI/CD* — pinned inputs, hermetic builds, one gate in CI and on the machine],
  [*Release gates* — artefact read back, builders off, dry plan before apply],
  [*Supply chain* — sops per host, SSH CA, submodule pins, content-addressed store],
  [*Incident work* — ledger and paging, postmortem ending in a structural check],
  [*Automation* — Go and Python behind one validated task surface],
  [*Security* — KEV-driven patching ordered by real exposure and effort],
  [*Reliability* — job state, generation age, disk and PSI every fifteen minutes],
  [*Writing* — runbooks and decisions recorded where the next person finds them])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Owned CI, CD and release for a thirteen-host fleet: an inventory file decides which hosts a change reaches, one gate per host runs in CI and on the machine, and every generation rolls back with one command.
- Made the pipeline hermetic: all inputs pinned in a flake lock, builds in the Nix sandbox, gates shelling out with the builders disabled so a check cannot consume the budget it protects.
- Guarded the expensive path: fleet sweeps dispatched one host per process under an out-of-memory watchdog, so a broad change cannot take the build host down with it.
- Kept releases single-writer: one host per process, no fleet-wide default, a dry-run plan before any apply, and a rollback documented per host rather than remembered.
- Hardened the supply chain: sops-encrypted secrets per host with the age key cut from the host's SSH key, host authentication through an own certificate authority, and self-hosted submodules pinned per host path.
- Ran vulnerability work as a pipeline rather than an event: the CISA KEV catalogue matched against what the fleet actually runs, ordered by exposure and effort, so patching follows what is exploited.
- Wrote the services behind it in Go and Python: an append-only event log, a single task surface with typed arguments, dry runs and JSON output, and a sentinel writing job state, generation age, disk and PSI to a ledger every fifteen minutes with Gatus paging on bad state and on silence.
- Built risk models for client portfolios and audited bug bounty programmes, triaging reports against known-exploited data rather than impressions.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Built the financial models and operated ten megawatts of solar PV, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Analysed corporate liability risk and built the internal risk management framework the subsidiaries were measured against.
- Managed an international team and built an incentive structure tied to a live financial model, which is where I learned that adoption is a design problem before it is a communication one.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Managed a project pipeline above USD 100M and advised commercial clients on energy strategy, cybersecurity software and risk.
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
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— CI/CD and supply chain]
    #linebreak()
    Thirteen hosts from one flake: pinned inputs, hermetic builds, sops secrets, SSH CA, one gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— platform interface]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, called by people and by agents.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— reliability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[kev-time] #text(size: 8pt, fill: muted)[— vulnerability data]
    #linebreak()
    The CISA KEV catalogue as a time series in static SVG, so a trend is readable before a report exists.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— PostgreSQL]
    #linebreak()
    Mail ingested and classified, served over a tailnet API with a verdict workflow that records who decided what.
  ],
  [
    #text(weight: "bold")[Swirl Engine] #text(size: 8pt, fill: muted)[— Go]
    #linebreak()
    Polygon areas from stochastic data by Green's theorem, with a Go fuzzer generating the shapes that would break it.
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
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · based in Gutach im Breisgau, Germany · available 01.12.2026]
