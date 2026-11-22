# Application — Canonical, Senior Site Reliability / Gitops Engineer

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Canonical |
| Role | Senior Site Reliability / Gitops Engineer |
| Team | Information Systems |
| Location | Home based — Worldwide; remote from Germany |
| Source | Greenhouse job API, HTTP 200 on 22.11.2026 |
| Req | 5517891 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory and no DB row, so there were no legacy PDFs, symlinks or `selection.json` to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| GitOps, Git as source of truth | Hosts and services described in one flake; no host edited by hand; rollback by revert | Strong |
| CI/CD ownership | Gate on modules and assertions before deployment; same config evaluated, built and deployed | Strong |
| Linux system engineering | systemd, networking, nftables, storage, SSH CA across three hardware generations | Strong |
| IT operations automation | Python and Go tooling that removes manual steps; tasks replace procedures | Strong |
| Observability | Gatus probes, 15-minute sentinel ledger, analysis in Python and Go | Strong |
| Reliability culture | Alert delivery confirmed by a Go bridge; restores verified, not backup runs counted | Strong |
| Systems serving a very large Ubuntu population | Not held at that scale | **Gap** |
| Kubernetes | Not held | **Gap** |
| ArgoCD or equivalent GitOps controller | Not held; GitOps practised without a sync controller | **Gap** |
| Remote from Germany, no sponsorship | Germany base, permanent residence, US citizen | Met |
| English native, German C1 | Stated | Met |

## Fit reasoning: 4 of 5

Four, as briefed. The method matches what the Information Systems team describes: Git as the only path to change, automation instead of procedure, a gate before rollout, observability written by the operator.

Not 5, because Kubernetes and ArgoCD are absent and the fleet is thirteen hosts rather than systems at Canonical's scale. Four means the discipline is demonstrated and the tooling is learnable.

## Open items

1. **Kubernetes, ArgoCD** named in the letter, not hidden.
2. **Scale**: thirteen hosts vs systems serving millions of users.
3. Certificates still missing.

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
