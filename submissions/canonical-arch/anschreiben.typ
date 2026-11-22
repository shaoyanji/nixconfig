// Canonical — Information Systems, Open Source Technical Architect. English letter, one page.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.85cm))
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

#v(0.35cm)
#text(size: 8.6pt, fill: muted)[22 November 2026]
#v(0.35cm)
Canonical #linebreak() Information Systems

#v(0.45cm)
#text(weight: "bold", size: 10.1pt)[Application: Information Systems — Open Source Technical Architect]
#v(0.35cm)

Dear Canonical team,

your posting asks for infrastructure as code at global scale. That is the only way I have run infrastructure, so let me describe what
it looks like when the repository is the whole truth. One flake declares thirteen hosts; a host is a feature list concatenated in
order, a service is a module with a systemd unit and defined failure behaviour; secrets are sealed with sops behind a certificate
authority that issues the host keys; rebuilds come from a shared binary cache and remote builders. The gate CI runs is the gate the
machine passes before it switches, so a host definition that cannot evaluate never reaches hardware, and rollback is a pointer
rather than a sequence someone remembers at three in the morning.

The incident question in the role description is the one I have actually built for. systemd tells you a unit exited; it does not
tell you the work finished, and a green socket is not a done job. A sentinel on my fleet writes job status, generation age, disk and
pressure into a ledger every fifteen minutes and pages on any state short of ok — and on silence, because a monitor that stops
reporting looks exactly like a system with nothing to report. When something breaks I want the postmortem to end in a structural
change: the check that caught it joins the gate, and the same page does not arrive twice for the same reason.

I am also realistic about the half of this role I have not done. I have not run Ubuntu or Debian packaging for tens of millions of
devices, designed internet transit or CDN networking, or led SRE and data-centre engineers. My leadership so far is technical
direction over a fleet this size and a repository other people can follow: I set the gates and the runbooks, review every host
change, and own the rollback decision. The network-scale and organisational parts I would learn from your team, and I would rather
say so now than have it discovered in month two.

What I bring that is harder to hire is the habit of writing the reason down where the machine can check it. My background is energy
risk before it was software — hedging models, yield models for a portfolio above USD 100M, heliostat metrology — and the discipline
that survived from that world is that a number without a provenance is a guess. The same rule produces a configuration that
evaluates, a secret that has an owner, and a runbook that names the command instead of the intention.

Open source is the substrate here rather than the branding, which is why this role interests me more than a generic platform job.
The repository is the honest version of the work: https://github.com/shaoyanji/nixconfig

Kind regards,
#v(0.4cm)
Matt Ji
