# CoreWeave — Senior Data Platform Engineer, Weights & Biases

Greenhouse **4625588006**, published 2025-12-12. **US-based**: Livingston NJ / New York / San Francisco / Sunnyvale /
Bellevue / Remote-US. English packet. Native Typst sources; `selection.json` and the old Nix-built PDFs are removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `coreweave` |
| Employer | CoreWeave (Weights & Biases) |
| Role | Senior Data Platform Engineer - Weights & Biases |
| Location | US hubs or Remote-US; **three office days expected** |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/coreweave/jobs/4625588006 |
| Compensation | published base **USD 165,000 – 242,000** |
| Fit | 3 (DB entry 4) |

## What the job is, in the posting's own proportions

30% distributed batch and streaming pipelines (ingest, transform, validate, deliver structured and semi-structured
data); 20% transformation and orchestration frameworks (dbt, Dagster, Airflow or comparable) with testing, deployment,
data-quality and observability standards; 15% warehouse performance and reliability in **multi-petabyte** environments
(models, schemas, partitioning, cost); 15% product telemetry and event instrumentation; 10% catalog, lineage,
governance, semantic layer; 5% data foundations for internal AI apps; 5% operations and on-call.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Production data pipelines | Validate-before-write ingestion, idempotent reruns, explicit error budgets | **strong** |
| Distributed / batch processing | Thirteen-host fleet, per-host gates, job ledger | partial, small scale |
| dbt / Dagster / Airflow or comparable | **task runner and systemd, not these tools** | **gap, required** |
| Data models, schemas, partitioning for analytics | PostgreSQL schema design, versions, retention as decision | strong at small scale |
| Multi-petabyte warehouse, cost efficiency | **no PB-scale warehouse** | **gap, required** |
| Product telemetry and event instrumentation | Fifteen-minute ledger, event schemas, alert on state, silence as fault | **strong** |
| Data-quality testing and production monitoring | Explicit error budget, failing loudly, monitoring as first-class | strong |
| SQL and database performance | Query plans, indexing, partitioning trade-offs | strong |
| Python / Go | Go service with tests, Python tooling | strong |
| Catalog, lineage, governance, semantic layer | **none** | **gap** |
| Cloud data services (AWS/GCP/Azure) | bare metal, no managed warehouse | **gap, preferred only** |
| Right to work in the US | US citizen, no sponsorship | fulfilled |
| Location | Germany today; relocation to a US hub asserted | **decision to confirm** |

## The argument the letter makes

It opens on the moment every practitioner knows — the loss curve and the logs disagree — and reframes the job: that gap
is the product, because instrumentation is a promise someone will read the number later. From there the letter stays in
the two areas the posting weights at 45%: ingestion that fails rather than writing half a batch, and instrumentation
with the two habits that transfer to event schemas — alert on state rather than volume, and treat the absence of data as
data, since the failure mode is a dashboard that looks calm while nothing reports.

Four gaps named, not blurred: no dbt/Dagster/Airflow, no multi-petabyte warehouse, no catalog or lineage, no managed
cloud warehouse. The letter says these are the parts of the job that would be learning.

## Location — the thing to settle before submitting

The posting is US-based with three office days. Matt is in Germany today, is a **US citizen**, and the letter says the
relocation is logistics rather than permission. That claim needs a real decision from the applicant before the form is
sent: the Greenhouse answer already staged says yes to relocation.

## Form notes (24 live labels, from the 2026-11-21 inspection)

Country: Germany. Current company: independent infrastructure and platform work. Metropolitan area: none in the US —
Germany. Right to work: yes, US citizen. Sponsorship: no. Citizenship/export-control: yes, US citizen, most recent
country N/A. Office days: yes, with relocation. Preferred coding language for the paired exercise: Python and Go.
Gender, ethnicity, veteran status: prefer not to say. Attach `lebenslauf.pdf` (2 pp) and `anschreiben.pdf` (1 p).

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json`, old Nix-built PDFs | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `PSI`, `retention`, `idempotent`, `telemetry` |
| Markers letter | `Airflow` (as gap), `PSI`, `silence`, `US citizen` |
| `task checks:prose` | 246 prose files, exit 0 |
| sha256 CV | `81b19ffaa426114d03aadbe2493b0ea489dac3578326ca8b0e9cfe4ff13d01ed` |
| sha256 letter | `6052850be0e6153ccdbbc4b0f1bd76a14356bc026b7b80916e689d16dbf4817f` |
| DB read-back | verified after upsert |

## Next steps

1. Confirm the relocation answer before submitting — everything else on the form is settled.
2. Ask what the orchestration stack actually is post-acquisition; dbt plus Dagster and Airflow are all named, which
   usually means one is legacy.
3. Expect the paired Python or Go exercise; the validation-before-write argument is the strongest thing to bring to it.
