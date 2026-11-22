# Application: Grafana Labs — Staff Software Engineer, Databases SRE (Germany, remote)

As of: 22 November 2026
Fit: 2
Language: English

## The role

| Field | Value |
| :--- | :--- |
| Employer | Grafana Labs |
| Role | Staff Software Engineer — Databases SRE |
| Location | Germany, 100% remote (same role advertised for UK, Sweden, Spain) |
| Source | Grafana Labs Greenhouse board API, HTTP 200 on 22 Nov 2026, job id 6103688004 |
| Salary | EUR 113,000 – 135,601 base in Germany (stated in the advert); no figure in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Cover letter | `anschreiben.pdf` | One page, English, opens with the missing stack |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compiles standalone |
| Certificates | none | Still to be added |

## Requirement match

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Operating Prometheus and Grafana in production | None | **Hard gap** |
| Database operations at scale (MySQL, PostgreSQL, Cassandra, ClickHouse) | None | **Hard gap** |
| Telemetry pipelines and instrumentation | Self-built ledger, Gatus, delivery-confirmed alerting | Partial — practice, not products |
| Incident response and root-cause discipline | Diagnosis from ledger and logs, runbooks for every procedure | Strong |
| Go-level engineering | Alerting bridge, AI platform router | Strong for an SRE, thin for Staff SWE |
| Linux reliability and internals | systemd, cgroups, PSI, namespaces, nftables | Strong |
| Kubernetes and cloud-native operations | None | Gap |
| Staff-level scope: cross-team direction, mentoring | Sole operator, no multi-team leadership | **Gap** |
| Remote from Germany | Based in Baden-Württemberg, remote-ready | Met |
| Work authorisation | US citizen, permanent German residence | Met |
| German C1 / English native | Both | Met |

## Fit: 2 of 5

The brief said 4. Grafana Labs sells the exact stack this candidate has never run, and this role additionally owns databases at scale, of which there is none. At Staff level that is the subject of the job, not a gap closed during probation.

Not a 1 because the underlying discipline is real and close in spirit: building a ledger, endpoint checks and delivery-confirmed alerting because no monitoring budget existed is observability work, just not with these products.

## Open points

1. **Prometheus, Grafana and databases absent** — stated in the first paragraph of the letter.
2. **Fit lowered from the briefed 4 to 2.** Restorable in one command if you want the brief's value kept.
3. Staff level implies scope this CV does not show: no multi-team technical direction, no mentoring record.
4. Certificates still missing; the German range is recorded here and in `lead.md`, but no figure is quoted in the letter.
5. Application is via the Germany Greenhouse posting, not the UK/Ireland/Spain/Sweden variants.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full advert text with a cross-check note. |
| `lead.md` | Fit reasoning, matches, gaps, route, salary. |
| `lebenslauf.typ` | Typst source, compiles standalone. |
| `anschreiben.typ` | Typst source, compiles standalone. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
