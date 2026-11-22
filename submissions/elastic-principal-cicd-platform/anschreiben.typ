// Elastic — Principal Software Engineer I, CI/CD. English letter, one page.
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
Elastic #linebreak() Platform Engineering Productivity

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Principal Software Engineer I, CI/CD]
#v(0.32cm)

Dear Elastic Hiring Team,

your description frames the job as making every engineering team ship faster and more securely, with leverage through the work of
others. That is the only kind of platform work I have done: my repository is the CI, the CD and the release process for a thirteen-host
fleet, and the rule from the first commit is that a change is not finished until a gate has read the built artefact back.

The pipeline is hermetic by construction rather than by policy. Every input is pinned, every build happens in the Nix sandbox, and
gates run with the builders switched off, so a check can never quietly spend the build budget it is meant to protect. Sweeps that do
need to build are dispatched one host per process under an out-of-memory watchdog, because an unbounded fleet sweep is how a CI box
takes down the machine it is measuring. Deploys are single-writer by design: one host per process, no fleet-wide default, and a dry
plan before any apply. Those gates are cheap to obey, which is why they are obeyed, and that is the property I would want to reproduce
at Elastic scale.

The supply chain half of the description is where most of my recent work sits. Secrets are sops-encrypted per host with an age key cut
from the host's SSH key, machines authenticate through a certificate authority instead of shared user keys, and self-hosted inputs are
pinned so a host path cannot silently refetch different code. Vulnerability work is a scheduled pipeline over the CISA KEV catalogue
matched against what the fleet actually runs, ordered by exposure and effort, so patching follows what is exploited.
Content-addressed store paths give me provenance for free; what does not exist here is the org-wide policy layer that makes those
guarantees legible to hundreds of engineers, and that is the part of this role I would be learning.

What I do not bring, stated plainly: no Buildkite, no Argo CD, and no production Kubernetes. Isolation here is a certificate authority
and a module boundary rather than namespaces and quotas; GitOps is a flake and a task interface rather than a controller watching a
cluster. I have also directed work without managing people — standards, design review and a task surface others adopted voluntarily,
but not a team of engineers with quarterly goals.

Two practical points I would rather raise now. The posting is for Poland and I am in Germany, so I am asking whether a Germany
contract exists rather than assuming a relocation nobody has agreed to. And on AI: coding agents are the operating layer of this fleet
every day, including the gates and the coordination log, so the description's point about AI reshaping supply chain and scale is not
abstract to me.

I would welcome a conversation about where the CI/CD roadmap is going and which bottleneck you would want addressed first.

Kind regards,
#v(0.4cm)
Matt Ji
