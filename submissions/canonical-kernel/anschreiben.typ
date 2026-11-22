// Canonical — Lead Linux Kernel Engineer, Ubuntu. English letter, one page.
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
Canonical #linebreak() Kernel Team

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Lead Linux Kernel Engineer — Ubuntu]
#v(0.32cm)

Dear Canonical Kernel Team,

I am applying for the Lead Linux Kernel Engineer role. I have worked on Linux systems for more than ten years, and for five of them I
have run a thirteen-host NixOS fleet from one flake: kernels, systemd units, packaging, secrets and CI declared in the same repository.

The kernel is a declared input in that fleet, not a default. Hosts whose NVIDIA drivers require it pin the 6.12 LTS track, desktops
follow the latest stable, modules and parameters are set per host where the hardware needs them, and a canary guest built from the same
definitions is booted before a change reaches a real machine. Every service ships as a module: an explicit unit, socket or timer, its
dependencies named, and a build that runs without network access. That is the packaging discipline I would bring to Ubuntu —
reproducible, reviewable, and gated before it reaches a user's machine.

My C and C++ work is systems-adjacent rather than upstream: C++ software for a heliostat interferometer at Fraunhofer ISE that captured
and processed optical measurement data, Python for the analysis and 3D geometry, and more recently Go and C for the services in my fleet.
On the vulnerability side I built tooling around CISA's Known Exploited Vulnerabilities catalogue and audited bug-bounty programmes, so
advisories are read for what they actually require rather than for what the headline says.

What I have not done is submit patches to Linux mainline, maintain Debian source packages, or carry an Ubuntu kernel through an SRU. I
have consumed and debugged Ubuntu and Debian systems for years, but archive policy, the SRU process and the kernel release cadence would be
learned from your team rather than claimed here. What I can offer is the habit of turning a fuzzy delivery problem into a declared, tested
process, and of bringing other engineers with me — including the writing and review that remote work demands.

I am based in Germany, a US citizen with permanent German residence, and glad to travel for the twice-yearly team events. I would welcome a
conversation about which part of the kernel roadmap needs a lead first.

Yours sincerely,
#v(0.4cm)
Matt Ji
