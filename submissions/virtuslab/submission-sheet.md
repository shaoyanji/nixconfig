# VirtusLab — Linux Hacker & Nix Wizard (Senior / Expert)

Remote Poland (Kraków, Warszawa, Wrocław), B2B. English packet. Native Typst sources; the directory previously held Nix-built PDFs
plus two `.txt` artefacts, all replaced.
Status: compiled and checked, **nothing submitted**.

| Field | Value |
| :--- | :--- |
| Role ID | `virtuslab-linux-hacker-nix-wizard-senior-expert` |
| Employer | Virtus Lab Sp. z o.o., Tooling Space |
| Role | Linux Hacker & Nix Wizard (Senior / Expert) |
| Project | ESM — enterprise ecosystem, GraphDB hardening and observability, cross-language data pipelines |
| Location | Remote Poland; hiring timezone UTC+1 |
| Language | **en** |
| Careers page | https://careers.virtuslab.com/job-offer/linux-hacker-nix-wizard-senior-expert |
| Application form | https://join.vl.team/o/linux-hacker-nix-wizard-senior-expert (Traffit; offer 2067646, guid 4c9dc) |
| Rate | published **140 – 185 PLN net per hour**, B2B. Staged **175 PLN/h**; no figure in the letter |
| Fit | 3 |

## Measured output

| Artefact | Pages | Words | sha256 |
| :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | **2** | 1031 | `95cad389869d01a7d3c198e58ea2b7febbc2b57e59f8631b9058c045b4147c8b` |
| `anschreiben.pdf` | **1** | 0 | `524a521973767fb7e706a5e8a33c60568e7399df527f9ad4891e1cefff6e412e` |

Both compiled with typst at **0 warnings**; no `**` in either source. Every job entry is an unbreakable block, so no heading can be
orphaned at a page foot — the class of defect that hit three earlier packets.

## Provenance note

A sibling pane logged a `done` turn for this subject at 10:34 today naming commit `5466aebd`. That commit does not exist in this
repository, `git ls-files` shows no `virtuslab` path, and the directory was untracked with only the old Nix PDFs and `.txt` files
present. The artefacts were therefore never landed here, and this packet was built from scratch against the live posting, which was
fetched on 2026-11-22 and matches the earlier notes (B2B, 140–185 PLN/h, remote Poland).

## What the role is

A consulting engagement on the ESM project, coordinated from VirtusLab's Tooling Space: supporting an enterprise ecosystem that
thousands of developers depend on, mapping and tracing graph data connections across it, hardening **GraphDB** to enterprise
security standards, and keeping monitoring and alerting honest. Stack: Linux/Unix, **Python**, **Java**, **Apache Kafka**,
GraphDB/Neo4j/GraphQL, **Kubernetes**. Required: deep Linux internals (memory management, IPC, system calls), expert Python
(performance, async, C/Rust interop), hands-on **Nix/NixOS** or equivalent declarative systems, advanced low-level diagnostics
(**eBPF, perf, strace, valgrind**), fluent English, and ownership. The posting's own skill chart rates Python and Linux core as
Expert/Advanced and Nix as Regular — the candidate's shape is the inverse, and the letter addresses that asymmetry directly.

## Fit map

| Requirement | Evidence | Verdict |
| :--- | :--- | :--- |
| Nix / NixOS, declarative systems | One flake declares thirteen hosts as feature lists, pinned inputs and submodules, per-host gates, rollback as a pointer | **strongest** — the "Nix Wizard" half is real and unusual |
| Reproducible builds | Hermetic builds, shared binary cache, remote builders, lock-file-pinned toolchains | **strong** |
| Linux internals, system calls | systemd, cgroups, PSI, initrd, module parameters, sysfs-level diagnosis | strong at the configuration and boundary layer |
| Low-level diagnostics: strace | Used routinely to see what a process asked the kernel for | **strong** |
| perf / valgrind | **none** | **gap** |
| eBPF | **none**; no bpf() programmes of my own | **gap (named in the letter)** |
| Expert Python | Pipelines, tooling, tests, APIs, services | strong for engineering; not performance-tuning or C/Rust interop |
| C / Rust interop | C++ instrument software at Fraunhofer; small C changes; no Rust | partial |
| GraphDB / Neo4j / GraphQL | **none** | **gap (project centre)** |
| Java / Kafka pipelines | **none** at enterprise scale | **gap** |
| Kubernetes | **none**; NixOS and systemd | gap |
| Monitoring, alerting, tracing | Fifteen-minute ledger, paging on bad state and on silence, runbooks | **strong** |
| English, ownership | Native English; founded and ran a company | **strong** |

Fit **3**: the Nix and Linux-system half of this role is the candidate's deepest work, and the reliability and observability habits
are exactly what the GraphDB hardening asks for. It is not higher because the project's day-to-day is GraphDB, Kafka and Java, none
of which is present, and because the posting wants eBPF, perf and valgrind rather than the systemd and PSI route the candidate
actually uses.

## The letter's argument

It opens with the fleet in the posting's own terms — one flake, feature-list hosts, SOPS per host, SSH through a certificate
authority, the same module gate in CI and on the hosts, pinned inputs and submodules so a rebuild is a function of the repository.

The second paragraph is flake architecture as craft: option surface is what a gate pays for, modules keyed, imports downward, facts
answered by evaluation rather than by building a machine.

The third moves under the declaration to the systemd and kernel boundary, names the signals that separate a broken configuration
from a sick host, and puts `strace` and `tcpdump` where they belong.

The fourth is the honest paragraph: no eBPF, perf or valgrind programmes of my own; no GraphDB, Neo4j, Kafka or large Java codebase.
It then offers the transferable method — map the system, instrument the failing boundary, make the fix reproducible, leave a
runbook — and closes on the two logistics questions that matter: whether a Germany-based B2B contractor fits a remote-Poland
engagement, and the rate.

## Traffit form — staged answers

One upload field (CV), no cover-letter slot, no email field for a separate letter.

| Field | Value |
| :--- | :--- |
| Full name * | Matt Ji |
| Email address * | matt@bountystash.com |
| Phone number * | +49 1733281570 (the widget defaults to +48; switch to +49) |
| CV or resume * | `lebenslauf.pdf` |
| Q1 (120 chars): interest in specific stack/domain/project | `Nix/NixOS platform work, Linux internals, Go/Python tooling, and GraphDB observability and hardening.` |
| Q2 (120 chars): anything to add | `Germany-based (UTC+1); US citizen with German PR, no visa. B2B at 175 PLN/h; available 01.12.2026.` |
| Consent, current process * | accepted (GDPR art. 6.1.a) |
| Consent, future processes | accepted, 36-month retention |
| Location question | not rendered on the live form (`isLocationsQuestionOn=false`); nothing staged |

The letter is staged as `anschreiben.pdf` for the recruiter thread, since the form accepts no letter upload.

## Before applying

1. Decide the B2B question: a Germany-based contractor on a remote-Poland engagement is unconfirmed by the posting, and the letter
   asks it rather than assumes it.
2. Confirm 175 PLN/h sits where you want it inside the published 140–185 band; the letter names no figure on purpose.
3. Expect the interview to probe kernel diagnostics; the honest position is systemd/journald/PSI plus `strace`, not eBPF.
4. Attach `lebenslauf.pdf`; the form offers one file slot only.
