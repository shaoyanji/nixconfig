# Adyen — Senior Platform Engineer, GenAI (Amsterdam / Madrid)

**Status: prepared, NOT submitted.** 2026-11-22. No account created, nothing sent.

Adyen, office-first in Amsterdam or Madrid. Position: Senior Platform Engineer - GenAI
(Greenhouse `8163866`). The job description's own headline calls the team "GenAI Platform
Engineer"; the Greenhouse title is the senior variant and is the one used on the letter.

## Role

| Field | Value |
| :--- | :--- |
| Company | Adyen |
| Role | Senior Platform Engineer - GenAI |
| Greenhouse ID | `8163866` |
| Apply URL | https://job-boards.greenhouse.io/adyen/jobs/8163866 |
| Location | Amsterdam or Madrid — office-first, **no remote-only** |
| Language | `en` |
| Board | `adyen` (Greenhouse) |
| Posted / updated | 2026-11-20 |

## Location and hybrid — confirmed from the posting

The description ends with the only statement that settles it:

> "This role is based out of either our Madrid or our Amsterdam offices. We are an
> office-first company and value in-person collaboration; we do not offer remote-only
> roles."

So: a choice of two offices, in-person expected, and remote from Germany is not on
offer. The application must therefore carry a relocation commitment, and it does. Two
consequences are stated plainly rather than left for the recruiter to discover:

- The candidate is in Gutach im Breisgau, Germany (CET), ~7 h by train from Amsterdam.
- German permanent residence (*Niederlassungserlaubnis*) does **not** transfer to the
  Netherlands or Spain. As a US citizen he would need a Dutch or Spanish permit, i.e.
  employer-supported relocation, not a permit-free move.

## Files in `submissions/adyen-platform-genai/`

- `packet/lebenslauf.pdf` — 2 pages, projected from the JD: 10/32 highlights, 4/10 projects
- `packet/anschreiben.pdf` — 1 page, English letter (`letter.json`)
- `packet/selection.json` — the projection audit (which lines were kept, which dropped)
- `letter.json` — letter source, so the PDF is reproducible from this tree
- `job-description.txt` — scraped from the Greenhouse job page
- `submission-sheet.md` — this sheet

## Candidate Facts — Grounded Truth

| Fact | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Baden-Württemberg, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Website | https://www.bountystash.com |
| Citizenship | United States |
| Residence | German permanent residence (*unbefristete Niederlassungserlaubnis*) |
| Work authorization | Unrestricted in Germany. Netherlands/Spain: permit required, German PR does not transfer |
| Languages | German C1; English native |

## Alignment & Honest Gaps

- **Strengths (all built, all inspectable):** one flake declaring 13 NixOS hosts with
  per-host module chains, an SSH certificate authority and SOPS/age secrets; a task
  control plane that is the operator interface; gate-verified builds where a change is
  only real once the artifact has been read back; a closed-loop sentinel that logs job
  status, generation age, disk and PSI every 15 minutes and pages on failure; MCP
  servers declared through `mcp-servers-nix` and merged idempotently into editor
  settings; self-hosted model endpoints (chat, TTS, STT, image) behind a router on one
  GPU host; multi-agent coding workflows bounded by shellcheck, deadnix, hermetic
  builds and document read-backs; Python, Go and Bash services; Linux administration
  across cloud VMs, ARM microVMs and on-prem hardware.
- **Honest gaps:** daily GitOps is a flake plus task gates, not Helm and Argo CD, so
  the delivery stack itself is new; no owned production MLOps platform for other teams
  (no LiteLLM gateway, Langfuse tracing or vLLM serving at organisational scale); no
  commercial multi-tenant Kubernetes operation; relocation to Amsterdam or Madrid is
  required, with a Dutch or Spanish permit to arrange.

## What this CV does and does not say

The keyword projection kept 10 of 32 highlights, and at Bountystash only 1 of 10 — the
LLM knowledge-base line was scored out. Measured against the description's vocabulary,
the PDF carries **Kubernetes** once, **Python** twice and **LLM** once; **Helm**,
**Argo CD**, **GitOps**, **Prometheus**, **Grafana**, **MCP**, **vLLM**, **LiteLLM**,
**Langfuse** and **RAG** do not appear at all. The letter carries that argument instead
(MCP, model endpoints, evaluation that fails the build), and the sheet says so here so
nobody assumes the CV alone makes the case.

## Exact Form Mapping (Greenhouse 8163866)

Questions read from `boards-api.greenhouse.io/v1/boards/adyen/jobs/8163866?questions=true`.

| Greenhouse Field | Answer | Question ID / Value |
| :--- | :--- | :--- |
| First Name * | Matt | `first_name` |
| Last Name * | Ji | `last_name` |
| Email * | matt@bountystash.com | `email` |
| Phone * | +49 1733281570 | `phone` |
| Resume/CV * | `packet/lebenslauf.pdf` | `resume` (file); `resume_text` optional |
| Cover Letter | `packet/anschreiben.pdf` | `cover_letter` (file); `cover_letter_text` optional |
| Point of Data Transfer * | Acknowledge/Confirm | `question_68874046[]` -> `Acknowledge/Confirm` |
| Accessibility adjustments | (leave blank) | `question_68874047` |

No custom questions about authorization, salary or notice period are on this form; the
relocation and permit facts live in the letter, and should be repeated in the first
recruiter call.
