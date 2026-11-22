// IONOS SE — Staff Network Reliability Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
IONOS SE\\
Karlsruhe

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff Network Reliability Engineer (f/m/d) — req 4971782101]
#v(0.45cm)

Dear Hiring Team,

network reliability is mostly a discipline of distrust: distrust of an assumption, of a dashboard that has always
been green, and of a change nobody can trace. I have spent five years building that distrust into systems. Host and
inter-site connectivity designed once and declared in a repository: nftables default-deny with explicit
allowances, WireGuard tunnels, an own DNS zone, a TLS certificate authority. Faults diagnosed with tcpdump and MTU
analysis instead of an interface restart, then written into the runbook so the next one is cheaper.

The change process matters as much as the design. Every change passes a check that runs identically in CI and on
the machine; a failing check leaves the previous generation serving, so a bad change has a known way back rather
than an improvised one at 3 a.m. A fifteen-minute telemetry loop records job status, generation age, disk pressure
and pressure stall information, and treats silence as a fault rather than as calm.

On AI in operations, since the posting is explicit about it: I use it daily for drafts of configuration, scripts
and documentation, and I never let a generated artifact near a production path before it has been read line by
line and checked against the running system. The failure mode is not a bad model, it is a person who accepted an
answer because it looked confident. My rule is simple — a machine may propose, a check must dispose.

What I have not done is as specific: I have not designed BGP or EVPN fabrics, and I have not operated
carrier-grade switching in a data centre. My networks are fleet-scale: thirteen hosts across sites, built and run
by one person. Data-centre network reliability at IONOS scale is a different order of magnitude, and I would be
learning the protocols and the hardware rather than repeating work I have done. I would rather say that here than
in a third interview.

What should transfer is the operating posture: prove the state before touching it, keep the alert volume low
enough that someone acts, and write down what happened so the next engineer inherits knowledge instead of a
mystery. I am based in Baden-Württemberg — Karlsruhe is about 1.5 hours away — hold German permanent residence as
a US citizen, so no sponsorship is needed, and speak German at C1 with native English.

I would welcome a conversation about which failure modes currently cost IONOS the most network reliability.

Yours sincerely,
#v(0.5cm)
Matt Ji
