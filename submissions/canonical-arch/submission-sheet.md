# Canonical — Information Systems, Open Source Technical Architect

**Applied.** Greenhouse 4551832, 2026-11-22 (per the apps DB: "tailored CV + email code"). The previous version of this sheet said
"staged, not submitted"; the DB row is the later record and is what this sheet now follows.

Home based, EMEA. Twice-yearly company events, roughly four weeks of travel a year. Canonical publishes no salary band, so the
number is settled in the first call, not on the form (there is no salary field).

## Candidate facts — verified 2026-11-21

| | |
| :--- | :--- |
| Residence | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| Citizenship | United States |
| Residence status | Permanent German residence (unbefristete Niederlassungserlaubnis) |
| Work authorization | Germany/EU; no visa sponsorship required |
| Languages | German C1; English native |
| Contact | matt@bountystash.com · +49 1733281570 |

## Files

Native Typst sources, compiled 2026-11-22 with Typst 0.15.1, DejaVu Sans only:

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1,107 | 0 | `31b9a8b23f1e981b` |
| `anschreiben.pdf` | 1 | 499 | 0 | `9f90d90e7fc1807a` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, this sheet. `selection.json` retired: it described the Nix-built
artefacts and nothing reads it.

## What the rebuild changed

The submitted PDFs were generated from the application database, and carried a "Generated from the application database" footer
on page 2. Their bytes, kept here for the record:

- `lebenslauf.pdf` — `d44a840999fce79a…`, 2 pages, 680 words
- `anschreiben.pdf` — `e69c76f1813a97fe…`, 1 page, 350 words

This rebuild is not byte-faithful, deliberately. The generated CV carried a six-line skills block that the corpus does not
support — Kubernetes, AWS, Azure and Google Cloud under "DevOps"; React, Next.js and Laravel under web; Java, Kotlin, Erlang and
Lua under languages; MySQL, Django and FastAPI alongside PostgreSQL. Those claims are gone, because a Canonical interview would
find them in the first ten minutes and everything else in the packet would become suspect. What replaced them is what the fleet
actually runs: Nix and NixOS, systemd, sops, an SSH certificate authority, a binary cache, Go, Python, PostgreSQL, Gatus, and the
gate that CI and the machines share.

The letter was rewritten rather than ported. The submitted version was 350 words and its third paragraph named the gaps in one
sentence; the native version keeps the three named gaps — no Ubuntu/Debian packaging at Canonical scale, no internet transit or
CDN design, no line management of SRE and data-centre engineers — and keeps them in a paragraph of their own, because that is the
sentence an interviewer will test first.

## Fit

**3 of 5.** Strong on infrastructure as code, Linux operations, incidents and open-source posture; weak on the two things the
posting asks for that cannot be claimed: leading SRE/DCE teams, and operating at the scale of tens of millions of Ubuntu devices.
The posting's own emphasis — "the reason behind the reasons", structural improvement after incidents, self-service products — is
exactly the ground the packet holds.

## Greenhouse form 4551832 — live labels read 2026-11-21

| Field | Answer |
| :--- | :--- |
| First / Last Name | Matt / Ji |
| Email | matt@bountystash.com |
| Country | Germany |
| Phone | +49 1733281570 |
| Attach / Enter manually | Attach `lebenslauf.pdf` |
| School · Degree · Discipline | University of Freiburg · Master of Science · Renewable Energy Management |
| How did you perform in mathematics at high school? * | DECISION — historical, yours to answer |
| How did you perform in your native language at high school? * | DECISION — historical, yours to answer |
| Describe your leadership or management experience * | Technical direction over a small fleet, not line management. I set the gates and runbooks others follow, review every host change, own rollback decisions. I have not managed SRE/DCE teams. |
| Describe your devops, sysadmin or SRE experience * | One flake declares the fleet; hosts are feature lists, services are modules with systemd units. sops secrets behind an SSH CA, binary cache and remote builders, one-command rollback, per-host gate shared with CI, sentinel ledger with Gatus paging. Go and Python services, PostgreSQL operations. |
| Ideal developer and gitops experience on your private cloud * | A repository as the only source of truth: hosts as feature lists, peer review, CI running the same per-host gate the machine runs before switching, branch preview evaluation, one-command rollback, no snowflake host and no manual step only one person knows. |
| LinkedIn | https://linkedin.com/in/mattji |
| Companies in the past ten years * | DECISION — count since the first degree; the CV shows five employers |
| Country you currently work in | Germany |
| Recruitment privacy notice * | Tick after reading |
| Gender · Race/ethnicity | Prefer not to say (your choice) |
| Nationality * | United States (matches the CV) |

## Blockers before this packet is whole

1. **Canonical's own-words attestation.** Their form requires "I agree to use only my own words — AI content disqualified". I will
   not sign that on your behalf, and a native rebuild cannot remove the question. Read both documents and make them yours, or
   rewrite the passages that are not.
2. **Two high-school questions** — mathematics and native language. Historical facts only you know; Canonical screens on them and
   a mismatch with the transcript surfaces later.
3. **Employer count since the first degree** — the CV shows five; count from the degree date, not from 2016.
4. **Whether the submitted bytes were these hashes.** The DB says applied with a tailored CV and email code; the on-disk Nix PDFs
   are what the directory held before this rebuild. If a different file was attached, this sheet cannot prove which.

## Provenance

JD from Canonical's Greenhouse board, job 4551832, saved as `job-description.txt` with its source URL. The handed-over JD contained
raw `<p>`/`<li>` markup; it was stripped before the packet was built, and the original was kept at `.bak-html`. Form labels read
from the live embedded application form on 2026-11-21.
