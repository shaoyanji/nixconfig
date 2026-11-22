# Wolt — Staff Engineer, EU Infrastructure

Berlin. Greenhouse req **8324647**. English packet. Native Typst sources; the directory held only `job-description.txt`, so
nothing legacy needed removing.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `wolt-eu-infrastructure` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `wolt-eu-infrastructure` |
| Employer | Wolt (DoorDash group; with Deliveroo and DoorDash sharing the platform) |
| Role | Staff Engineer, EU Infrastructure |
| Location | Berlin, Germany |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/wolt/jobs/8324647 |
| Compensation | not published in the posting; no figure in the letter |
| Fit | 2 (DB entry 2 — no number was specified for this packet) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 963 | `12c578b35bc66587b86500eea6f973aa6633e1f1a2d18fea062f6dbb8c353a51` |
| `anschreiben.pdf` | **1** | 498 | `2b7bdbe9c413bc81b8e01dc7420746e2d0ca0d408b8a44402209eaef39eadbec` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs.

## What the role is

Infrastructure teams build the compute, cloud and networking foundation that engineers at Wolt, Deliveroo and DoorDash ship on.
The **EU Compute** team focuses on provisioning, scaling and efficient operation of **GPU infrastructure for AI and ML
workloads** — an emerging space with greenfield scope. The staff engineer sets technical direction for shared AWS and Kubernetes
infrastructure across three brands, leads substantial initiatives from design to operation, evolves clusters, networking,
identity and provisioning, builds reusable Terraform patterns and self-service tooling, improves GitOps and observability,
sunset legacy tooling, and mentors through design reviews and incidents.

Stated expectations: **deep experience operating Kubernetes and AWS in production**, GPU familiarity as a plus, Go or Python for
maintainable tooling, Terraform, systems other teams depend on, cross-team leadership, and judgement on distributed-systems
trade-offs including cloud cost.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Declarative fleet automation | Thirteen hosts from one repository, pinned inputs, rebuild as the upgrade, generations with parents | **strong** |
| Self-service tooling and developer experience | One task surface with named arguments, validation, dry runs, JSON output | **strong** |
| Telemetry, alerting, incident practice | Fifteen-minute ledger, paging on bad state and on silence, postmortem history | **strong** |
| Multi-tenant isolation | microVM canary; capped CPU and memory, read-only mount, no egress | strong (one host, not a cluster) |
| GPU operation | One card serving three workloads; throughput and queue depth measured; explicit yielding rule | moderate, **single tenant** |
| Capacity and cost reasoning | Build farm sized from observed queue depth; per-host process caps; retention as a decision | **strong** |
| Go / Python tooling | Go services, Python tooling, tests over canonical data | **strong** |
| Production Kubernetes | **none** | **gap, core requirement** |
| AWS | **none**; rented bare metal | **gap, core requirement** |
| Terraform and reusable patterns | **none**; declarative NixOS instead | **gap** |
| GPU fleet orchestration and scheduling | **none** | gap (listed as a plus) |
| Cross-brand technical leadership | Five years solo ownership, no multi-team mandate | partial |
| Security, identity, secrets | Fleet CA, short-lived credentials, sops/age, default deny | **strong** |

Fit **2**: the automation, developer-enablement, telemetry and cost-reasoning half of the job is genuine and publicly evidenced.
The posting's two explicit core requirements are deep production Kubernetes **and** AWS, and neither is in the corpus, with
Terraform also required for the provisioning patterns. This is the widest gap in the batch and is recorded honestly rather than
argued around.

## The argument the letter makes

It opens on the test a compute platform is judged by: what a product team can do **without asking anyone** — then maps that to
the fleet at a smaller scale, and to isolation by construction (microVM, capped resources, no egress) as the same question
namespaces and quotas answer.

The gap paragraph is deliberately blunt and placed second, not buried: no production Kubernetes, no AWS, no Terraform, my cloud
is rented metal, my multi-tenancy is one GPU with a yielding rule. It names the consequence — if the team needs someone who can
reason about cluster upgrades and network policy from memory on day one, this is not that hire.

What follows is only what transfers: self-service tooling, capacity and cost argued from measurements, silence-as-failure
telemetry, declarative change with a real rollback. GPU work is described at its true size, with fleet scheduling named as
exactly the thing to learn from people who have already run it.

It closes with a question that fits the team's focus: how does the platform discover that a GPU node is **degraded but not
failing** — the state where jobs complete slowly and nobody files a ticket? That is usually where utilisation quietly
disappears, and it is the cheapest thing to instrument before it turns into a capacity spend.

## Before applying

1. Decide whether a fit-2 application is worth sending to a staff role with two hard core requirements. The letter is honest
   enough to survive a screen, but it will not survive a cluster-design interview.
2. If it is sent, lead the conversation with developer enablement and cost reasoning, and let the Kubernetes/AWS gap stand as
   written.
3. Apply through Greenhouse `8324647`; attach `lebenslauf.pdf` and `anschreiben.pdf`.
