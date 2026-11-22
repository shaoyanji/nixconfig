# Publitas — Senior IT Operations Engineer (Remote / SaaS)

Remote-first SaaS (digital catalogues), Recruitee **2612158**. English packet. Native Typst sources; the old
`selection.json` is removed.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `publitas` |
| Employer | Publitas.com B.V., Amsterdam (department Operations / DevOps) |
| Role | Senior IT Operations Engineer |
| Location | Remote, EU — remote-first company |
| Language | **en** |
| Apply URL | https://publitas.recruitee.com/o/senior-it-operations-engineer-remote-saas |
| Compensation | no band published; **no figure in the letter** |
| Fit | 3 (DB entry 4) |

## What the role is

Build and scale the internal technology foundation for a distributed company: endpoints, SaaS tooling, identity and
access management, onboarding automation and device management, security posture, vendor and cost governance, audits and
business continuity. 5+ years in internal IT, IT operations or systems administration **in modern SaaS environments**;
strong IAM, endpoint and SaaS administration experience; comfort with remote-first work.

The posting also states, in its own words, that AI is a core lever and that it is not looking for the "AI-curious" but for
people who already use it and can show impact. That is treated as a requirement, not a bonus.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Identity and access management | Fleet CA minting short-lived SSH credentials, per-host sops/age, default deny | **strong** |
| Security posture improvements | Access that expires, no standing secrets, reviewable change | **strong** |
| Automation replacing manual support | One task surface with validation and dry-run plans | **strong** |
| Operational maturity and structure | Declared fleet, pinned inputs, one gate for CI and host | **strong** |
| Remote-first, async working | Written decisions, runbooks with the change, ownership defined as finished | **strong** |
| AI in daily work with demonstrable impact | Agents under claims, tiered tool access, approval gates, verification | **strong** |
| Documentation and operational resilience | Docs generated from source, stale page is a build failure | **strong** |
| Endpoint / MDM (Jamf, Kandji, Intune) | **none** | **gap** |
| Okta / Google Workspace / Entra administration | **none**; identity is Linux, SSH and sops | **gap** |
| SOC 2 / ISO 27001 / audit ownership | **none** | **gap** |
| SaaS estate and vendor cost governance | **none** at company scale | **gap** |
| 5+ years in internal IT specifically | 5 years systems and operations, 10 years energy commercial | partial |

Fit **3**: the systems, identity, automation and documentation half of this role is strong and publicly evidenced; the
corporate-IT half — Mac fleet, MDM, SaaS tenant administration, audit — is absent. The DB keeps the instructed **4**.

## Compensation

No band is published and the letter states no figure. If a number is asked for, the earlier sheet's ask was
**EUR 85,000 – 110,000** for remote EU; it is recorded here rather than in the letter, so the employer's number comes
first. Benefits listed: 25 vacation days plus local holidays, MacBook and remote gear, wellness and co-working allowances.

## The argument the letter makes

It opens on the failure this role exists to prevent: something was granted once, nobody knows to whom, and the only way to
find out is to ask. The answer offered is access that is issued rather than stored — a fleet CA, short-lived SSH
certificates, per-host secrets, default deny — because a permission that expires is a stronger control than a review
nobody reads.

Then the estate follows the same idea: declared hosts, pinned inputs, the same check in CI and on the machine, parents
recorded so rollback is a pointer, a fifteen-minute sentinel that pages on bad state and on silence, and routine work
behind one surface so the answer to a request is a command rather than a ticket.

The gap paragraph is the most important one in this letter, because a senior internal-IT role is judged on honesty about
scope: no Mac estate, no MDM, no Okta or Workspace, no audit carried. Stated as where I would be learning, not teaching.
The AI paragraph then answers the "not AI-curious" line with what actually runs — claims, tiered access, approval before
destructive actions, a written gate that decides whether output counts.

## Paperwork, stated correctly

Working remotely from Germany needs **no Dutch permit**: German permanent residence already covers it. The
**kennismigrant** route only becomes relevant if Publitas wants the role based in Amsterdam, and it is available there with
employer support. The letter says both, in that order, so a recruiter is not left guessing which one applies.

## The Recruitee form

| Field | Answer |
| :--- | :--- |
| Full name **required** | Matt Ji |
| Email **required** | matt\@bountystash.com |
| CV **required** | `lebenslauf.pdf` (2 pages) |
| Cover letter | `anschreiben.pdf` (1 page) |
| Where are you located, and in which time zone? **required** | Gutach im Breisgau, Germany — CET/CEST (UTC+1 / UTC+2), fully remote and async |
| LinkedIn **required** | https://linkedin.com/in/mattji |
| Which parts energize you, which would be challenging? **required** | Energize: identity as declared configuration and replacing manual support with automation. Challenging: MDM across a Mac fleet, SaaS tenant governance, audit ownership — Linux and SSH experience, not Jamf or Okta. |

Two cautions on this form: the **Yes/No radio labels carry no question text server-side**, so read the question before
clicking; and the canonical posting is at `jobs.publitas.com/o/senior-it-operations-engineer-remote-saas` — a trailing
dash in that URL returns 404.

## Checks

| Check | Result |
| :--- | :--- |
| `selection.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `short-lived`, `sops`, `fifteen minutes`, `MDM`, `Okta`, `Jamf` (gaps) |
| Markers letter | `Publitas`, `short-lived`, `MDM`, `Okta`, `highly skilled`, `Amsterdam` |
| Stray asterisks / salary figure / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 256 prose files, exit 0 |
| sha256 CV | `90c9682e173e803c28613fa86d4d629fd62d5522c19877083be64bfb60160261` |
| sha256 letter | `374a14b482b85abe83861fbb832117668fbd9cd7602d83aa69164016e68b6821` |
| DB read-back | verified after upsert |

## Note on the database

An earlier row exists as `publitas-senior-it-operations-engineer` from the previous packet build. This one is stored as
`publitas` per the current naming. One of the two should eventually be retired so the tracker does not double-count the
same application.

## Before you submit

1. Read the Yes/No radio question before clicking — the label carries no text.
2. Answer the energize/challenge field in your own words rather than pasting the letter; it is read as a writing sample.
3. If a salary question appears, the ask is EUR 85,000 – 110,000, staged in this sheet and not in the letter.
