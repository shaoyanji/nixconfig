# Grafana Labs — Senior Full Stack Engineer, Database Observability

Germany, fully remote. Greenhouse req **6250631004**. English packet. Native Typst sources; the directory held only
`job-description.txt` until this packet.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `grafana-db-observability` |
| Employer | Grafana Labs (Grafana Cloud Observability, Database Observability squad) |
| Role | Senior Full Stack Engineer — Database Observability, Grafana Cloud |
| Location | Germany (remote); posting also open to UK, Ireland, Spain |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/grafanalabs/jobs/6250631004 |
| Greenhouse API | https://boards-api.greenhouse.io/v1/boards/grafanalabs/jobs/6250631004?questions=true |
| Posting updated | 2026-11-06 (API `updated_at`) |
| Compensation | published for Germany: **€100,000 – €125,000** base plus RSUs. Sheet only; no figure in the letter |
| Form | 16 questions, **no cover-letter field** — résumé-only upload |
| Fit | **2** (DB now 2; the scout row had 4, corrected — see below) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 999 | `37cc3bdac4a145e388c3864e040b8787ae5764045b68b9f5a0186ad72d3c4723` |
| `anschreiben.pdf` | **1** | 506 | `0872e958cd1c65e7362e91c4000e5198e79f1e6c18663f446421de8495d16389` |

Both compiled with typst at **0 warnings**; no `**` in either source. The Halliburton entry is wrapped in an unbreakable block:
an earlier pass left that heading at the foot of page 1 with its bullet on page 2. The letter has no slot in the form, so it is
staged for the recruiter thread rather than the upload.

## The fit correction, first

The scout row carried fit 4. That number was wrong for this posting and the DB now says 2. The role is **frontend-primary**:
production React and TypeScript web applications are the first requirement, with Go backends as the "across the stack"
opportunity. This candidate's shipped interface work is plain JavaScript over WebSocket and JSON frames, with Go and Python
services behind it. Claiming React or TypeScript fluency would survive the CV screen and die in the technical interview, and every
other packet in this series has refused that trade.

## What the role is

Build and evolve Grafana Cloud Database Observability: help users understand the health and performance of their databases,
find slow queries and troubleshoot through clear, actionable insights. Frontend-heavy — TypeScript and React against Go
backends — with ownership from problem framing to rollout, measuring whether what shipped worked. Mentor, review, participate in
on-call for the squad's software, support customer escalations, and contribute to design proposals and occasionally open source.
AI coding assistants are part of the expected workflow, with validation and review. Bonus: OSS contribution, observability
interest (Prometheus, Loki, Tempo), database/SQL performance monitoring, Go backend experience, prior on-call use of Grafana.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Production web applications | tokenloom's browser workbench over a binary WebSocket protocol; generated dashboards and site pages | real, but **JavaScript, not React** |
| React and TypeScript | **none in production** | **gap (first requirement)** |
| Backend services and APIs | Go event-log service with HTTP endpoints, turn-log and archive APIs with pagination and idempotent writes | **strong** |
| Operate what you build, on-call | Fleet on-call: paging, diagnosis at the failing layer, incidents ending as gates or runbooks | **strong** |
| Observability instinct | Fifteen-minute ledger of job state, generation age, disk and PSI; paging on bad state and on silence | **strong** |
| SQL and databases | Postgres operations, migrations, query plans measured against realistic row counts | meets — operating, not product-level performance analysis |
| Database performance monitoring as a product | **none**; no slow-query product work, no customer-facing telemetry tool | **gap** |
| Prometheus / Loki / Tempo / Grafana | **none**; a self-built ledger and gatus instead | **gap (bonus)** |
| Technical ownership and mentoring | Founded and ran a company; set fleet standards and gates; wrote the docs | **strong** |
| AI-assisted development with review | Agent tooling, MCP tool mounts and JSON task surfaces built and used daily | **strong** |
| Remote, asynchronous communication | Written documentation and runbooks as the default artefact | **strong** |
| Germany remote, no sponsorship | German permanent residence | **strong** |

Fit **2**, and honestly argued: the backend, on-call, telemetry-instinct and ownership layers are real, the frontend is real but
in the wrong framework, and the role's centre of gravity is React/TypeScript product engineering plus database-domain telemetry.
The letter says all of that in its fourth paragraph rather than in a footnote.

## The argument the letter makes

It opens on the claim that observability is a reading problem — the data is usually there and what is missing is the sentence
that turns it into a decision — then shows the same instinct applied to hosts: what changed, not just is it up.

The second paragraph connects that to the squad's product and to the habit of ending incidents in gates and runbooks.

The third is the interface and server evidence: tokenloom's real-time workbench at roughly two milliseconds end to end, and Go
APIs over Postgres with pagination and idempotent writes.

The fourth is the honest paragraph, placed where a recruiter will read it: no production React or TypeScript, no Prometheus,
Loki, Tempo or Grafana in anger, no database-performance product. It states the trade plainly — "if the squad needs someone
productive on the frontend in week one, I am not that person" — and names what instead is on offer.

It closes with a product question about ranking causes, which is where the squad's real judgement lives.

## Greenhouse form — staged answers

16 questions, ids read from the boards API on 2026-11-22. There is **no cover-letter field**, and four contact fields are
duplicated (LinkedIn and Website appear twice each).

| Field | Id | Required | Staged answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Preferred First Name | `preferred_name` | no | leave empty |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | yes | +49 1733281570 |
| Resume/CV | `resume` | yes | `lebenslauf.pdf` |
| LinkedIn Profile (1) | `question_20606671004` | no | https://linkedin.com/in/mattji |
| Website (1) | `question_20606672004` | no | https://www.bountystash.com |
| LinkedIn Profile (2) | `question_20606673004` | no | https://linkedin.com/in/mattji |
| Website (2) | `question_20606674004` | no | https://www.bountystash.com |
| Based in Ireland, UK, Spain or Germany? | `question_20613640004` | yes | Yes — Germany |
| Eligible to work in country of residence | `question_20606675004` | yes | Yes — German permanent residence |
| Require visa sponsorship | `question_20606676004` | yes | No |
| How did you hear about this opportunity | `question_20606677004` | yes | LinkedIn — confirm with Matt, this is an inference |
| Which best describes you | `question_20606678004` | yes | I am a human being |
| How did you hear (duplicate) | `question_20606679004` | no | LinkedIn, same inference |

## Before applying

1. Decide whether to submit at all: this is the one packet in the series where the honest fit is a real argument against applying
   rather than a caveat. If the answer is yes, the letter already frames it as a backend-and-telemetry engineer joining a
   frontend-led squad.
2. Do not paste a React claim into the CV to pass the screen; the interview is a code screen and a component discussion.
3. The published German band is €100,000 – €125,000 plus RSUs; no figure belongs in the letter.
4. Attach `lebenslauf.pdf`; there is no letter field, so send `anschreiben.pdf` in the recruiter thread if one opens.
