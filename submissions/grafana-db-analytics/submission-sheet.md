# Grafana Labs — Senior Full Stack Engineer, Databases - Analytics

Germany Remote. Greenhouse req **6200027004**. English packet. Native Typst sources; scout staged `job-description.txt`.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `grafana-db-analytics` |
| Employer | Grafana Labs (Grafana Cloud observability; 100% remote company) |
| Role | Senior Full Stack Engineer, Databases - Analytics (staff-level backend, skunkworks context layer) |
| Location | Germany (Remote) — also listed UK/Ireland/Spain/Sweden |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/grafanalabs/jobs/6200027004 |
| Compensation | **EUR 100,000 – 125,000** (published, Germany base) |
| Fit | 5 |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 839 | `0e11517ae042e8da8be06912a8f42023b64f9b0078ac97a533d3e57274db8fc8` |
| `anschreiben.pdf` | **1** | 439 | `c95b0c616cc0f30a6b50815a4c891b36af3e018598e317f6fd34b4789df95058` |

Both compiled with typst 0.15.1 at **0 warnings**; `task checks:prose` — 271 files, exit 0.

## What the role is

Skunkworks initiative building an **AI-native data intelligence / context-layer system**: core backend services for context
ingestion, indexing, retrieval orchestration, retrieval APIs, source configuration and admin; multi-tenant SaaS foundations
(tenant isolation, usage tracking, quotas, audit logs, background jobs); agent-facing retrieval APIs for AI agents, MCP
tools, CLIs and internal apps carrying provenance, confidence signals and warnings. Staff-level backend, high autonomy,
dogfood-to-production path. Principle: "the context system retrieves, agents decide, data teams maintain the intelligence."

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Context layer for agents | Compiled inventory + epistemics table (which source settles which claim); agents query, never recite | **exceptional** |
| Retrieval APIs | Postgres archive: hot tables, full-text index, API surface | **strong** |
| Provenance / confidence signals | Epistemics table is literally per-claim authority + filing | **exceptional** |
| Multi-agent workflows | xs Go service: claims, ordered turns, idempotent writes; multi-agent fleet daily | **strong** |
| MCP-style tool surfaces | Agent tool surfaces for mail/calendar/system state in daily use | **strong** |
| Tenant isolation / quotas / audit | microVM caps, issued access (fleet CA), 15-min audit ledger | **strong** |
| LLM / GenAI practical | GPU serving stack + agent pipelines (incl. the one filling this form) | **strong** |
| Remote async writing | xs turn log, decisions next to change, prose budgets | **strong** |
| Production cloud (AWS/GCP/Azure) | none — rented metal + Nix | **gap** |
| TypeScript primary | tooling/dashboards level only | partial |
| Company-scale multi-team | single-operator estate evidence | partial |

Fit **5**: the role's core — governed context retrieval with provenance for agents — is the system Matt already built and
runs; the gaps (production cloud, TS depth, team scale) are conceded in the letter. Strongest req in the campaign to date.

## Form notes for Pane 2

- Grafana board: **resume-only** (no cover-letter slot — scout-verified on two sibling reqs).
- Standard Greenhouse remix fields: name/preferred/email/country(dial)/phone/**candidate-location** (geo-autocomplete —
  pick "Gutach im Breisgau, Baden-Württemberg, Germany").
- Question family on sibling req: LinkedIn, current company, work-eligibility Yes, visa-sponsorship No, free-text
  "anything else", **anti-bot honeypot "AI or human"**, how-heard. Answer per operator's ruling on the honeypot
  (answered "human being" as applicant on the security-assurance req; flagged for review).
- Greenhouse **OTP gate** on submit: 8-digit code to matt@bountystash.com via himalaya, enter into `security-input-0..7`,
  resubmit, verify `/confirmation`.
- Salary if asked: the role **publishes EUR 100–125k**; answer inside band (e.g., "110,000 EUR gross/year, within the
  published range").
