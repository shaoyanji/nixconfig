// Sourcegraph — Software Engineer, Platform [IC3]. English letter, one page.
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
Sourcegraph\\
Platform team

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Software Engineer, Platform \[IC3\]]
#v(0.45cm)

Dear Platform team,

the hard part of a control plane is not creating a hundred instances. It is that each of them has an identity, a
history and a way back, and that the person paged at 03:00 can see which of the three changed. I have spent five
years building that property into a smaller fleet, so the shape of the problem is familiar even though the scale is
not.

Thirteen Linux hosts, declared in one repository instead of tended by hand. Every deployment is a generation with a
parent, which makes rollback a pointer rather than a repair under pressure. Every change passes a gate that runs
identically in CI and on the target machine, so a failing check leaves the previous generation serving and the
question "what did we ship" has an answer with a hash on it. The parts a control plane would supply — one entry
surface, named arguments, machine-readable output, an audit trail — I built because the fleet needed them: today the
whole thing is drivable by a script or a colleague without reading the implementation.

The same instinct applies to data. In a Go service I built an append-only request lifecycle with exact hashes over
canonical JSON and a quotient hash over the fields a reviewer actually sees, so deduplication and audit became
properties of the schema rather than something a background job guesses at. That is the kind of decision I would
expect to be making on a platform serving single-tenant instances.

What I have not done, precisely: I have not operated Kubernetes, I have not written Terraform or CDKTF, and I have not
run services in GCP, AWS or Azure. My platform is bare metal, single region, thirteen machines, and the multi-tenant
SaaS problem — upstream providers, inter-cloud connectivity for regulated customers, a contractual SLA — is new work
for me. I am not going to pretend that gap is small; it is the part of this role I would be learning.

What does transfer is the debugging. I find distribution problems at the OS level before I reach for a dependency:
`tcpdump` for MTU and fragmentation, `strace` for syscall behaviour, cgroups and PSI to tell I/O starvation from
memory shortage, nftables rules read back rather than assumed. And on-call: I have run a fifteen-minute telemetry
loop over job status, generation age, disk pressure and PSI for two years, which taught me that silence is usually
not calm, it is blindness.

I am based in Germany with permanent residence as a US citizen, so there is no sponsorship question for a European
role. German is C1 and English is native, so the written communication this team runs on is not a stretch. Working
hours are the one thing I would want to agree on early: I am happy to work until 21:00 CET, which covers the EST
morning, and to shape the rest of the day around the overlap that actually matters.

Yours sincerely,
#v(0.5cm)
Matt Ji
