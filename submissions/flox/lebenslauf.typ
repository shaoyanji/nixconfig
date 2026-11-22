// Flox — Member of Technical Staff, Infrastructure & Operations. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f4858"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2f4858")
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
    #text(size: 9.8pt)[Nix · Hermetic Builds · Fleet Infrastructure · Release Engineering]
  ],
  [
    #align(right)[
      #text(size: 8.4pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
      #linebreak()
      #text(size: 8.4pt)[matt\@bountystash.com · github.com/shaoyanji]
      #linebreak()
      #text(size: 8.4pt)[German C1 · English native · US citizen, German permanent residence]
    ]
  ])
#v(-4pt)
#line(length: 100%, stroke: 0.9pt + accent)

#section("Profile")
I build with Nix every day and have for five years: 1,400 files and thirteen hosts in one flake, every input pinned in
a lock file, every host a feature list of modules rather than a hand-built machine, and every deployment a generation
with a parent so a rollback is a pointer to the previous one. Rebuilds come from a shared binary cache and remote
builders; CI runs the same per-host module gate the machines run, so a green check means the derivation evaluates and
the configuration it produces is the one that deploys. Before that I spent a decade on the commercial side of energy
assets, which is where I learned to price things in cost per unit rather than in uptime adjectives. I have not worked
on Nixpkgs itself, I have not run a public cache at Flox's scale, and my cloud is bare metal rather than AWS.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Nix* — flakes, modules, overlays, pinned inputs, `nix build` as the only path],
  [*Hermetic builds* — lock-file identity, content addressing, reproducible rebuilds],
  [*Release engineering* — generation pinning, rollback as a pointer, gated promotion],
  [*CI* — inventory-driven matrix, per-host module gate, same check as the host],
  [*Caches and builders* — substituters, remote builders, cache-miss triage],
  [*Linux* — systemd, cgroups/PSI, nftables, tcpdump, strace],
  [*Go and Python* — services, CLI surfaces, tests over canonical data],
  [*Telemetry* — fifteen-minute ledger over job, generation, disk and PSI])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Kept one flake describing thirteen hosts: each host is a feature list concatenated in order, each service a module, and `nix build` is the only path to a running machine.
- Pinned every input in `flake.lock`, so a rebuild months later produces the same derivation rather than something that merely compiles today.
- Deployed by rebuild and generation switch, never by editing a host: the configuration is the artefact and the store path is its identity.
- Made rollback structural: a generation keeps its parent, so returning to a known-good system is a pointer rather than a repair under pressure.
- Ran a shared binary cache and remote builders, and treated a cache miss as an event worth explaining — either an input changed or the cache is wrong.
- Built an inventory-driven CI matrix that evaluates and gates one host per process, the same module check the host applies locally, so CI and the machine cannot disagree.
- Wrote the telemetry loop: job status, generation age, disk pressure and PSI every fifteen minutes, reporting any state short of ok and keeping the history.
- Made the repo queryable rather than prose: a knowledge graph over hosts, modules, tasks and docs, so "what touches what" is a query and not a search through thirty files.
- Wrote the Go service behind the data model: append-only events, exact hashes over canonical JSON, tests that fix expected behaviour.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M: measurement pipelines, reconciliation across three feeds, deviation analysis.
- Replaced guesswork on missing readings with an explicit error budget, keeping history auditable years later.
- Ran software rollouts across client systems and documented each one.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised clients on energy strategy and risk, with data models as the basis of every recommendation.
- Carried a project pipeline above USD 100M.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and implemented its analysis in Python, including 3D geometry.
- Worked in measurement campaigns where a result had to be reproducible, not plausible.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Fixed equipment and process problems in the field, under time pressure and without a second attempt.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— the repository]
    #linebreak()
    Thirteen hosts, 1,400 files, one flake: modules, secrets, telemetry, CI, docs and a task surface, all evaluated
    and gated. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[per-host module gate] #text(size: 8pt, fill: muted)[— CI]
    #linebreak()
    A check that asserts the module system and host assertions, run per host in its own process under a memory guard,
    so a fleet-wide sweep never becomes one host's OOM.
  ],
  [
    #text(weight: "bold")[binary cache and builders] #text(size: 8pt, fill: muted)[— build economy]
    #linebreak()
    Substituters and remote builders configured as data, with the failure modes named: cache miss, builder capacity,
    and a rollback that has to work on the bad day.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok, and a timeout on
    silence itself.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only request lifecycle with exact and quotient hashes over canonical JSON, so identity and audit are
    schema properties rather than an inference.
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
#text(size: 7.8pt, fill: muted)[German C1 · English native (US citizen) · German permanent residence, no sponsorship needed · remote from Germany, on-call included · available immediately]
