# Submission sheet — SumUp, Senior DevOps Engineer

Greenhouse **8726158002** · https://sumup.com/careers/positions/8726158002?gh_jid=8726158002
Published 2026-08-18 · Berlin, Germany (office first)

**Applied 2026-11-21**, Greenhouse confirmation 310961. Target compensation **EUR 95,000 – 115,000**; asked **EUR 100,000 – 112,000**.
No band published.

Native English Typst rebuild, 2026-11-22, Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1,172 | 0 | `01fe8b291703ab82` |
| `anschreiben.pdf` | 1 | 501 | 0 | `eb49eaa2fffe020e` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, this sheet. `selection.json` retired in this rebuild.

## Two defects this rebuild fixed

**The letter was addressed to the wrong company.** The submitted `anschreiben.pdf` opened "Dear Nebius Compute Node team" — a
copy-paste from another application, sent with a SumUp application. Its body was otherwise SumUp's, so the error sat in the one line
a recruiter reads first. The submitted bytes are recorded here rather than kept: `977873f74a8391bf…`, 1 page, 390 words.

**The CV carried the database-generated skills block** — Kubernetes, AWS, Azure and Google Cloud under DevOps; React, Next.js and
Laravel under web; Java, Kotlin, Erlang and Lua under languages; MySQL and Django beside PostgreSQL — plus the footer *"Generated
from the application database"*. The submitted CV was `07ef8020b64c31cb…`, 2 pages, 653 words: thin for the space, because it was
assembled from database fields rather than from the work. The native CV is 1,172 words, all of it traceable to the fleet, the
portfolio or the field contract.

## Where the stack words now appear

The posting is AWS, EKS and Terraform. None of those is claimed, and none was silently dropped either: the CV names Kubernetes,
EKS, Terraform and AWS only inside the paragraph stating they are not part of my history, plus one comparison of a Terraform plan
with the evaluation gate I actually run. A screener finds the words attached to the truth instead of the fiction.

## Fit

**3 of 5 as instructed, honestly closer to 2** on the stack-specific requirements. Strong: declarative infrastructure, Linux and
systemd depth, secrets and short-lived access, canary-before-fleet, reliability telemetry, Go and Python. Gaps, all named in the
letter: no production EKS or service mesh, no Terraform modules consumed by other teams, no hands-on EC2/VPC/IAM at SumUp scale, no
PCI DSS or SOC2 programme leadership.

## Live Greenhouse fields (12 server-side labels, read 2026-11-21)

| Field | Answer |
| :--- | :--- |
| First / Last Name | Matt / Ji |
| Email | matt@bountystash.com |
| Country | Germany |
| Phone | +49 1733281570 |
| Location (City) | Gutach im Breisgau (Freiburg area) — relocating to Berlin |
| Attach | CV `lebenslauf.pdf`; letter `anschreiben.pdf` — this form has no separate cover-letter slot |
| Authorised to work in Germany? * | Yes. US citizen with German permanent residence (unbefristete Niederlassungserlaubnis); no sponsorship. |
| Salary expectations? * | EUR 100,000 – 112,000 base (target band EUR 95,000 – 115,000) |
| Available to work from our office? * | Yes. Office-first Berlin acceptable; based near Freiburg, prepared to relocate. |
| Confirm | Confirmed |

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| Salutation | "Dear SumUp Cloud Infrastructure team" — the Nebius address is gone |
| Unsupported claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native rebuild with `selection.json` removed in the same commit |
