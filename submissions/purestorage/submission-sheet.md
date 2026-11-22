# Application — Pure Storage, Cloud Native Architect, Strategic Accounts (EMEA)

Date: 22 November 2026
Fit: 2
Language: English
Status: packet compiled, **do not submit while French fluency is mandatory**

## Role

| Field | Value |
| :--- | :--- |
| Employer | Pure Storage (Everpure, NYSE: P; $3.7bn FY26 revenue) |
| Role | Cloud Native Architect, Strategic Accounts (EMEA) |
| Type | Technical pre-sales architect, assigned Portworx and Pure Storage Cloud quota with TCV goals |
| Location | Remote — France, Germany, Netherlands, United Kingdom |
| Source | Greenhouse job API, HTTP 200 on 22.11.2026 |
| Req | 8379480 |
| Comp | no band published; prior note recorded a 130–155k target |

## Hard blocker

The posting states: *"Written and verbal fluency in French as well as English is mandatory."* The candidate has native English, German C1, and no French. That is a screening filter, not a preference.

A second structural mismatch follows: the role is quota-carrying pre-sales — demonstrations, proofs of concept, RFx and SOW input — while the entire record is operations and engineering.

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English, opens with the French blocker |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory and no PDFs; the DB row existed and already recorded fit 2 with a do-not-submit warning, which the fetched posting confirms.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| French and English fluency | No French | **Hard blocker** |
| Pre-sales, quota, TCV ownership | None | **Gap** |
| Production Kubernetes | None | **Gap** |
| Portworx / enterprise storage arrays | None | **Gap** |
| Linux storage and capacity | Capacity planned from measured pressure, NAS targets, verified restores | Strong (operational) |
| Linux performance | PSI, OOM, disk and memory pressure, systemd, cgroups | Strong |
| Infrastructure automation | Declarative fleet, CI gate, rollback by generation, Python and Go tooling | Strong |
| Telemetry | 15-minute ledger, Gatus, pressure metrics | Strong |
| Technical communication | Runbooks, decision notes, public repository | Strong |
| Storage economics / TCO reasoning | Financial models from four years of asset management; not sales | Partial |
| Multi-region cloud data architecture | None | **Gap** |

## Fit reasoning: 2 of 5

The brief specified 4. Two is what the advert supports.

Two independent filters sit in front of the technical overlap: a mandatory language the candidate does not speak, and a profession — pre-sales with a quota — that the record does not contain. Designing a storage architecture for a strategic account is adjacent to operating storage, but the job also requires winning the account.

Two means: the substrate knowledge is real, and there is no path through screening without a waiver.

## Open items

1. **French** — mandatory, absent. Nothing in the packet can fix this.
2. **Pre-sales and quota** acknowledged in the letter as a different profession.
3. **Kubernetes, Portworx, enterprise arrays** named as absent.
4. Do not submit unless the language requirement is waived for a German account base.
5. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text plus cross-check note. |
| `lead.md` | Fit, blocker, gaps. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
