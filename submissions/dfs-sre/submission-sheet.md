# DFS Deutsche Flugsicherung — Ingenieur Site Reliability (m/w/d)

**Priority lead (fit 5).** BA advert `17761-1172604-2-S`, internal reference `J000000038`, edited
two days ago, so open. Advert copy is already in `job-description.txt`; this sheet adds the fit
map, the salary band and the portal answers.

| | |
| :--- | :--- |
| Role ID | `dfs-sre` |
| BA reference | 17761-1172604-2-S |
| DFS reference | J000000038 |
| Employer | DFS Deutsche Flugsicherung GmbH |
| Location | Am DFS Campus 1, 63225 Langen (Hessen) |
| Contact | Jessica Kuprat, karriere@dfs.de |
| Contract | 38,5 h/week, 32 days holiday, on-call |
| Requirements | security screening consent, medical fitness, driving licence B |

## Candidate facts used

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau |
| E-mail / phone | matt@bountystash.com / +49 173 3281570 |
| Languages | German C1, English native |
| Right to work | US citizen with German permanent residence, no sponsorship needed |
| Distance | ~250 km to Langen |
| Salary | target **90.000 – 100.000**, letter states **95.000** |
| Start | immediate or by agreement |

## Fit map

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Own service architectures across the whole lifecycle | Thirteen hosts declared once, projected per host, documented, rolled back by pointer | strong in miniature |
| Expert Linux administration | NixOS, systemd units, cgroups/PSI, nftables, DNS and MTU diagnosis with tcpdump | strong |
| Windows administration | Never administered Windows servers | **gap** |
| Ansible | Not used. Automation is Go/Python behind a task interface plus gates | **gap** |
| Python or another language | Python and Go tooling in daily use | strong |
| Building CI/CD pipelines | Gates that run in CI and on the host, changes only through them; no GitLab or Jenkins pipeline built | partial |
| Data-centre platform or cloud services: proxy, DNS, VPN, identity, monitoring, backup | DNS, WireGuard mesh, SSH CA, ledger and gatus-style alerting; no proxy, IAM or backup platform at enterprise scale | partial |
| Containers, orchestration, Kubernetes | Not operated in production | **gap** |
| Responsibility in critical infrastructure | Single-operator fleet where a bad change breaks mail and telemetry, not a simulator | partial — different stakes |
| Negotiation-level German, good English | German C1, English native | strong |
| Security screening, medical fitness, on-call, licence B | Screening: yes. On-call: yes. Medical fitness and licence B: **to confirm before submitting** | open |

## Portal schema — BA advert → DFS application

The BA page hides the contact behind a character test, so the two identifiers that matter are the
BA reference and DFS `J000000038`. The application itself runs through the DFS career route with a
document upload; the table below is the standard shape for that form.

| # | Field | Answer |
| :-- | :--- | :--- |
| 1 | Referenz | 17761-1172604-2-S / J000000038 |
| 2 | Anrede / Vorname | Herr, Matt |
| 3 | Nachname | Ji |
| 4 | E-Mail | matt@bountystash.com |
| 5 | Telefon | +49 173 3281570 |
| 6 | Anschrift | Am Burgerhof 4, 79261 Gutach im Breisgau |
| 7 | Lebenslauf | `lebenslauf.pdf` (2 Seiten) |
| 8 | Anschreiben | `anschreiben.pdf` (1 Seite) |
| 9 | Gehaltsvorstellung | 95.000 EUR brutto (Band 90.000 – 100.000) |
| 10 | Frühester Eintritt | sofort oder nach Vereinbarung |
| 11 | Bereitschaft Rufbereitschaft | ja |
| 12 | Sicherheitsüberprüfung | ja, Einwilligung erteilt |
| 13 | Medizinische Tauglichkeit | vor Abgabe klären |
| 14 | Führerschein Klasse B | vor Abgabe klären |
| 15 | Deutschkenntnisse | C1, verhandlungssicher |
| 16 | Arbeitserlaubnis | unbefristetes Niederlassungsrecht, kein Sponsoring |
| 17 | Datenschutz-Einwilligung | ja |

## Salary

Band requested by the candidate: 90.000 – 100.000 EUR. The letter states 95.000, in the middle,
which leaves room for the DFS pay grid and the 38,5-hour week. Aviation SRE roles at this level in
Hessen usually land in the upper half of that band, so 95.000 is a fair ask rather than a stretch.

## What the letter says

It opens with 10.000 flights a day as the reason reliability has to be provable, then describes
Linux administration down to cgroups and nftables, Go/Python automation behind a task interface,
and the ledger that decides whether something is healthy. The fourth paragraph names Ansible,
CI/CD pipelines, Kubernetes, Windows and the enterprise platform services as absent, and flags the
screening as accepted. Distance and salary close the letter.

## Checks

| Check | Result |
| :--- | :--- |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 192 prose files, exit 0 |
| selection | 14/37 highlights, 0/0 projects |
| sha256 CV | `f24d5be10d862f42e966a637d1e7bd9b875ec2556d85a6547598f18fb637c341` |
| sha256 letter | `b2d967119909ace0947718fb5ba1088dd400d6a936d8821084e4baa879c8b4f8` |

## Next actions

1. Confirm medical fitness and licence B — both are listed as conditions in the advert and the
   sheet marks them instead of assuming them.
2. Submit through the DFS career route quoting J000000038 and the BA reference.
3. Prepare the relocation answer: 250 km makes an office week impossible, and on-call in a control
   environment usually implies presence requirements.
