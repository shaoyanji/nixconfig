# Scout24 — Lead Platform Engineer (d/m/f)

Berlin, hybrid (three on-site days). Greenhouse req **8129746**. English packet. Native Typst sources; the directory held only
`job-description.txt` until this packet.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `scout24-lead-platform-engineer` |
| Employer | Scout24 (ImmoScout24), ~1,100 colleagues, 58 nationalities |
| Role | Lead Platform Engineer (d/m/f) — individual contributor, technical lead |
| Team | Application Platform, 12 engineers, reporting to the Head of Application Platform |
| Location | Berlin, hybrid: three days on site per week, 30 days vacation |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/scout24/jobs/8129746 |
| Greenhouse API | https://boards-api.greenhouse.io/v1/boards/scout24/jobs/8129746?questions=true |
| Posting updated | 2026-11-06 (API `updated_at`), read 2026-11-22 |
| Salary | **staged 95,000 – 110,000 EUR gross per year**, per instruction; the posting says only "competitive plus bonus" |
| Fit | 3 |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 1076 | `f81e9f5efbd8294dfa809b4f871df428a7f22b12fdf0f91a8f9d5e34a1db2954` |
| `anschreiben.pdf` | **1** | 490 | `40f97b03771a23261ace689ae90295c94f2775a193d96ca4d778e07f66dc34ca` |

Both compiled with typst at **0 warnings**; word counts measured with `pdftotext | wc -w` on the rendered PDFs. No `**` in either
source. Page 1 ends on the O3 Energy entry and page 2 opens on Director of Sustainability, which is wrapped in an unbreakable
block: earlier passes left that heading orphaned at the foot of page 1 with its bullet on page 2.

## What the role is

Technical leadership inside a platform department, with hands on the keyboard. Set the platform's technical direction and turn
approved decisions into architecture, service interfaces and standards; lead cross-team initiatives and migrations; own
build-versus-buy and make the call. Build platform capabilities over managed services, an **AWS EKS** compute platform and a
shared software-delivery path. Turn recurring developer needs into secure, reliable APIs and self-service workflows, explicitly
including **machine-usable interfaces for AI agents**. Set standards for reliability, observability, security and performance;
strengthen incident learning and DR; share on-call. Required: production Go, TypeScript or Python across unfamiliar codebases;
services on **AWS and Kubernetes (EKS)**; IaC, CI/CD, automated testing and safe rollout (they use **AWS CDK**; Terraform or
Pulumi equally relevant); SRE with **observability, SLIs, SLOs, error budgets**, incident learning and recovery; AI tooling with
human oversight.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Production software in Go or Python | Task control plane, bountystash service, CLI tools over REST, tests | **strong** |
| APIs and self-service workflows | One validated surface with typed arguments, dry runs and JSON output; CLI over REST | **strong** |
| Machine-usable interfaces for agents | MCP tool mounts, turn-log API on 8449, archive API on 8450, JSON/TOON as the agent boundary | **strong** |
| Platform used by other engineers | Thirteen hosts, one repository, generated docs, gate shared by CI and hosts | **strong** |
| Reliability practice | Fifteen-minute ledger of job state, generation age, disk and PSI; paging on bad state and on silence | **strong** |
| Safe rollout and recovery | Canary guest before production, rollback as a pointer, rebuildable hosts | **strong** |
| Incident learning | Every escalation ends as a gate, a check or a runbook entry | strong |
| Build versus buy judgement | Tailscale over a self-run overlay, gatus over a bespoke checker, self-hosted where data could not leave | **strong** |
| Leading with no established approach | Founded and ran a company; set the fleet's standards and gates | **strong** |
| AWS | **none**; rented bare metal | **gap** |
| Kubernetes / EKS | **none**; NixOS hosts and microVMs instead | **gap (central)** |
| TypeScript | **none** in production; Go and Python carry the work | gap |
| Terraform / Pulumi / AWS CDK | **none**; declarative NixOS instead | gap |
| Formal SLI/SLO/error-budget programme | **none at company scale**; targets lived as gate thresholds and alert conditions | **gap** |
| AI tooling with human oversight | Agent tooling and MCP mounts built and used daily, with the human as the decision point | meets |
| Berlin hybrid, three on-site days | Based near Freiburg (~700 km); a relocation question, raised in the letter | **constraint** |

Fit **3**: the platform, API, agent-interface and reliability-practice layers are genuinely what the last five years were, and
the build-versus-buy and no-formal-authority leadership the posting asks for is the shape of running a company. It is not higher
because the estate is not AWS/EKS, there is no TypeScript or CDK, and no formal SLO programme has been owned. The Berlin on-site
model is a relocation question rather than a commute and is stated plainly rather than glossed.

## The argument the letter makes

It opens on the judgement the role actually lives under: a platform is judged by the teams that use it, so the paved road wins
only where it is shorter than the workaround. Then the concrete version — one command with real help text, a dry run that says
what would change, output a script can consume.

The second paragraph takes the posting's own unusual requirement, machine-usable interfaces for agents, and answers it with built
work rather than enthusiasm: typed arguments, validation before any side effect, a stable JSON contract, no operation an agent
can invoke that a person could not.

The third paragraph is reliability as practice: the fifteen-minute ledger, paging on silence, canary before production, rollback
as a pointer, incidents ending as gates or runbook entries.

The fourth states the gaps directly — no AWS or EKS, no TypeScript, CDK, Terraform or Pulumi, no formal SLI/SLO/error-budget
programme — and argues they are learnable because an error budget is a gate that says stop and an SLO is a promise written where
the system can check it. It ends with the relocation point, stated before an offer rather than after.

## Greenhouse form — staged answers

12 questions, labels and ids read from the boards API on 2026-11-22.

| Field | Id | Required | Staged answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | yes | +49 1733281570 |
| Resume/CV | `resume` | yes | `lebenslauf.pdf` |
| Cover Letter | `cover_letter` | no | `anschreiben.pdf` |
| LinkedIn Profile | `question_68588551` | no | https://linkedin.com/in/mattji |
| Website | `question_68588552` | no | https://www.bountystash.com |
| How did you hear about this job? | `question_68588553` | no | LinkedIn — confirm with Matt, this is an inference |
| Certificates | `question_68588554` | no | leave empty; no certificates are claimed anywhere in the packet |
| Disability representative involvement | `question_68588555` | no | voluntary; Matt's choice, no answer staged |
| Desired salary (gross per year, EUR) | `question_68588557` | yes | **95,000 – 110,000 EUR gross** |

The salary field is mandatory on this form, so the staged figure is the one supplied for this application. No figure appears in
the letter, where compensation belongs to a conversation.

## Before applying

1. Decide the Berlin question first: three on-site days from Freiburg is a relocation, and the letter says so plainly.
2. Expect the interview to probe EKS and SLO practice; the honest position is mechanism-level knowledge, not production AWS.
3. Have the agent-interface work ready to demo — MCP mounts plus the JSON task surface is the most differentiated thing here.
4. Attach both PDFs; submit through Greenhouse `8129746`. Nothing was submitted.
