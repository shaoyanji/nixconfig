# Adyen — GenAI Platform Engineer (Amsterdam / Madrid)

English packet, **office-first**. Native Typst sources; the old `packet/` directory (Nix-built PDFs plus
`selection.json`) and `letter.json` are removed.
Status: compiled and checked, **nothing submitted**. **[applied per apps DB `adyen-platform-genai` — this sheet's status predates submission]**

| Field | Value |
| :--- | :--- |
| Role ID | `adyen-platform-genai` |
| Employer | Adyen (payments and financial platform) |
| Role | GenAI Platform Engineer |
| Location | Amsterdam **or** Madrid — office-first, posting states it does not offer remote-only |
| Language | **en** |
| Apply URL | https://careers.adyen.com/vacancies/7607736 |
| Compensation | not published in the posting; no figure in the letter |
| Fit | **2** (DB entry 5) |

## One discrepancy to settle before applying

The assignment supplies `careers.adyen.com/vacancies/7607736`, and the job text in this directory is headed
"GenAI Platform Engineer - Madrid OR Amsterdam". The earlier sheet in this folder recorded a **different** requisition —
Greenhouse `8163866`, titled **Senior** Platform Engineer - GenAI. Three identifiers, one role family.

The sheet keeps the URL the operator supplied and the job text's own title. Before submitting, confirm which requisition is
live: the senior variant and this one may be the same team posting at two levels, in which case applying twice reads as
scattergun, and applying to the junior one while the senior is open understates the case.

## What the role asks

Build and scale the capabilities that let teams across Adyen develop, deploy and operate LLM applications, agents and
**MCP** integrations: model access, tool integration, orchestration, evaluation, observability, runtime infrastructure.
Kubernetes as the runtime, Helm and Argo CD with GitOps, Prometheus/Grafana/Kibana, Python for services and APIs, DevEx
and SDLC paving, LLM architectures (tool calling, RAG, agent workflows, model gateways, evaluation), reliability, latency,
cost and security of GenAI systems. Desirable: MCP experience, LiteLLM-style gateways, Langfuse tracing and evaluation,
vLLM serving. 4+ years platform/DevOps/MLOps/backend.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Platform capabilities reused across teams | Module registry, one entry surface, docs as build artefact | **strong** |
| Developer experience and SDLC paving | Named arguments, dry-run plans, fast failure, colleague ships unaided | **strong** |
| Python services and APIs | Production services and tooling, tests over canonical data | **strong** |
| Linux, cloud and on-prem | systemd, cgroups, PSI, nftables, `strace`, mixed bare metal | **strong** |
| Observability | Fifteen-minute ledger, paging on silence, postmortem history | **strong** |
| Access control, privacy, governance | sops/age per host, SSH-CA short-lived credentials, default-deny | **strong** |
| LLM agents and evaluation in practice | Agents dispatched to worktrees under written gates, human merge | moderate, **own work, not others'** |
| Kubernetes, Helm, Argo CD, GitOps | **none** | **gap, core to the role** |
| Prometheus / Grafana / Kibana | **none**; own ledger and journald | **gap** |
| LiteLLM, Langfuse, vLLM | **none** | **gap (desirable)** |
| Production GenAI platform for other teams | **none** | **gap, core to the role** |
| MCP integrations | tool use only, no MCP server operated | weak |

Fit **2**: the platform craft — DevEx, Python, Linux, observability, guardrails, reusable capabilities — is genuinely
strong and defensible with public evidence; the Kubernetes and GitOps layer and the production GenAI platform itself are
the two things the role is built from, and both are absent. The DB keeps the instructed **5**.

## The relocation question, stated plainly

The posting is explicit: office-first, no remote-only. So the application offers Amsterdam with intent to relocate, and
says so in the letter rather than letting a recruiter discover it.

German permanent residence does **not** transfer to the Netherlands or Spain. As a US citizen the candidate needs a Dutch
permit, i.e. **employer-supported relocation under the highly skilled migrant (kennismigrant) route**: Adyen must be a
recognised sponsor, and the salary must clear the threshold that route sets for the applicable age band. Confirm both with
the recruiter early — the threshold is the binding constraint, not willingness to move.

## The argument the letter makes

It opens on the platform test: **a platform succeeds when the second team does not have to solve the first team's problem
again**. Then two halves of the posting the candidate can actually own — developer experience on top of the platform, and
guardrails as a mechanism (validation, dry runs, encrypted secrets, short-lived credentials) rather than a policy document.

The AI paragraph is deliberately precise instead of enthusiastic: agents run daily against a real repository under written
gates, which teaches the practical failure modes — confident wrong summaries, patches that compile and do not work, cost
drift — and makes evaluation a build artefact. It then names what is missing: no shared GenAI platform for other teams, no
Kubernetes/Helm/Argo, no vLLM, no LiteLLM or Langfuse.

## Checks

| Check | Result |
| :--- | :--- |
| `packet/` directory, `selection.json`, `letter.json` | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** (`**…**` corrected to `*…*`; Typst drops the former silently) |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `Kubernetes`, `Python`, `guardrails`, `observability`, `MCP`/`LiteLLM`/`vLLM` (gaps) |
| Markers letter | `Adyen`, `Amsterdam`, `Kubernetes`, `highly skilled`, `developer` |
| Stray asterisks / salary / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 254 prose files, exit 0 |
| sha256 CV | `850584ce24585fcda4e8c12ce97c7bbcf07bf40f09bb3cc68573b5221247ab27` |
| sha256 letter | `aadacf8e8e362948093c1e796f9fa6bcceb6c6838ece44f01c37f5006c284d69` |
| DB read-back | verified after upsert |

## Next steps

1. Confirm which requisition is live — `7607736`, or Greenhouse `8163866` under the senior title.
2. Ask the recruiter about the kennismigrant salary threshold before investing in a four-week process.
3. Prepare for the platform-design conversation: the honest position is "guardrails and DevEx yes, Kubernetes runtime no",
   with NixOS and microVMs as the comparable isolation work.
