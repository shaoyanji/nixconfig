# Lead: smartclip Europe GmbH — Site Reliability Engineer (f/m/d), Observability & Internal Tools

Fit: 3
As of: 22 November 2026
Language: English dossier
Location: Germany, remote-first; on-site in Berlin/Cologne for larger features

## Why interesting

The posting asks for someone who designs systems instead of consuming off-the-shelf SaaS, with end-to-end ownership of the stack, and it asks for proof of building: a portfolio, a side project, a production-ready demo. That is the unusual part — most SRE adverts ask for years of a specific vendor product and call it ownership.

The work itself is the work already done: alerting that is confirmed delivered, a ledger instead of a dashboard, tools written rather than bought, security inside the pipeline instead of after it.

## What matches

- Self-built telemetry: a sentinel job writing job status, generation age, disk and PSI pressure every 15 minutes into a JSONL ledger — a number for "is the system healthy", not a screen to watch.
- Alerting with delivery confirmation: a Go bridge that only acknowledges once the message arrives, so alarms cannot fail silently.
- Linux internals: systemd unit hardening, cgroup limits per service, PSI as a first-class signal, nftables, own SSH CA with short-lived certificates.
- Infrastructure as code in the literal sense: every service a module, every host a feature list, every change a commit; CI gates on the same state that gets deployed.
- Security in delivery: sops and age for secrets, short-lived certificates over long-lived keys, no service with a public socket.
- Builder evidence: the repository is public, with 3,800 commits of runbooks, gates and rollbacks.
- Forgejo automation: task verbs drive the git.envs.net Forgejo REST API for repository and metadata operations, with the token read from sops rather than a browser login.

## What is missing

- **Prometheus and Grafana in production — the hard requirement.** No Prometheus server, no exporters, no Grafana dashboards, no Alertmanager.
- A formal SLO and error-budget programme: the ledger measures health, but no SLO targets, burn rates or budget policy were written.
- On-call rotation in a multi-team organisation; the fleet was operated alone.
- Kubernetes and cloud platforms (the posting's detected skills include AWS and GCP); own infrastructure is bare metal.
- Distributed systems at smartclip's scale, and ad-tech domain knowledge.
- Upstream open-source contribution of the kind the nice-to-have asks for: the work is public, but not contributed to other projects.

## Route

Apply through the original posting. Hidden Jobs gates the application link behind a paid plan, so the direct smartclip careers route may be the cheaper path; the posting was last verified on 22 November 2026.

## Salary

Expectation 80,000 to 85,000 EUR, stated in the letter as instructed. The posting says salary is not specified and lists benefits instead — 30 days plus Christmas Eve and New Year's Eve, an optional four-day week through focus Fridays, transport subsidy, bike leasing.

## Fit: 3 of 5

Three, because Prometheus and Grafana are the first named requirement and the whole observability ecosystem in the role is built on them. The custom stack is real and it is genuinely the same discipline, but it is not the same tooling, and an SRE team does not get to re-platform on day one.

Not a 4 (the brief's value) because "demonstrable hands-on experience operating Prometheus, Grafana and related observability tooling in production" is a must-have, not a preference. The brief was written from a summary; the full posting makes the requirement explicit.

Not a 2 because the rest fits unusually well: Linux internals, IaC, security in CI/CD, and above all the explicit demand for proof of building — which the public repository provides in a way a CV cannot.
