# Canonical — Rust Engineering Lead, Linux and Open Source

Greenhouse **5833620** · https://job-boards.greenhouse.io/canonical/jobs/5833620 · home based, any timezone · no published band.
A standing pipeline posting for Rust engineers at all levels (first published 2024-04-04, updated 2026-08-05): candidates are matched to a
product team after the first round.

**Applied 2026-11-21** per the apps DB (code 92730157, CV plus three Rust essays) — **rejected, email 2026-11-22** (`canonical-rust-engineering-lead-linux-and-open-source`, "not progressing"). This sheet reflects the native rebuild.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1177 | 0 | `48cafc7d3a41de0f` |
| `anschreiben.pdf` | 1 | 477 | 0 | `f38c2bb5729853cc` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, this sheet. `selection.json` retired in this rebuild.

## What changed

The submitted CV was 642 words over two pages, built from the application database, and its skills block still claimed React, Next.js,
Laravel, MySQL, Django, Kubernetes, AWS, Azure and Google Cloud — on a Rust requisition, where none of it helps and some of it actively
hurts. More importantly, it contained **no Rust project at all**: the strongest evidence in the corpus, the `tokenloom` workspace, was absent,
so the CV's Rust case rested on a sentence in the letter.

The native CV leads with the work, described from the crates themselves: the chunked piece table and ripple re-tokeniser, the invariant
"incremental state equals full rebuild after any edit" held by `tests/acceptance.rs`, six reactors over the diff, a minimal wire diff, the
five-millisecond socket gate with fuzz and replay, and the Hilbert image bridge (bytes as pixels, exact bounding boxes for byte ranges,
typed span algebra from three test-held properties, no per-point allocation, no dependencies, parity-tested against the earlier JavaScript
implementation). The second Rust service — tokio and axum fan-out, written as a deliberate comparison with its Go prototype — is included
because dependency surface is engineering judgement, not trivia.

Submitted bytes: `lebenslauf.pdf` `4f695444d481dea1…` (2 pages, 642 words), `anschreiben.pdf` `214de1b0b0bde67c…` (1 page, 382 words).

## Where the gaps sit

No upstream Rust contribution, no commercial Rust codebase led, no Ubuntu or Debian package maintained, no LXD, Juju, SnapD, Ubuntu Core or
MicroK8s, no kernel or bootloader work. LXD, Juju, SnapD, Ubuntu Core and MicroK8s appear in the CV zero times; the CV and letter name the
absence in prose instead of parking the words in a skills list where a screener would read them as experience.

## Fit

**3 of 5.** Genuine Rust systems work with tests, a benchmark gate and a real invariant; genuine Linux systems depth and packaging
discipline; genuine declarative deployment. Short on seniority for a *lead* requisition: no team led in Rust, no upstream standing, and the
15-year-equivalent expectation of the more senior bands is not met at ten years of systems work.

## Compensation and route

EUR 120,000–150,000 staged for a home-based contract; Canonical publishes no band and shapes pay by location, experience and performance.
The form carries three Rust essays (notable project, why Rust, where Rust does and does not fit) plus the own-words attestation, which is
marked **Hold** — the essays were drafted with AI assistance and must be made the applicant's own before submission of any follow-up.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Unsupported platform claims | 0 (LXD/Juju/SnapD/Ubuntu Core/MicroK8s absent) |
| `task checks:prose` | exit 0 |
| Commit | native rebuild, `selection.json` removed in the same commit |
