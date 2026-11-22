// DeepL — Staff Site Reliability Engineer, Sovereign Cloud. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#123a52"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#123a52")
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
    #text(size: 9.8pt)[Site Reliability · Immutable Linux · Secrets · Reproducible Builds]
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
Reliability work on a fleet that has no mutable state to drift: thirteen Linux hosts declared as one repository, rebuilt
from pinned inputs, upgraded by switching a generation rather than editing a running machine. That is the property
sovereign hosting actually needs — not a data-residency checkbox, but a platform whose behaviour is a function of the
repository, whose builds are content-addressed, and whose access is issued rather than stored. One flake pins every input
by hash; secrets are sops-encrypted per host and decrypted at activation with that host's age key; SSH is a short-lived
certificate from the fleet's own authority, never a file of standing keys.

The reliability layer is a loop rather than a dashboard: job status, generation age, disk pressure and PSI every fifteen
minutes, paging on any state short of ok and on silence, with the history kept for the postmortem. The gate that CI runs is
the gate the machine passes before it switches, so a green build is a claim about a real host. High-performance Linux is
where I work at the system layer — cgroups for accounting, PSI for pressure, `strace` for syscall behaviour, `tcpdump` for
an MTU that breaks on one path — and where I run a single-GPU inference stack and measure rather than guess.

What I have not done: managed Kubernetes in production, Terraform or Crossplane, a BSI C5 or ISO 27001 audit, or a formal
on-call rotation at company scale. My estate is thirteen machines and one GPU, operated by the person who built it.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Immutable Linux* — declared hosts, generations, no edits on a live system],
  [*Reproducible builds* — pinned hashes, content addressing, shared cache],
  [*Secrets* — sops and age per host, decrypted at activation only],
  [*Identity* — short-lived SSH certificates from a fleet authority, no standing keys],
  [*Telemetry* — fifteen-minute ledger, paging on state and on silence],
  [*Linux performance* — cgroups, PSI, `strace`, `tcpdump`, journald],
  [*Change control* — one gate for CI and host, dry runs, rollback as a pointer],
  [*Compliance* — auditable by construction: decision records, generated docs])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts as an immutable, declared platform: every service a module, every input pinned by hash, and no manual changes on a running machine — the upgrade path is a rebuild, not a patch.
- Made builds reproducible end to end: content-addressed outputs, a shared binary cache and remote builders, so the artefact that runs is the artefact that was built.
- Kept secrets out of the closure: sops-encrypted per host with age, decrypted at activation with that host's key, so the repository holds no credential that outlives its rotation.
- Replaced standing host keys with a fleet certificate authority issuing short-lived SSH credentials, and default-deny network rules between hosts.
- Put one gate in front of every change, identical in CI and on the machine, with dry-run plans for anything destructive, so a mistake fails before it reaches production.
- Kept every generation's parent, making rollback a pointer to a known-good system rather than a repair under pressure.
- Built the telemetry loop reliability work runs on: job status, generation age, disk and PSI every fifteen minutes, paging on any state short of ok and when a service stops reporting.
- Measured rather than guessed on Linux: cgroup accounting to prove where CPU went, PSI to separate I/O starvation from memory pressure, `strace` to see what a process asked the kernel for.
- Documented as a build artefact: hosts, modules, tasks and decisions generated from the same source as the configuration, so an audit trail is the system rather than a parallel narrative.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data integrity and reporting for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Built models that survived bank review, where an unexplained variance was a finding rather than a rounding error.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— platform]
    #linebreak()
    Thirteen hosts, pinned inputs, shared cache and remote builders, one per-host gate, rollback as a pointer.
    https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— security]
    #linebreak()
    A fleet certificate authority issuing short-lived SSH credentials and per-host encrypted secrets, with default-deny
    network rules.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, history kept for
    the postmortem.
  ],
  [
    #text(weight: "bold")[generated documentation] #text(size: 8pt, fill: muted)[— auditability]
    #linebreak()
    References and a queryable graph built from the source of truth, so a stale page fails the build instead of drifting.
  ],
  [
    #text(weight: "bold")[single-GPU inference stack] #text(size: 8pt, fill: muted)[— performance]
    #linebreak()
    Chat, speech-to-text and text-to-speech behind one card, with throughput and queue depth measured and a yielding rule
    for contention.
  ],
  [
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— isolation]
    #linebreak()
    An on-demand guest with capped CPU and memory, a read-only host mount and no egress, for code that should not run on
    the host.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, Munich hybrid commutable by arrangement]
