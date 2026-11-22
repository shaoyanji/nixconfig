// VirtusLab — Linux Hacker & Nix Wizard. Standalone English source.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.2cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#2f3350"))[•], indent: 0.85em, spacing: 0.32em)
#let accent = rgb("#2f3350")
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
    #text(size: 9.8pt)[Nix / NixOS · Linux internals · Python · Reproducible systems]
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
I run a NixOS fleet the way this role describes the work: one flake declares thirteen hosts, each host registers a feature list
instead of a hand-edited machine, secrets are SOPS-encrypted per host, SSH access goes through a certificate authority, and CI
runs the same module gate the machines run. Inputs are pinned and host paths pin their submodules, so a rebuild is a function of
the repository rather than of the day it ran.

Flake architecture is where I do my most careful work. Option surface is what a gate pays for, so modules are keyed, imports only
go downward, and a fact is answered by evaluation rather than by building a machine. The same discipline scales down: the Go risk
engine I built is containerised by a flake, so its toolchain comes out of the lock file and not out of someone's shell history.

Beneath the declaration I work at the systemd and kernel boundary — units and sockets, journald, initrd contents, module
parameters, PSI pressure and generation age are the signals that separate a broken configuration from a sick host, and `strace`
and `tcpdump` are where I go when the boundary itself is the suspect. I have written the services too: a Go binary that turns a
request into a content-addressed specification with an append-only event log, an email archive that classifies its own mail behind
an HTTP API, and Python throughout the tooling.

What I have not run in production: eBPF, `perf` or `valgrind` as diagnostic programmes of my own — my kernel-level work has come
through systemd, journald and PSI rather than through bpf() probes — and I have not worked with GraphDB, Neo4j, Kafka or a Java
codebase at enterprise scale. I would rather say that plainly than let a keyword carry an interview.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Nix / NixOS* — flake architecture, pinned inputs, feature-list hosts],
  [*Reproducibility* — hermetic builds, shared cache, remote builders],
  [*Linux internals* — systemd, cgroups, PSI, initrd, modules, syscalls],
  [*Diagnostics* — `strace`, `tcpdump`, journald, generation and state diffing],
  [*Python* — pipelines, tooling, tests, APIs; not C or Rust interop],
  [*Go services* — event log, HTTP endpoints, one binary, one contract],
  [*Access and secrets* — SSH certificate authority, sops/age per host],
  [*Writing* — design notes, runbooks and docs beside the configuration])

#section("Experience")

#block(breakable: false)[
#job("Founder", "Bountystash", "Jun 2020 – Aug 2025")
- Declared the whole estate in one flake: each host a feature list, each service a module, imports downward only, so option surface stays something a gate can pay for.
- Pinned flake inputs and host submodules, so a rebuild reproduces the repository rather than the machine it happened to run on; generations roll back in one command.
- Encrypted secrets per host with sops and age and issued credentials from the fleet's own SSH certificate authority, so nothing standing on disk outlives the session that needed it.
- Worked the kernel and userspace boundary directly: out-of-tree modules pinned per host, kernel parameters set per machine with the reason beside each exception, initrd and module-load failures diagnosed from journald rather than guessed at.
- Built the telemetry that separates a broken configuration from a sick host: job status, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
- Wrote services in Go and Python with tests: a content-addressed specification with an append-only event log, HTTP endpoints with pagination and idempotent writes, and a mail archive that classifies its own traffic in PostgreSQL.
- Automated recurring operations behind one validated task surface with named arguments, dry runs and JSON output, so a routine change is a command and a wrong argument fails before it runs.
- Kept the answers in the repository: design notes and runbooks beside the configuration, so the person on call reads what the author wrote.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries, including user access, rollout and documentation.
- Managed an international team and built an incentive structure tied to a real-time financial model.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016")
- Advised commercial clients on energy strategy, risk and cybersecurity software, translating both directions between technical and commercial readers.
]

#block(breakable: false)[
#job("Research Assistant", "Fraunhofer ISE", "Mar 2012 – Sep 2012")
- Wrote the C++ application driving a heliostat interferometer and its Python analysis with 3D geometry, then verified the geometry independently in Mathematica.
]

#block(breakable: false)[
#job("Associate Technical Professional", "Halliburton", "Jun 2010 – Sep 2011")
- Field diagnosis of equipment and process failures under time pressure, with a crew and a schedule depending on the answer.
]

#section("Selected Work")
#grid(columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 5pt,
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— flake architecture]
    #linebreak()
    Thirteen hosts, feature lists instead of hand-edited machines, pinned inputs and submodules, one gate per host, rollback as a
    pointer. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— observability]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes, paging on bad state and on silence.
  ],
  [
    #text(weight: "bold")[bountystash] #text(size: 8pt, fill: muted)[— Go service]
    #linebreak()
    Append-only event log, terminal UI and HTTP endpoints from one binary and one contract.
  ],
  [
    #text(weight: "bold")[email-archive] #text(size: 8pt, fill: muted)[— service]
    #linebreak()
    Mail ingested into PostgreSQL and classified, served over a tailnet API with a verdict workflow that records who decided what.
  ],
  [
    #text(weight: "bold")[risk engine on a flake] #text(size: 8pt, fill: muted)[— reproducibility]
    #linebreak()
    A Go toolchain taken from the lock file, the pipeline containerised so the environment is a property of the commit.
  ],
  [
    #text(weight: "bold")[fibtransponder] #text(size: 8pt, fill: muted)[— benchmarking]
    #linebreak()
    A corpus benchmark falsified the first design, so the claim narrowed rather than being defended.
  ])

#section("Education")
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[M.Sc. Renewable Energy Management] #text(fill: muted)[— University of Freiburg]],
  [#text(size: 8pt, fill: muted)[2011 – 2014 · grade 1.8]])
#grid(columns: (1fr, auto),
  [#text(weight: "bold")[B.Sc. Petroleum Engineering] #text(fill: muted)[— Colorado School of Mines, McBride Honors Program]],
  [#text(size: 8pt, fill: muted)[2006 – 2010 · 3.2 GPA]])

#v(4pt)
#text(size: 8pt, fill: muted)[*Languages* — English native, German C1. *Tooling* — Nix/NixOS, Linux, systemd, Python, Go, C++, Bash, SQL/PostgreSQL, sops, git.]

#v(4pt)
#text(size: 7.8pt, fill: muted)[US citizen with German permanent residence, unrestricted EU right to work, no sponsorship needed · Germany, UTC+1, remote or B2B engagement · available 01.12.2026]
