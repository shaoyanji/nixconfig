# Application: smartclip Europe GmbH — Site Reliability Engineer (f/m/d), Observability & Internal Tools

As of: 22 November 2026
Fit: 3
Language: English dossier

## The role

| Field | Value |
| :--- | :--- |
| Employer | smartclip Europe GmbH |
| Role | Site Reliability Engineer (f/m/d) — Observability & Internal Tools |
| Location | Germany, remote by default; on-site in Berlin or Cologne for larger features |
| Stack in the posting | Prometheus, Grafana, Forgejo; open-source alternatives to proprietary tooling |
| Salary in the posting | Not specified; benefits listed instead |
| Own expectation | 80,000 to 85,000 EUR, stated in the letter |
| Application | Original posting on hiddenjobs.dev, retrieved 22 November 2026 |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Cover letter | `anschreiben.pdf` | One page, English, salary and residence status stated |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compiles standalone |
| Certificates | none | Still to be added |

## Requirement match

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Production experience with Prometheus, Grafana and related tooling | None | **Hard gap** |
| Turning monitoring into a platform capability | Ledger, Gatus, Go alerting bridge, runbooks | Partial — own tooling, not theirs |
| Actionable alerts and SLOs, reactive to proactive | Delivery-confirmed alerting; no formal SLO programme | Partial |
| Linux internals and distributed systems | systemd hardening, cgroup limits, PSI, namespaces, nftables | Strong on internals; single-site fleet, not distributed at scale |
| Infrastructure as code | Flake with modules, gates, generations and rollback | Strong |
| Proof of building rather than configuring | Public repository, 13 hosts, self-written telemetry and tools | Strong — the explicit ask |
| Security integrated into CI/CD | sops and age, own CA, short-lived certificates, gates before deploy | Strong |
| Automating other engineers' work | Task verbs for Forgejo REST operations, runbooks, CI gates | Partial |
| Open-source engagement, conferences | Public repo only, no upstream contributions | Weak |
| Kubernetes, AWS, GCP | None | Gap (not required in the text; detected as skills) |

## Fit: 3 of 5

Three because Prometheus and Grafana are the first requirement and the role is built on them. The custom stack is the same discipline but not the same tooling, and re-platforming on day one is not on offer.

The brief said 4; the brief was written from a summary. The full posting makes production Prometheus and Grafana experience explicit, which is the pattern used elsewhere in this pipeline: a named must-have that is absent lowers the fit and gets said out loud in the letter.

Not a 2 because the posting's most distinctive demand — show that you build — is exactly what the public repository answers.

## Open points

1. **Prometheus and Grafana absent.** Conceded in the fourth paragraph of the letter, named as new work rather than reframed.
2. **No formal SLO or error-budget practice.** The letter says so and describes the informal budgets actually used.
3. **Application link is gated.** Hidden Jobs requires a paid plan to reveal the original link; the low-cost route is smartclip's own careers page.
4. Certificates still missing.
5. Single-site fleet, no on-call rotation with a team, no ad-tech experience.
6. Salary expectation 80,000 to 85,000 EUR; the posting states none, so no band conflict to manage.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full English posting text with a cross-check note. |
| `lead.md` | Fit reasoning, matches, gaps, route, salary. |
| `lebenslauf.typ` | Typst source, compiles standalone. |
| `anschreiben.typ` | Typst source, compiles standalone. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
