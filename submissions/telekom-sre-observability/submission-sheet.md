# Deutsche Telekom / T-Systems — Site Reliability Engineer (SRE), Observability/Tracing

Requisition is the Bundesagentur advert `12444-563465374109848-DT-S`, posted 30+ days ago and
edited 23 days ago, so still open. One oddity: the BA page hides the employer contact behind a
character test, so the reference number is the identifier to quote, not a portal id.

| | |
| :--- | :--- |
| Role ID | `telekom-sre-observability` |
| BA reference | 12444-563465374109848-DT-S |
| Employer | Deutsche Telekom AG / T-Systems International GmbH |
| Role focus | Observability and distributed tracing for cloud, edge and Kubernetes platforms |
| Locations | Darmstadt, Berlin, Dresden, **Karlsruhe 76185**, Kassel, Saarbrücken, Hannover, Bielefeld, Magdeburg, München |
| Contact | thomas.arbeit@t-systems.com (technical questions) |
| Language | very good German, C1 |
| Model | hybrid, mobile work possible, part-time possible |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Nearest listed site | Karlsruhe, ~120 km |
| Salary stated | **85.000 EUR** |
| Start | immediate or by agreement |

## Fit map

What is claimed here is limited to what the repo actually contains: `gatus` in 9 files,
`sentinel` in 15, `journald` in 5, `PSI` in 13, plus SQLite and Postgres event stores. The lead
note's line that Matt "runs Prom/Grafana/Loki" was wrong and is corrected in `lead.md`.

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| OpenTelemetry Collector, OTLP, SDKs, auto-instrumentation | None. No collector, no exporter, no instrumentation history | **gap** |
| Distributed tracing: span correlation, context propagation, sampling | No tracing at all; correlation of log and event is done by hand over host, unit and time window | **gap** |
| Jaeger operation: trace storage, indexing, query optimisation | Never operated | **gap** |
| SIEM integration, security event management, CEF and Syslog | journald collection and an event store; no SIEM, no CEF, no syslog forwarding | **gap** |
| Go, Python or Shell for telemetry and integration work | Go and Python tooling behind a task interface, gates in CI and on hosts | strong |
| Kubernetes observability, cloud-native platforms | No Kubernetes operations and therefore no cluster observability | **gap** |
| Building metrics/logs/traces pipelines | Sentinel ledger every 15 minutes (job status, generation age, disk, PSI) and alerting on any non-ok state; logs via journald | partial — pipeline thinking, not that stack |
| IT security understanding, awareness | SOPS/age secrets per host, SSH CA with short-lived certificates, nftables default-deny | partial |
| SRE or infrastructure operations experience | Single-operator fleet, incident discipline, gates instead of promises | strong |
| Very good German, C1 | German C1, letter and CV in German | strong |

## Portal mapping

Two routes exist and neither is a Greenhouse-style form:

1. **BA jobdetail** (`arbeitsagentur.de/jobsuche/jobdetail/12444-563465374109848-DT-S`) — the
   advert page, with the employer contact behind a character test. The BA reference is the key
   that survives; the "Bewerben" link it offers leads to the employer's own portal.
2. **T-Systems careers** (`careers.t-systems.com`) — the application itself, one profile with CV
   upload and free-text motivation, then a job-specific question set.

| # | Field | Answer |
| :-- | :--- | :--- |
| 1 | Referenz / Requisition | 12444-563465374109848-DT-S |
| 2 | Anrede / Vorname | Herr, Matt |
| 3 | Nachname | Ji |
| 4 | E-Mail | matt@bountystash.com |
| 5 | Telefon | +49 173 3281570 |
| 6 | Wohnort | Am Burgerhof 4, 79261 Gutach im Breisgau |
| 7 | Wunschstandort | Karlsruhe (76185), alternativ mobil |
| 8 | Lebenslauf | `lebenslauf.pdf` (2 Seiten, deutsch) |
| 9 | Anschreiben | `anschreiben.pdf` (1 Seite, deutsch) |
| 10 | Gehaltsvorstellung | 85.000 EUR brutto |
| 11 | Frühester Eintritt | sofort oder nach Vereinbarung |
| 12 | Deutschkenntnisse | C1 |
| 13 | Arbeitserlaubnis | unbefristetes Niederlassungsrecht, kein Sponsoring |
| 14 | Schwerbehindertenstatus | keine Angabe |
| 15 | Datenschutz-Einwilligung | ja |

## What the letter says

It leads with the question the role exists to answer — how do you know a service is down before
the customer does — and then names the four hard requirements it cannot meet: no OpenTelemetry
collector, no Jaeger, no SIEM with CEF and Syslog, no Kubernetes observability. Prometheus,
Grafana and Loki are named as absent too, because the corpus has zero hits for them and the repo
has no such modules.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 190 prose files, exit 0 |
| selection | 11/37 highlights, 0/0 projects |
| sha256 CV | `024037bf2717790a0143c8ed13c039042d02f46b8a48f97773d5659fa977f2f2` |
| sha256 letter | `f940002db003266baa65993ab86a52bcc414f1f47cf90d63e13943925bd650e1` |

## Next actions

1. Apply through T-Systems careers with the BA reference in the motivation field; the BA page is
   only the advert.
2. This is the weakest overlap of the packet set: the JD's must-haves are OTel and Jaeger, and
   neither is in the history. Do not send it ahead of a closer role.
3. If it is sent, ask whether the team will train the tracing stack — that is the only honest way
   in, and it filters for teams that mean it.
