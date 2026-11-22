# Workato — Senior Infrastructure Engineer (PostgreSQL DBA)

**Status: packet staged, not submitted.** Prepared 2026-11-21. Nothing sent.

## Role

| Field | Value |
| :--- | :--- |
| Company | Workato |
| Role | Senior Infrastructure Engineer (PostgreSQL DBA) |
| Role ID | `workato-senior-infrastructure-engineer-postgresql-dba` |
| Requisition | REQ 2960 |
| Apply URL | https://job-boards.greenhouse.io/workato/jobs/8842211002 |
| Greenhouse job id | 8842211002 (posting updated 2026-11-20) |
| Source listing | https://www.arbeitnow.com/jobs/companies/workato/senior-infrastructure-engineer-postgresql-dba-berlin-frankfurt-munich-228113 (posted 2026-11-15) |
| Locations (Greenhouse) | Berlin, Germany; Frankfurt, Germany; Munich, Germany |
| Employment | Full-time, on-site/no remote per the listing |
| Compensation | Not published. Target **EUR 130,000 – 150,000** (or **USD 140,000 – 165,000**). |
| Category / language | `tech`, `en` |
| JD | `job-description.txt` |

## Candidate facts

| Field | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Website | https://www.bountystash.com |
| Citizenship | United States |
| Residence | Germany — unbefristete Niederlassungserlaubnis (permanent) |
| Work authorization | US and Germany/EU; no visa sponsorship required |
| German | C1 (verhandlungssicher) |
| English | Native |
| Availability | 01.12.2026 |

## Files

- `lebenslauf.pdf` — **2 pages** A4, PDF/UA-1 tagged, page budget enforced by `lib/typeset.nix`
- `anschreiben.pdf` — **1 page** A4
- `selection.json` — engineering evidence; projects `nixconfig`, `email-archive`, `bountystash`, `fibtransponder`
- `job-description.txt` — the JD as fetched
- `submission-sheet.md` — this file

Build: `scripts/task/appflow-packet.sh` → `modules/plugins/appflow/packet.nix`; typst in the Nix sandbox, `cv-ats-check.sh` read the finished PDFs back against `work/resume.json` in the same derivation. Budgets 2 / 1, zero page-budget errors.

## Live Greenhouse form — fields and staged answers

Fields, ids and option sets read from the boards API on 2026-11-21.

| Field | Id | Required | Answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | yes | +49 1733281570 |
| Resume/CV | `resume` | yes | `lebenslauf.pdf` |
| Cover Letter | `cover_letter` | no | `anschreiben.pdf` |
| LinkedIn Profile link | `question_38510810002` | **yes** | https://linkedin.com/in/mattji |
| Authorized to work in the listed country of hire for any employer? | `question_38510811002` | yes | **Yes** |
| Will you now or in the future require visa sponsorship? | `question_38510812002` | yes | **No** |
| What is your expected compensation? | `question_38510813002` | yes | `EUR 130,000 – 150,000 base (or USD 140,000 – 165,000 for a USD contract)` |
| Why do you think you will be successful in this role? | `question_38510814002` | yes | See the drafted answer below |
| Consent to recruiting SMS messages | `question_39015531002` | yes | Yes/No — Matt's decision; consenting is not required to apply |

### Drafted answer — "Why do you think you will be successful in this role?"

> Because the job is the one I already do at a smaller scale, and the parts I lack are learnable while the parts I have are not quickly taught. I run PostgreSQL as a production service: a full-text archive with a generated tsvector and GIN index, an upsert keyed on message_id, reviewed migrations, and backups that are only called done after a restore into an ephemeral cluster verifies the tables. I work in Linux daily, automate in Go, Python and Bash, and turn runbooks into released procedures rather than heroics. I would be honest about the gaps — no Aurora fleet, no PgBouncer layer, no multi-TB tables — and I would close them by pairing with the team and taking the support rotation seriously from the first week.

## Staged answers for the recruiter call

**Compensation.** EUR 130,000 – 150,000 base; USD 140,000 – 165,000 if the contract is in dollars. Workato publishes no band, so the number is a proposal, not a demand.

**Work authorization.** US citizen with permanent German residence (unbefristete Niederlassungserlaubnis). Authorized in Germany for any employer; no sponsorship now or later.

**Location.** Gutach im Breisgau, Baden-Württemberg. The posting is Berlin/Frankfurt/Munich with no remote flag, so relocation or a commute is a real question — raise it early rather than after an offer.

**The gap statement.** Operational PostgreSQL tenure is below the 5+ year DBA bar; there is no Aurora/RDS or PgBouncer production experience and no multi-TB table work. The sheet and letter say so, because the interview will establish it anyway and a packet that oversells would waste both sides' time.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| 5+ years operational PostgreSQL | Archive plus Bountystash schema/index work; below five DBA years | **Gap**, stated |
| Query plans, indexing on multi-TB tables | EXPLAIN on archive search paths, GIN/tsvector design; not multi-TB | Partial |
| Managed PostgreSQL (Aurora/RDS) | None | **Gap**, stated |
| PgBouncer in production | None | **Gap**, stated |
| Logical replication, major upgrades, low-downtime migration | Reviewed migrations; no logical replication/upgrade ownership | Partial |
| Terraform / IaC | No Terraform; NixOS declarative infrastructure is the equivalent practice | Adjacent, **gap** on the named tool |
| Linux proficiency | Daily driver; fleet, kernel pinning, systemd, networking | **Strong** |
| Scripting (Bash/Python/Go) | Go service, Python/Bash tooling | **Strong** |
| Observability | Sentinel ledger for jobs, generation age, disk, PSI; not postgres_exporter/VictoriaMetrics | Adjacent |
| Incident response / RCA | Solo-operator incidents, rollbacks, written follow-ups | Partial — no multi-team command |
| Developer support posture | Runs a platform whose users are services; writes the runbooks | Meets in shape |
| Location / authorization | Germany, permanent residence, no sponsorship | **Strong** on authorization; location needs a decision |

## Before submitting

- [ ] Decide the compensation sentence — EUR 130–150k is a proposal, not a published band.
- [ ] Decide the SMS-consent answer (it does not block the application).
- [ ] Confirm whether Berlin/Frankfurt/Munich in-office is workable from Gutach, or whether to apply at all.
- [ ] Attach `lebenslauf.pdf` and the optional cover letter; verify the parser reads name, email and phone.
- [ ] Submit only on explicit instruction.

No application was submitted.
