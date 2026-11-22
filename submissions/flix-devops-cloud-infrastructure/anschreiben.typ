// Flix — DevOps / Cloud Infrastructure Engineer. English letter, one page.
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
Flix\\
Cloud Platform

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: DevOps / Cloud Infrastructure Engineer (B2B)]
#v(0.4cm)

Dear Flix team,

a train is a remote site with a bad network and nobody on hand to fix it. That is the environment I have been operating in for five
years, at thirteen machines instead of a fleet of vehicles: telemetry collected on the box, written to a ledger every fifteen minutes,
and paged on when it stops arriving rather than when somebody notices. Absence is the signal I trust most, because the failure that
costs a day is always the system that went quiet.

The infrastructure underneath that is declared, not assembled. One repository holds every host, every input is pinned by hash, and a
rebuild is the upgrade path — there is no drift to reconcile because nobody edits a running machine. Builds come from a shared cache
and remote builders, so the artefact that runs is the artefact that was built, and the same gate runs in CI and on the target, so a
green build is a claim about a real host. Every generation records its parent, which makes rollback a pointer instead of a rescue.

On secure transport between endpoints, which is the heart of your trains-to-cloud design: I run a fleet certificate authority issuing
short-lived credentials, per-host encrypted secrets decrypted only at activation, TLS terminated in one declared place with per-vhost
certificates, and a default-deny network between hosts. The discipline is the same one mTLS demands — every endpoint proves itself,
nothing is trusted because of where it sits, and no private key lives in the repository.

The honest part, because a contractor who overstates is worse than one who does not: I have not run Terraform or Terragrunt, I have not
operated AWS, and I have no automotive or IoT device integration behind me. My provisioning language is Nix and my cloud is rented
metal. What I would bring instead is the systems reasoning your posting keeps asking for — Linux down to cgroups and PSI, networking
down to MTU and fragmentation, and the habit of forming a hypothesis before changing anything.

One practical matter worth raising early: your engagement is a B2B service agreement, and I contract through a Polish entity, so the
commercial form is straightforward. I am based in Germany; if the work needs a Warsaw presence rather than remote delivery, that is
the first thing to settle, and I would rather ask now than discover it at contract stage.

A question I would put on the table in a first call: when a vehicle stops sending telemetry, is that currently detected as a missing
heartbeat per device, or inferred from the absence of downstream data? The second is cheaper to build and much harder to trust.

Kind regards,
#v(0.45cm)
Matt Ji
