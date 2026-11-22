// Langdock — Senior Systems Software Engineer (Linux & HPC). English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.6pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.4pt)[Matt Ji]
  #linebreak()
  #text(size: 9pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau, Germany]
  #linebreak()
  #text(size: 9pt)[matt\@bountystash.com · +49 1733281570]
]

#v(0.4cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.4cm)
Langdock\\
Systems Engineering

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Systems Software Engineer (Linux & HPC)]
#v(0.45cm)

Dear Langdock team,

the sentence in your posting that decided whether I would write this is the last one in the agenda: the engineer who ships
a change owns it in production. That is how I have worked for five years, alone, on systems I then had to be woken up by.

The closest thing I have to your secure agent execution is a sandbox I built because I did not trust my own automation: a
microVM that boots on demand with capped CPU and memory, a read-only host mount, and no route off the tailnet. Untrusted
runbook code runs there, and when it misbehaves the host does not notice. Getting that to be useful rather than merely safe
meant working on startup cost, on what a persistent filesystem has to guarantee, and on what a suspended instance has to
remember when it comes back — which is the same list your posting gives for the agent runtime.

The other half of my week is inference on one card. Chat models, speech-to-text, text-to-speech, all behind a single GPU,
where I measure tokens per second and queue depth instead of guessing, and where the interesting question is not peak
throughput but what happens when a second workload wants the card and something has to yield. Single card, single tenant.
Your scale is not my scale and I will not pretend otherwise.

So, plainly, what is missing: no Slurm or MPI cluster, no RDMA fabric, no multi-tenant accelerator scheduler, no
multi-cloud Kubernetes, and no Bazel monorepo with TypeScript beside Go. My distributed compute is a build farm with remote
builders and a shared cache; my orchestration is a declarative fleet with content-addressed rebuilds. Those answer
different questions with the same discipline — measure first, make failure explicit, keep the rollback real — but they are
not the same systems, and the first months here would be reading your serving path before touching it.

What I would bring on day one is the habit your last paragraph asks for: investigate an unfamiliar system until it explains
itself. Most of what I know came from a system that was behaving badly and a terminal: `strace` on a service that would not
exit, cgroups and PSI to separate I/O starvation from memory pressure, `tcpdump` for an MTU that only broke on one path.
The repository is public, including its mistakes: https://github.com/shaoyanji/nixconfig

One question I would ask early: where does agent startup time actually go today — image or rootfs preparation, the VM boot,
or the first network call — and which of those three has been measured most recently?

Yours sincerely,
#v(0.5cm)
Matt Ji
