// Flox — Member of Technical Staff, Security.
// Native English source replacing the ad-hoc PDF. Supply chain, hermetic builds, artefact identity, KEV work.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#3a2438"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#3a2438")
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
    #text(size: 9.8pt)[Security engineer · build-graph and supply-chain defence]
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
The last three years I have spent on the build graph, which is where this role sits. My fleet is a NixOS estate declared by one flake:
every input pinned, host paths pinned to their submodules, builds run in the sandbox with the network closed, and the output is
content-addressed. An artefact is identified by a hash of what produced it, so "which binary is in production" is a question with one
answer and a diff that shows when it changed.

Supply-chain control, concretely: I pin what enters the graph and I verify what arrives from outside it. Binaries pulled from GitHub
releases carry an expected `sha256` that a second party confirms before anything is installed, and the filter that selects an asset is
written to exclude the sidecars — `^sbom`, `.proof`, `.zsync` — so a release cannot quietly redirect the fetch to a different object.
Never a `curl | sh` path in a shipped definition; a pinned digest or nothing.

Hermeticity is the property that makes the rest testable. No network at build time means a dependency cannot be swapped underneath a
build, and a rebuild that does not reproduce is a finding rather than a flake. Where the build touches credentials, they are sops values
encrypted to per-host age keys and decrypted at activation, and host access is short-lived SSH certificates from an own certificate
authority rather than standing keys distributed by hand.

On artefacts and advisory work I am honest about the edges. The inventory I actually keep is the store closure: the set of paths an
artefact depends on, which is exactly what an SBOM is for. I have not emitted CycloneDX or SPDX from it, and no grype, trivy or
osv-scanner runs in my pipeline — I would build that next, and the closure is the half that already exists. The vulnerability half is
real: the CISA KEV catalogue turned into a time series, grouped into effort clusters with exposure per cluster, so patching follows what
is being exploited against what it costs to close.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Supply chain* — pinned inputs, submodules locked, digests verified before install],
  [*Hermetic builds* — sandbox, network closed, reproducibility as a tested property],
  [*Artefact identity* — content-addressed outputs, store closure as the inventory],
  [*Cryptographic keys* — sops encrypted to age, short-lived SSH certificates from an own CA],
  [*Vulnerability work* — CISA KEV as a time series, effort clusters, exposure per cluster],
  [*Access control* — default-deny nftables, grants as a reviewed diff with history],
  [*Evidence and detection* — fifteen-minute ledger, paging on bad state and on silence],
  [*Writing* — findings and threat models an engineer can act on, not a risk register entry])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Declared a thirteen-host NixOS fleet in one flake: inputs pinned by the lock file, host paths pinned to their submodules, so an unreviewed upstream move cannot enter a definition silently.
- Made builds hermetic — sandboxed, no network, content-addressed output — and served them from a shared cache, so the artefact in a host is traceable to the revision that produced it.
- Verified what came from outside the graph: fetched release binaries carry an expected `sha256`, the asset filter excludes `^sbom` and signature sidecars from matching, and a linkage check rejects a binary that does not run on its target.
- Kept secrets out of the repository: sops-encrypted to per-host age keys, decrypted at activation, rekeyed when a host leaves. Host authentication through an own SSH certificate authority with short-lived certificates and a listable principal set.
- Made access a reviewed diff: default-deny nftables, grants declared in the same repository as the systems they protect, so the history answers "who could reach this and since when".
- Ran vulnerability work as a pipeline rather than a report: the CISA KEV catalogue as a time series, effort clusters with exposure per cluster, and bug-bounty programme audits read against exploit status instead of severity prose.
- Built the evidence loop: job state, generation age, disk and PSI to a ledger every fifteen minutes, paging on any state short of ok and on silence, because a monitor that stops reporting looks like a quiet system.
- Gated change at evaluation: the same per-host module check runs in CI and on the machine, so a break fails as a red check before it becomes a deployed artefact.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- Vulnerability operations concept: a sample vulnerability programme built on KEV data — exposure table, effort clusters, a 90-day method and a service model — published on sample data and labelled as sample data throughout.
- tokenloom: a Rust workspace behind a pinned dev shell, where a piece table and a ripple re-tokeniser hold an editor's document state and an acceptance test encodes the invariant.
- fibtransponder: a state machine streaming a bitstream with bounded work per step; a corpus benchmark refuted the first detector design, so the claim narrowed instead of the measurement being explained away.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on cybersecurity software and risk management, and translated findings for readers who were not engineers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it; verified the geometry in Mathematica rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Diagnosed equipment and process failures in the field under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— supply chain]
    #linebreak()
    Pinned inputs and submodules, hermetic builds, content-addressed output, default-deny nftables. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[vulnerability operations concept] #text(size: 8pt, fill: muted)[— programme]
    #linebreak()
    Exposure table, effort clusters, 90-day method and a service model, on sample data that says so.
  ],
  [
    #text(weight: "bold")[secrets and certificates] #text(size: 8pt, fill: muted)[— cryptography]
    #linebreak()
    sops to per-host age keys, rekeyed on host exit; short-lived host certificates from an own CA, principals listable.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— detection]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— automation]
    #linebreak()
    Typed arguments, validation, dry-run plans, JSON output, one exit code per outcome — auditable by construction.
  ],
  [
    #text(weight: "bold")[library fetch] #text(size: 8pt, fill: muted)[— third-party artefacts]
    #linebreak()
    Release binaries only with a pinned digest, sidecars filtered out of the match, linkage checked before install.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · remote, US hours from Germany · available 01.12.2026]
