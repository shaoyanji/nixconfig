// QED.ai — Infrastructure Engineer (Warsaw).
// Native English source replacing the ad-hoc PDF. Bare metal, NixOS flakes, infrastructure automation.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2b2440"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#2b2440")
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
    #text(size: 9.8pt)[Infrastructure engineer · bare metal, NixOS flakes, automation]
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
The machines I run are mine down to the firmware setting, and that is the part of this role I know best. A box arrives, boots an installer or a
rescue image over the network from the iVentoy server on the internal network — ProxyDHCP, TFTP and HTTP with an ISO library behind it — gets an
operating system that is a function of its declaration rather than a hand-built snowflake, and is then watched at the layer that fails first:
SMART and NVMe health, ZFS pool state and scrub results, filesystem headroom, pressure stall information, and a ledger of job state and
generation age every fifteen minutes.

The fleet is one flake. Every input pinned by the lock file, every host path pinned to its submodules, every service a module, and every host
composed by concatenating a feature list in order — so what a machine runs is readable rather than inferred, and the option surface a change
touches is the surface a gate has to pay for. Overlays carry modifications instead of forked files; options with types and assertions decide
what is legal before anything evaluates.

That gate is the automation I would point at first. The same per-host module evaluation runs in CI and on the machine, so a broken declaration
fails as a red check rather than as a half-built host; a canary KVM guest built from the host's own modules proves a configuration before the
fleet receives it; and a generation is a pointer, so a change that was right and a result that was not are two separate problems with two
separate fixes. Secrets are sops values encrypted to per-host age keys, host access is a short-lived certificate from an own authority, and
nftables is default-deny between hosts.

The constraint your posting names — modules that deploy across many environments where the client's data stays in the country — is the one I
have built toward rather than at. What I have is a fleet designed to be reproduced by someone else, months later, with no memory of my
decisions, and a written reason for each architecture choice in the repository.

What I have not done: no k3s or Kubernetes in production, no Terraform, no deployment at national health-surveillance scale, and no long
stretches of pager duty for a customer estate. My model is thirteen hosts and one operator, not a data centre.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Bare metal* — installs over the network, firmware and boot parameters, disks and filesystems],
  [*Linux systems* — systemd units, sockets, timers, cgroups, PSI, journald, nftables],
  [*Flake management* — pinned inputs and submodules, overlays, module options with assertions],
  [*Automation* — typed task surface, dry runs, JSON output, one exit code per outcome],
  [*Gating* — per-host evaluation in CI and on the machine, canary guest, rollback by pointer],
  [*Observability* — fifteen-minute ledger, thresholds that page on bad state and on silence],
  [*Secrets and access* — sops to per-host age keys, own SSH CA, default-deny network policy],
  [*Services* — Go and Python daemons, PostgreSQL with migrations, a rehearsed restore])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Ran the server lifecycle end to end: PXE netboot for installs and rescue, a declared host definition for everything afterwards, and a generation pointer as the rollback.
- Declared a thirteen-host NixOS fleet in one flake — pinned inputs and submodules, feature-list hosts, overlays instead of forked files, options with types and assertions.
- Gated every change with the same per-host module check in CI and on the machine, so a broken definition fails before it reaches an installer.
- Deployed through a canary: a KVM guest built from the host's own modules proves a configuration before the fleet receives it.
- Watched the hardware layer rather than the dashboard: SMART and NVMe health, ZFS pools and scrubs, headroom, and a netboot path tested instead of assumed.
- Kept secrets and access declarative: sops-encrypted values with per-host age keys, host authentication through an own certificate authority, default-deny nftables.
- Built the evidence loop: job state, generation age, disk and PSI to a ledger every fifteen minutes, paging on any state short of ok and on silence.
- Wrote the services the fleet runs — Go daemons with append-only state, Python ingestion, PostgreSQL with migrations and a rehearsed restore — behind one task surface with typed arguments, dry runs and JSON output.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- Diagnosed a path-specific MTU fault to the boundary that dropped the packet instead of raising an application timeout, and wrote the path down so the next diagnosis starts where the evidence ends.
- fibtransponder: a state machine streaming a bitstream with bounded work per step; a corpus benchmark refuted the first detector design, so the claim narrowed.
- tokenloom: a Rust workspace with a piece table, a ripple re-tokeniser that touches only the changed span, and a 5 ms gate that keeps a keystroke honest.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, and translated findings for readers who were not engineers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012", "Freiburg, DE")
- Wrote the C++ application driving a heliostat interferometer and the Python analysis beside it; verified the geometry independently rather than trusting the first implementation.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011", "Williston, ND, US")
- Troubleshot equipment and process failures on site in twelve-hour shifts, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— the fleet]
    #linebreak()
    Thirteen hosts from pinned inputs, one evaluation gate per host, rollback by pointer. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[iVentoy netboot] #text(size: 8pt, fill: muted)[— provisioning]
    #linebreak()
    ProxyDHCP, TFTP and HTTP with an ISO library: installer or rescue image with no media, no hands.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— monitoring]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— safety]
    #linebreak()
    A guest built from the host's own modules proves a change before an estate receives it.
  ],
  [
    #text(weight: "bold")[mail archive] #text(size: 8pt, fill: muted)[— service]
    #linebreak()
    Go and Python daemons, PostgreSQL with migrations, tsvector and GIN search, a rehearsed restore.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · currently in Gutach im Breisgau; relocation to Warsaw is a real question, not an assumed yes · available immediately]
