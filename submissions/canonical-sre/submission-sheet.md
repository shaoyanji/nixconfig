# Application — Canonical, Senior Site Reliability Engineer

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Canonical |
| Role | Senior Site Reliability Engineer |
| Location | Home based — Worldwide; team sprints two to four times a year |
| Source | Greenhouse job API, HTTP 200 on 22.11.2026 |
| Req | 3029798 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: the directory and the row were both absent, so the legacy `packet` symlink and JSON leftovers named in the brief did not exist.

## Requirements check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Linux at depth | systemd, nftables, networking, storage and capacity work across three hardware generations | Strong |
| Python software engineering | Tooling for rollout, ledger analysis and automated checks | Strong |
| Pure-software infrastructure automation | Declarative fleet, CI gate on evaluated state, rollback as a task | Strong |
| Scientific approach to operations | Telemetry written to be acted on, 15-minute ledger, alert delivery confirmed, restores verified | Strong |
| Open source | NixOS, Gatus, restic, sops, Tailscale; public repository | Strong |
| Worldwide remote | Germany base with permanent residence, US passport, no sponsorship | Met |
| Kubernetes | Not held | **Gap** |
| Kernel development | Linux operated, not patched | **Gap** |
| Distributed storage | No Ceph or storage internals | **Gap** |
| Scale | 13 hosts, single operator | **Gap** |

## Fit reasoning: 4 of 5

Four, as briefed. The working method matches unusually closely: infrastructure as code, a gate before rollout, observability written by the person on call, operational knowledge kept as runbooks. The self-direction a globally distributed company needs is demonstrated by five years of sole operation.

Not 5, because Kubernetes and kernel-level work appear in the posting and neither is evidenced, and the fleet is orders of magnitude smaller.

## Open items

1. **Kubernetes** named in the letter, not hidden.
2. **Kernel**: the CV says Linux is operated, not patched.
3. **Scale**: thirteen hosts vs fleets of thousands.
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
