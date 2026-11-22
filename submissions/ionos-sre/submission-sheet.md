# IONOS SE — Site Reliability Engineer (f/m/d) – Application Hosting, Karlsruhe

**Archive artifact. The requisition is closed.** Built 2026-11-22 against Greenhouse `ionos2` 4956693101 (German duplicate
4956674101, IONOS Kennziffer 1585). Do not submit to that link.

Packet rebuilt 2026-11-22 from Nix-built PDFs into native Typst sources, German, compiled with Typst 0.15.1 (DejaVu Sans only).

## The posting is closed — verified four ways

| Check | Result |
| :--- | :--- |
| `job-boards.eu.greenhouse.io/ionos2/jobs/4956693101` | redirects to `?error=true`: *"The job you are looking for is no longer open."* |
| Live board `ionos2` (Greenhouse API, `?content=true`) | 60 jobs, `4956693101` absent |
| Live board `ionos` (German duplicate, `4956674101`) | 49 jobs, both ids absent |
| IONOS careers / Arbeitsagentur mirror | 404 / 410 Gone |

`job-description.txt` carries that provenance in its header; its body is the recovered text of the same requisition.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 980 | 0 | `0a15977333b436b0` |
| `anschreiben.pdf` | 1 | 441 | 0 | `5bae4d2f69689b47` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, this sheet. Retired in this rebuild: the `/nix/store` `packet` symlink,
`selection.json`, and `letter.json` — the letter now has a single source, `anschreiben.typ`.

## What the rebuild changed

The submitted PDFs were generated from the application database and their CV carried the same unsupported skills block as the other
database-built packets: Kubernetes, AWS, Azure and Google Cloud under DevOps; React, Next.js and Laravel under web; Java, Kotlin,
Erlang and Lua under languages; MySQL and Django beside PostgreSQL. None of it is in the corpus, so none of it survives. Bytes of the
submitted artefacts, for the record:

- `lebenslauf.pdf` — `3f7421383101c569…`, 2 pages, 533 words
- `anschreiben.pdf` — `a06726af9ed82732…`, 1 page, 457 words

The CV was also thin for two pages (533 words with a large empty band) because it was assembled from database fields rather than from
the work. The native version is 980 words and every bullet is something the fleet, the portfolio or the field work actually did.

Kubernetes appears exactly once in the CV — inside the sentence saying it has not been operated in production. That is deliberate:
the word must be present where a screener looks, and it must be attached to the truth.

## Fit

**3 of 5 for this requisition as written**, which is why the letter names the gaps in their own paragraph: no production Kubernetes,
no Nextcloud administration, no Terraform / GitLab CI / Argo CD / Prometheus-Grafana history, no scale beyond thirteen hosts. What is
strong is the layer underneath — declarative Linux, one gate shared by CI and the machines, rollback as a pointer, a ledger that
alarms on silence as well as failure, Go and Python automation, PostgreSQL operations.

## Live IONOS alternatives (board API, same day)

| Requisition | Title | Location |
| :--- | :--- | :--- |
| `4971782101` | Staff Network Reliability Engineer (f/m/d) | Karlsruhe — network specialism, already applied (ack 311052) |
| `4988144101` | Staff Site Reliability Engineer (f/m/d) | Berlin — level above, no Karlsruhe |
| `5036214101` | Associate Site Reliability Engineer (f/m/d) | Berlin — level below target |
| `4706356101` | Staff Reliability Engineer (f/m/d) Ceph | Berlin |

## Staged answers (standard Greenhouse EU shape)

The form for this requisition cannot be opened, so these are the board's standard `job_application[...]` fields: first/last name
Matt / Ji, email matt@bountystash.com, phone +49 173 3281570, location Gutach im Breisgau, CV `lebenslauf.pdf`, letter
`anschreiben.pdf`, website https://matt.bountystash.com, GDPR consent accepted. LinkedIn left empty on purpose.

| Candidate fact | Value |
| :--- | :--- |
| Languages | German C1, English native |
| Work authorisation | US citizen, German permanent residence — no sponsorship |
| Salary expectation | EUR 85,000 gross p.a. (in the letter, as previously staged) |
| Earliest start | 01.12.2026 |
| Location | Karlsruhe ~130 km from home: office days possible, daily not |

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| Unsupported claims in CV text | 0 (Kubernetes appears only in the negation) |
| `task checks:prose` | exit 0 |
| Commit | native rebuild, legacy artefacts removed in the same commit |

## Next action

Do not submit to the dead link. Either wait for IONOS to repost a Karlsruhe SRE requisition, send this packet speculatively with the
closure noted, or re-tailor for `4971782101` — which is already applied and needs no second submission.
