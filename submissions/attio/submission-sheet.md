# Application — Attio, Senior Platform Engineer

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Attio |
| Role | Senior Platform Engineer |
| Location | London (board also lists the same role for Poland) |
| Source | Attio Ashby board, HTTP 200 on 22.11.2026 |
| Ashby ID | c05a61a4-ae7c-4d93-a920-08d60c7448ad |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

Existing state: the directory was absent, so the legacy `packet` symlink and JSON leftovers named in the brief did not exist; nothing to remove.

## Requirements check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Platform as a product | Thirteen-host fleet, rollout only through a pipeline, publishing and rollback as tasks | Strong |
| Declarative infrastructure | One module per service, one feature list per host, CI checks the evaluated state | Strong |
| CI/CD ownership | Gate on modules and assertions before every rollout; same configuration built and deployed | Strong |
| Observability | Gatus probes, 15-minute sentinel ledger, analysis in Go and Python | Strong |
| Reliability culture | Alert delivery confirmed by a Go bridge; restores verified rather than backups counted | Strong |
| Kubernetes | Not held | **Gap** |
| Terraform | Not held; declarative work is Nix | **Gap** |
| AWS | No cloud platform ownership | **Gap** |
| Scale | 13 hosts, single operator | **Gap** |
| Remote Europe base, no sponsorship | Germany, permanent residence, US citizen | Met |
| English native, German C1 | Stated | Met |

## Fit reasoning: 4 of 5

Four, as briefed. The way of working matches: a platform a team owns, gates instead of promises, observability as part of the system rather than a purchase.

Not 5, because Kubernetes, Terraform and AWS are the three tools the role is built around and none has been run in own responsibility. Four means the discipline is evidenced and the tools are learnable.

## Open items

1. **Kubernetes, Terraform, AWS** named in the letter, not hidden.
2. **Scale**: thirteen hosts vs a multi-team platform.
3. **London**: the posting names London; application is from Germany with permanent residence.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full posting plus cross-check note. |
| `lead.md` | Fit, gaps, route, salary. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
