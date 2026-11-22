# Nebius — Senior Site Reliability Engineer (DevTools)

**Status: SUBMITTED 2026-11-21** (DB `nebius-senior-site-reliability-engineer-devtools`, stage `applied`). This pass did not apply
again. It rebuilt the packet as native Typst sources, because the directory held only Nix-generated PDFs and a `selection.json`.

| Field | Value |
| :--- | :--- |
| Role ID | `nebius-senior-site-reliability-engineer-devtools` |
| Employer | Nebius (Nasdaq: NBIS; Amsterdam HQ, 1,500+ people, R&D across Europe, UK, US, Israel) |
| Role | Senior Site Reliability Engineer (DevTools) — SRE team inside DevTools |
| Locations offered | Amsterdam, Germany, Israel, London, Remote Europe, UK |
| Language | **en** |
| Posting | https://careers.nebius.com/?gh_jid=4889227101 (Greenhouse **4889227101**) |
| Form | https://boards.greenhouse.io/embed/job_app?for=nebius&token=4889227101 |
| Published / updated | 2026-06-08 / 2026-11-18 |
| Compensation | none published; the submitted letter stated **EUR 130,000 – 160,000** for Germany / Remote Europe |
| Fit | 3 |

## Submitted, and rebuilt

| Artefact | Submitted 2026-11-21 | Native rebuild |
| :--- | :--- | :--- |
| CV | 2 pages, 638 words, `32a33e26c565fdeadd19b55173e2ad7223ba30f7f4749759e60b1e66312bb49d` | 2 pages, 1000 words, `86c05b9991b162e9bd555a6641223622a217e718ed9effd4cf7b68d03f44e02e` |
| Letter | 1 page, 444 words, `2cb17db49525dc5683cefb45c4838c7db80879f9d1da370da2ac1be755188683` | 1 page, 438 words, `fbbe0d90dd94cb2d0f1c85892c800d81be2bb80f2253ea36854093a02304cb51` |

The submitted bytes stay recoverable from git history, so nothing was duplicated. Both native documents compile at **0 warnings**
with typst, contain no `**`, and every job entry is wrapped in an unbreakable block so no heading can be orphaned at a page foot.

**Three divergences, recorded rather than hidden.**

1. The Nix CV carried a skills block claiming Kubernetes, AWS, Azure and Google Cloud, and listed Kotlin. Nothing in the repository
   supports production experience in any of them, and the submitted letter itself says "Java/Kotlin depth no" — so the rebuild
   lists Go, Python, C++, Bash, SQL/PostgreSQL, Nix, systemd, git, sops and microVMs, with Java at reading level only.
2. The submitted letter named a salary ask. The rebuild states no figure, consistent with the rest of this series: the band lives
   here and in the recruiter conversation, not in correspondence.
3. The submitted letter said "available immediately"; the rebuild says 1 December 2026, which is the availability on record.

## What the role is

An SRE team inside DevTools, running **25k TeamCity builds a day**, **100 TB of artifacts in Artifactory**, and a monorepo in
GitLab at a scale the posting itself compares to FAANG. The team patches GitLab and writes its own TeamCity plugins, is
experimenting with a RAG setup and agent operation, and frames the goal as understanding user problems, defining metrics that
capture them, improving those metrics, and verifying the problem is gone. Responsibilities: improve services from feedback, build
fault-tolerant self-healing architecture, remove friction, modify closed- and open-source solutions, support users. Expected: a
50/50 SRE/SWE mix in Java/Kotlin, Go, Python and Ruby; Unix and JVM internals; a passion for user experience. Bonus: platform
engineering, operating GitLab or TeamCity, Spring and Java monoliths. Coding interviews are part of the process.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| SRE and SWE split | Fleet reliability work plus Go and Python services with tests | **strong** (nearer 60/40) |
| Build systems at depth | Hermetic hash-pinned builds, shared binary cache, remote builders, one-command rollback | **strong** |
| CI as enforcement | Same per-host module gate in CI and on the machine before switch | **strong** |
| Fault-tolerant, self-healing architecture | Canary guest before production, rollback as a pointer, paging on silence | **strong** |
| Unix internals | systemd, cgroups, PSI, initrd, `strace`, `tcpdump`, nftables | **strong** |
| Developer tooling as a product | Task surface with dry runs and JSON, generated docs, runbooks in the repo | **strong** |
| Go / Python / Ruby | Go and Python in production; no Ruby | meets for two of three |
| Java / Kotlin / JVM internals | Java at reading level; no Java monoliths or Spring operated | **gap** |
| TeamCity / Artifactory / GitLab operations | **none** | **gap (role centre)** |
| Patching GitLab internals, writing TeamCity plugins | **none**; own tooling is bespoke, not a fork | **gap** |
| Platform engineering | Declared fleet, per-host gates, self-service task plane | **strong** |
| Agent / RAG operation | Agent stacks used daily with approval gates; RAG setup itself not operated | partial |
| Kubernetes / Terraform | **none**; NixOS and systemd | gap |

Fit **3**: the build-system, CI-gate, reliability and tooling-as-product layers are the actual work of the last five years, and the
Unix depth is real. It is not higher because the toolchain at the centre — TeamCity, Artifactory, GitLab internals — has not been
operated, and the JVM half of the expected language mix is language-level only.

## The letter's argument

It opens by separating load from purpose: 25k builds a day is not the interesting part, the interesting part is that the tools are
a product and the metric is whether a developer's problem is gone. Then the fleet in their language — one flake, hermetic
hash-pinned builds from cache and remote builders, rollback in a single command.

The second paragraph is CI as a gate rather than a notification, microVM isolation behind a bridge with udev taps and NAT, and
access as short-lived certificates with per-host keys.

The third covers operations as telemetry plus a human, services in Go and Python with PostgreSQL, and daily work with agent
stacks — tiered tool access, approval gates, outputs checked — pointed at the RAG-and-agents experiment.

The fourth is the gap paragraph, specific and unhedged: no TeamCity, Artifactory or GitLab at scale, no GitLab internals, no
TeamCity plugins, JVM at language level, NixOS rather than Kubernetes, the flake rather than Terraform, 60/40 rather than 50/50.

## Greenhouse form — as answered

14 live fields from the embedded form.

| Field | Answer |
| :--- | :--- |
| First Name | Matt |
| Last Name | Ji |
| Email | matt@bountystash.com |
| Country | Germany |
| Phone | +49 1733281570 |
| Location (City) | Gutach im Breisgau |
| Attach | CV (the submitted 2-page version; originally attached PDF is in git history) |
| Enter manually | only if the resume parser mangles dates |
| LinkedIn Profile | https://linkedin.com/in/mattji |
| Languages spoken | English (native), German (C1) |
| Authorized to work without sponsorship | Yes for Germany — US citizen with unbefristete Niederlassungserlaubnis |
| Reside in the location specified for the role | Yes — Germany, which the posting lists |
| Previously employed by Nebius | No |
| Candidates Privacy Policy | read and accepted |

The form offers no cover-letter upload and no free-text field.

## Standing state

1. Do not resubmit: the application is with Nebius.
2. If a screen opens, send the native CV and letter so both sides hold the same documents.
3. Expect a coding interview in the Go/Python range with Unix-system questions; have the build-system and CI-gate evidence ready
   to explain concretely.
4. Salary: the submitted letter stated EUR 130,000 – 160,000; if asked again, anchor to the German market, not Amsterdam or London.
