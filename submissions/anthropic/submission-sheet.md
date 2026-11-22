# Application — Anthropic, Staff+ Software Engineer, Data Infrastructure

Date: 22 November 2026
Fit: 2
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Anthropic |
| Role | Staff+ Software Engineer, Data Infrastructure |
| Location | Remote-friendly, travel required; San Francisco, Seattle, New York |
| Source | Greenhouse job API, HTTP 200 on 22.11.2026 |
| Req | 5114768008 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory, no DB row, no `selection.json` and no old nix-built PDFs to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Data processing pipelines | JSONL telemetry ledger every 15 minutes, analysed in Python and Go | Partial (single host) |
| Storage patterns and capacity | Capacity from measured pressure, NAS targets, verified restores | Strong (small scale) |
| Access control systems | Own SSH CA, short-lived certificates, sops/age per host | Partial |
| Linux performance under load | PSI, OOM, disk pressure, cgroups and namespaces | Strong |
| Telemetry and audit trails | Structured ledger, reviewed commits, runbooks | Strong |
| AI systems reliability | Model-serving host operated with a router and resource guard | Partial |
| Spark / distributed data processing | Not held | **Gap** |
| Petabyte-scale data | Not held; 13 hosts | **Gap** |
| Cloud storage services | Owned hardware, no S3/GCS | **Gap** |
| Staff+ scope across teams | Not held | **Gap** |
| US site presence, travel | German resident | **Condition** |

## Fit reasoning: 2 of 5

The brief specified 4. Two is what the advert supports.

This is a Staff+ engineering role for distributed data infrastructure at Anthropic's scale: Spark, petabyte datasets, cloud storage reliability, access control for an organisation, and financial reporting pipelines. The record is a single-operator Linux platform with telemetry, storage discipline and audit habits. The instincts transfer; the systems, the scale and the level do not.

Two means: the packet is honest and sendable, and the probability of progressing is low.

## Open items

1. **Spark, petabyte scale, cloud storage, Staff+ scope** named in the letter as absent.
2. **US presence and travel** raised as something to discuss, not assumed.
3. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text plus cross-check note. |
| `lead.md` | Fit, gaps, route, salary. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
