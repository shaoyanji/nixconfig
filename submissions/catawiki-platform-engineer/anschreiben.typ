// Catawiki — Platform Engineer. English cover letter.
#set page(paper: "a4", margin: (x: 2.3cm, y: 1.9cm))
#set text(font: "DejaVu Sans", size: 9.9pt, fill: rgb("#191919"), lang: "en")
#set par(justify: true, leading: 0.62em)
#let muted = rgb("#5c6b7a")

#align(right)[
  #text(weight: "bold", size: 10.6pt)[Matt Ji]
  #linebreak()
  #text(size: 9.2pt)[Am Burgerhof 4 · 79261 Gutach im Breisgau · Germany]
  #linebreak()
  #text(size: 9.2pt)[matt\@bountystash.com]
]

#v(0.45cm)
#text(size: 8.8pt, fill: muted)[22 November 2026]
#v(0.4cm)
Catawiki\\
Platform Horizontal\\
Amsterdam, Netherlands

#v(0.55cm)
#text(weight: "bold", size: 10.3pt)[Application: Platform Engineer]
#v(0.45cm)

Dear Catawiki Platform Team,

I am applying for the Platform Engineer role. Your framing is the one I have worked from for five years:
the platform exists so product teams can deploy, monitor and optimise without drowning in infrastructure.
I have built that for one engineer's scale — my own — and the principles are the ones in your advert.

The front door matters most. On my fleet the operator touches one task surface; provisioning, checks,
rollback and incident notes all sit behind it, and nobody logs in to fix a host by hand. Every change runs
through a gate that executes in CI and on the host, so a red check never reaches production and rollback is
a pointer to the previous generation rather than a rebuild at 3 a.m. Telemetry is a ledger, not a dashboard:
job status, generation age, disk pressure and PSI every fifteen minutes, a page on any state other than ok.
I keep the platform's own index as a graph — 1,772 edges over hosts, modules, docs and tasks — so "what
does this change touch" is a query. Go, Python, Bash and Nix are how a repeated manual step becomes
something the machine does once, and cost is a design input: ARM over x86, microVMs over VMs, build cache
instead of recompiling.

Now the part your advert asks for that I cannot claim. I have not run Kubernetes in production — containers
were pinned build environments, not clusters I upgraded or scaled. I have not written Terraform or Ansible;
my infrastructure as code is NixOS modules and flake wiring. And I have not operated Prometheus, Grafana or
an OpenTelemetry pipeline; my observability is a custom ledger, journald and PSI. Three of your five
requirements, honestly missing. What I bring into the gap is the habit underneath them: declarative state,
gates before rollout, reversible changes, and telemetry that is written down rather than observed once.

On location: your role asks for two days a week in Amsterdam and offers relocation support, which is the
arrangement I would take. I live near Freiburg, hold German permanent residence as a US citizen, and would
need the Dutch permit route your advert mentions — I would rather say that now than discover it at offer
stage. German is C1, English native.

Yours sincerely,
#v(0.5cm)
Matt Ji
