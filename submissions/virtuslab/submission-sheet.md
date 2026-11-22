# Application — VirtusLab, Linux Hacker & Nix Wizard (Senior / Expert)

Date: 22 November 2026
Fit: 4
Language: English
Status: packet compiled; two contractual points to confirm before sending

## Role

| Field | Value |
| :--- | :--- |
| Employer | Virtus Lab Sp. z o.o. (VirtusLab), Tooling Space |
| Role | Linux Hacker & Nix Wizard (Senior / Expert) |
| Location | Poland |
| Terms | B2B, brief states 175 PLN/h |
| Source | join.vl.team, HTTP 200 on 22.11.2026 |
| Salary in letter | none stated |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English, links the public repository |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, compile standalone |
| Certificates | none | still missing |

State on arrival: no directory and no DB row; no legacy txt or PDF files to replace.

## Requirement check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| Nix / NixOS, declarative configuration, reproducible builds | One flake over 13 hosts, module per service, feature list per host, pinned inputs, generation rollback | **Strongest evidence in the pipeline** |
| Flake architecture and module design | Option surface treated as a gate cost; host registration as a feature list | Strong |
| Linux core and system behaviour | systemd, cgroups, namespaces, PSI, disk pressure, boot and initrd | Strong as an operator |
| Low-level kernel internals (memory, IPC, syscalls) | Not held | **Gap** |
| eBPF, perf, strace, valgrind | Not held as working instruments | **Gap** |
| Python, expert level | Tooling, ledgers, automation; not performance engineering or async | **Partial** |
| C / Rust interop | C++ lab instrumentation only; no Rust | **Gap** |
| System architecture and automation | Gates, tasks, generated docs, delivery-confirmed alerting | Strong |
| English C1 | Native | Met |
| B2B contracting | Open in principle; rate and form to confirm with the candidate | **Condition** |

## Fit reasoning: 4 of 5

The brief specified 5. Four is what the advert supports.

The Nix half is the strongest evidence anywhere in this pipeline: not Nix familiarity, but five years of operating a fleet as one flake, with module boundaries, feature lists, pinned inputs, a gate on the evaluated state and rollback by generation. That is precisely the "flake architecture" work the role describes.

Not 5 because the posting lists **Linux core or low-level kernel internals as the first required skill**, and adds eBPF, perf and Python at expert level. None of that is evidenced. A 5 would claim the kernel half; the letter says plainly that it would start from a low base.

## Open items

1. **Kernel internals, eBPF, perf, C/Rust** named as gaps in the letter.
2. **B2B and 175 PLN/h** come from the brief; confirm the candidate accepts the contract form and rate before sending.
3. **Location**: the board lists Poland; the letter states a German base and remote work, which needs confirming with VirtusLab.
4. Certificates still missing.

## Package

| File | Content |
| :--- | :--- |
| `job-description.txt` | Posting text plus cross-check note. |
| `lead.md` | Fit, gaps, route, terms. |
| `lebenslauf.typ` | Typst source, two pages. |
| `anschreiben.typ` | Typst source, one page. |
| `lebenslauf.pdf` | Two pages. |
| `anschreiben.pdf` | One page. |
| `submission-sheet.md` | This overview. |
