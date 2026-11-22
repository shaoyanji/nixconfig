// Adyen — GenAI Platform Engineer. English letter, one page.
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
Adyen\\
GenAI Platform team

#v(0.55cm)
#text(weight: "bold", size: 10.1pt)[Application: GenAI Platform Engineer (Amsterdam)]
#v(0.45cm)

Dear GenAI Platform team,

a platform succeeds when the second team does not have to solve the first team's problem again. That is the test I have
been building against for five years: a registry where a new service composes existing parts, one entry point for every
operation with named arguments and validation, documentation generated from the same source as the configuration, and a
gate that runs identically in CI and on the machine so a green build cannot disagree with a healthy host.

Two parts of your posting are the work I would want to own. The first is *developer experience for people building on
top of the platform* — paving the path from experiment to production so nobody re-solves model access, tool wiring or
deployment. My version of that is a task plane where a colleague acts without reading the implementation, and where a
wrong argument fails before it touches a host. The second is *guardrails as a mechanism rather than a policy document*:
validation before action, dry-run plans, per-host encrypted secrets, short-lived credentials from a fleet certificate
authority. For AI systems this is where the interesting engineering sits, because the failure modes are wide, quiet and
expensive.

I should be precise about my AI work, since a GenAI platform role deserves precision rather than enthusiasm. I run LLM
agents daily against a real repository: isolated worktrees, mandatory claims before edits, a written gate the agent must
pass, a human who merges. That has taught me most of the practical failure modes — confident wrong summaries, patches that
compile and do not work, cost that drifts when nobody measures it — and it has made me treat evaluation as a build
artefact rather than a vibe. What I have not done is operate a shared GenAI platform for other teams: no Kubernetes, Helm
or Argo CD in production, no vLLM serving, no LiteLLM or Langfuse deployment. My cloud is rented bare metal and my runtime
is NixOS with microVMs, which answers container and isolation questions with different machinery.

The observability side, by contrast, is not a gap. I built the loop my platform runs on: job status, generation age, disk
pressure and PSI every fifteen minutes, paging on any state short of ok and on silence itself, with the history kept
because the interesting question always arrives after the incident. Python is where I write services and APIs; Go where a
process must hold state under concurrency; Linux at the systemd, cgroup and syscall layer on both on-premises and cloud
hardware.

On location: the posting is office-first, so I am applying to Amsterdam with the intention of relocating, not to work
remotely from Germany. I am a US citizen on German permanent residence, which does not transfer, so this needs Adyen's
support under the highly skilled migrant route — I would rather state that in the first conversation than at contract
stage. German is C1, English native, and I am willing to learn Dutch.

I would like to know which capability your internal teams ask for most often and which one you wish they would stop
asking for — the second answer usually says where the platform should standardise instead of customise.

Yours sincerely,
#v(0.5cm)
Matt Ji
