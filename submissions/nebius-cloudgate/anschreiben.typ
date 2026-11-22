// Nebius — Senior System Engineer (CloudGate). English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.8cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.6em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.32cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.32cm)
Nebius

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior System Engineer, CloudGate]
#v(0.32cm)

Dear Nebius CloudGate team,

your team owns the software side of external connectivity — IPv4, Cloud Interconnect, egress NAT and a load balancer at tens of millions of packets per second.
The part of that I already do is the forwarding decision itself: a bridge owned by NetworkManager with the gateway address, STP off and forward delay zero; taps
attached by a udev rule on the add event, because the dispatcher never sees an interface it does not manage; NAT with the bridge internal and the uplink
external; and a firewall generated from a per-service table that says LAN, tailnet or neither.

That table is the piece I would carry into a control plane. Exposure is data, not holes: each service declares its scope, the firewall is derived from it, and
rows are pruned with a date when the listener goes away — which is how a port nobody remembers opening stops being open. Where the module surface ends, the
rule is nftables with the owning profile as its comment, placed in the firewall's start path rather than a daemon's `openFirewall`, because a daemon stop can
kill a reload that added the rule and leave INPUT dropping.

Remote access runs over a WireGuard mesh instead of exposed ports, and the same table records which rows cannot have a tailnet client: broadcast, multicast,
DHCP and PXE do not cross a mesh, so they stay LAN-only by construction. Filesystems follow the mesh when a machine leaves the house. When something is wrong
the diagnosis is by path — counters, `tcpdump`, `strace`, and the MTU on every hop, since an MTU fault behaves exactly like an application timeout until you
read the path. Telemetry is gatus thresholds plus a sentinel ledger of job state, generation age, disk and pressure every fifteen minutes, paging on a bad
state and on silence.

What I have not done, so a first call does not have to find it: no VPP or DPDK, no eBPF programs in production, no BGP, MPLS, SDN control plane or NFV. My
traffic is fleet-scale rather than tens of millions of packets per second through a purpose-built forwarding plane, and my C is tooling with explicit
allocation and lifetime rather than years inside one. I would expect to spend the first months reading the pipeline and its load-testing harness before
touching forwarding behaviour.

Practical points: I am based near Freiburg, apply for Amsterdam or remote across Europe, and need no sponsorship as a US citizen with German permanent
residence. German C1, English native. The repository is public: https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
