// Nebius — Senior Site Reliability Engineer (DevTools). Native English letter, reproducing the submitted text.
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
#text(size: 8.6pt, fill: muted)[21 November 2026]
#v(0.4cm)
Nebius #linebreak() DevTools, Site Reliability Engineering

#v(0.5cm)
#text(weight: "bold", size: 10.1pt)[Application: Senior Site Reliability Engineer (DevTools)]
#v(0.4cm)

Dear Nebius DevTools team,

25,000 builds a day, 100 TB of artifacts, a monorepo at FAANG scale: the interesting part of that description is not the load, it
is that the tools are a product and the metric is whether a developer's problem is actually gone. That is the same loop I run on my
own infrastructure, only smaller. My fleet is one flake: hermetic, hash-pinned builds from a shared cache and remote builders, each
host a feature list, each service a module, and every generation rollback-able in a single command.

I treat CI as a gate rather than a notification. The same per-host module check runs in CI and on the machine before a change
switches, so a broken definition fails in review instead of in production. For isolation I run microVMs behind a bridge with
udev-attached taps and NAT, which is the same trade-off a build and test fleet makes: cheap, disposable environments without
giving up Linux semantics. Access follows the same rule — short-lived certificates from the fleet's own SSH CA, per-host sops/age
keys, nothing long-lived on disk.

Operations is telemetry plus a human: a sentinel writes job status, generation age, disk and PSI to a ledger every fifteen minutes
and pages when a service goes quiet, with runbooks kept as text in the repository. I build the services too — Go and Python,
PostgreSQL with migrations, an email archive that classifies its own traffic — and I work with agent stacks daily: tiered tool
access, approval gates before destructive actions, outputs checked against requirements, which is directly relevant to a team
experimenting with RAG and agents in its tooling.

The gaps are specific: I have not operated TeamCity, Artifactory or GitLab at your scale, I have not modified GitLab internals or
written TeamCity plugins, and my JVM knowledge is language-level rather than operating Java monoliths in production. My
orchestration is NixOS and systemd rather than Kubernetes, and my infrastructure as code is the flake rather than Terraform. The
50/50 SRE/SWE split is closer to 60/40 in my case: Go and Python services yes, Java/Kotlin depth no.

I am a US citizen with an unbefristete Niederlassungserlaubnis, so no sponsorship is needed for Germany; I am applying to the
Germany or Remote-Europe location, not Amsterdam or London. My German is C1, my English native, and I am available from
1 December 2026. The repository is the honest version of the work: https://github.com/shaoyanji/nixconfig

Kind regards,
#v(0.45cm)
Matt Ji
