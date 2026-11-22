# ScorePlay — Senior Platform / SRE Engineer

Ashby posting. English packet. Native Typst sources, old `packet/` tree and JSON leftovers removed.
Status: built and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `scoreplay` |
| Employer | ScorePlay (sports media platform) |
| Role | Senior Platform / SRE Engineer |
| Language | **English** |
| Compensation | no figure in the letter — none supplied |
| Fit | 3 (DB entry 4) |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Storage architecture | Content-addressed store, retention as design, lifecycle | strong at small scale |
| Multi-region distributed systems | **no multi-region operation** | **gap** |
| 15 PB estate / storage economics | capacity measured, cost instinct; **no PB-scale** | **gap** |
| BYOS (bring your own storage) | **not built** | **gap** |
| Linux system engineering | systemd, journald, cgroups/PSI, tcpdump, strace | strong |
| Telemetry and alerting | Fifteen-minute ledger, silence as fault | strong |
| Event-driven pipelines | Ingest, normalise, publish, idempotent reruns | strong |
| Declarative platform work | Flake, pinned inputs, gate, rollback | strong |
| Remote Europe, no sponsorship | German permanent residence, US citizen | fulfilled |

## The framing worth keeping

The letter's opening is the argument: **media platforms are storage businesses with a video player attached** —
once an asset is in, it must stay retrievable, verifiable and affordable for years, and every shortcut at ingest
returns as a migration. That reframes the role away from "run Kubernetes" towards capacity, retention and cost,
which is where the corpus has something real: a content-addressed store where identical input lands on identical
identity, so deduplication and retention are properties of the design rather than a cleanup job.

Three gaps are named: no 15 PB multi-region estate, no BYOS deployments, no cross-region replication or egress
economics at that size. Fit **3** — the discipline and the cost instinct transfer, the scale does not.

## Checks

| Check | Result |
| :--- | :--- |
| `packet/` directory, JSON leftovers | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers | `Maxime`, `15 PB`, `BYOS`, `content-addressed`, `idempotent` |
| `task checks:prose` | 241 prose files, exit 0 |
| sha256 CV | `6aafcd638b29b43a28025d8702ebffb4a0509c885865fb35231034fa963d05ca` |
| sha256 letter | `d34b4f2f70725f920e59114b6d62ec75c68b8d8d7c21a05adf85c7e055a65ab9` |
| DB read-back | verified after upsert |

## Next steps

1. Apply through Ashby; the letter is addressed to Maxime and the Platform team.
2. Ask how storage is partitioned today — per-asset vs per-tenant — and what drives cost: hot storage, egress, or
   replication.
3. If the answer is "all three at PB scale", expect the interview to test multi-region failure reasoning, which is
   the stated gap.
