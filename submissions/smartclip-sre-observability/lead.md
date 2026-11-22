# Lead — smartclip Europe GmbH, Site Reliability Engineer (f/m/d) – Observability & Internal Tools

**Stage: prep.** Posted on hiddenjobs.dev; last verified by the board on 2026-11-22. Nothing
submitted.

| Field | Value |
| :--- | :--- |
| Company | smartclip Europe GmbH |
| Role | Site Reliability Engineer (f/m/d) – Observability & Internal Tools |
| Source | hiddenjobs.dev listing (`…-0cdc83e8`) |
| Location | Germany, remote-first; Berlin/Cologne for larger initiatives |
| Language | English (JD in English) |
| Salary | 80.000 – 85.000 EUR requested |
| DB role id | `smartclip-sre-observability` |

## Why it is a lead

The posting asks for an engineer who *builds* internal infrastructure instead of consuming SaaS:
Prometheus/Grafana/Forgejo as a platform, alerts as design, SLOs, security in the delivery
pipeline, Linux depth. That is the shape of this repository — one flake, a task control plane, a
hand-written telemetry ledger, gatus, a Forgejo remote driven through its REST API.

## Gaps, honestly

- **Prometheus server and Grafana are not operated here.** The fleet declares `node_exporter`
  (`hosts/gok/instance.nix`, `:9100`) and uses gatus plus a sentinel ledger; there is no Prometheus
  server, no Alertmanager, no Grafana dashboard anywhere in the tree. The letter says so.
- **Forgejo is a remote, not a service this fleet runs**: `git.envs.net` is a Forgejo instance used
  through `scripts/task/gitenvs.sh`, not a self-hosted forge.
- Formal SLO/error-budget practice is new; alerting on state is real.
- Salary, experience level and employment type are not stated in the listing.

## Next action

Packet built from `job-description.txt`; submit through the listing when the form is reachable.
