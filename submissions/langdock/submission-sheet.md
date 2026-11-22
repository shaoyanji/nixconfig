# Langdock — Senior Systems Software Engineer (Linux & HPC)

Berlin, remote-friendly per the posting. Ashby `a9b93572-71a1-469f-8d91-f1eaf218658c`. English packet. Native Typst
sources at the top level; the legacy `systems-hpc/` folder (Nix PDFs plus `selection.json`) and `README.md` are removed,
and the posting text is now `job-description.txt` here.
Status: compiled and checked, **staged — see the conflict below before submitting**.

| Field | Value |
| :--- | :--- |
| Role ID | `langdock` |
| Employer | Langdock (enterprise AI platform, past USD 40M ARR, small team) |
| Role | Senior Systems Software Engineer (Linux & HPC) |
| Location | Berlin, remote-friendly per the posting |
| Language | **en** |
| Apply URL | https://jobs.ashbyhq.com/langdock/a9b93572-71a1-469f-8d91-f1eaf218658c |
| Compensation | not published in the posting; no figure in the letter |
| Fit | 3 (DB entry 4) |

## The conflict to settle first

The DB has `langdock-senior-platform-engineer` at **status `applied`, 2026-11-22** — the tailored CV plus staged essays
were submitted for the (Senior) Platform Engineer role. The DB note on the systems row records Langdock's stated policy:
**one role per candidate at a time**, with the advice to mention HPC in the recruiter screen rather than filing a second
application.

So this packet is built and ready, and it should not be sent while the platform application is live. The options, in order
of preference:

1. Wait for the platform screen and raise the systems role there — their own advice, and it costs nothing.
2. If the platform application is rejected or withdrawn, send this one.
3. Only if the platform posting is confirmed closed should this go in without a conversation.

## What the role is

Systems software behind agent execution, model serving and shared services. The agenda: secure execution of untrusted code
in Linux, containers and microVMs (startup, persistent filesystems, network restrictions, suspend/resume); inference and HPC
throughput, latency, accelerator utilisation and cost; Linux performance and resource scheduling so one tenant cannot
degrade another; distributed execution with explicit ordering, idempotency and tenant isolation across retries and crashes;
storage and data systems with consistency and predictable performance; usage metering that stays accurate through
concurrent reporting and duplicate events.

Stack: Go and TypeScript in one Bazel monorepo, Protobuf and gRPC, Kubernetes across GCP/AWS/Azure/on-prem, Terraform and
Terragrunt, PostgreSQL and Redis, open-source model serving. Three to six years of production systems judged on depth, not
credentials; eBPF, RDMA, confidential computing and accelerator infrastructure called out as particularly relevant.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Secure execution of untrusted code | microVM canary: capped CPU and memory, read-only host mount, no egress | **strong** |
| Linux depth | cgroups, PSI, scheduling, `strace`, `tcpdump`, nftables, kernel-boundary diagnosis | **strong** |
| Inference serving | Single-GPU stack for chat, STT and TTS with throughput and queue depth measured | moderate, **single tenant** |
| Distributed execution and failure | Rendering and mail jobs with retries, idempotency, recovery paths | moderate |
| Usage metering under concurrency | Idempotency where a retry could double-count; no billing system | partial |
| Go | Long-lived services, streaming protocol with benchmarks | **strong** |
| Measure before optimising | Capacity, cache and builder arguments with numbers attached | **strong** |
| Operate what you build | Five years of own pager, rollback as a pointer | **strong** |
| HPC at scale (Slurm, MPI, RDMA) | **none** | **gap** |
| Multi-tenant accelerator scheduling | **none**; one card, one tenant | **gap** |
| Bazel monorepo, TypeScript, gRPC | **none**; Nix, Go, Python | gap |
| Kubernetes across four clouds, Terraform | **none**; declarative fleet on bare metal | gap |

Fit **3**: the isolation and Linux work is the closest match in the whole batch — a microVM sandbox with capped resources
and no egress is the same problem as agent execution, at one machine instead of a fleet. The gap is scale and HPC: no
Slurm, MPI, RDMA fabric or multi-tenant accelerator scheduler. The DB keeps the instructed **4**.

## The argument the letter makes

It opens on the posting's own closing principle — the engineer who ships a change owns it in production — which is exactly
how five years of solo operation worked. Then the microVM canary, described in the terms the posting uses for its runtime:
startup cost, what a persistent filesystem must guarantee, what a suspended instance must remember.

The inference paragraph is deliberately modest: one card, one tenant, measured throughput and queue depth, and the
interesting question being what happens when a second workload wants the card. Scale is disclaimed in the next sentence
rather than implied.

The gap paragraph lists what is absent — Slurm, MPI, RDMA, multi-tenant scheduling, multi-cloud Kubernetes, Bazel with
TypeScript — then says what replaces it: a build farm with remote builders and a shared cache, and a declarative fleet with
content-addressed rebuilds. Different questions, same discipline.

It closes with a question that shows where he would look first: where agent startup time actually goes — image preparation,
VM boot, or the first network call — and which of the three has been measured most recently.

## Ashby form

The form is the standard Ashby set: full name, email, resume upload, and free-text questions. Resume is `lebenslauf.pdf`
(2 pages), cover letter `anschreiben.pdf` (1 page). The posting's own compensation fields are empty, so no band is offered
and none is quoted.

## Checks

| Check | Result |
| :--- | :--- |
| `systems-hpc/` legacy folder, `README.md` | removed; JD moved to `job-description.txt` |
| `platform-engineer/` (already applied) | **left intact**, not deleted |
| `chmod u+w *.pdf` | applied |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| Markers CV | `microVM` 5, `PSI` 5, `strace` 3, `Slurm` 1 and `RDMA` 1 (in the sentence naming them absent) |
| Markers letter | `Langdock` 2, `microVM` 1, `Slurm` 1, `RDMA` 1, `Bazel` 1, `inference` 1 |
| Stray asterisks / salary figure / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 257 prose files, exit 0 |
| sha256 CV | `2c5560646b720d76b542d8faf528349fb11d363a5b81f1a1d4ed8ccbeee79b6a` |
| sha256 letter | `da2bdcd0d44198a93f1528ce3e6bcc94c97ed3faa5eb1a7c4b9c94df09f72289` |
| DB read-back | verified after upsert |

## Before you submit

1. Resolve the one-role policy first. This packet exists so that the moment the platform route closes, it can go in
   unchanged.
2. If the conversation moves to systems, ask about agent startup time as the letter does — it is the question that
   separates someone who has run a runtime from someone who has read about one.
3. Nothing about HPC should be implied. The letter names Slurm, MPI and RDMA as absent, so a screen that probes them is
   testing honesty rather than knowledge.
