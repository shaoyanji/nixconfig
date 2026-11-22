# Celonis — Senior Software Engineer, Query Engine & Database Systems

Munich, Germany. Greenhouse req **7980155003**. English packet. Native Typst sources; scout staged `job-description.txt`.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `celonis-query-engine-database` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `celonis-query-engine-database` |
| Employer | Celonis SE (HQ Munich + NYC; Process Intelligence / Context Model) |
| Role | Senior Software Engineer — Query Engine & Database Systems, **Core squad** |
| Location | Munich, Germany (hybrid) |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/celonis/jobs/7980155003?gh_jid=7980155003 |
| Compensation | not published; no figure in the letter |
| Fit | 3 |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 851 | `c09d8856363622ee98cb26698271e7bf0362dff29b9897354fe40722623cad7c` |
| `anschreiben.pdf` | **1** | 469 | `ec58a8c3c57f81f1b7b3eb636eff2e641a66ecbc053e791cf2b67eaae4537119` |

Both compiled with typst 0.15.1 at **0 warnings**; `task checks:prose` — 266 files, exit 0.

## What the role is

The **Process Query Engine** is Celonis' analytical database for process mining — the core product under the Context Model.
The Core squad builds new concepts and algorithms for data management and query execution, benchmarks against performance-
engineering principles, and owns reliability, scalability and performance of a highly parallelised, distributed engine in
**modern C++ (Java a plus)**. Stated needs: systems programming in C++, parallel computing / distributed systems / database
internals, 5+ years in productive systems; cloud, Linux, IaC, build systems and performance monitoring as pluses; German a
plus.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Systems programming | Go + Python daily; C++ production code at Fraunhofer ISE (2012) | partial — C++ dated |
| Parallel / distributed systems | Go coordination service: concurrent claims, ordered turns, idempotent writes | **strong** |
| Database internals | Postgres hot tables behind an API; query surface design — storage **use**, not engine internals | partial — no shipped internals |
| Performance engineering | cgroup accounting, PSI, `strace`, `tcpdump`, queue-depth capacity | **strong** |
| Resource bounding under load | microVM caps, explicit GPU yielding — the memory-limit problem at OS layer | **strong** (analogous layer) |
| Determinism / build systems | Pinned inputs, reproducible builds, shared cache — the property an engine test loop wants | **strong** |
| Java | none | gap |
| Production DB engine internals | none | **gap, core requirement** |
| Modern C++ as primary language | none recent | **gap, core requirement** |
| German | C1 | meets "plus" |

Fit **3**: measurement discipline, concurrency and determinism are genuine and directly transferable; the two explicit core
requirements — current modern C++ and shipped engine internals — are not in the corpus and are conceded in the letter rather
than papered over. Munich is a long commute from Gutach; the letter offers office days by arrangement.

## Form notes for Pane 2

- Greenhouse board `celonis` — standard fields + likely react-select questions; the earlier Celonis record family used the
  proven OTP lane (this board sent OTP codes for other reqs).
- Watch for: cover-letter slot presence, work-authorisation and relocation comboboxes, voluntary demographics
  (prefer-not-to-say where a fact is unknown), any "severe disability" disclosure (prefer not to answer).
- Honest answers if asked: no production C++ project recently, no Java, willing to grow both on the job; Munich presence by
  arrangement, no relocation promised.
