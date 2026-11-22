# Application — Elastic, Principal CI/CD & Platform Engineer

Date: 22 November 2026
Fit: 4
Language: English
Status: application already submitted 22.11.2026; packet compiled retrospectively, not for sending

## Role

| Field | Value |
| :--- | :--- |
| Employer | Elastic |
| Role | Principal CI/CD & Platform Engineer |
| Location | Remote, EMEA |
| Source | brief; no requisition fetched |
| Route | https://jobs.elastic.co/ |
| Salary in letter | none stated |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English; concession in the third paragraph |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

Arrived as a directory and a DB row with no Typst sources; `letter.json` and other JSON removed, stale PDFs rebuilt from new sources.

The DB row read `applied` with two linked mails before this packet was built. Those mails are Elastic's thank-you for the application and a portal security code, both dated 22 November 2026, on the posted title `Principal Software Engineer I - CI/CD - Platform Engineering Productivity`. An upsert during this build had set the row back to `prep`; it is restored to `applied`. **The packet below is retrospective** and should not be submitted for this id.

## Requirement check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Reproducible build pipelines | Pinned inputs; same commit and inputs yield the same system | Strong |
| Gating that means something | Gate over evaluated configuration — modules and assertions — not exit code | Strong |
| CI matrix maintenance | Matrix derived from the host inventory; registration is the trigger | Strong, small scale |
| Test orchestration at scale | Tiered gates, one host per process, memory watchdog around sweeps | **Partial — correctness yes, scale no** |
| Developer productivity | Task menu as sole entry point, generated docs, cost-ordered gates | Strong in a one-person setting |
| Linux systems depth | systemd, cgroups, namespaces, PSI, boot and initrd, nftables, WireGuard | Strong |
| Bazel / Gradle / distributed caches / K8s runners | Not held | **Gap** |
| Java ecosystem | Not held | **Gap** |
| Thousands of builds per day | Not held | **Gap** |
| English | Native | Met |
| Remote EMEA from Germany | Yes | Met |

## Fit reasoning: 4

The brief said 4 and the evidence agrees. What transfers is the judgement: reproducibility that means something, gates that refuse, rollback as a generation, a matrix that maintains itself, and sweeps that cannot take their own machine down. What does not transfer is the stack and the scale, and both are named in the letter rather than left for the reader to find.

## Correction log

| When | What |
| :--- | :--- |
| 22.11.2026 | Upsert set status `prep`, overwriting `applied` and dropping the official role title; both restored after reading the linked mail. |
| 22.11.2026 | Brief title (`Principal CI/CD & Platform Engineer`) differs from the submitted title; both recorded in the DB notes. |

## Open items

1. **Scale and stack** — Bazel, Gradle, distributed caches, Kubernetes runners, Java: named as gaps.
2. **Requisition** — no advert fetched; confirm level and EMEA remote scope on jobs.elastic.co.
3. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Brief-derived scope plus cross-check note. |
| `lead.md` | Fit, gaps, route. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
