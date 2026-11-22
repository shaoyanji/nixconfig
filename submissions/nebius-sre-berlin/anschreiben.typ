// Nebius — Senior Site Reliability Engineer. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · github.com/shaoyanji]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Nebius\\
Site Reliability Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer (SRE)]
#v(0.45cm)

Dear Site Reliability team,

a GPU cloud is a bet that software can make expensive, failure-prone hardware behave like a dependable service. That bet is
won or lost in the boring places: whether a node that quietly loses its network is noticed before a customer notices,
whether a bad rollout has a way back that does not depend on the person who shipped it being awake, and whether the
numbers you page on mean anything.

I have spent five years on the small version of that problem and I know where my experience stops. Thirteen bare-metal
Linux hosts, declared in one repository rather than tended by hand: pinned inputs, a gate that runs identically in CI and
on the machine, a generation per deployment with a parent, and rollback as a pointer instead of a repair under pressure.
A ledger checks job status, generation age, disk pressure and PSI every fifteen minutes and pages on any state short of
ok, with a timeout on silence itself, because the failure that hurts is the one that stopped reporting. On the network
side, nftables default-deny, a WireGuard mesh, an own DNS zone and an SSH certificate authority with short-lived
credentials, with MTU and fragmentation problems proven by `tcpdump` rather than guessed at.

The diagnostic habit is the part that transfers most directly. I reach for the kernel before I reach for a hypothesis:
`strace` for what a process actually asked for, cgroups and PSI to tell I/O starvation from memory shortage, memory-capped
slices so a leaking workload costs a process and not a node. On a platform where one bad node can idle a rack of GPUs,
attributing a symptom to its real layer is most of the job.

What I have not done is worth being exact about. I have not run Kubernetes, Docker or Helm in production, I have not used
Ansible, Salt or Terraform, and my compute is thirteen machines rather than a GPU fleet with an orchestration layer above
it. My configuration management is a flake, which is a real answer to the same problem and not the same tool. I have also
not operated at a scale where distributed-systems failure modes become ordinary rather than exceptional.

Berlin hybrid works for me: I am based in Germany with permanent residence as a US citizen, so there is no sponsorship
step, German is C1 and English is native. I would rather move for a team that owns its platform than stay remote from one,
and I am happy to discuss what office rhythm the Berlin team actually keeps, since your listing and the aggregator
description disagree on that point.

One question I would enjoy hearing answered: at your growth rate, what breaks first — the hardware, the orchestration, or
the on-call rotation's ability to keep up with both?

Yours sincerely,
#v(0.5cm)
Matt Ji
