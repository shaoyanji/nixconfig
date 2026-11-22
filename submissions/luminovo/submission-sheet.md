# Luminovo — Senior/Staff Platform Engineer

Munich or remote-first inside two hours of CET. Ashby `c3c7438e-8f66-4ff2-8df3-c1f078fde121`. English packet. Native
Typst sources; the legacy `Luminovo_*.pdf/.txt`, `Matt_Ji_Resume_Luminovo.pdf` and `selection.json` are removed.
Status: compiled and checked. **This requisition is already applied to** — see below.

| Field | Value |
| :--- | :--- |
| Role ID | `luminovo` |
| Employer | Luminovo (electronics supply-chain software, Munich) |
| Role | Senior/Staff Platform Engineer (posted as Platform Engineer – Rust) |
| Location | Remote-first within 2h of CET; Munich preferred, then Berlin, Germany, Europe |
| Language | **en** |
| Apply URL | https://jobs.ashbyhq.com/luminovo/c3c7438e-8f66-4ff2-8df3-c1f078fde121 |
| Compensation | published: **Level 3 €82,200–93,000** + €6,165–6,975 equity; **Level 4 €99,900–106,800** + €9,990–10,680 equity. No figure in the letter |
| Fit | 3 (DB entry 4) |

## Already applied — what this packet is for

The DB row `luminovo-senior-staff-platform-engineer-rust-d-f-m` is **status `applied`, 2026-11-22** for this exact
Ashby URL, with a CV and an honest Rust-gap note, remote (no office), salary 95,000 and a start of 01.12.2026.

So this is not a new application. It is the standardised rebuild of a packet that has already gone in: same role, same
evidence, better documents. It is what to send if Luminovo asks for an updated CV, and the reference for a second
conversation. Do not submit it twice through the same form.

## What Team Core does

Keep DevOps and CI/CD fast and reliable, build the tools every team needs, act as the in-house Rust expert for a Rust
monolith on actix-web, own developer experience, and help engineers use agents productively. Stack: Rust,
TypeScript/React, Postgres, ClickHouse, Redis, Kafka, Kubernetes, Helm, Flux, Honeycomb/Prometheus/Grafana, Azure and
Cloudflare.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| CI/CD speed and reliability | One gate identical in CI and on the host, inventory matrix, one host per process under a memory guard | **strong** |
| Reproducible builds | Pinned inputs, content-addressed outputs, shared binary cache, remote builders | **strong** |
| Developer experience owned as a product | One task surface, validation, help text, dry-run plans, JSON output | **strong** |
| Tooling every team needs | Module registry, generated references, runbooks shipped with the change | **strong** |
| Helping engineers use agents | Isolated worktrees, claims, tiered access, approval gates, written checks | **strong** |
| Observability | Fifteen-minute ledger, paging on state and on silence | **strong** |
| Go, Python | Services in Go, tooling and data work in Python | strong |
| Postgres / ClickHouse / Kafka / Redis | **none** operated; SQL for data work, not database operations | gap |
| Kubernetes, Helm, Flux, Azure | **none** | **gap** |
| Rust (actix-web monolith) | **none in production**; Go and Python, C and C++ earlier | **gap, centre of the role** |
| TypeScript / React | **none** | gap |

Fit **3**: the platform, CI and developer-experience half is strong and publicly evidenced, and it is the half Team Core
spends most of its week on. It is not higher because the posting's stated centre is in-house Rust expertise, and there is
none. The DB keeps the instructed **4**.

## The letters, and the Rust question

Both the previous cover note and this one put the Rust gap in the first third, in the same words: no Rust in production,
Go and Python with C and C++ earlier, and if Team Core needs that depth on day one, this is not the hire. A padded answer
to the required Rust field would be worse than the gap, because Team Core would discover it in the first pairing session.

What the letter argues instead is the half that can be owned immediately: a gate that is identical in CI and on the
machine, so "it passed" is a statement about a real system; a content-addressed build, so a rebuild months later is the
same artefact; a task surface with validation, so support requests become commands. At thirteen hosts today, with the
failures that scale — cache misses, builder capacity, a gate slow enough that people route around it.

It closes with a question about pipeline time: how long the slowest stage takes on a median change, and what the p95 is.
The distance between those two numbers is usually the next month of platform work.

## Ashby form, as it renders

| Field | Answer |
| :--- | :--- |
| Name / email / phone **required** | Matt Ji · matt\@bountystash.com · +49 1733281570 |
| Resume **required** | `lebenslauf.pdf` (2 pages) |
| LinkedIn **required** | https://linkedin.com/in/mattji |
| Your message to the Luminerds | paste the letter text — **this form has no cover-letter upload** |
| Languages at C1 or better **required** | English, German |
| Where are you located? **required** | Gutach im Breisgau, Germany (not relocating; inside the 2h CET window) |
| Join us in an office? | **No** — Yes means two or more days a week in Munich, Berlin or New York |
| When can you start? **required** | a date, not "immediately"; 01.12.2026 was staged |
| Salary expectations | 95,000 sits between Level 3 (82.2–93k) and Level 4 (99.9–106.8k); choose the level being argued for |
| How did you hear? | Other (job board) — the honest answer |
| Rust question **required** | the gap, stated plainly, as in the letter |

Ignore the "Autofill from resume" block above the fields: it parses the PDF and can overwrite what you typed.

## Checks

| Check | Result |
| :--- | :--- |
| Legacy `Luminovo_*`, `Matt_Ji_Resume_Luminovo.pdf`, `selection.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `Go` 5, `PSI` 4, `pinned inputs` 2, `binary cache` 2, `Rust` 1 (gap) — no `Postgres`, correctly: SQL is claimed, database operation is not |
| Markers letter | `Rust` 2, `agents` 2, `Luminovo` 1, two-hour CET window 1 |
| Stray asterisks / salary figure / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 258 prose files, exit 0 |
| sha256 CV | `2d06e622b3b535d8192e0f7c5b0ca396e781b204450e31bdf45323596d3bbdad` |
| sha256 letter | `0f781a6e869803f24ebd3887a5fc1177adbf6e8211c9fa1c8982a3ff8882ffc7` |
| DB read-back | verified after upsert |

## Next steps

1. Nothing to submit: the application is in. Keep this packet as the updated CV if they ask for a newer one.
2. If a screen happens, lead with CI and developer experience and let the Rust gap stand as written.
3. If they push on Rust depth, the honest position is the letter's: platform owner for the monolith, learning the language
   on their codebase with their Staff engineers.
