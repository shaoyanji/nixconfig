# Black Forest Labs — Member of Technical Staff, Infrastructure Security

English packet, native Typst sources. Legacy read-only `lebenslauf.pdf`, `anschreiben.pdf` and `selection.json` removed and
rebuilt from `lebenslauf.typ` / `anschreiben.typ`.
Status: compiled and checked, **nothing submitted by this packet**.

| Field | Value |
| :--- | :--- |
| Role ID | `black-forest-labs` |
| Employer | Black Forest Labs (FLUX; latent diffusion and Stable Diffusion lineage; labs in Freiburg and San Francisco) |
| Role | Member of Technical Staff, Infrastructure Security |
| Location | Board says **remote**, with **Freiburg** among locations; the JD body still refers to San Francisco |
| Language | **en** |
| Apply URL | https://jobs.ashbyhq.com/black-forest-labs/a7e73f45-97d8-48c9-b97e-311711845321/application |
| Compensation | stated **USD 220,000 – 280,000 base + equity**; no figure in the letter |
| Fit | 4 (DB entry 5) |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 926 | `74741113b7092215d911ab037f48fea58692e4d37d66bf8d4dfb884339a94bf4` |
| `anschreiben.pdf` | **1** | 543 | `9afba0bca168fa2fb9fb7ddeb6694c4aa70a9da1003d36b2cacbdb365183c52b` |

Both compiled with typst, **0 warnings**, at 9.2 pt. Word counts measured with `pdftotext | wc -w` on the rendered PDFs,
not on the sources.

## The location conflict, unresolved on purpose

Two statements in the same posting disagree: the Ashby board lists the role as **Remote** with **Freiburg** (plus Berlin,
Munich, Frankfurt, London, Amsterdam, Zurich, Paris), while the JD body says *"This role is based in San Francisco, and
you'll join us in the office at least 2 days a week, or one full week every other week."*

The letter does not paper over it — it states twenty minutes from the Freiburg lab, then asks which office owns the
requisition. For this candidate the difference is the whole application: Freiburg is a commute, San Francisco is a
relocation across an ocean with a family. Resolve before any form is submitted.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Identity and access, least privilege | Fleet CA issuing short-lived SSH credentials; access expires rather than accumulates | **strong** |
| Secrets management | sops and age per host, keys per machine, nothing standing on disk | **strong** |
| Workload isolation | microVM canary: capped CPU and memory, read-only host mount, no egress | **strong** |
| Linux and operating systems | systemd, cgroups, PSI, namespaces, `strace`, `tcpdump`, journald | **strong** |
| Security in engineering workflows | Pinned inputs, content-addressed builds, one gate for CI and host, dry-run plans | **strong** |
| Practical guardrails engineers adopt | One task surface with validation and dry-run plans; generated documentation | **strong** |
| Detection and response | Fifteen-minute ledger, paging on bad state and on silence, postmortem history | **strong** |
| LLMs and agents in security work | Agents with tiered tool access, claims, approval gates; prompt-injection reasoning | **strong** |
| Cloud and compute security at scale | **none**; rented bare metal, no managed cloud security | **gap** |
| Kubernetes, orchestration, containers | **none** (microVMs instead) | **gap** |
| GPU clusters, ML infrastructure | One GPU, single tenant | **gap** |
| Multi-tenant serving, model artifact protection | **none** | **gap** |
| Software supply-chain security tooling | Pinning and content addressing, **no SBOM or signing programme** | partial |

Fit **4**: the access, secrets, isolation, workflow-security and agent-security work is a direct match, and it is the part
of the role that is engineering rather than audit. It is not a 5 because every scale term in the posting — cloud, clusters,
GPU estates, multi-tenant serving — is absent. The DB keeps the instructed **5**.

## What the letter argues

It opens on the question that decides security in a research lab: not whether a boundary exists, but whether a researcher
with a deadline routes around it. The answer offered is the design principle — the safe path is also the short one — and
then identity as a mechanism: a certificate authority minting short-lived credentials, secrets per host, default deny,
nothing standing.

Isolation gets its own paragraph, described in the terms the posting uses: what a persistent filesystem must guarantee,
what a suspended instance remembers, where the escape hatch is. Then the honest sentence about scale: the same questions
arrive with GPU clusters and model artifacts attached, and the first months would be reading their systems.

Supply chain and detection follow, with the line that shows the security mindset rather than the tool list: detection
assumes silence is failure, because the machine that went quiet is the one that matters.

The agents paragraph is the one most likely to be read twice, since the posting asks for a clear-eyed view: a model with
shell access is a new class of principal, it can be prompt-injected by data it reads, and the only reliable defence found
is that the gate decides whether output counts, not the model's confidence.

## Ashby form

Seven fields, one section, no custom questions: name, email, resume (`lebenslauf.pdf`), phone, cover letter
(`anschreiben.pdf`), LinkedIn, and website/GitHub (https://github.com/shaoyanji). No salary, authorization or location
field exists, so those values belong in the recruiter conversation instead.

An earlier attempt at this same posting hit an **interactive reCAPTCHA image grid on submit** and was left filled but
unsent (DB row `black-forest-labs-mts-infrastructure-security`, `other/manual`). Submit by hand in a normal browser;
do not retry headless.

## Checks

| Check | Result |
| :--- | :--- |
| Legacy read-only PDFs and `selection.json` | removed, rebuilt from source |
| `chmod u+w *.pdf` | applied before removal and compile |
| `typst compile lebenslauf.typ` | exit 0, **0 warnings** |
| `typst compile anschreiben.typ` | exit 0, **0 warnings** |
| `pdfinfo` pages | **2 / 1** |
| Markers CV | `short-lived`, `sops`, `microVM`, `systemd`, `Kubernetes`/`GPU` (gaps), `Freiburg` |
| Markers letter | `Freiburg`, `short-lived`, `microVM`, `Kubernetes`, `San Francisco`, `agents` |
| Stray asterisks / salary figure / foreign-company leak | 0 / 0 / 0 |
| `task checks:prose` | 260 prose files, exit 0 |
| sha256 + word counts | recorded above, measured from the PDFs |

## Next steps

1. Ask which office owns the requisition before filling the form; Freiburg versus San Francisco changes everything.
2. Submit by hand in a browser — the earlier attempt died on a reCAPTCHA image grid on submit.
3. In the first call, lead with isolation and short-lived access, and let the cloud/GPU scale gap stand as written.
