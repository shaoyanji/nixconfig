# Lead — Catawiki, Platform Engineer

**Stage: prep.** Greenhouse job `8405079`, fetched 2026-11-22 (posted 2026-11-20). Packet built the same
day; nothing submitted.

| Field | Value |
| :--- | :--- |
| Company | Catawiki (Amsterdam; online marketplace for special objects, 800+ staff, 60+ nationalities) |
| Role | Platform Engineer, Platform Horizontal (Reliability, Developer Experience, Security, Quality) |
| Apply URL | https://job-boards.greenhouse.io/catawiki/jobs/8405079 |
| Source | Greenhouse boards API, 2026-11-22 |
| Location | Amsterdam, **hybrid — minimum 2 days/week** at HQ; relocation support offered |
| Language | English |
| Fit | 3 |
| Salary | "competitive annual gross base" — no band published |

## What the role is

Build a self-service developer platform and abstract infrastructure complexity away from product teams:
Kubernetes clusters and cloud resources with FinOps attention, CI/CD and GitOps workflows with reusable
templates, fault tolerance and disaster recovery, and an observability stack that catches platform problems
before customers do. Requirements are explicit: **5+ years production Kubernetes**, a named cloud (GCP, AWS
or Azure), Terraform or Ansible, and hands-on Prometheus, Grafana, ELK or OpenTelemetry.

## Honest position

The developer-experience half matches well: a single task surface as the front door, gates that run in CI
and on the host, reversible changes, telemetry written down rather than watched. The cloud-native half does
not: **no production Kubernetes, no Terraform/Ansible, no Prometheus/Grafana/OTel**, and the cloud record is
Oracle hosts plus one Lambda. Three of five stated requirements are missing.

## Gaps

- Kubernetes in production — absent.
- Terraform / Ansible — absent; IaC is NixOS modules and flake wiring.
- Prometheus, Grafana, ELK, OpenTelemetry — absent; observability is a custom ledger plus journald and PSI.
- GCP/AWS/Azure at scale — weak.
- Amsterdam 2 days/week — relocation, not commuting; the advert offers relocation support.
- Dutch work authorisation — German permanent residence does not carry over; the sponsorship route in the
  advert would be needed, and the letter says so.

## Next action

Apply through Greenhouse with both PDFs. The letter names the three missing requirements in one paragraph
and closes on relocation and the permit route; if that combination is acceptable, the developer-experience
evidence is the argument.
