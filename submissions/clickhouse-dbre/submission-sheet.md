# ClickHouse — Database Reliability Engineer, Core Team (EMEA Remote)

**Ashby `c3617664-a679-406a-8fd5-71d51a407243`.** Status: packet prepared, **nothing submitted**.
Posted 2026-04-02, still listed on the board on 2026-11-22. First members of the Reliability
Engineering team in ClickHouse Core.

| Field | Value |
| :--- | :--- |
| Role ID | `clickhouse-database-reliability-engineer-core-emea` |
| Ashby id | `c3617664-a679-406a-8fd5-71d51a407243` |
| Employer | ClickHouse (ClickHouse Cloud) |
| Team | Engineering — ClickHouse Core |
| Location | **EMEA remote: Netherlands, UK or Germany** |
| Employment | Full-time |
| Apply URL | https://jobs.ashbyhq.com/clickhouse/c3617664-a679-406a-8fd5-71d51a407243 |
| Language | `en` |

## Location and authorisation — the reason this one is worth doing

The posting names Germany explicitly as a remote base, so there is no relocation and no permit:
the candidate lives in Gutach im Breisgau and holds German permanent residence. Unlike the
MongoDB storage-layer role, nothing here depends on a move. The letter says so in one sentence and
does not ask for sponsorship, because for a German contract none is needed.

## Compensation notes

The Ashby posting carries **no compensation tiers** — `compensationTiers`, the salary summary and
the scrapeable summary all come back empty from the board API. What it does state is the package
shape: equity for every eligible hire, employer contributions to healthcare, flexible time off
outside the US, a USD 500 home-office allowance, and global offsites. No figure goes into the
letter; a number without a band would anchor against nothing. First call: ask for the German
remote band, then decide.

## Fit map

| Requirement (description) | Evidence | Verdict |
| :--- | :--- | :--- |
| Improve reliability and performance of the core | Thirteen-host fleet with a gate on every change, rollback by pointer, a ledger of PSI and disk pressure | partial — method real, scale small |
| Metrics and alerts that catch problems before customers | Sentinel ledger every 15 minutes (pressure, disk headroom, job status, generation age) with paging on any non-ok state | strong |
| Root-cause work deep enough to file the bug | Faults traced through journald, unit state, cgroup counters and tcpdump; the fix becomes a check | strong |
| Incident response and blameless postmortems | Incident evidence and decision notes kept; no postmortem process owned in a 24/7 org | partial |
| Chaos initiatives | None run | **gap** |
| On-call process ownership | Accepted on-call; no rotation carried at company scale | partial |
| 5+ years reliability, QA or customer-facing engineering | Ten years of systems and client work; reliability practice concentrated in the last three | partial |
| Operating ClickHouse or another SQL database in production | PostgreSQL as system of record for an archive and a pipeline, SQL by hand, schema in the same repo | partial — Postgres, not ClickHouse |
| Distributed database internals and SQL | SQL yes; storage engine, replication and query planner no | **gap** |
| Shell or Python, able to read C++ | Python, Bash and Go daily; C++ written at Fraunhofer ISE, readable now | partial |
| AWS, Azure or GCP | Small AWS Lambda project and Oracle Cloud hosts, not platform ownership | partial |
| Production debugging, problem solving | Single operator: every fault was mine to find and close | strong |

## Ashby schema

Ashby renders the form from the posting; the public board API exposes the job but not its custom
questions, so the standard fields below are the stable part and the custom ones must be read on the
form itself before submitting.

| Field | Answer |
| :--- | :--- |
| Name | Matt Ji |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| Resume/CV | `lebenslauf.pdf` (2 pages) |
| Cover Letter | `anschreiben.pdf` (1 page) |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Website | https://www.bountystash.com |
| Location | Gutach im Breisgau, Germany — remote in Germany is offered |
| Work authorisation | German permanent residence, no sponsorship needed |
| How did you hear about us | ClickHouse job board (Ashby) |

## What the CV says, measured on the built PDF

The projection kept 11 of 30 highlights and 4 of 10 projects. Measured on the finished text:
**SQL ×3, PostgreSQL ×3, PSI ×3, cgroup ×3, telemetry ×2, reliability ×2, disk ×2**, and
**ClickHouse, kernel and distributed zero times**. The CV is a Linux-performance and
telemetry document; the letter has to argue the database-reliability case and concede the internals.

## What the letter says

It opens on the three things the role actually asks for — improve the core, alert before customers
notice, find the bug — then describes the fleet: PostgreSQL as system of record, pressure-based
telemetry, journald and cgroup debugging, tcpdump when the network lies, releases with a rollback
pointer, Go and Python tooling. The third paragraph is the database concession: Postgres operated,
SQL by hand, C++ readable but not current, ClickHouse and distributed internals not touched. The
fourth names chaos, postmortems at scale, on-call at company scale and cloud platform ownership as
absent, and notes that Germany remote needs no sponsorship.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 205 prose files, exit 0 |
| selection | 11/30 highlights, 4/10 projects |
| sha256 CV | `2280bd1481ff3f747c95277d91bc72a552ad87de45d32b9cb808d020e6579c62` |
| sha256 letter | `d73f8ab1c1ca3090eb65052eb86102bed0020beb7c8197e8ef5da0d4413847aa` |

## Next actions

1. Submit through Ashby at the apply URL; the form's custom questions (authorisation, location,
   how-heard) must be read live, not guessed.
2. Ask for the German remote band in the first conversation — the posting publishes none.
3. Prepare the internals answer honestly: Postgres operation and SQL fluency plus Linux
   performance debugging is the transferable half; the storage engine is the learning half.
