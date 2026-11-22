# DeepL — Staff Site Reliability Engineer, Sovereign Cloud

Munich, hybrid (two days a week in office). English packet. Native Typst sources; the legacy read-only
`lebenslauf.pdf`, `anschreiben.pdf` and `selection.json` are removed and rebuilt from `.typ`.
Status: compiled and checked, **nothing submitted by this packet**.

| Field | Value |
| :--- | :--- |
| Role ID | `deepl` |
| Employer | DeepL (Language AI; ~1,000 staff, 200,000+ business customers) |
| Role | Staff Site Reliability Engineer, Sovereign Cloud |
| Location | Munich, hybrid — two days a week in office |
| Language | **en** |
| Apply URL | https://www.arbeitnow.com/jobs/companies/deepl/staff-site-reliability-engineer-sovereign-cloud-munich-48462 |
| Compensation | no band published; no figure in the letter |
| Fit | 3 (DB entry 4) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 964 | `a204fedf9055e2fa4078b39d4ba7d700485f93765dea1f38cc94965257a4907f` |
| `anschreiben.pdf` | **1** | 571 | `428188e0e8e0b1e221fa31fd866131687c29fb2c82fa85d27af2a4a29c50e0f0` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs.

## What DeepL for Sovereign Markets is

The offering for public-sector bodies and regulated organisations that need more than data residency: hosted and operated
entirely in the EU, under EU jurisdiction, running alongside the global platform. The work is the platform foundation —
how services are built, deployed, secured, observed and operated — with a stated preference for managed infrastructure and
good abstractions over bespoke low-level plumbing. Responsibilities include owning the architecture (Kubernetes,
networking, storage, identity, secrets), infrastructure as code and delivery standards, ADRs, observability and incident
response, low-invasive product changes, auditability with security and compliance, mentoring, and on-call.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Immutable, declared OS architecture | Hosts declared as one repository; upgrades by generation switch, no edits on a live machine | **strong** |
| Reproducible builds and supply-chain hygiene | Inputs pinned by hash, content-addressed outputs, shared cache, remote builders | **strong** |
| Secrets and identity | sops/age per host decrypted at activation; short-lived SSH certificates; default deny | **strong** |
| Observability and incident practice | Fifteen-minute ledger, paging on bad state and on silence, postmortem history | **strong** |
| High-performance Linux | cgroups, PSI, `strace`, `tcpdump`; single-GPU inference stack measured under load | **strong** |
| Automation over manual work | One task surface with validation and dry runs; generated documentation | **strong** |
| Written decisions others can build on | Decisions and references generated from source; reviewable diffs | **strong** |
| AI-native velocity | Agents under claims, tiered tool access, approval gates, checks that decide | **strong** |
| Go | One service, not a portfolio; Python and Bash heavier | partial |
| Managed Kubernetes in production | **none** | **gap, core to the role** |
| Terraform / Crossplane / GitOps | **none**; declarative NixOS instead | **gap** |
| BSI C5, ISO 27001, SOC 2 | **none** | **gap (bonus points)** |
| On-call at company scale | Own pager for five years, no formal rotation | partial |
| EU sovereign cloud providers | **none** | gap (bonus) |

Fit **3**: the immutability, secrets, telemetry and Linux-performance work is a direct match for what makes a sovereignty
promise true in practice, and it is the part of the role that is engineering. It is not higher because the managed-cloud
layer — Kubernetes, Terraform or Crossplane, GitOps — is the platform this team actually runs, and none of it is in the
corpus. The DB keeps the instructed **4**.

## The argument the letter makes

It opens on the distinction that decides whether sovereignty is real: if the build depends on an ambient machine, if the
secret sits on disk, if a host can be edited in place and nobody can reconstruct why, jurisdiction is a contract term rather
than an engineering property. Then the fleet that does the opposite — pinned hashes, content-addressed builds, sops per
host, short-lived certificates, default deny.

Reliability follows as the place the promise is kept: the gate CI runs is the gate the host passes, generations keep their
parents so rollback is a pointer, and the sentinel pages on silence because the machine that went quiet is the expensive
one.

Then the honest paragraph, because a staff role deserves it: no managed Kubernetes in production, no Terraform or
Crossplane, no GitOps controller, no BSI C5 or ISO 27001 audit, no formal on-call rotation at scale. Against that, the
things the posting emphasises — one IaC standard, observability before the incident, security fundamentals as practice —
are what the candidate does weekly.

It closes with the question an auditor would ask: when someone asks why a change was made six months ago, do you hand them a
ticket, a chat thread, or the diff and the decision record beside it?

## Application route — read before investing time

The posting has **no DeepL ATS link**. `boards-api.greenhouse.io/v1/boards/deepl/jobs` answers 404, and the apply button
points at arbeitnow's own form, which ships **no server-rendered fields** (zero labels, zero `job_application[...]`
inputs). The form is client-rendered, so it must be filled on the live page, and an arbeitnow account or profile step is
likely before any upload.

A previous attempt at this posting was recorded as blocked: **CAPTCHA token rejected on submit, form filled and files
attached**. Two consequences: expect the CV to land in an aggregator inbox rather than DeepL's ATS, and consider finding a
DeepL recruiter address to send the packet directly instead.

## Checks

| Check | Result |
| :--- | :--- |
| Legacy read-only PDFs and `selection.json` | removed, rebuilt from source |
| `chmod u+w *.pdf` | applied before removal and compile |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo` pages | **2 / 1** |
| Markers CV | `PSI` 6, `immutable` 3, `sops` 3, `short-lived` 4, `Compliance` 1, `Kubernetes`/`Terraform`/`BSI` (gaps) |
| Markers letter | `sovereign` 4, `PSI` 2, `DeepL` 2, `short-lived` 1, `Kubernetes` 1, `ISO 27001` 1, `immutability` 1 — the letter says immutability, the CV says immutable |
| Stray asterisks / salary figure / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 262 prose files, exit 0 |
| sha256 + word counts | recorded above, measured from the PDFs |

## Before submitting

1. Decide the channel: arbeitnow's client-rendered form, or a DeepL recruiter address with the packet attached.
2. If the form asks for salary, DeepL publishes no band; answer in the recruiter conversation instead.
3. Expect a CAPTCHA on submit — the previous attempt at this posting failed there with the form fully filled.
