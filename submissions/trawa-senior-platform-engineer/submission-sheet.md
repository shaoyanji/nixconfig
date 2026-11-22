# Application trawa — Senior Platform Engineer (Berlin)

Prepared: 22 November 2026
Fit: 4 / 5
Language: English

## Role

| Field | Value |
| :--- | :--- |
| Company | trawa, B2B renewable energy platform, Berlin HQ, around 100 employees, over EUR 35M raised |
| Team | Platform — infrastructure, shared tooling, developer experience |
| Role | Senior Platform Engineer, permanent, full-time |
| Location | Berlin HQ, in person most of the week, flexible hours |
| Compensation | Salary plus stock options, 30 days vacation; no band published |
| Deadline | None published |
| Route | Ashby application form on the posting |

## The two requirements that decide this application

1. **At least 8 years in a platform, DevOps or SRE role.** The candidate has ten years in operations, five of them owning a fleet end to end as founder. That is the work, but not the titled tenure. The letter states this instead of rounding up.
2. **In person most of the week in Berlin.** The candidate lives in Gutach im Breisgau, about 700 km away. Relocation is a genuine decision and the letter says so.

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Cover letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compiles standalone |
| Certificates | none | Degree certificate still missing from the packet |

## Match

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| 8+ years platform, DevOps or SRE | Ten years of operations, five owning a fleet as founder | Close, not literal |
| Deep hands-on AWS | No production AWS; bare metal and VLANs | Gap |
| Infrastructure as code, ideally Terraform | Declarative estate in Nix, module per service, gate per host | Strong concept, different tool |
| Distributed services in production, security, reliability, observability, cost | Ledger, delivery-confirmed alerts, restores, rollback, resource limits, PSI watching | Strong |
| Scalable, secure, highly available AWS infrastructure | Equivalent properties on own hardware, not AWS primitives | Partial |
| CI/CD pipelines and internal platforms | CI gate identical to rollout gate; documented tasks instead of tribal knowledge | Strong |
| Security in infrastructure and pipelines: access, secrets, compliance | sops/age, own CA with short-lived certificates, nftables, no exposed service | Strong on craft, no compliance frameworks |
| Docker, GitHub Actions, Spacelift | None | Gap |
| Python, TypeScript | Go, Python, shell; no TypeScript | Partial |
| Dash0, Sentry, Incident.io | Adjacent practice, different products | Gap |
| Partner with engineers, make the right way the easy way | Onboarded others onto the fleet, runbooks, tasks as the interface | Strong |

## Why 4 and not 5

Four, because the platform discipline is real and shows in the details trawa says it cares about: availability, security, observability, cost, and the developer experience of shipping safely. The domain fit is unusually good for a platform role, since the candidate studied exactly what trawa sells.

Not five, because four of the named stack items are absent, and because the eight-year criterion is met in substance rather than in title. A senior platform hire who needs to learn AWS and Terraform on production infrastructure is a real cost, and the letter does not hide it.

## Open points

1. **Relocation to Berlin.** In-person most of the week is explicit; the letter commits to the move for the domain. Decide whether that is true before sending.
2. Certificates are missing; the application form normally asks for a CV upload, and a degree document strengthens the 1.8 claim.
3. No compensation band. Do not name a figure first; stock options are part of the package and worth asking about at offer stage.
4. No deadline, no named contact. The posting is live as of 22 November 2026.
5. Nothing has been submitted; the Ashby form was not rendered.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full posting text from the Ashby job board API, with header notes. |
| `lead.md` | Fit, gaps, route, pay. |
| `lebenslauf.typ` | Typst source, compiles standalone. |
| `anschreiben.typ` | Typst source, compiles standalone. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This sheet. |
