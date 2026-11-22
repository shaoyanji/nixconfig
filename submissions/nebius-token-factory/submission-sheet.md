# Nebius — Senior Site Reliability Engineer, Token Factory (Inference Platform)

**Status: packet staged, not submitted.** **[applied per apps DB `nebius-senior-site-reliability-engineer-token-factory-inference-platform` — this sheet's status predates submission]** Prepared 2026-11-21. Nothing sent.

## Role

| Field | Value |
| :--- | :--- |
| Company | Nebius (Token Factory, part of Nebius Cloud) |
| Role | Senior Site Reliability Engineer — Token Factory (Inference Platform) |
| Role ID | `nebius-senior-site-reliability-engineer-token-factory-inference-platform` |
| Apply URL | https://careers.nebius.com/?gh_jid=4600919101 |
| Greenhouse job id | 4600919101 (posting updated 2026-11-18) |
| Locations | Amsterdam; **Berlin, Germany**; London; Prague; **Remote – Europe** |
| Employment | Full-time |
| Compensation | Not published. Target **EUR 130,000 – 160,000**, staged for the recruiter call. |
| Category / language | `tech`, `en` |
| JD | `job-description.txt` (HTML stripped for the selector; raw source in `~/.config/appflow/jd/`) |

## Candidate facts

| Field | Value |
| :--- | :--- |
| Name | Matt Ji |
| Address | Am Burgerhof 4, 79261 Gutach im Breisgau, Germany |
| Email | matt@bountystash.com |
| Phone | +49 1733281570 |
| LinkedIn | https://linkedin.com/in/mattji |
| GitHub | https://github.com/shaoyanji |
| Website | https://www.bountystash.com |
| Citizenship | United States |
| Residence | Germany — unbefristete Niederlassungserlaubnis (permanent) |
| Work authorization | US and Germany/EU; no visa sponsorship required |
| German | C1 (verhandlungssicher) |
| English | Native |
| Availability | 01.12.2026 |

## Files

- `lebenslauf.pdf` — **2 pages** A4, PDF/UA-1 tagged, page budget enforced by `lib/typeset.nix`
- `anschreiben.pdf` — **1 page** A4
- `selection.json` — engineering evidence; projects `nixconfig`, `email-archive`, `bountystash`, `fibtransponder`
- `job-description.txt` — cleaned JD used by the selector
- `submission-sheet.md` — this file

Build: `scripts/task/appflow-packet.sh` → `modules/plugins/appflow/packet.nix`; typst in the Nix sandbox, `cv-ats-check.sh` read the finished PDFs back against `work/resume.json` in the same derivation. Budgets reported 2 / 1, zero page-budget errors.

## Live Greenhouse form — fields and staged answers

Fields and ids read from the boards API on 2026-11-21. Note that **Resume and Cover Letter are both optional** on this posting, and there is no salary or essay field.

| Field | Id | Required | Answer |
| :--- | :--- | :--- | :--- |
| First Name | `first_name` | yes | Matt |
| Last Name | `last_name` | yes | Ji |
| Preferred First Name | `preferred_name` | no | leave blank |
| Email | `email` | yes | matt@bountystash.com |
| Phone | `phone` | yes | +49 1733281570 |
| Resume/CV | `resume` | no | `lebenslauf.pdf` (attach anyway) |
| Cover Letter | `cover_letter` | no | `anschreiben.pdf` |
| LinkedIn Profile | `question_7091343101` | no | https://linkedin.com/in/mattji |
| Website | `question_7091344101` | no | https://www.bountystash.com |
| Authorized to work without sponsorship, now or in future? | `question_7093961101` | yes | **Yes** — US citizen with permanent German residence; no sponsorship |
| Do you currently reside in the location specified? | `question_7093970101` | yes | **Yes** — Germany (Gutach im Breisgau). Berlin and Remote – Europe are both listed; not Berlin itself |
| Which languages do you speak? | `question_7094346101[]` | yes | English (native), German (C1) — select both |
| Employed by Nebius before? | `question_8262247101` | yes | **No** |
| Candidates Privacy Policy | `question_9817502101` | yes | Read, then acknowledge |

## Staged answers for the recruiter call

**Compensation.** EUR 130,000 – 160,000. Nebius publishes no band.

**Work authorization.** US citizen with permanent German residence (unbefristete Niederlassungserlaubnis); full right to work in Germany/EU and the US, no sponsorship now or later.

**Location.** Gutach im Breisgau, Germany. Berlin and Remote – Europe are both listed on the posting, so either is worth confirming before agreeing to an office cadence.

## Fit map

The honest shape: strong on Linux, isolation, declarative infrastructure and operating discipline; no GPU-cloud or inference-serving experience.

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Linux, kernel-to-application debugging | Kernel track pinning, systemd units, networking, Go services, PostgreSQL | Meets |
| Isolation (cgroups, systemd sandboxing) | Per-service systemd units with sandboxing; microvm canary | **Strong** |
| Declarative infrastructure / IaC | One flake declares 13 hosts; gate shared by CI and host | **Strong**, Nix rather than Terraform |
| Telemetry, alerting, SLOs | Sentinel ledger (job status, generation age, disk, PSI) paging on silence | Adjacent — fleet SLIs, not Prometheus/Grafana at scale |
| Kubernetes / autoscaling | Consumer-level only | **Gap**, stated in the letter |
| GPU clusters, vLLM / Triton / Ray | None | **Gap**, stated in the letter |
| Prometheus, Grafana, Terraform | Not used in production | **Gap**, stated in the letter |
| eBPF telemetry | None | **Gap**, stated in the letter |
| Python / Bash / Go scripting | Go service, Python and Bash tooling | **Strong** |
| Incident response, post-mortems, canary gates | Solo incidents, rollback by generation, canary before rollout, written follow-ups | Meets at small scale |
| High-throughput network fabrics | WireGuard mesh, PXE, no fabric/DPDK work | Partial |
| Location / authorization | Germany, permanent residence, no sponsorship | **Strong** |

## Before submitting

- [ ] Confirm the EUR 130–160k target.
- [ ] Answer "reside in the location specified" with the Germany/Remote-Europe reading in mind, not Berlin only.
- [ ] Select both languages on the multi-select.
- [ ] Attach the CV and the optional cover letter; verify the parser reads name, email and phone.
- [ ] Submit only on explicit instruction.

No application was submitted.
