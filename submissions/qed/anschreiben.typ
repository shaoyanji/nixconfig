// QED.ai — Infrastructure Engineer (Warsaw). English letter, one page.
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
QED.ai

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Infrastructure Engineer, Warsaw]
#v(0.32cm)

Dear QED team,

the part of your posting I recognised immediately is the bare metal. A machine arrives, boots an installer or a rescue image over the network from
the iVentoy server on my own network — ProxyDHCP, TFTP and HTTP with an ISO library behind it — and then gets an operating system that is a
function of its declaration rather than a hand-built snowflake. Everything after that is watched where it fails first: SMART and NVMe health, ZFS
pool state and scrubs, headroom, pressure stall information, and a ledger of job state and generation age every fifteen minutes.

The fleet behind that is one flake. Every input pinned, every host path pinned to its submodules, every service a module, every host composed by
concatenating a feature list in order. Overlays carry modifications instead of forked files, and options with types and assertions decide what is
legal before anything evaluates. The automation I would point at first is the gate: the same per-host module evaluation runs in CI and on the
machine, so a broken definition fails as a red check rather than as a half-built host; a canary guest built from the host's own modules proves a
configuration before a fleet receives it; and a generation is a pointer, so rolling back is one command at three in the morning.

Your constraint — reusable modules, client data staying in the country — is the one I have built toward rather than at. What I have is a system
designed to be reproduced by someone else months later with no memory of my decisions, and the reason for each architectural choice written into
the repository. That is the closest honest analogue I have to a deployment that has to survive a handover in another country.

Two things I will not blur. First, the office: your posting expects two or three days a week in Warsaw, and I am in Gutach im Breisgau today. I
would rather discuss relocation in the first conversation than have the form and the letter disagree. Second, the stack: no k3s or Kubernetes in
production and no Terraform — my declarative layer is NixOS itself — and no deployment at national health-surveillance scale. I have run thirteen
hosts and one operator, not a data centre, and I would be learning your scale rather than bringing it.

What I bring is the habit the role runs on: make the hardware layer boring, turn a recurring failure into a check, and leave the runbook better
than you found it. I am a US citizen with German permanent residence, so sponsorship is not a question. The repository is the argument:
https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
