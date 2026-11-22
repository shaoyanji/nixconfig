// Nebius — Senior System Engineer (CloudGate), Greenhouse 4377696101.
// Native English source replacing the Nix-built PDF. Firewalling, WireGuard, NAT, telemetry.
#set page(paper: "a4", margin: (x: 1.5cm, y: 1.15cm))
#set text(font: "DejaVu Sans", size: 9.2pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.55em)
#set list(marker: text(fill: rgb("#1d2e3a"))[•], indent: 0.85em, spacing: 0.3em)
#let accent = rgb("#1d2e3a")
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
    #text(size: 9.8pt)[Systems engineer · Linux networking, filtering, declared fleets]
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
My network work is at the host boundary, where forwarding decisions are actually made. A bridge is created and owned by NetworkManager with a gateway address,
STP off and forward delay zero; taps are attached by a udev rule on the add event, because the dispatcher cannot do it — it never sees an event for an interface
it does not manage. NAT runs with the bridge as its internal interface and the uplink as its external one. Each of those is a declaration in the same tree as
the guests it serves, so the forwarding path is reviewable rather than remembered.

Filtering is default-deny with a scope, not a list of holes. Every service declares where it may be reached — LAN only, tailnet only, or both — and the firewall
is generated from that table. Entries get pruned with a date and a reason when the listener behind them goes away, which is how a port that nobody remembers
opening stops being open. Where the ruleset needs something the module cannot express, it is an nftables rule with the comment naming the profile that owns it,
placed in the firewall's start path rather than in a daemon's `openFirewall` — because a daemon's stop command can kill a reload that added the rule and leave
INPUT dropping.

Remote access is a WireGuard mesh rather than exposed ports. The same scope table knows which rows cannot possibly have a tailnet client: broadcast, multicast,
DHCP and PXE do not cross a mesh, so those stay LAN-only by construction and a tailnet row for them would be a hole with no user. Filesystems follow the mesh
when a machine leaves the house — NFS over WireGuard, measured rather than assumed — and the tailnet keeps the direct WireGuard path open where it can.

Telemetry is built to answer "which hop" rather than "is it up". Gatus checks with their thresholds, a sentinel ledger writing job state, generation age, disk
and pressure stall information every fifteen minutes, and packet-level reasoning when a symptom crosses a boundary: counters, `tcpdump`, `strace`, the MTU on
each hop. An MTU fault on one path looks exactly like an application timeout until you read the path, and I have spent the afternoon that teaches you the
difference.

What I have not done is the specialist part of CloudGate. No VPP or DPDK, no eBPF programs in production, no BGP, MPLS, SDN control plane or NFV. My traffic is
fleet-scale, not tens of millions of packets per second through a purpose-built forwarding plane, and my C is tooling with explicit allocation and lifetime
rather than years inside one.

#section("Areas")
#grid(columns: (1fr, 1fr), column-gutter: 14pt, row-gutter: 2pt,
  [*Filtering* — default-deny with per-service scope, nftables rules where modules stop],
  [*WireGuard* — mesh routing, tailnet-only services, direct path where it exists],
  [*Bridge and NAT* — NM-owned bridge, udev-attached taps, NAT to the uplink],
  [*Exposure* — one table deciding LAN, tailnet or neither, with dated prunes],
  [*Diagnosis* — counters, tcpdump and strace; MTU by path, not by guess],
  [*Telemetry* — gatus thresholds, sentinel ledger, page on bad state and on silence],
  [*Fleet* — one flake, pinned inputs, per-host evaluation gate, rollback by pointer],
  [*Code* — Go services, Python tooling, C where lifetime has to be explicit])

#section("Experience")

#block(breakable: false)[
#job("Founder and engineer", "Bountystash", "Jun 2020 – Aug 2025", "Freiburg, DE")
- Built the guest network: NetworkManager-owned bridge with gateway address, STP off and forward delay zero, taps attached by a udev rule on the add event because the dispatcher never sees an unmanaged interface.
- Declared NAT with the bridge as internal interface and the uplink as external, and marked the bridge trusted at the firewall so guest traffic is filtered at the edge rather than twice.
- Wrote exposure as data: a per-service table with LAN and tailnet booleans, generated into the firewall, with rows removed and dated when the listener behind them disappeared — CUPS, uptime-kuma and Plex DLNA all pruned that way.
- Added nftables rules where the module surface stopped, each carrying the profile name as its comment, in the firewall's start path rather than a daemon's `openFirewall`, so a reload cannot be undone by a stop command.
- Routed remote access over a WireGuard mesh: NFS to a laptop away from the LAN, tailnet-only service ports, and LAN-only rows for broadcast, multicast, DHCP and PXE on the grounds that they cannot cross a mesh at all.
- Diagnosed by path: counters and `tcpdump` before a dashboard, `strace` when the process is the suspect, and the MTU on every hop when a stream works until it carries real payload.
- Built the telemetry the rest of it reports into: gatus checks with thresholds, a sentinel ledger of job state, generation age, disk and PSI every fifteen minutes, paging on a bad state and on silence.
- Declared the whole fleet from one flake, gated each host by evaluation before deployment, and kept access short-lived: sops to per-host age keys, host certificates from an own SSH authority.
]

#block(breakable: false)[
#job("Independent projects", "Self-directed", "2023 – present", "Remote")
- fibtransponder: a state machine streaming a bitstream with bounded work per step, because an unbounded step is a latency bug waiting for the wrong input.
- tokenloom: a Rust workspace with a piece table, a ripple re-tokeniser that touches only the changed span, and a 5 ms gate that keeps a keystroke honest.
- Wrote proxy and relay paths where connection state, timeouts and backpressure decide whether a peer that vanishes mid-stream leaks or closes.
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
    #text(weight: "bold")[microVM host networking] #text(size: 8pt, fill: muted)[— bridge and NAT]
    #linebreak()
    NM-owned `brlan`, udev-attached taps, NAT to the uplink, bridge trusted once at the edge.
  ],
  [
    #text(weight: "bold")[exposure table] #text(size: 8pt, fill: muted)[— filtering]
    #linebreak()
    LAN and tailnet scopes per service, generated into a default-deny firewall; pruned rows carry a date.
  ],
  [
    #text(weight: "bold")[VRRP accept rule] #text(size: 8pt, fill: muted)[— nftables]
    #linebreak()
    An nftables rule with its owning profile as the comment, placed where no daemon stop can undo it.
  ],
  [
    #text(weight: "bold")[WireGuard mesh] #text(size: 8pt, fill: muted)[— remote access]
    #linebreak()
    NFS over the mesh when away, tailnet-only ports, and LAN-only rows for traffic a mesh cannot carry.
  ],
  [
    #text(weight: "bold")[fleet-sentinel] #text(size: 8pt, fill: muted)[— telemetry]
    #linebreak()
    Job state, generation age, disk and PSI every fifteen minutes; pages on bad state and on silence.
  ],
  [
    #text(weight: "bold")[nixconfig] #text(size: 8pt, fill: muted)[— the fleet]
    #linebreak()
    Thirteen hosts from pinned inputs, one evaluation gate per host. https://github.com/shaoyanji/nixconfig
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
