# MongoDB — Senior Site Reliability Engineer, Agent Engine (Dublin)

**Status: prepared, NOT submitted.** **[applied per apps DB `mongodb-sre-agent-engine` — this sheet's status predates submission]** 2026-11-22. No account created, nothing sent.

MongoDB Atlas Agent Engine: SRE for the multi-tenant Kubernetes clusters that run
customer agents. Position: Senior Site Reliability Engineer, Agent Engine
(Greenhouse `8366599`). The scraped description ends with a second number,
`Req ID: 4273615094` — that is MongoDB's internal requisition, not the Greenhouse
job id; the apply URL uses `gh_jid=8366599` and the boards API resolves that id to
this title, so `8366599` is the one to trust.

## Role

| Field | Value |
| :--- | :--- |
| Company | MongoDB |
| Role | Senior Site Reliability Engineer, Agent Engine |
| Greenhouse ID | `8366599` |
| Internal req | `4273615094` (from the description footer) |
| Apply URL | https://www.mongodb.com/careers/job/?gh_jid=8366599 |
| Location | Dublin — hybrid, in-person expected |
| Language | `en` |
| Board | `mongodb` (Greenhouse) |
| Posted / updated | 2026-11-17 (boards API `updated_at`) |

## Location and hybrid — what the posting settles

The description is explicit: *"We are looking to speak to candidates who are based
in Dublin for our hybrid working model."* That is a location requirement, not a
preference, and it is why relocation is the first thing the letter concedes rather
than the last. The candidate is in Gutach im Breisgau, Germany (CET).

Two consequences, stated in the letter and repeated at the first call:

- German permanent residence (*Niederlassungserlaubnis*) does **not** transfer to
  Ireland. As a US citizen he needs an Irish employment permit, i.e.
  employer-supported relocation.
- The Greenhouse form asks the same question directly and makes it required:
  *"Will you now or in the future require employment sponsorship?"* — the honest
  answer is **Yes**, and answering it that way is consistent with the letter
  instead of contradicting it.

## Files in `submissions/mongodb-sre-agent-engine/`

- `packet/lebenslauf.pdf` — 2 pages, projected from the JD: 10/32 highlights, 4/10 projects
- `packet/anschreiben.pdf` — 1 page, English letter (`letter.json`)
- `packet/selection.json` — the projection audit (kept and dropped, with scores)
- `letter.json` — letter source, so the PDF is reproducible from this tree
- `job-description.txt` — scraped from the Greenhouse job page
- `submission-sheet.md` — this sheet

Built with `task agents:apps:packet ID=mongodb-sre-agent-engine LETTER=… JD=…`,
which compiles in the Nix sandbox and runs `cv-ats-check.sh` against the finished
PDFs; the build passed 2 / 1 pages with no budget violation.

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
| Work authorization | Unrestricted in Germany. Ireland: employment permit required; German PR does not transfer |
| Languages | German C1; English native |

## Alignment & Honest Gaps

- **Strengths (built, inspectable):** one flake declaring 13 NixOS hosts with
  per-host module chains, an SSH certificate authority and SOPS/age secrets; a task
  control plane as the operator interface; gate-verified builds where a change is
  only real once the built artifact has been read back; a sentinel that logs job
  status, generation age, disk and PSI every 15 minutes and pages when the state is
  not ok; Go, Python and Bash services; Linux administration across cloud VMs, ARM
  microVMs and on-prem hardware; debugging at the below-the-abstraction layer —
  systemd units, journald, nftables, TLS handshakes.
- **Honest gaps, all three named in the letter:**
  1. **No multi-tenant Kubernetes fleet.** The hosts are single-tenant and
     separated by role; isolation is a CA, per-host keys and a module boundary, not
     namespaces, quotas and network policy. Scheduler and cluster-API debugging is
     a step up, not a familiar surface.
  2. **Kubernetes is barely in the corpus.** On the built CV the word appears
     exactly **once** — as a skills keyword. There is no production cluster story
     to point at, and the sheet says so rather than letting the keyword imply one.
  3. **Istio/Cilium unproven.** Production networking is a WireGuard mesh
     (Tailscale), nftables and an internal CA. No service mesh anywhere.
  4. **Relocation.** Dublin hybrid from Germany, Irish permit required, sponsorship
     question answered **Yes**.

## What this CV does and does not say

The description's twelve ranked terms lead with **cloud**, **kubernetes**,
**networking**, **aws**, **azure**, **google**. The projection kept 10 of 32
highlights (Bountystash 2/10, O3 Energy 4/8, Smart Energy 360 1/4, Fraunhofer ISE
2/4, Halliburton 1/6) and 4 of 10 projects: *Master's Thesis*, *nixconfig*,
*kev-time*, *Vulnerability operations concept*. Dropped by score, notably:
**bountystash** (3.22 — the highest-scoring project that still lost a slot), the
Risk Calculation Engine, and fibtransponder.

Measured on the finished PDF, the CV carries **Kubernetes** once, **Go** four
times, **AWS** and **Azure** once each — and **Linux, TCP, DNS, TLS, Prometheus,
Grafana, Istio, Cilium, Helm, service mesh, multi-tenant, on-call and SLO zero
times**. That is the honest picture: the CV opens the door on language and cloud,
and the letter has to carry isolation, networking and the on-call posture. The
`bountystash` drop costs the best Go-service evidence in the corpus, so the letter
carries the Go services instead.

## Exact Form Mapping (Greenhouse 8366599)

Questions read from `boards-api.greenhouse.io/v1/boards/mongodb/jobs/8366599?questions=true`.

| Greenhouse Field | Answer | Question ID / Value |
| :--- | :--- | :--- |
| First Name * | Matt | `first_name` |
| Last Name * | Ji | `last_name` |
| Email * | matt@bountystash.com | `email` |
| Phone * | +49 1733281570 | `phone` |
| Resume/CV * | `packet/lebenslauf.pdf` | `resume` (file); `resume_text` optional |
| Cover Letter | `packet/anschreiben.pdf` | `cover_letter` (file); `cover_letter_text` optional |
| Preferred Name * | Matt | `question_70598221` |
| Website | https://www.bountystash.com | `question_70598222` |
| LinkedIn Profile | https://linkedin.com/in/mattji | `question_70598223` |
| Culture & careers content | (optional; either is fine) | `question_70598224` |
| How did you learn about this job? | job-board option, specify "MongoDB careers (Greenhouse)" | `question_70598225` + `…26` |
| Alerts for similar jobs | (optional) | `question_70598227` |
| **Require employment sponsorship?** * | **Yes** — Irish permit, German PR does not transfer | `question_70598228` |
| Worked at MongoDB before? * | No | `question_70598229` |

The sponsorship answer is the one field that must not be softened: the letter
promises to plan the permit openly, and a "No" here would contradict it in the
same submission. The "how did you learn" option list was not fetched, so pick the
board option and fill the free-text with the source rather than guessing a label.
