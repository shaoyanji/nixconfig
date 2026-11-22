# GoCardless (a Mollie company) — Senior Site Reliability Engineer (Database Focus)

Greenhouse **8385160** · https://job-boards.greenhouse.io/gocardless/jobs/8385160
Platform Engineering — London · Riga · Lisbon. Payments: Direct Debit, real-time payments, open banking, USD 130bn+ a year.

**Status per the apps DB: applied** (OTP mail 311053 on file, 2026-11-22). The previous version of this sheet said "built, not
submitted, stage prep"; the DB row is the later record.

Native English Typst rebuild, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1212 | 0 | `94a34448bac98c4d` |
| `anschreiben.pdf` | 1 | 480 | 0 | `6561bb6e42d040ab` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, `lead.md`, this sheet. Retired in this rebuild: the whole `packet/`
directory (Nix-projected PDFs plus `selection.json`) and `letter.json` — the letter now has one source, `anschreiben.typ`.

## What the rebuild changed, and why it matters here

The old packet was a projection of the application database: the scorer ranked twelve terms from the posting, then kept 10 of 32 work
highlights. It kept two of Bountystash's ten — a covered-call hedging strategy and an LLM knowledge base — and dropped the mail
archive, the one project in the corpus built on PostgreSQL. It also substituted a UN University postgraduate module for that slot.

So the submitted CV carried **one** mention of PostgreSQL (inside the skills block), no migrations, no restore, no statement timeouts,
while the letter argued the database case in prose. On a role whose screening is database-first, the CV contradicted its own letter.
The native CV leads with the database work: PostgreSQL with versioned migrations, a rehearsed restore, statement timeouts, disk-pressure
alerting, plans read before indexes, autovacuum lag and idle-in-transaction sessions chased.

The old CV also carried the standard unsupported stack — Kubernetes, AWS, Azure, Google Cloud, React, Next.js, Laravel, Java, Kotlin,
Erlang, Lua, MySQL, Django — and 2 pages that were mostly whitespace. Submitted bytes: `packet/lebenslauf.pdf`
`52b7a1a54e4ee44c…`, `packet/anschreiben.pdf` `9eae0526a88d8b4e…`.

Where the stack words now sit: Kubernetes, Terraform, GKE, Argo CD, Prometheus, Grafana and Stolon appear only in the paragraph stating
they are not in my history. None of them is claimed.

## Location, and why it decides this packet

| Route | Reality |
| :--- | :--- |
| London | **Not open.** UK right to work needs a visa he does not hold; German permanent residence does not extend to the UK. |
| Riga / Lisbon | Would need a Latvian or Portuguese permit and a relocation. The German Niederlassungserlaubnis is the asset worth keeping. |
| Remote from Germany | The only clean version, and it is the recruiter's decision — the letter asks it rather than assuming it. |

The CV footer states "no UK right to work" so no form answer can drift into implying otherwise.

## Compensation — the band is narrower than it looks

Published **EUR 76,000–114,000**, and the posting states the policy: pay sits between the minimum and the midpoint until performance
can be assessed in role. Midpoint is **EUR 95,000**, which is the candidate's floor. A strong interview may not move it, so the ask is
the midpoint plus a written review date; the upper half is not negotiating room at hire. No figure appears in the letter.

## Fit

**2 of 5.** The specialty requirement — five or more years of production PostgreSQL with HA, replication, failover and major-version
upgrades led end to end — is not met: one production instance with a recovery path, no replication topology, no upgrade led. Strong on
the reliability half: solo on-call, a ledger paging on silence, gate discipline, declarative infrastructure, Go and Python. Absent
entirely: Stolon, Cloud SQL, PgBouncer in production, Terraform, GKE, Argo CD, Grafana, Prometheus, Datadog, Ruby.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| Unsupported claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native rebuild; `packet/` and `letter.json` removed in the same commit |

## Before anything else is sent

Settle the location question — remote from Germany, or not at all — before touching a form. If a location field forces a choice among
London, Riga and Lisbon, stop: that is the operator's decision, not a form-filling exercise. Never answer a UK right-to-work question
positively.
