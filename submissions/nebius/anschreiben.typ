// Nebius — Senior/Staff SRE (Server Infrastructure). English letter, one page.
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
Nebius

#v(0.42cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior/Staff Site Reliability Engineer, Server Infrastructure]
#v(0.32cm)

Dear Nebius team,

the Server Infrastructure role describes the lifecycle I already run at a smaller scale: a machine arrives, gets an operating system over the
network, joins a declared fleet, is watched, and is rebuilt or retired without anyone logging in to edit it. iVentoy serves ProxyDHCP, TFTP and
HTTP with an ISO library behind it, so a bare-metal box boots an installer or a rescue image with no media. NixOS then makes the installed
machine a function of its declaration, so provisioning is a repeatable output rather than a state reached once and defended.

Everything after that is code. One flake declares the fleet, pins its inputs and composes each host from a feature list; a change is gated by
the same module check the machines run and lands as a generation that rolls back in one command. Secrets are sops values encrypted to per-host
age keys, host access is a short-lived certificate from an own CA, and nftables is default-deny between hosts.

Observability is aimed at what fails first. Pressure stall information for IO, memory and CPU; job state and generation age in a ledger every
fifteen minutes; SMART and NVMe health, ZFS pool state, filesystem headroom; gatus checks that page when a service stops answering — and page
again on silence, because a monitor that died quietly looks exactly like a quiet system. When a symptom crosses a network boundary I go to the
packet path rather than the dashboard: an MTU fault here was isolated by path instead of guessed at from an application timeout. Canaries do the
same for change: a KVM guest built from the host's own modules proves a configuration so a bad rollout costs one guest, not an estate.

What I would be learning rather than doing on day one: I have not operated thousands of servers, and I have not run a GPU fleet. One host here
serves inference on a GPU and yields the card to a human playing games on it, which teaches contention but not DCGM, GPU health telemetry or
losing a card in a rack. No SaltStack, no Terraform, no IPMI or Redfish in production. Kubernetes is familiar rather than deep, and I have built
health gates and alerts far more often than I have owned formal SLOs for a cloud platform.

What I bring is the habit the role rests on: turn a recurring failure into automation, make the hardware layer boring, and leave the runbook
better than you found it. I am in Germany — one of your listed locations — work in CET, and can start on 01.12.2026. My target is EUR
130,000–160,000. The PXE and fleet setup is in the repository: https://github.com/shaoyanji/nixconfig

Best regards,
#v(0.4cm)
Matt Ji
