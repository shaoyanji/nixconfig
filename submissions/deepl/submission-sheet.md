# Application — DeepL, Staff SRE Sovereign Cloud

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | DeepL (~1,000 employees, 200,000+ business customers) |
| Role | Staff Site Reliability Engineer - Sovereign Cloud |
| Team | DeepL for Sovereign Markets — public sector and regulated organisations, hosted and operated inside the EU |
| Location | Munich / Germany remote |
| Source | arbeitnow posting, HTTP 200 on 22.11.2026 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory, no DB row, no `selection.json` and no old nix-built PDFs to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Linux depth | systemd, cgroups, namespaces, boot and recovery across three hardware generations | Strong |
| System isolation | WireGuard mesh, no public listener, nftables, per-service boundaries | Strong |
| Secrets and access | sops/age per host, own SSH CA with short-lived certificates | Strong |
| Telemetry and observability | Gatus, 15-minute JSONL ledger, PSI and disk pressure, delivery confirmation | Strong |
| Automated remediation | Runbooks as tasks, gated rollout, rollback by generation | Strong |
| Hermetic reproducible builds | Pinned inputs, identical builds, rollback by generation | Strong |
| European residency / jurisdiction | Resident in Germany with permanent residence | Met |
| Kubernetes | Not held | **Gap** |
| Managed cloud infrastructure | Owned hardware, no managed cloud | **Gap** |
| Staff-level scope | Single operator; no cross-team direction or mentoring record | **Gap** |
| Formal EU compliance (BSI C5, ISO 27001, SOC 2) | Audit trail kept by habit, no programme carried through an audit | **Gap** |

## Fit reasoning: 4 of 5

Four, as briefed. The technical substance matches: isolation, secrets, certificates, reproducible builds and observability are built and operated, not quoted, and German residency settles the jurisdiction question for a sovereign EU platform.

Not 5, because Kubernetes and managed cloud are absent and the role is Staff-scoped — influence across teams is not in the record. Four means the conversation is plausible and platform tooling plus reach are the onboarding.

## Open items

1. **Kubernetes, managed cloud, Staff scope** named in the letter, not hidden.
2. **Compliance programmes** explicitly not claimed; the audit habit is.
3. **Residency** is stated as German with permanent residence — the EU-jurisdiction requirement is met.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text plus cross-check note. |
| `lead.md` | Fit, gaps, route, salary. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
