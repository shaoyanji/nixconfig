# Anduril Industries — Senior Embedded NixOS Engineer

Costa Mesa (on-site), Electromagnetic Warfare team. English packet. Native Typst sources; no `job-description.txt` was
kept — the role detail below is reconstructed from the apps-DB notes and the letter itself.
Status: applied through Greenhouse, **rejected by email 2026-11-22**. Closed.

| Field | Value |
| :--- | :--- |
| Role ID | `anduril-senior-embedded-nixos-engineer` |
| Employer | Anduril Industries |
| Role | Senior Embedded NixOS Engineer |
| Location | Costa Mesa, CA — on-site; US person + clearance path required |
| Language | **en** |
| Apply URL | https://job-boards.greenhouse.io/andurilindustries/jobs/5043617007 |
| Compensation | $191K–$253K (the non-senior twin posts $129K–$171K) |
| Fit | 2 (per apps DB) |

## What the role is

From the DB notes: NixOS is required **in practice** — the EW team's software supply chain, NixOS bring-up on custom
hardware, and image-building infrastructure. AArch64 embedded Linux, kernel modules, a typed functional language
(Haskell/Scala/F#/OCaml/Rust), plus FPGA and MATLAB exposure. US-person status and a clearance path were hard
requirements.

## The argument the letter makes

It opens by owning the mismatch honestly: most NixOS experience is server-room shaped; theirs must survive a board, a
radio front end and a field. Then it makes three claims with evidence — (1) one flake describes thirteen hosts as
feature lists with every input pinned, so a rebuild months later reproduces the same derivation, which is the root
property a software supply chain needs; (2) cross-compiled images for aarch64/x86_64 in one pipeline, device trees,
initrd and serial consoles as the debug surface — real but narrower than custom-board bring-up, and it says so; (3)
the supply-chain side it matches closely: binary caches, cache misses as explainable events, inventory-driven CI
gating one host per process, and a sentinel logging job status, generation age, disk and PSI every fifteen minutes.
It names its own gap rather than hiding it: no FPGA, no custom driver/kernel-module work, no bring-up on hardware
that did not exist before the schematic.

## Checks

| Check | Result |
| :--- | :--- |
| `typst compile lebenslauf.typ` | exit 0, no warnings |
| `typst compile anschreiben.typ` | exit 0, no warnings |
| `pdfinfo lebenslauf.pdf` | **2 pages** |
| `pdfinfo anschreiben.pdf` | **1 page** |
| anomaly | `anschreiben.typ` line 1 comment still reads `// Flox — Member of Technical Staff` (adapted from the flox packet; invisible in the PDF, stale in the source) |
| DB row | `anduril-senior-embedded-nixos-engineer` → rejected (email 2026-11-22) |
| `job-description.txt` | absent — DB `notes` field is the role source |

## Outcome

Rejected by email 2026-11-22. The posting's US-person + clearance-path requirement was structural; the letter
disclosed residency and citizenship upfront. No re-application action — the folder is a closed record.
