# Catapult Sports — Senior DevOps Engineer

Arbeitnow listing `457952`, fetched 2026-11-22. Packet built the same day, **nothing submitted**. **[applied per apps DB `catapult-sports-senior-devops` — this sheet's status predates submission]**
Unlike the other packets, this one is hand-authored Typst (`lebenslauf.typ`, `anschreiben.typ`), not the
JSON builder: the brief asked for compilable sources beside the PDFs.

| Field | Value |
| :--- | :--- |
| Role ID | `catapult-sports-senior-devops` |
| Employer | Catapult Sports, Cologne (NRW) |
| Role | Senior DevOps Engineer |
| Source | Arbeitnow API, 2026-11-22 |
| Language | English (advert, CV and letter) |
| Contract | Full-time; offer subject to Catapult's pre-hire check |
| Salary | **not published**; no figure in the letter, ask in the first call |
| Fit | 3 — the advertised 4 does not survive the requirement list |

## Match analysis

| Requirement (advert) | Evidence in the packet | Verdict |
| :--- | :--- | :--- |
| 5+ years DevOps / SRE / Platform | Ten years operating software and systems; five running a thirteen-host fleet | strong |
| Kubernetes in production: upgrades, networking, troubleshooting | **None.** Containers as pinned build environments only | **gap** |
| AWS plus bare-metal / self-hosted | Bare metal strong (PXE, iVentoy, rebuild, rollback); AWS weak (Oracle hosts, one Lambda) | half |
| Terraform / Ansible, GitOps workflow | NixOS modules and flake: declarative, versioned, gated — different tool | **gap in tool, not concept** |
| GitLab CI pipelines and shared templates | Gate design and shared module gate; no GitLab CI instance built | **gap** |
| GPU clusters, CV models, media engines | Models run locally under cgroup limits; no GPU cluster, no media pipeline | **gap** |
| Observability, meaningful alerting, HA | Ledger every 15 min (job status, generation age, disk, PSI), page on state ≠ ok | strong, different stack |
| Security: scanning, image screening, secrets, access control | SOPS/age, least privilege, private CA, short-lived certs; no image scanner | half |
| Deep Linux, Go/Python/Bash automation | NixOS, systemd, cgroups, journald, tcpdump; Go and Python services behind one task surface | strong |
| PostgreSQL (nice to have) | Go services on PostgreSQL, append-only event log | strong |
| Internal developer platform / self-service | Task surface and gates as the interface; not a portal | partial |

Four hard gaps (Kubernetes, Terraform, Ansible, GitLab CI) against an explicit "strong hands-on
Kubernetes" bar. The letter states all four in one paragraph before any call, and leans on Catapult's
own line that they would rather talk than miss the right person. Applying is defensible; expecting a
screen is not guaranteed.

## Cologne hybrid — the honest evaluation

The advert says "Based in Cologne" and Arbeitnow marks it `remote=false`. Gutach im Breisgau is roughly
450 km away, about four and a half hours by train with a change in Mannheim.

| Option | Reality |
| :--- | :--- |
| Fully remote | Not offered by the advert. Do not assume it |
| Hybrid with regular presence | Workable only at 1–2 office days per week with overnight stays; commute-and-return in a day is 9 h of travel |
| Relocation | The honest answer if the team wants 3+ days; the letter says it is open to discussing it |
| Pre-hire check | Standard for Catapult; nothing in the packet should be a surprise there |

The letter commits to hybrid with regular presence and offers relocation as a discussion, rather than
promising a commute that does not exist.

## Prüfungen / Checks

| Check | Result |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** (budget 2) |
| `pdfinfo anschreiben.pdf` | **1 page** (budget 1) |
| `task checks:prose` | 222 prose files, exit 0 |
| sha256 Lebenslauf | `c36a5c3cef8acb0c36300cabfc22025ddaf54a6e5d1d3873b22a3652c61f04e9` |
| sha256 Anschreiben | `01fa49c524fa8e1dc80635ffb4e800043e6eb4a89fe2237cd81d5ed22311edd4` |

Fonts: `DejaVu Sans` — `Inter` and `Liberation Sans` are not installed on this host, and pinning a
missing family would have silently changed layout between machines.

## Next steps

1. Decide the hybrid question before applying: 450 km is the real constraint, not the stack.
2. Submit via the Arbeitnow link with both PDFs.
3. In the first call, ask which of the four gaps the team can train and which are hard filters.
