# MongoDB — Site Reliability Engineer (Senior or Staff), Storage Layer Services

Greenhouse **6984814** (`gh_jid`) · internal req **2263171786** · https://www.mongodb.com/careers/job/?gh_jid=6984814
Team: Storage Layer Services, founding SREs for the re-architected Atlas storage layer. Location: Dublin, Cork, or remote **in Ireland**.

**Submitted** per the apps DB (OTP mail 311062 on file, 2026-11-22).

Native English Typst rebuild, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1139 | 0 | `389836ae7c36ae4c` |
| `anschreiben.pdf` | 1 | 474 | 0 | `ab3e052abb77d7ff` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, `lead.md`, this sheet. Retired in this rebuild: the `/nix/store` `packet`
symlink, `letter.json`, and the per-packet `resume.json` — the corpus copy is the source, and a second copy of it in a submission folder
only drifts.

## What changed

The submitted CV was a projection: 635 words over two pages, thirteen of thirty-six highlights kept, and — measured on its own text —
Kubernetes, SRE, SLO, durability, multi-tenant and on-call appear **zero** times. For a storage reliability role that is the wrong shape
even before the content is judged: the reliability vocabulary lived entirely in the letter.

The native CV carries the argument itself: measure-change-verify with the way back designed in, the ledger every fifteen minutes paging
on state and on silence, journald plus an event store to trace by host, unit and time window, systemd and cgroups and PSI and nftables
and tcpdump, capacity as a budget with a check, Go and Python behind one task interface, PostgreSQL with migrations and a walked restore.
The unsupported stack from the database build is gone.

Submitted bytes: `lebenslauf.pdf` `5f92cdda357bf853…` (2 pages, 635 words), `anschreiben.pdf` `84f34d15842b3d35…` (1 page, 506 words).

## Where the stack words sit

Kubernetes and the cloud platforms appear in the CV **zero** times and in the letter only inside the paragraph naming them as gaps. The
gaps paragraph is deliberately long here, because the posting asks for Kubernetes, AWS/GCP/Azure depth and stateful multi-tenant storage,
and a candidate who blurs that gets found out in the first technical screen.

## Location and sponsorship — the decisive constraint

"Remotely in Ireland" is not "remote in the EU". The candidate is in Germany.

| Item | Position |
| :--- | :--- |
| Relocation | Open to it — stated in the letter and in the CV footer |
| German permanent residence | Does not transfer to Ireland |
| Irish employment permit | Required; employer-supported. Greenhouse field `question_57683854` ("require employment sponsorship?") is answered **Yes** |
| Salary | No figure in the letter; MongoDB bands by location, so ask for the Dublin/Cork band first |

## Fit

**2 of 5.** Strong on the operating discipline the team says it wants — software over toil, measurement over dashboards, gates over
heroics, Linux and networking depth, Go and Python. Short on the specialty: no stateful multi-tenant storage at scale, no production
Kubernetes, no cloud platform ownership, no formal SLO programme, no 24/7 rotation carried. The letter says all of it before the first
call.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| Unsupported claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native rebuild; `packet` symlink, `letter.json` and `resume.json` removed in the same commit |

## If they reply

Expect Kubernetes first — the honest answer is containers as pinned build environments, a module boundary and a certificate authority,
not a cluster story. Then storage durability: the closest real ground is PostgreSQL with migrations, a rehearsed restore and statement
timeouts, plus immutable generations and a rollback that is a pointer.
