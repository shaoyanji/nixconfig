# Application — Treatwell, Senior Platform Engineer, Platform Core

Date: 22 November 2026
Fit: 4
Language: English
Status: packet compiled; advert body unavailable, so the requisition needs confirming

## Role

| Field | Value |
| :--- | :--- |
| Employer | Treatwell |
| Team | Platform Core |
| Role | Senior Platform Engineer |
| Reference | Workable 359BA205E3 |
| Location | Netherlands; relocation and a highly skilled migrant permit required |
| Source | brief; Workable v3 endpoint 404, public page returns a 7.7 kB shell with the title only |
| Route | https://apply.workable.com/treatwell/j/359BA205E3/ |
| Salary in letter | none stated |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English; concession in the third paragraph |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Advert | `job-description.txt` | Source note plus cross-check; **no advert body** |
| Certificates | none | still missing |

Arrived with no directory and no DB row. No JSON drafts or store symlinks were present.

## Requirement check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Platform ownership end to end | 13 Linux hosts, three hardware generations, five years, one operator | Strong, small scale |
| Reproducible infrastructure | Pinned inputs; same commit reproduces the system | Strong |
| Automated gates | Gate over evaluated configuration; inventory-derived matrix; cost-tiered checks | Strong |
| Telemetry and alerting | 15-minute ledger, probes, delivery-confirmed alert bridge | Strong |
| Reliability judgement | Rollback by generation, exercised restores, leading indicators | Strong |
| Linux depth | systemd, cgroups, namespaces, PSI, nftables, WireGuard, own CA | Strong |
| Go and Python tooling | Internal tools, bridges, reports, generated docs | Strong |
| AWS / cloud provider | Not held | **Gap** |
| Kubernetes, Terraform, Kafka | Not held | **Gap** |
| Marketplace traffic, multi-tenant data | Not held | **Gap** |
| Netherlands work authorisation | US citizen, German permanent residence; kennismigrant route needs sponsor and salary threshold | **Open** |
| English | Native | Met |

## Fit reasoning: 4

Briefed as 4 and the evidence agrees. The craft the role names — reproducible platforms, gates that refuse, telemetry that reaches a human — is demonstrated across five years of sole ownership.

Not 5 because the cloud stack is the working vocabulary of a Platform Core role and none of it is held, and because the scale is thirteen machines rather than a marketplace. Both are in the letter, not hidden.

## Open items

1. **Advert body missing** — endpoint 404 and a JS shell; confirm the requisition is open before sending.
2. **Kennismigrant** — sponsor status and salary threshold to confirm; the letter asks rather than asserts.
3. **Relocation** to the Netherlands, stated as willingness.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Source note and cross-check. |
| `lead.md` | Fit, gaps, route, permit question. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
