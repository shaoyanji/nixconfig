# Application KAYAK - Staff Data Platform Engineer (Berlin)

Stand: 22 November 2026
Fit: 4 / 5

## Role

| Field | Value |
| :--- | :--- |
| Employer | KAYAK, part of Booking Holdings (NASDAQ: BKNG) |
| Team | Data Platform: shared foundation for analytics, ML, BI and AI features |
| Role | Staff Data Platform Engineer, senior individual contributor |
| Location | Berlin office, Friedrichshain; three days per week on site |
| Contract | Full time |
| Compensation | Not stated |
| Deadline | None in the ad |
| Listing | https://www.arbeitnow.com/jobs/companies/kayak/staff-data-platform-engineer-berlin-152496 |

## Application route

Arbeitnow carries the listing; applications go through KAYAK's own careers site, which the listing forwards to. Nothing was submitted and no portal was rendered. No deadline is given, so there is no schedule pressure but also no urgency signal.

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Cover letter | `anschreiben.pdf` | One page, English, addressed to the Kayak Hiring Team |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile directly |
| Certificates | none | Must be added before sending |

## Candidate

| Field | Value |
| :--- | :--- |
| Name | Matt Ji |
| Location | Gutach im Breisgau, Germany; relocation to Berlin workable |
| Languages | English native, German C1 |
| Education | M.Sc. Renewable Energy Management, University of Freiburg, 2014 |
| Systems | Thirteen Linux hosts as declarative code, per-host roles, gates and rollback |
| Telemetry | Sentinel ledger every 15 minutes, Gatus probes, delivery-confirmed alerts |
| Languages at work | Python, Go, SQL, Bash |
| Data modelling | Append-only event log, immutable content-addressed records |
| Cloud and streaming | No AWS, Kafka, Flink, Iceberg, Trino, Airflow, Kubernetes, Java |

## Match analysis

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| 7+ years in data engineering at senior or staff level | Ten years in systems and platform work, not data engineering | Partial: years yes, domain no |
| Lakehouse at scale: Iceberg, Parquet, S3 | None | Gap |
| Streaming pipelines: exactly-once, consumer lag, checkpoints | None; delivery-confirmed alerting is the closest analogue | Gap |
| Data contracts, governance, metadata, semantic layer | Append-only event log with immutable, content-addressed records | Partial, strong reasoning |
| Strong Python, maintainable production code | Python tooling and services in production | Yes |
| Data workloads on Kubernetes, resource tuning, health checks | No Kubernetes; resource limits and health checks on systemd | Partial |
| Influence across teams, architectural trade-offs | Runs the platform, writes standards, mentors through runbooks | Partial at this scale |
| Mentoring and raising standards | Led a team at O3 Energy; wrote runbooks and skill pages | Yes |
| Ownership of ambiguous problem spaces | Founder; built the fleet and the incident process from nothing | Yes |
| Trino, Kafka, Flink, Airflow, AWS, GitHub Actions, Java | None | Gap |

## Staff platform scope

A staff engineer at KAYAK is expected to set direction for many consuming teams: data contracts that others adopt, a semantic layer that analytics can trust, and platform decisions where cost, latency and correctness trade off. The packet argues that the *reasoning* is present, evidenced by the event-log design, the ledger and the declarative fleet, while the *scale and the specific stack* are not. That is the honest shape of this application: a strong systems engineer applying one level outside his recorded domain.

The letter says this in the third paragraph instead of hiding it, because a staff loop at KAYAK will find it in the first design conversation.

## Fit reasoning

Four because the platform instincts, the observability discipline and the code quality line up with what the role rewards, and the candidate can speak to schema and storage durability from practice.

Not five because the ad's hard requirements are a lakehouse stack, streaming semantics and seven years of data engineering. None of those are present, and no amount of Linux depth substitutes for operating Iceberg and Kafka at metasearch scale.

## Compensation

Not stated. Booking Holdings pays Berlin staff engineers well above the 85,000 to 95,000 EUR target, but nothing in the ad confirms a band. No number in the letter. Ask for the band and the level in the first call, before naming a figure.

## Open points

1. Certificates missing from the packet.
2. The lakehouse and streaming gap is the deciding factor; do not apply expecting a systems-engineering loop.
3. Relocation to Berlin and three days on site: decide before sending, not after an offer.
4. The listing is an Arbeitnow mirror; confirm the role is still open on KAYAK careers.
5. Level and band: ask first, since staff compensation varies widely.

## Packet

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full ad text as published. |
| `lead.md` | Fit, gaps, route, compensation. |
| `lebenslauf.typ` | Typst source, standalone. |
| `anschreiben.typ` | Typst source, standalone. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This sheet. |
