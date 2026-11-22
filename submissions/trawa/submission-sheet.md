# trawa — Senior Platform Engineer

Berlin HQ, in person most of the week. English packet. Rebuilt as native Typst sources; the directory previously held Nix-built
PDFs plus a `selection.json`, all replaced.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `trawa-senior-platform-engineer` |
| Employer | trawa (B2B energy platform, ~100 people, €35M+ raised, €24M Series A May 2025) |
| Role | Senior Platform Engineer |
| Team | Platform — infrastructure, shared tooling, developer experience |
| Location | Berlin HQ, in the office most of the week |
| Language | **en** |
| Apply URL | https://www.arbeitnow.com/jobs/companies/trawa/senior-platform-engineer-berlin-57894 |
| Posting | Arbeitnow, posted 2026-11-20, fetched 2026-11-21 |
| Compensation | salary plus stock options, no band published; no figure in letter or sheet |
| Fit | 3 (DB entry 4, carried from the scout row) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 1049 | `d56c28efb3cfecfcb221a4af651d60f0f6cc937e0fcb099a780f890067f3b69d` |
| `anschreiben.pdf` | **1** | 502 | `ff8ff7f4de03424db01a0a12b013c14404355d2868f6aab4062f134695268030` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w`. No `**` in either source. The
Director of Sustainability entry is wrapped in an unbreakable block, because an earlier pass left that heading orphaned at the
foot of page 1 with its bullet on page 2.

## What the role is

Own the foundation every trawa engineer relies on: scalable, secure, highly available AWS infrastructure for mission-critical
services; CI/CD, observability and internal platforms so teams ship faster; security embedded in infrastructure and pipelines
(access, secrets, compliance); and making the right way the easy way for engineers across the company. Eight-plus years in
platform, DevOps or SRE, deep hands-on AWS and infrastructure as code (ideally **Terraform**), distributed services in
production with a grasp of security, reliability, observability and cost efficiency. Stack: **AWS, Terraform, Spacelift, Docker,
GitHub Actions, Python, TypeScript, Dash0, Sentry, Incident.io**. The 90-day plan is explicit: understand the stack, own part of
the AWS and Terraform estate, find the biggest workflow friction, then lead one improvement from design to rollout.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| 8+ years platform, DevOps or SRE | Five years running a thirteen-host production fleet plus six years of energy systems work | meets in platform years; the shape is small-estate depth, not fleet scale |
| Infrastructure as code | One repository declares thirteen hosts, services, secrets and network policy; pinned inputs, hermetic builds | **strong** (Nix, not Terraform) |
| Security in infrastructure and pipelines | sops and age per host with only that host's key, certificate-based SSH with 90-day renewal, default-deny networks, declared grants | **strong** |
| CI/CD and safe rollout | One gate identical on laptop, CI and host; canary guest before production; rollback as a pointer | **strong** |
| Observability | Fifteen-minute ledger of job state, generation age, disk and PSI; paging on bad state and on silence | **strong** (self-built and gatus, not Dash0) |
| Distributed services in production | Services with defined failure behaviour, systemd units, a Go event-log service, REST APIs | strong |
| Cost efficiency | Capacity and spend decisions recorded beside the configuration they belong to | meets |
| Developer experience | One validated task surface, generated docs, help text and dry runs that answer before a ticket | **strong** |
| AWS | **none**; rented bare metal | **gap (central)** |
| Terraform / Spacelift | **none**; declarative NixOS instead | **gap** |
| TypeScript | **none** in production; Go and Python carry the work | gap |
| Docker / GitHub Actions | partial: builds are hermetic and gated, but not Docker images or Actions workflows | partial |
| Energy domain | PPA and hedging models, weather derivatives, gas storage and swing risk for a German trader, solar asset management above USD 100M | **differentiator** |
| Berlin, in office most of the week | Based near Freiburg; a relocation question, raised in the letter | **constraint** |

Fit **3**: the platform mechanics and the security and reliability practice map closely, and the energy domain is a genuine
differentiator for a company selling electricity-cost reduction. It is not higher because the estate is not AWS and not
Terraform, and those are the two things the posting names first; the letter says so and does not dress Nix up as either.

## The argument the letter makes

It opens on the least common thing in the application: six years pricing energy before five years building infrastructure, so
the 30% saving in trawa's pitch is understood as a number that has to survive settlement periods, forecast error and a moving
market.

The second paragraph is the platform practice: declared estate, pinned inputs, sops/age per host, certificate-based SSH,
default-deny, one gate for laptop, CI and host, canary and pointer rollback, and the ledger that pages on silence.

The third states the stack gap plainly — Nix rather than Terraform on AWS, a self-built ledger and gatus rather than Dash0 and
Sentry, Go and Python rather than TypeScript — and argues the transferable part is judgement about which exceptions deserve to
exist and making the safe path the short one.

The fourth maps onto their 90-day plan: find friction by watching where engineers route around the tooling rather than asking
them. It ends with the relocation point and a question about how they decide build, buy or leave-it-to-the-team.

## Before applying

1. Decide the Berlin question first: in-office most of the week is a relocation from Freiburg, and the letter says so.
2. Apply through Arbeitnow; the posting links an apply route rather than a Greenhouse form, so no staged form questions exist.
3. Expect AWS and Terraform probing; the honest position is mechanism-level fluency in the concepts with Nix as the working
   implementation.
4. Lead with the energy domain in any conversation — it is the part no other platform candidate will have.
