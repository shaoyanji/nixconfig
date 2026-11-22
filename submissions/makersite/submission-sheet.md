# Makersite — DevOps / Platform Engineer

Munich, remote-first in Germany. English packet. Native Typst sources; the legacy `Makersite_Cover_Note.pdf`,
`Matt_Ji_Resume_Makersite.pdf` and `selection.json` are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `makersite` |
| Employer | Makersite GmbH (product lifecycle and supply-chain digital twins) |
| Role | DevOps / Platform Engineer |
| Location | Munich, remote-first within Germany |
| Language | **en** |
| Apply URL | https://makersite.io/careers/ |
| Compensation | no band published; no figure in the letter |
| Fit | 3 (DB entry 4) |

## A mismatch to settle before applying

The assignment names **DevOps / Platform Engineer** at `makersite.io/careers/` — a careers index, not a specific posting.
The job text staged in this folder is a **different requisition**: `Senior Site Reliability Engineer (SRE) m/f/x`,
arbeitnow, posted 2026-11-20, with its own requirements (7+ years SRE, Terraform and Ansible, AWS or Azure, Prometheus and
Grafana, ISO compliance, RTO/RPO, on-call).

This sheet and the documents are built for the **DevOps / Platform Engineer** role as assigned. If the live posting is in
fact the SRE one, the documents still hold — the evidence overlaps almost entirely — but three items would need adding to
the letter: on-call rotation, backup and recovery objectives, and ISO participation. Those are named as gaps below, not
claimed.

There is also an older DB row, `makersite-gmbh-senior-site-reliability-engineer-sre-m-f-x`, at `other/other`, fit 3.

## What the role is

Platform operations for a data-heavy product: keeping the Linux estate and the services on it reliable, building the CI/CD
that lets product teams ship, owning the data plumbing that feeds the twins, and enabling developers rather than servicing
them. Python is the working language of that plumbing; SQL is where the answers live.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Linux platform operations | Thirteen hosts declared as one repository, rebuilt from pinned inputs | **strong** |
| Automated CI/CD gates | One check identical in CI and on the host, dry-run plans, fast failure | **strong** |
| Python data pipelines | Pipelines and tooling with tests over canonical data | **strong** |
| Data quality and reconciliation | Three measurement feeds into one auditable series | **strong** |
| Observability and alerting | Fifteen-minute ledger, paging on bad state and on silence | **strong** |
| Developer enablement | One task surface, validation, generated documentation | **strong** |
| Postgres data modelling | SQL and reporting schemas; **no Postgres operation** | partial, **gap** |
| Terraform / Ansible | **none**; declarative NixOS instead | **gap** |
| AWS / Azure managed services | **none**; rented bare metal | **gap** |
| ISO certification / audit participation | **none** | **gap** |
| On-call rotation, RTO/RPO ownership | Own pager for five years; recovery reasoned explicitly, no formal RTO/RPO | partial |
| Domain: PLM, LCA, supply chain | Adjacent: energy asset data, not product lifecycle | partial |

Fit **3**: the platform, CI and Python-data half is strong and publicly evidenced, and it is the half a DevOps/Platform
role spends its week on. It is not higher because the storage layer, the managed cloud and the certification work in the
posting are all absent. The DB keeps the instructed **4**.

## The argument the letter makes

It opens on the thing a digital twin lives or dies by: a number a user can trace back to a source. Then the two directions
that experience came from — ten years of models that had to survive a bank's question, five years of the Linux platform
those numbers were produced on.

The data paragraph is concrete: three feeds into one auditable series, missing readings as an explicit error budget, one
origin per reported figure, Python for pipelines and SQL where the answer is a query. The Postgres limit is stated in the
same breath rather than left for a design review.

The platform paragraph then argues enablement rather than heroics: one gate for CI and host, pinned inputs, shared cache
and remote builders, generations with parents, a sentinel that pages on silence, and a task surface so the answer to a
routine request is a command.

Two further boundaries are named — no Terraform or managed cloud, no ISO audit — with the transferable discipline spelled
out: access that expires, changes reviewable in a diff, secrets encrypted per host, recovery asked about in advance.

It closes with a question specific to this product: when a customer disputes a figure in a twin, how far back can it be
traced today — the ingesting job, the source record, or only the dataset version?

## Checks

| Check | Result |
| :--- | :--- |
| Legacy cover-note PDF, resume PDF, `selection.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `Python` 5, `reconciliation` 3, `Postgres` 1 and `dry-run` 1; no `Terraform` and no `ISO` — those are named only in the letter, where the gap belongs |
| Markers letter | `Makersite` 3, `Postgres` 2, `Terraform` 1, `ISO` 1, `Python` 1, permanent residence 1 |
| Stray asterisks / salary figure / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 259 prose files, exit 0 |
| sha256 CV | `e2ba35a87a611764530e228825a5bb99d81be3608e6122510bef9fbc8145765d` |
| sha256 letter | `a20c9b08f004d0695470035252c0fccfc1be744363e3065aec8c026edb8f4c93` |
| DB read-back | verified after upsert |

## Next steps

1. Open `makersite.io/careers/` and confirm which requisition is live: DevOps/Platform or Senior SRE.
2. If it is the SRE posting, add on-call, RTO/RPO and ISO lines to the letter before sending — the CV already supports the
   pager and recovery reasoning.
3. If it is the platform role, this packet goes as it is.
