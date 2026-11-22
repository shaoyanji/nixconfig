# Attio — Senior Platform Engineer

Remote, open to candidates in **Poland, Germany, Portugal, Ireland** — Germany is where Matt lives, so no relocation and no
sponsorship. English packet. Native Typst sources; the `packet` symlink into `/nix/store` and `selection.json` are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `attio` |
| Employer | Attio (CRM for agentic revenue; $116M from GV, Redpoint, Balderton, Point Nine, 01A) |
| Role | Senior Platform Engineer |
| Location | Remote — eligible countries include Germany |
| Language | **en** |
| Apply URL | https://jobs.ashbyhq.com/attio/47b583e0-9d7c-4451-9c58-4fce60821d7a/application |
| Compensation | published **EUR 105,000 – 125,000** + equity; staged ask EUR 115,000, not quoted in the letter |
| Fit | 3 (DB entry 4) |

## What the role asks

The platform as a product, with every engineer at Attio as its customer: infrastructure as code (**Terraform, Kubernetes,
GCP**) so environments are reproducible and auditable; **CI/CD owned end to end**; the **observability stack** — metrics,
logging, distributed tracing — as the basis of a reliability culture; **SLOs** for latency, availability and error rates plus
capacity management; **incident response** with blameless post-mortems and fixes shipped as code; toil removed for product
teams. Requirements: production SRE mindset (SLOs, error budgets, toil reduction, post-mortems), modern cloud (GCP or AWS)
including networking and IAM, deep Docker/Kubernetes at scale, TypeScript/Go/Python/Rust with tested automation, and
ownership of centralised logging or APM (Datadog, Splunk).

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Platform as product, self-service | One entry surface with validation and help text; docs generated from source | **strong** |
| CI/CD owned end to end | Gate identical in CI and host, inventory-driven matrix, fast feedback | **strong** |
| Reliability and incident practice | Fifteen-minute ledger, alert on state, silence as fault, postmortems ending in a gate | **strong** |
| Toil reduction | Netboot provisioning, certificate-issued access, retention as a decision | **strong** |
| Observability | Job ledger, generation age, disk and PSI, journald | strong, **hand-built, no tracing** |
| Infrastructure as code | Nix flake with pinned inputs, generations, per-host gate | strong, **not Terraform** |
| SLOs and error budgets | No formal SLO programme across service teams | **gap** |
| GCP / AWS, networking, IAM | Bare metal; no cloud account ownership | **gap, required** |
| Kubernetes and Docker at scale | **none** | **gap, required** |
| Datadog or Splunk | **none** | **gap, required** |
| TypeScript / Rust | Go and Python; Rust reading only | partial |
| Location | Remote from Germany, which the posting lists | fulfilled |

Fit **3**: the platform-as-product, CI/CD and reliability columns are the ones this corpus can defend with evidence, and the
three required stack columns (cloud, Kubernetes, Datadog) are absent. The DB keeps the instructed **4**.

## The argument the letter makes

It opens on the posting's own framing — the platform is a product, every engineer is its customer — and offers the only
metric that ever mattered here: **whether someone shipped without asking me**. Then three concrete properties: one entry
surface with validation so a wrong argument fails before it touches a host; a gate identical in CI and on the machine, so a
green build cannot mean something different from a healthy machine; docs generated from the same source as the config, so
the page about a host is built out of that host.

Reliability is written from the pager seat — ledger, generations with parents, incidents that repeated twice becoming
checks rather than paragraphs, and toil removed at the source. Gaps are named: no Kubernetes/Terraform/GCP, no
Datadog/Splunk, no formal SLO and error-budget programme negotiated with several teams, TypeScript and Rust not in use.

## Location and money — the easy parts this time

- **No relocation, no permit question.** Germany is explicitly listed as eligible and the role is remote.
- The band is published and workable; the letter says so in one line without naming a figure, so the first number is theirs.

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink into `/nix/store` | removed |
| `selection.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `PSI`, `Kubernetes` (gap), `Terraform` (gap), `self-service` |
| Markers letter | `Platform team`, `Kubernetes`/`Terraform`/`GCP` (gaps), `Germany` |
| `task checks:prose` | 252 prose files, exit 0 |
| sha256 CV | `9d5f4837ebba0d948e71c47fcc0a8077003fa82abce93701b326e08ad99891b4` |
| sha256 letter | `7ebc15fb0e466ff2c9f6eb707374b2639c03abacdfe140aedfa1b496437dd45b` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Ashby; upload both PDFs, and skip the resume autofill parser.
2. Expect a systems interview around Kubernetes and cloud primitives: the honest position is that the concepts are known
   and the tooling is not.
3. Ask how SLOs are set today — whether the platform team proposes them or product teams do — since that tells you how
   much of the role is negotiation.
