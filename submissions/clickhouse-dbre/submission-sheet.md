# ClickHouse — Database Reliability Engineer, Core Team (EMEA Remote)

Ashby posting `c3617664-a679-406a-8fd5-71d51a407243`. English packet. Native Typst sources, `packet` symlink and
JSON leftovers removed. Status: built and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `clickhouse-dbre` |
| Employer | ClickHouse |
| Role | Database Reliability Engineer, Core Team |
| Location | EMEA Remote — Germany base, no relocation |
| ATS | Ashby |
| Language | **English** |
| Compensation | no figure in the letter — none supplied |
| Fit | 2 (DB entry 4) |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Database reliability | PostgreSQL as service backend, schema and indexes, data pipelines | partial — app backend, not a DB fleet |
| ClickHouse | **not operated** | **gap** |
| Linux internals | systemd, journald, cgroups/PSI, tcpdump, strace | strong |
| Performance under load | PSI/cgroups triage, memory versus I/O versus CPU | strong |
| Telemetry and alerting | Fifteen-minute ledger, silence as fault | strong |
| Postmortems without blame | Cause-before-action notes kept beside the repo | strong in practice |
| High availability | Generation rollback, no half-applied change | strong at fleet scale |
| Distributed systems at scale | **no evidence** | **gap** |
| Germany remote, no sponsorship | German permanent residence, US citizen | fulfilled |

## The honest position

The Core team works on ClickHouse itself — replication, merge behaviour, performance at scale. Nothing in the
corpus touches that, so the letter puts the gap in the middle rather than at the edge: *"that gap is the centre of
this application rather than a footnote."* Fit **2**. A 4 would be unjustifiable for a role whose subject is a
database the candidate has never operated.

Why send it at all: the transferable half is unusually strong and unusually specific — Linux internals rather than
abstraction, pressure-based diagnosis, alert design, and postmortem discipline. ClickHouse hires for analytical
depth in systems, and a candidate who can say precisely what they have not done is a better bet than one who
claims the vocabulary.

## Checks

| Check | Result |
| :--- | :--- |
| `packet` symlink | removed |
| Legacy JSON | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers | `ClickHouse`, `EMEA`, `PSI`, `postmortem`, `no sponsorship` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 CV | `6ce0167978fe4c5c4e5933b5fab60a5fd763d47ec28850f26648665e09562f38` |
| sha256 letter | `619fff629892255e34fba7a81669d3b71a0bad7f1ff63831f5e1fe5d0ebe760d` |

## Next steps

1. Apply through the Ashby link.
2. Ask which reliability surface the Core team owns today — replication, merges, or query performance — before a
   technical interview is scheduled.
3. If the answer is "all of it, from day one", this application is unlikely to convert; the letter says as much.
