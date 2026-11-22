# Application — Black Forest Labs, MTS Infrastructure Security

Date: 22 November 2026
Fit: 5
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | Black Forest Labs (founders of latent diffusion / Stable Diffusion; FLUX models) |
| Role | Member of Technical Staff - Infrastructure Security |
| Location | Freiburg im Breisgau lab / San Francisco; posting listed as remote |
| Comp | $220,000 – $280,000 + equity (from the brief; not shown on the fetched page) |
| Source | arbeitnow posting, HTTP 200 on 22.11.2026 |
| Salary in letter | none stated |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English, local anchor in the final paragraph |
| CV | `lebenslauf.pdf` | Two pages, English, security work first |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory, no DB row, no `selection.json` and no old nix-built PDFs to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Network boundaries and workload isolation | WireGuard mesh, no public listener, nftables, cgroups and namespaces | Strong |
| Identity and access, least privilege | Own SSH CA, short-lived certificates, per-host keys | Strong |
| Secrets management | sops/age, encrypted in git, one key per host | Strong |
| Cloud and compute security | Owned hardware; AWS and Kubernetes not held | **Gap** |
| Hermetic, reviewable builds | Pinned inputs, gate on evaluated state, rollback by generation | Strong |
| Audit trail | 15-minute sentinel ledger, runbooks, git history | Strong |
| Protecting model assets and customer data | No model-asset lifecycle work; financial data handled under external reporting | **Partial** |
| ML training fleets | Not held | **Gap** |
| Formal threat modelling, IR, SOC 2 / ISO 27001 | Not held | **Gap** |
| Hands-on engineering | Sole builder and operator, reads code and ships changes daily | Strong |
| Local presence near Freiburg | Gutach im Breisgau, ~25 km from the lab | Strong |
| Work authorisation | US citizen with permanent German residence | Met |

## Fit reasoning: 5 of 5

The role asks for someone who can dig into infrastructure, make boundary and identity decisions, and ship the fix. That is what running a thirteen-host fleet alone requires, and the evidence is specific: a certificate authority instead of shared keys, sops per host, a mesh with no public listener, cgroups and PSI for isolation, hermetic builds, and an audit trail that existed before anyone asked for one.

The local anchor is real: 25 km from the Freiburg lab, in the same Landkreis.

That is why 5 holds even with three honest gaps — no security title, no AWS/Kubernetes security, and no ML compute fleet. The gaps are the environment; the instinct is the qualification.

## Open items

1. **AWS, Kubernetes, ML training infrastructure** named in the letter as absent.
2. **Formal security practice** — threat modelling, incident response, compliance — explicitly not claimed.
3. **Comp** is recorded from the brief; the fetched page did not show it, so no number appears in the letter.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text plus cross-check note. |
| `lead.md` | Fit, gaps, route, comp. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
