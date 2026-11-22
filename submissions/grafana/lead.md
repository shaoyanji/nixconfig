# Lead: Grafana Labs — Staff Software Engineer, Databases SRE

Fit: 2
As of: 22 November 2026
Location: Germany, 100% remote
Greenhouse id: 6103688004

## Source

The advert is live on Grafana Labs' own Greenhouse board (HTTP 200, 140 open jobs, retrieved today) and the full text sits in `job-description.txt`. This is the Germany-remote variant of the same Staff Databases SRE role advertised for the UK, Sweden and Spain.

## Why interesting

Grafana Labs is the company that makes the tooling this fleet has been imitating by hand: dashboards, metrics, tracing, alerting. A Staff Databases SRE there owns the data layer under Grafana Cloud and the telemetry pipelines that feed it — which is genuinely the work this candidate has done at a small scale, without the products.

Remote from Germany is also the practical fit: no relocation, and the household is already in Baden-Württemberg.

## What matches

- Linux reliability at the level of systemd, cgroup limits, PSI and namespaces, not just service configuration.
- Declarative platform operations: one module per service, gates before deploy, every state kept as a generation and rollbackable.
- Self-built telemetry: a 15-minute JSONL ledger of job status, generation age, disk and PSI pressure; Gatus checks; a Go bridge that confirms alert delivery.
- Go tooling in production: the alerting bridge and the router of a self-hosted AI platform.
- Incident discipline: diagnosis from ledger and logs before users report, every cause written into a runbook.
- Public repository as evidence of building rather than configuring.

## What is missing

- **Prometheus and Grafana in production** — the company's own products, absent entirely.
- **Database operations at scale** — no MySQL, PostgreSQL, Cassandra or ClickHouse fleet to point at.
- OpenTelemetry, Tempo, Loki, trace pipelines.
- Kubernetes and cloud-native platform operations.
- Staff-level scope: multi-team technical direction, cross-org design, mentoring.
- On-call in a 24/7 follow-the-sun organisation.

## Route

Apply through the Greenhouse posting. The role is advertised in five European countries; applying to the Germany variant is the correct one for this candidate.

## Salary

The Germany advert states EUR 113,000 to 135,601 base, before equity and bonus. The letter quotes no figure. That range sits well above this candidate's current band, so the conversation would be about level rather than number.

## Fit: 2 of 5

Two, against the briefed 4. Grafana Labs sells the exact stack the candidate has never run — Prometheus, Grafana, tracing — and this role additionally owns databases at scale, of which there is none. At Staff level that is not a gap to be closed in a probation period; it is the subject of the job.

Not 1 because the underlying discipline is real and unusually close in spirit: someone who built a ledger, endpoint checks and delivery-confirmed alerting because no monitoring budget existed has done observability work, just not with these products, and the Go and Linux-internals depth a Staff databases team needs is partly there.
