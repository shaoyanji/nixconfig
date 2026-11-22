# n8n — Senior Infrastructure / DevOps Engineer (requested) → Staff Platform Engineer, Agentic Engineering (live)

English packet. Native Typst sources; `Matt_Ji_Resume_n8n.pdf`, `n8n_Anschreiben.pdf`, `selection.json`,
`n8n_Cover_Note.txt` and `n8n_Submission_Sheet.txt` are removed.
Status: compiled and checked, **nothing submitted**.

## Title: the requested role does not exist on n8n's board

This packet was requested as **Senior Infrastructure / DevOps Engineer** with the generic careers URL
`https://n8n.io/careers/`. n8n's live Ashby board (queried 2026-11-22, 68 listed postings) contains **no title
containing "Infrastructure"**, and no DevOps or SRE req at all. The engineering reqs are: Sr Security Engineer,
Senior Product Engineer (TS/NodeJS/Vue), Engineering Manager | Remote | Europe, Senior Product Manager - Core Platform
(Engine, Scale & Reliability), Forward Deployed Engineer (EMEA and US East), Internal Context Engineer, Internal AI
Enablement Lead, and **Staff Platform Engineer, Agentic Engineering**.

The packet is therefore written against **Staff Platform Engineer, Agentic Engineering** —
https://jobs.ashbyhq.com/n8n/24ad7d68-fac9-476c-b9fa-3410d73a6d7d — the only live req that owns platform
infrastructure. The letter keeps this assignment's infrastructure framing (self-hosted deployment as a contract,
bounded and isolated job execution, CI gates, telemetry) and connects it to that req's own isolated-execution and
safety questions, so it is readable by the actual reviewer.

| Field | Value |
| :--- | :--- |
| Role ID | `n8n` |
| Employer | n8n |
| Requested title | Senior Infrastructure / DevOps Engineer — **not on the board** |
| Target req | Staff Platform Engineer, Agentic Engineering |
| Location | Hybrid, Berlin + 30 European countries |
| Language | **en** |
| Apply URL | https://jobs.ashbyhq.com/n8n/24ad7d68-fac9-476c-b9fa-3410d73a6d7d |
| Compensation | published bands: Western/Northern Europe €159.4K–175.3K + equity; Southern €143.5K–157.8K; CEE €127.5K–140.2K; UK £157.7K–173.5K; Ireland €183.3K–201.6K. Staged ask €165,000, **not quoted in the letter** |
| Fit | 3 |

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Linux infrastructure automation | Thirteen hosts as one declaration, modules, pinned inputs | **strong** |
| Self-hosted / cloud deployment architecture | Rebuild instead of edit, generations, rollback by pointer, canary | **strong** |
| Bounded, isolated job execution | Declared microVM per job, memory-capped slices, teardown owned by the declaration | **strong, small scale** |
| CI/CD as the safety model | Gate identical in CI and host, inventory-driven matrix, one process per host | **strong** |
| Telemetry and reliability | Fifteen-minute ledger, alert on state, silence as fault | **strong** |
| Docker | **none**; hosts are NixOS | **gap** |
| Kubernetes | **none** | gap |
| TypeScript / Node codebase | **none**; Go, Python, Bash, C++ | **gap** |
| Workflow automation domain (n8n itself) | **no n8n usage yet** | **gap, and the form asks directly** |
| Scale | thirteen machines vs n8n Cloud's fleet | gap |
| Work authorisation | German permanent residence, no sponsorship | fulfilled |

Fit **3**; the DB row keeps the requested title and the instructed fit of 4, with the mapping recorded in its notes.

## The argument the letter makes

It opens on the thing that makes n8n's infrastructure peculiar: the product runs on other people's machines, and
community operators discover your release notes with their workflows in production, so **the deployment path is part of
the product**. That is the operator's side of self-hosted software, which is the side this corpus knows.

Then the two columns the req cares about. Deployment: one declaration, pinned inputs, rebuild rather than edit, rollback
as a pointer, a gate that cannot disagree between CI and the machine. Execution: runs with a window, a memory cap and a
named owner, teardown owned by the creating declaration, and a microVM boundary for work that must not touch anything
else — with the reason stated plainly, since **a run that leaks state is a capacity bill four weeks later**, not a bug you
notice at the time.

Gaps named: no Docker or Kubernetes in production, no TypeScript, thirteen machines rather than n8n Cloud's fleet.

## Form constraints — read before submitting

From the 2026-11-21 live read of the Ashby form:

- **One application per 15 days**, and **no re-apply to the same role for 90 days** unless an offer is presented. This
  packet is prepared, not sent; there is no second attempt for three months.
- The form asks **"What knowledge/experience do you have with n8n?"** with a radio scale and an optional screenshot
  field. The posting asks applicants to try the product. Registering and building one workflow before answering is the
  difference between "none" and a real answer.
- Ignore the "Autofill from resume" upload: it parses the PDF and overwrites typed values.
- Work contract box: **"I can be based in Germany and do not need visa support"** is the correct one.
- Unsent facts for the first recruiter reply: availability 01.12.2026, no notice period, ask €165,000 base, Berlin hybrid.

## Checks

| Check | Result |
| :--- | :--- |
| Legacy PDFs, `selection.json`, both `.txt` files | removed |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `microVM`, `PSI`, `rollback`, `jobs` |
| Markers letter | `Docker` (gap), `TypeScript` (gap), `generation`, `fifteen days` |
| `task checks:prose` | 250 prose files, exit 0 |
| sha256 CV | `f27072e2ba1899e63b685b6a5d63220ca1b92302db5f34a84d4449af3bb30a19` |
| sha256 letter | `553fd4a605b187d8be643262865d985e7e5e4ef0f3f861f846be71282bf7445e` |
| DB read-back | verified after upsert |

## Next steps

1. Decide whether to submit to Staff Platform Engineer — it is the only live platform req — or wait for an
   infrastructure-specific posting to open.
2. Build one n8n workflow before applying, so the form's experience question has a true answer with a screenshot.
3. Ask what an agent-run job is allowed to touch: that is the design question under the role, and the best opening
   question to have ready.
