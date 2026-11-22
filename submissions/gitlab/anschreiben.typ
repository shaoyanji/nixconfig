// GitLab — Senior Staff SRE, Hosted Runners. English letter, one page.
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
GitLab\\
Hosted Runners, Architecture Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Staff SRE, Architecture Engineering: Hosted Runners]
#v(0.45cm)

Dear Hosted Runners team,

a hosted runner is one of the few places where a stranger's code runs inside your infrastructure on purpose, thousands of
times an hour, and every one of those jobs has to get a machine, be contained, finish, and leave nothing behind. The
containment and the leaving-nothing-behind part is the work I know best, because it is the only way a shared fleet stays
available.

Five years of running a smaller fleets has taught me the shape of that problem. Workloads isolated in declared microVMs and
memory-capped systemd slices, so a job that forks until it dies costs a process rather than a host someone else is using.
Teardown owned by the same declaration that creates the workload, because a slice that leaks per run becomes a fleet that
cannot accept the next job — and that shows up as a capacity bill before it shows up as an incident. A gate that runs
identically in CI and on the machine, a generation per deployment with a parent, and rollback as a pointer, so a bad
rollout has a way back that does not depend on the person who shipped it being awake. And a ledger over job status,
generation age, disk pressure and PSI every fifteen minutes that pages on any state short of ok, with a timeout on silence
itself.

The Go side is real but modest in scale: a service with an append-only job lifecycle, exact hashes over canonical JSON and
tests that fix expected behaviour, plus a streaming protocol implementation with benchmarks. Debugging a fleet is where I
am strongest — `strace` for what a process actually asked for, cgroups and PSI to tell I/O starvation from memory
shortage, `tcpdump` when the network is blamed before it is measured.

What I have not done, exactly: I have not operated Kubernetes in production, I have not built or run an autoscaling
cloud fleet, and my compute is thirteen machines I know intimately rather than thousands of workers I would have to
reason about statistically. Job pickup latency, capacity handover during spikes and usage metering for billing are
problems I understand the shape of and have not solved at your scale. I would be joining as someone who can own a
control-plane component and its operations, not as someone who has already run this fleet.

One practical matter. The posting lists Remote, United States, Canada and the United Kingdom, and I am a US citizen based
in Germany. I am happy to work a US contract or relocate; what I would not want is to discover at offer stage that the req
is tied to residency in a country I am not in. Settling that early saves us both a month.

On the staff dimension: what I can offer is architecture argued in writing, decisions that survive being read six months
later, and mentoring through mechanism rather than review comments — the best change I ever made to a team was a check
that stopped a whole class of incident, and the second best was the document that let someone else find it. I also use AI
heavily and validate its output against the requirement before it reaches production, which your posting wisely names.

Yours sincerely,
#v(0.5cm)
Matt Ji
