# Application — Kraken, Infrastructure / DevOps Engineer

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Kraken |
| Role | Infrastructure / DevOps Engineer |
| Location | not confirmed — no live posting found |
| Source | role brief of 22.11.2026 |
| Board check | Lever API `kraken` returned HTTP 200 with an empty array; jobs.lever.co/kraken shows no open postings |
| Salary | not stated; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: the directory and the row were both absent, so there were no legacy txt or PDF files to replace.

## Requirement check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| 24/7 high-reliability bare metal | 13 hosts, three hardware generations, five years sole operation | Strong (small scale) |
| Least privilege, ephemeral certificates | Own SSH CA issuing short-lived certificates; no shared keys | Strong |
| sops-encrypted secrets | sops/age per host, ciphertext in git, keys separate | Strong |
| Telemetry loops | Gatus probes, 15-minute JSONL ledger, PSI and disk pressure | Strong |
| Alert delivery confirmed | Go bridge confirms delivery; unconfirmed treated as no alert | Strong |
| Automated incident resilience | Gated rollout, rollback by generation, restic with verified restores, runbooks | Strong |
| Kubernetes / cloud infrastructure | Not held | **Gap** |
| Company-scale on-call rotation | Rotation of one | **Gap** |
| Crypto exchange operations | Not held | **Gap** |
| Formal incident command | Not held | **Gap** |
| Work authorisation | US citizen with permanent German residence | Met |

## Fit reasoning: 4 of 5

Four, as briefed. The four things the brief names — bare metal, least privilege with ephemeral certificates, sops secrets, closed telemetry with automated recovery — are exactly what the fleet ran on, built because there was no team to hand them to.

Not 5, because the estate is thirteen hosts rather than a global trading platform, the on-call rotation was one person, and the exchange domain is new. Four means a conversation is plausible once the requisition is confirmed.

## Open items

1. **No live posting**: the Lever board returned an empty array. Confirm the requisition and location before submitting; the letter deliberately does not name a location or team beyond "Infrastructure".
2. **Kubernetes, cloud, on-call rotation, crypto domain, incident command** named as gaps in the letter.
3. Certificates still missing.
4. No salary band, because none was available.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Brief-derived scope plus the board check. |
| `lead.md` | Fit, gaps, route, sourcing. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
