# Application — Treatwell, Senior Platform Engineer, Platform Core

Date: 22 November 2026
Fit: 3
Language: English
Status: packet compiled against the retrieved advert; two core requirements conceded

## Role

| Field | Value |
| :--- | :--- |
| Employer | Treatwell |
| Team | Platform Core |
| Role | Senior Platform Engineer |
| Reference | Workable 359BA205E3 |
| Location | Netherlands; relocation and a highly skilled migrant permit required |
| Source | Workable v1/v2 account endpoints, 22.11.2026, 4,289 characters (v3 returns 404, public page is a JS shell) |
| Route | https://apply.workable.com/treatwell/j/359BA205E3/ |
| Salary in letter | none stated |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English; concession in the third paragraph |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Advert | `job-description.txt` | Advert text plus requirement cross-check |
| Certificates | none | still missing |

Arrived with no directory and no DB row. No JSON drafts or store symlinks were present.

## Requirement check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Ownership of a platform used by others | 13 hosts, three hardware generations, five years, one operator | Strong, small scale |
| Every change through a reviewed pipeline | Gate over the evaluated configuration; nothing edited on a host | Strong |
| Self-service and developer experience | Task menu and generated docs as the only entry point | Strong in a small setting |
| Reliability judgement and recovery | Rollback by generation, exercised restores, leading indicators | Strong |
| Linux depth | systemd, cgroups, namespaces, PSI, nftables, WireGuard, own CA | Strong |
| Bash and Python automation | Tooling, bridges, reports, generated docs | Strong |
| Incident command | Operator was also the on-call; single-machine stakes | **Partial** |
| Observability practice (SLIs, alerting) | Delivery-confirmed alerting, probes, leading signals — but self-built | Partial |
| **Terraform / OpenTofu on AWS, modules, multi-account** | Not held | **Core gap** |
| **Kubernetes (EKS), Helm, Kustomize at scale** | Not held | **Core gap** |
| Core AWS (EC2, VPC, IAM, Route53, S3, RDS) | Not held | **Gap** |
| GitLab CI, reusable pipeline components | Not held | **Gap** |
| Datadog, Prometheus, Grafana, CloudWatch | Not held | **Gap** |
| GCP, Bedrock, VPC Lattice, service mesh, DSOMM | Not held | **Gap** |
| Mentoring at team scale | Not evidenced | **Gap** |
| Netherlands work authorisation | US citizen, German permanent residence; kennismigrant needs sponsor and threshold | **Open** |
| English | Native | Met |

## Fit reasoning: 3, not the briefed 4

The brief said 4 and the advert does not support it. Two of the three core requirements are literally absent: **deep hands-on Terraform or OpenTofu on AWS with module design and multi-account setups**, and **expert Kubernetes on EKS with cluster upgrades and Helm/Kustomize at scale**. The third — owning a production platform other teams depend on — is real here, at thirteen machines and one operator.

What survives is genuine: a platform where every change goes through a reviewed pipeline, rollback measured in minutes, telemetry counted only once delivery is confirmed, and self-service through a task menu rather than tickets. A senior platform engineer's judgement is visible in that work. What is not visible is the cloud stack that this role is built on, and claiming 4 would imply it.


## Open items

1. **Core gaps** — Terraform/OpenTofu on AWS and EKS: conceded in the letter, not implied elsewhere.
2. **Kennismigrant** — sponsor status and salary threshold to confirm; the letter asks rather than asserts.
3. **Relocation** to the Netherlands, stated as willingness.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Source note and cross-check. |
| `lead.md` | Fit, gaps, route, permit question. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
