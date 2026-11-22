# Application — Canonical, Lead Linux Kernel Engineer - Ubuntu

Date: 22 November 2026
Fit: 1
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Canonical |
| Role | Lead Linux Kernel Engineer - Ubuntu |
| Location | Home based — Worldwide |
| Source | Greenhouse job API, HTTP 200 on 22.11.2026 |
| Req | 6010955 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English, opens with the disqualifier |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: the directory and the row did not exist, so the legacy files named in the brief (`Canonical_Kernel_Cover_Note.pdf`, `Matt_Ji_Resume_Canonical_Kernel.pdf`, `selection.json`) were not present to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Kernel configuration | Options declared in NixOS modules, reviewed in git, applied by rebuild | Strong (operational) |
| systemd, cgroups, namespaces | Service isolation, resource limits, debugging limit-caused failures | Strong (operational) |
| Hermetic reproducibility | Pinned inputs, identical builds across machines, generation rollback | Strong |
| CVE mitigation | Kernel and CVE updates across a fleet by rebuild; no patch authorship | Partial |
| Boot, initrd, recovery | Recovery without console across three hardware generations | Strong (operational) |
| Driver and subsystem analysis | Not held | **Gap** |
| Kernel patch development and review | Not held | **Fatal gap** |
| eBPF | Not held | **Gap** |
| Upstream triage | Not held | **Fatal gap** |
| Silicon and cloud partner engagement | Not held | **Gap** |
| Leading kernel engineers | Not held | **Gap** |
| Remote from Germany, no sponsorship | Germany base, permanent residence, US citizen | Met |

## Fit reasoning: 1 of 5

The brief specified 4; the evidence supports 1, and the DB records 1.

This role's subject is kernel code and upstream authority: patches, reviews, driver and subsystem work, triage, partner engagements, and leading the engineers who do it. The record contains none of that. What it contains is the operating half — kernel configuration as code, hermetic builds, cgroup and namespace isolation, fleet-wide kernel updates, boot recovery — which is genuinely relevant but second-order here.

A 4 would claim an interview is plausible. At this level it would end in the first technical screen, and claiming otherwise would misrepresent the candidate to a team that would find out in ten minutes. A 1 means: the packet is honest and sendable, and expectations are set accordingly.

## Open items

1. **Every kernel-engineering requirement** is absent and stated as such in the letter's first line.
2. **Leadership**: no team, no mentoring history, no maintainer role.
3. If submitting, expect no response; this is a long shot by design.
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
