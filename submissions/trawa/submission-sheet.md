# Application — trawa, Senior Platform Engineer

Date: 22 November 2026
Fit: 4
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Employer | trawa (Berlin HQ, ~100 people, €35M raised, €24M Series A May 2025) |
| Role | Senior Platform Engineer |
| Location | Berlin, in person most of the week; markets Germany and Austria |
| Source | arbeitnow posting, HTTP 200 on 22.11.2026 |
| Salary | not stated in the posting; no number in the letter |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English, names relocation and the AWS/Terraform gap |
| CV | `lebenslauf.pdf` | Two pages, English, dual capability first |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory and no DB row, so no `selection.json` and no old nix-built PDFs to remove.

## Fit map

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Energy domain | 10 MW solar PV managed commercially, financial models, yield and cost analysis, M.Sc. Renewable Energy Management | Strong |
| 8+ years platform / DevOps / SRE | ~5 years sole operator plus earlier IT administration | **Partial** |
| Deep hands-on AWS | Owned hardware and NAS, not AWS | **Gap** |
| Infrastructure as code, ideally Terraform | Declarative with Nix and a flake, not HCL | Partial (concept strong, tool gap) |
| Distributed services in production | 13 hosts, single operator, no company-scale services | **Gap** |
| Security | sops/age, own SSH CA, no public listeners, nftables | Strong |
| Reliability | Health-gated rollout, rollback by generation, boot recovery | Strong |
| Observability | Gatus, 15-minute JSONL ledger, PSI and disk pressure, delivery confirmation | Strong |
| Cost efficiency | Small hosts, measured pressure, capacity planned from data | Strong |
| CI/CD and developer experience | Gate before rollout, tasks instead of procedures, public repo | Strong |
| Berlin presence | Candidate near Freiburg, willing to relocate | **Condition** |

## Fit reasoning: 4 of 5

The brief specified 5. Four is what the evidence supports.

The domain combination is the strongest in the entire pipeline: four years on the commercial side of solar PV plus five years running a declarative platform. That is rare and directly relevant to a company selling energy procurement, management and flexibility in one product.

Not 5 because the posting names three hard requirements that are absent: deep AWS, Terraform, and eight years of platform work. A 5 would assert those are met. A 4 says: the domain and the discipline carry the conversation, and the cloud stack is genuine onboarding.

## Open items

1. **AWS and Terraform** named in the letter, not hidden.
2. **Years**: ~5 vs 8+.
3. **Berlin**: relocation stated as willingness, not assumed.
4. **Unused brief claims**: "USD 100M portfolio, bank audits, EPC" appear in no repository source, so the packet says 10 MW and commercial asset management instead. If those numbers are real, send the source and they can be added.
5. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text plus cross-check note. |
| `lead.md` | Fit, gaps, route, salary, unused claims. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
