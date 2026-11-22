# Camunda — Senior Site Reliability Engineer

Remote-first, posted 2026-11-17. English packet. Native Typst sources; `selection.json` and the JSON-era PDFs are
removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `camunda` |
| Employer | Camunda |
| Role | Senior Site Reliability Engineer |
| Location | **100% remote** (USEAST / USWEST tags in the posting; Germany hires run through Remote.com) |
| Language | **en** |
| Apply URL | https://www.arbeitnow.com/jobs/companies/camunda/remote-senior-site-reliability-engineer-440254 |
| Compensation (as stated) | **$149,800 – $241,500** USD total target cash, location-based |
| Fit | 3 (DB entry 4) |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Deep hands-on Kubernetes in production | **none** | **gap, must-have** |
| Infrastructure as code (Terraform or similar) | Nix: pinned inputs, generations, per-host modules | **transferable, different tool** |
| Monitoring and observability (Prometheus, Grafana or similar) | Bespoke fifteen-minute ledger, alerting on state, silence as fault | **strong in principle, wrong tools** |
| 3rd-level support and incident response | Bounded changes, rollback as a pointer, debugging from packets and syscalls | strong |
| Automation, raising the quality bar | One validated entry surface, runbooks as executable procedures | **strong** |
| Responsible use of AI tools | Drafts gated against requirements, no credentials to models, human signs | **strong, and rare** |
| Python, Go (nice-to-have) | Go service with tests, Python tooling, Bash | strong |
| SLOs and alerting frameworks (nice-to-have) | Signal-over-volume alerting; **no formal SLO framework** | partial |
| ArgoCD / GitOps (nice-to-have) | Declarative config, but **not GitOps with a cluster reconciler** | partial |
| Remote, no sponsorship | Germany, permanent residence, C1 German, native English | fulfilled |

## The argument the letter makes

Camunda sells governed autonomy — agents propose, people decide, the audit trail proves which. The letter says the
infrastructure here runs on the same rule, which is why the role was worth applying to: **a machine may propose, a
check must dispose.** The must-have "responsible use of AI tools" is answered with a working control rather than
enthusiasm, including the honest failure mode: not a bad model, a person who accepted a confident answer.

Second strand: **alerts that do not cry wolf**. One condition per check, thresholds that mean something, silence
treated as blindness — an alert nobody trusts being worse than no alert.

Three gaps named: no Kubernetes in production, no Terraform, no Prometheus/Grafana. The letter says the concepts
transfer but the tooling would be new, and on a multi-cloud Kubernetes estate that is a real ramp.

## Compensation note

The stated band is US total target cash and explicitly location-based; a Germany-based hire goes through Remote.com
with a local band. The letter acknowledges the posted range and declines to anchor on a figure that does not apply,
rather than quoting the US maximum.

## Two practical caveats

1. **The apply URL is an aggregator** (`arbeitnow.com`), not Camunda's ATS. Prefer Camunda's own careers page and
   treat the aggregator as the source of the posting text only.
2. **The posting carries US time-zone tags** (`#USEAST #USWEST`) alongside `#LI-Remote`. The remote contract is real,
   but on-call expectations should be confirmed before investing in the process.

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json`, JSON-era PDFs | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `telemetry`, `PSI`, `runbook`, `Kubernetes` (as gap) |
| Markers letter | `governed autonomy`, `Remote.com`, `Prometheus`, `silence` |
| `task checks:prose` | 244 prose files, exit 0 |
| sha256 CV | `360146af582b7ee53d68e47c7989d14ba679e472403824f19e7e23b2277d1b7e` |
| sha256 letter | `46f755c4cc7074d27e7855c56c5fa037ea0a8e3ece84e75ae5dfd990a7dbf5dd` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Camunda's own careers page, not the aggregator.
2. Ask what "multi-cloud" means concretely — EKS and GKE both live, or one primary with failover.
3. Ask how much of the on-call is US-hours, since the posting tags US time zones.
