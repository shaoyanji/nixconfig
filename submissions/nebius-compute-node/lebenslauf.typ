// Nebius — Senior SRE, Compute Node Team (Greenhouse 4766627101).
// Native English source replacing the Nix-built PDF. Hypervisor boundary, microVMs, canary, PSI.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#233043"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#233043")
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
    #text(size: 9.8pt)[Site reliability engineer · KVM guests, node observability, declared hosts]
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
The Compute Node team sits where a guest meets the host, and that is the layer I have built at fleet scale small enough to know every part of it: a
pinned kernel track per host, kernel parameters declared rather than adjusted, every service a systemd unit with defined failure behaviour, and a
generation that rolls back in one command. When a host misbehaves the useful question is which layer lied — user space, the unit, the kernel
parameter, or the declaration that produced it — and each of those has a different piece of evidence.

The guests are microVMs: microvm.nix driving cloud-hypervisor on KVM, with vsock for control, a tap attached to the host bridge and NAT in front of it,
and the guest firewall off because the boundary is drawn on the host that owns the bridge. The guest's store arrives read-only over virtiofs with a
writable overlay, `/var` lives on its own volume so a restart does not reinstall identity, and the ssh host key comes from a persistent share, so a
guest keeps its name across boots. On a host without `/dev/kvm` the definition says so and the runner falls back to TCG instead of dying on a missing
module — a distinction that has to be declared, because discovering it in production means the guest never boots.

That guest is also my canary. It carries its own kernel and root, imports no host chain and therefore none of the host's service tier, so a runbook
can be executed against a real systemd and ssh machine and then thrown away. A configuration proves itself on one guest before the fleet receives it,
and a host whose modules fail evaluation never reaches an installer at all.

Node observability is written rather than consumed: a sentinel records job status, generation age, disk and pressure stall information for IO, memory
and CPU to a ledger every fifteen minutes, `node_exporter` feeds the dashboards behind it, gatus pages on a service that stops answering, and the
same threshold pages on silence — because a monitor that has quietly died looks exactly like a healthy node. Runbooks live as text in the repository,
next to the definition they describe.

What I have not done: no QEMU/cloud-hypervisor internals and no live migration at scale, no NUMA placement or cgroup v2 controller tuning beyond what
systemd gives by default, no perf, eBPF, ftrace or kdump debugging in production, and no GPU, NVLink, InfiniBand or BMC/IPMI hardware lifecycle. My
kernel work is configuration and operations, not hypervisor development.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*KVM guests* — microvm.nix, cloud-hypervisor, vsock, TCG fallback where KVM is absent],
  [*Host/guest boundary* — bridge, tap and NAT on the host; guest firewall off by design],
  [*Guest filesystems* — read-only store over virtiofs, writable overlay, `/var` volume],
  [*Kernel* — pinned track per host, parameters declared, modules loaded by name],
  [*Unit behaviour* — systemd units, sockets and timers with defined failure modes],
  [*Canary* — guest built from the same definitions, proven before the fleet switches],
  [*Node observability* — PSI by resource, generation age, job state every fifteen minutes],
  [*Release* — evaluation gate per host, rollback by pointer, secrets behind an own CA])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Ran microVMs on KVM in production use: cloud-hypervisor behind a tap on the host bridge with NAT, vsock for control, a read-only virtiofs store with a writable overlay, and a separate `/var` volume so guest identity survives a restart.
- Declared the boundary instead of assuming it: guest firewall off because the host owns the bridge, host keys from a persistent share, TCG fallback named for hosts without `/dev/kvm`.
- Used a guest as the canary: its own kernel and root, no host chain imported, so a configuration or a runbook is exercised on one throwaway machine before an estate sees it.
- Pinned a kernel track and kernel parameters per host, loaded modules by name, and kept each service a systemd unit or socket with defined failure behaviour.
- Built the node evidence loop: a sentinel writing job status, generation age, disk and PSI pressure to a ledger every fifteen minutes, with `node_exporter` behind the dashboards and gatus paging on a dead service and on silence.
- Gated every change with the same per-host module evaluation in CI and on the machine, so a broken declaration fails as a red check rather than as a half-built host.
- Kept access and secrets declarative: sops values encrypted to per-host age keys, short-lived host certificates from an own SSH authority, default-deny nftables between hosts.
- Wrote the services the nodes run — Go daemons with append-only state, Python ingestion, PostgreSQL with migrations — behind one task surface with typed arguments and dry runs.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- Diagnosed a path-specific MTU fault to the boundary that dropped the packet rather than raising an application timeout, and wrote the path down so the next diagnosis starts where the evidence ends.
- fibtransponder: a state machine streaming a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input.
- tokenloom: a Rust workspace with a piece table, a ripple re-tokeniser that touches only the changed span, and a 5 ms gate that keeps a keystroke honest.
]

#block(breakable: false)[
#job("Asset Manager", "O3 Energy", "Aug 2016 – Jun 2020", "Dallas, TX")
- Owned data quality and yield models for a solar portfolio above USD 100M, reconciling three measurement feeds into one auditable series.
- Administered software and IT for the company and its subsidiaries; managed an international team.
]

#block(breakable: false)[
#job("Director of Sustainability", "Smart Energy 360", "Aug 2015 – Aug 2016", "Dallas, TX")
- Advised commercial clients on energy strategy, cybersecurity software and risk, translating between technical and commercial readers.
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
    #text(weight: "bold")[microVM canary] #text(size: 8pt, fill: muted)[— guests]
    #linebreak()
    2 vCPU, 2 GB, vsock cid, tap on the bridge, virtiofs store, `/var` volume. Boots its own kernel; thrown away after the runbook.
  ],
  [
    #text(weight: "bold")[host/guest isolation] #text(size: 8pt, fill: muted)[— boundary]
    #linebreak()
    NAT and tap on the host, guest firewall off by design, host keys from a share so identity survives a reboot.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— node telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— declared fleet]
    #linebreak()
    Thirteen hosts, pinned kernels and parameters, one evaluation gate per host. https://github.com/shaoyanji/nixconfig
  ],
  [
    #text(weight: "bold")[task control plane] #text(size: 8pt, fill: muted)[— operations]
    #linebreak()
    Typed arguments, dry-run plans, JSON output, one exit code per outcome; the guest lifecycle runs through it.
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
#text(size: 7.8pt, fill: muted)[German C1 · English native · US citizen with German permanent residence, no sponsorship needed · Gutach im Breisgau, remote in CET · available immediately]
