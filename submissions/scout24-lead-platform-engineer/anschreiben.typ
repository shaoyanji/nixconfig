// Scout24 — Lead Platform Engineer. English letter, one page.
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
Scout24 #linebreak() Application Platform

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Lead Platform Engineer]
#v(0.4cm)

Dear Scout24 team,

a platform is judged by the teams that use it, not by the team that builds it. I learned that building shared capability for a
thirteen-host fleet and watching where engineers actually went: the paved road won only where it was shorter than the
workaround. So I optimised for shorter — one command with real help text, a dry run that says what would change, and output a
script can consume. Adoption stopped being a communication problem once it became a design property.

The part of your posting I keep coming back to is machine-usable interfaces for agents. I have built exactly that, and it
imposes a discipline that improves the human interface too: typed arguments instead of prose, validation before any side effect,
a stable JSON contract, and no operation an agent can invoke that a person could not. On my fleet the task surface, the turn-log
and archive APIs and the MCP tool mounts all work this way, because an agent that guesses is worse than an agent that fails
loudly. Extending that to a department of twelve engineers and hundreds of users is the work I want next.

Reliability I would bring as practice rather than vocabulary. My loop records job state, generation age, disk and pressure every
fifteen minutes and pages both on a bad state and on silence, because a monitor that dies quietly is indistinguishable from a
system with nothing to report. Deploys reach a canary before anything that matters, rollback is a pointer, and every incident I
have handled ended as a gate or a runbook entry so the same page did not arrive twice.

I will be direct about the gaps. I have not run workloads on AWS or EKS, written TypeScript or CDK, Terraform or Pulumi, and I
have not owned a formal SLI/SLO/error-budget programme at company scale — mine lived as thresholds and alert conditions in the
repository. Those are learnable quickly because the concepts are not new to me: an error budget is a gate that says stop, and an
SLO is a promise written where the system can check it. What I bring that is harder to teach is the build-versus-buy judgement
and the habit of writing the decision down where the next person will find it.

One practical point: I am based near Freiburg, so three on-site days in Berlin is a relocation question rather than a commute,
and I would rather raise it now than at offer stage.

Your posting asks for someone who has led technical work with no established approach and aligned people without formal
authority. That is most of what running your own company is, and the part I would want to keep doing inside a team that owns its
platform.

Kind regards,
#v(0.45cm)
Matt Ji
