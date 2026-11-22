# Lead: Treatwell — Senior Platform Engineer, Platform Core

Fit: 3
Date: 22 November 2026
Source: advert retrieved via Workable v1/v2 account endpoints, 22.11.2026, 4,289 characters (v3 returns 404; the public page is a JS shell)
Route: https://apply.workable.com/treatwell/j/359BA205E3/
Language: English
Location: Netherlands — relocation and a kennismigrant permit required

## State on arrival

No directory and no database row; the packet is new. No JSON drafts or store symlinks existed.

## Why it is interesting

Platform Core is the layer other teams build on, and the only honest measure of it is whether they can ship without thinking about it. That is exactly what the thirteen-host estate taught, at a much smaller scale.

## What carries

- Reproducibility with teeth: pinned inputs, a commit reproducing a system.
- Gating on the evaluated configuration rather than an exit code.
- Rollback as the previous generation, in minutes.
- An inventory-derived CI matrix, so registration is what puts a machine under test.
- Cost-tiered gates, so the cheap check runs before the expensive one.
- Telemetry as a delivery problem: alerts counted only once delivery is confirmed.
- Leading signals: PSI, disk, generation age.
- Linux depth and Go/Python tooling, documented from one graph.

## What does not

- **Terraform or OpenTofu on AWS** — module design, multi-account setups: the first named core requirement, absent.
- **Kubernetes on EKS**, Helm, Kustomize, cluster upgrades: the second, absent.
- Core AWS services, GitLab CI components, Datadog/Prometheus/Grafana.
- GCP, Bedrock, VPC Lattice, service mesh, DSOMM, mentoring at team scale.

## Fit reasoning: 3

The brief said 4. The advert says something narrower: deep Terraform on AWS with multi-account module design, expert EKS, GitLab CI components, Datadog or Prometheus with SLIs. Two of the three core requirements are entirely absent; the third — owning a platform other people build on — is present at thirteen machines and one operator.

Three is the honest number. The platform craft is real and visible: reviewed pipelines, rollback in minutes, delivery-confirmed telemetry, self-service through a task menu. That gets a conversation. It does not get a 4 when the stack the role is built on is missing.

## Open items

1. **Core gaps** — Terraform/OpenTofu on AWS and EKS conceded in the letter; nothing else in the packet contradicts them.
2. **Kennismigrant** — US citizen with German permanent residence; the Dutch highly skilled migrant route depends on the salary threshold and Treatwell being a recognised sponsor. The letter asks instead of assuming.
3. **Relocation** to the Netherlands required; stated as willingness, not arranged.
4. Certificates still missing.

## Way

Apply through Workable once the posting is confirmed live.
