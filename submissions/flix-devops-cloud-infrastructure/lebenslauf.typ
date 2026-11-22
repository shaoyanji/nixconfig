// Flix — DevOps / Cloud Infrastructure Engineer. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#5a1f2b"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#5a1f2b")
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
    #text(size: 9.8pt)[Infrastructure as Code · Telemetry · Linux · Secure Transport]
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
Ten years between physical assets and the software that watches them: first yield and cost models for energy installations where a
missing measurement was a real commercial problem, then five years building and operating the Linux platform that collected and
reported those numbers. The estate is declared rather than assembled — thirteen hosts from one repository, every input pinned, every
service a module, rebuilt from a shared cache and remote builders — and it is instrumented the way a remote fleet has to be: job
status, generation age, disk pressure and PSI every fifteen minutes into a ledger that pages on bad state and on silence.

Secure transport between untrusted endpoints is the part that carries over most directly: a fleet certificate authority issuing
short-lived credentials, per-host encrypted secrets, default-deny network rules, and TLS terminated in one declared place. Python and
Go for services and tooling, Bash where it is honest, and the system layer when the answer is there — cgroups for accounting, PSI for
pressure, `strace` for syscall behaviour. What I have not run is Terraform, Terragrunt or AWS, and I have not integrated automotive or
IoT devices; my cloud is rented metal and my provisioning language is Nix.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Infrastructure as code* — one repository, pinned inputs, reproducible by design],
  [*Telemetry and alerting* — fifteen-minute ledger, paging on state and silence],
  [*Linux systems* — systemd, cgroups, PSI, nftables, `strace`, `tcpdump`],
  [*Secure transport* — mTLS-capable TLS termination, fleet CA, short-lived creds],
  [*Secrets* — sops and age per host, decrypted only at activation],
  [*CI/CD* — one gate for CI and host, dry runs, rollback as a pointer],
  [*Automation* — Python, Go, Bash behind a validated task surface],
  [*Operations* — capacity measured, budgets argued with numbers])

#section("Experience")

#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Ran thirteen Linux hosts as a single declaration: services, storage, firewall and secrets as modules, with a documented rebuild path per host and no manual edits on a running machine.
- Built the telemetry path end to end — collection, storage, threshold and absence detection — and paged on both a bad state and a stopped report, because a silent remote system is the expensive one.
- Issued rather than stored access: a fleet certificate authority minting short-lived SSH credentials, per-host sops/age secrets, and default-deny network rules between hosts.
- Terminated TLS in one declared place with per-vhost certificates, and kept the private keys out of the configuration tree.
- Made every build reproducible: inputs pinned by hash, outputs content-addressed, rebuilds served from a shared cache and remote builders, so the artefact that runs is the artefact that was built.
- Put one gate in front of every change, identical in CI and on the machine, with dry-run plans for anything destructive.
- Kept rollback real: every generation records its parent, so recovery is a pointer to a known-good system rather than a repair under pressure.
- Provisioned machines instead of hand-assembling them: network boot, installer image, first-boot join into the declared fleet.
- Measured before optimising: cgroup accounting to prove where CPU went, PSI to separate I/O starvation from memory pressure, `tcpdump` for an MTU that broke on one path only.

#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Turned missing readings into an explicit error budget rather than a quietly good month, and reported variance line by line.

#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy and risk, with data models behind every recommendation.

#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry.

#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure.

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence, history kept for the
    postmortem. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— infrastructure]
    #linebreak()
    Thirteen hosts, pinned inputs, shared cache and remote builders, one per-host gate, rollback as a pointer.
  ],
  [
    #text(weight: "bold")[zero standing secrets] #text(size: 8pt, fill: muted)[— transport and access]
    #linebreak()
    A fleet certificate authority, short-lived credentials, per-host encrypted secrets and default-deny rules between hosts.
  ],
  [
    #text(weight: "bold")[netboot provisioning] #text(size: 8pt, fill: muted)[— fleets]
    #linebreak()
    PXE and installer images that bring a machine into the declared fleet on first boot instead of being configured by hand.
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Every platform operation behind one surface with validation and dry-run plans, so routine work is a command, not a ticket.
  ],
  [
    #text(weight: "bold")[single-GPU inference stack] #text(size: 8pt, fill: muted)[— performance]
    #linebreak()
    Serving behind one card with throughput and queue depth measured, and an explicit rule for contention.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— Albert-Ludwigs-Universität Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(5pt)
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence · contracting through a Polish entity, remote from Germany · available from 01.12.2026]
