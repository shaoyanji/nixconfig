// Flox — Member of Technical Staff, Nix Packaging.
// Native English source replacing the ad-hoc PDF. Packaging, hermetic builds, flakes, module patterns.
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
    #text(size: 9.8pt)[Nix packaging and platform engineer · hermetic builds · flakes]
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
Three years of running a real fleet on Nix taught me the parts of packaging that are not compile errors. Pinning a source is easy until the
upstream hash moves; a patch applies until the file it edits is refactored; a dependency bump takes a module with it and the failure surfaces
two hosts later, at evaluation. My answer to that is an evaluation gate that covers the whole host rather than the package: if the
declaration cannot evaluate, nothing is built and nothing is switched, so the cost of being wrong is a red check instead of an outage.

The build path is hermetic by construction. A flake pins every input, builds run in the sandbox with the network closed, and the result is
served from a shared binary cache with remote builders doing the compiling. Reproducibility is not a slogan here: the same commit produces
the same store paths, and a generation is a pointer, so a build that was right and a result that was not are two separate problems with two
separate fixes.

The patterns are the ones nixpkgs itself uses. Outputs are assembled once and projected per host and per kind; overlays carry the
modifications instead of forking files; the module system does the composition, with options, types and assertions deciding what is legal
before anything evaluates; and small library functions in `lib/` keep the repeated shapes from being copy-pasted into a hundred modules. The
same repository evaluates for NixOS and for nix-darwin from one module set, which is where the cross-platform habit comes from rather than
from a porting project.

What I have not done: I have not committed to nixpkgs upstream, maintained a package in the official set, or built a multi-tenant package
service. No RPM, deb or apk packaging, no npm, Cargo or PyPI registry work beyond consuming those ecosystems, and no ownership of a large
C/C++ build system. My packaging is deep on my own software and its dependencies, and the gaps are real.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Flakes* — pinned inputs, hermetic evaluation, outputs projected per host and kind],
  [*Packaging* — sources pinned, patches applied, hashes verified, builds without network],
  [*Module system* — options, types, assertions, composition instead of forking],
  [*Overlays and lib* — modifications layered, repeated patterns in library functions],
  [*Build infrastructure* — remote builders, shared binary cache, capacity as a budget],
  [*Cross-platform* — one module set evaluated for NixOS and nix-darwin],
  [*Failure modes* — moved hashes, stale patches, dependency drift, caught at evaluation],
  [*Operations* — sentinel ledger, alert thresholds, canary before fleet, rollback by pointer])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Declared a thirteen-host fleet in one flake: outputs assembled once and projected per host and kind, inputs pinned by the lock file, and every service packaged as a module whose source cannot drift from the pin.
- Kept the build path hermetic: sandboxed builds with the network closed, remote builders for the compiles that matter, a shared binary cache for the results, and cache and builder capacity watched as a budget rather than discovered by a timeout.
- Gated packaging at evaluation instead of at build: a per-host module evaluation runs in CI and on the machine, so a moved hash or a stale patch fails as a red check rather than as a half-upgraded host.
- Layered modifications with overlays and pulled repeated shapes into `lib/` functions, so a change to a pattern is one edit rather than a sweep through every module that copied it.
- Used the module system as the contract: options with types, defaults and assertions, composition where a fork would have been easier, and an option surface that a gate pays for instead of a copy-paste that silently diverges.
- Evaluated one module set for two platforms — NixOS hosts and nix-darwin — with platform-specific pieces behind conditions rather than in separate trees.
- Made a release a pointer: the generation rolls back with one command, so a build that was reproducible but wrong is a rollback rather than an incident review.
- Packaged and operated the services that use all of this: PostgreSQL with migrations, a mail archive, Go and Python services, and a task surface with typed arguments, dry runs and JSON output.
- Ran the reliability loop over the same fleet: job status, generation age, disk and PSI to a ledger every fifteen minutes, paging on any state short of ok and on silence.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including rollout, access and the documentation that made it repeatable.
- Managed an international team and built an incentive structure tied to a live financial model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating both directions between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it, then verified the geometry independently in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Diagnosed equipment and process failures in the field under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— flakes and packaging]
    #linebreak()
    Thirteen hosts, pinned inputs, hermetic builds, overlays, library functions, one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— reproducibility]
    #linebreak()
    One validated surface with typed arguments, dry-run plans and JSON output, so the release path runs the same way twice.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— packaged service]
    #linebreak()
    A module plus a PostgreSQL schema: migrations, tsvector and GIN search, an upsert keyed on message_id.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— measurement]
    #linebreak()
    A benchmark falsified its own seed-only claim, so the claim narrowed instead of the measurement being explained away.
  ],
  [
    #text(weight: "bold")[tokenloom] #text(size: 8pt, fill: muted)[— Rust workspace]
    #linebreak()
    A cargo workspace behind a pinned dev shell: piece table, ripple re-tokeniser, acceptance tests holding the invariant.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · remote in CET from Gutach im Breisgau · available 01.12.2026]
