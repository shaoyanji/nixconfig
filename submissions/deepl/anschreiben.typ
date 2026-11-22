// DeepL — Staff SRE, Sovereign Cloud. English letter, one page.
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
DeepL\\
Sovereign Markets

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Staff Site Reliability Engineer, Sovereign Cloud]
#v(0.4cm)

Dear DeepL team,

a sovereignty promise is only as strong as the platform underneath it. If the build depends on an ambient machine, if the
secret sits on disk, if a host can be edited in place and nobody can reconstruct why, then jurisdiction is a contract term
rather than an engineering property. I have spent five years building the opposite, alone, on a fleet I then had to operate:
thirteen Linux hosts declared as one repository, rebuilt from pinned inputs, upgraded by switching a generation rather than
touching a running system.

That immutability is the part I would bring to Sovereign Markets. One flake pins every input by hash, so behaviour is a
function of the repository and not of the day the machine was installed. Builds are content-addressed and served from a
shared cache with remote builders, so the artefact that runs is the artefact that was built. Secrets are sops-encrypted per
host and decrypted only at activation with that host's age key, and SSH access is a short-lived certificate from the fleet's
own authority — no file of standing keys, nothing in the repository that outlives its rotation. Between hosts the default is
deny.

Reliability is where the promise is kept or lost. The gate CI runs is the gate the machine passes before it switches, so a
green build is a claim about a real host. Every generation records its parent, so rollback is a pointer to a known-good
system rather than a repair at the wrong hour. A sentinel writes job status, generation age, disk pressure and PSI every
fifteen minutes and pages on any state short of ok and on silence itself, because the machine that went quiet is the one
that costs you a weekend. On Linux I work at the system layer when it matters: cgroup accounting to prove where CPU went,
PSI to separate I/O starvation from memory pressure, `strace` for what a process actually asked the kernel for.

What I have not done, stated plainly because a staff role deserves it: no managed Kubernetes in production, no Terraform or
Crossplane, no GitOps controller, no BSI C5 or ISO 27001 compliance audit, and no formal on-call rotation at company scale. My platform
is thirteen machines and one GPU, run by the person who built it. Against that, the parts your posting emphasises —
infrastructure as code held to one standard, observability built before the incident, security fundamentals as practice
rather than policy — are exactly what I do by hand every week.

On AI-native velocity I have something concrete rather than an opinion: agents run against this repository daily under
claims, tiered tool access and approval gates, and the check decides whether output counts. That is how a small team
carries platform work without lowering the bar.

I am a US citizen with permanent German residence, so the work authorisation question is settled, German is C1 and English
native. Munich two days a week is workable from Freiburg by arrangement.

One question I would ask early: when a customer's auditor asks why a change was made six months ago, what do you hand them —
a ticket, a chat thread, or the diff and the decision record next to it?

Kind regards,
#v(0.45cm)
Matt Ji
