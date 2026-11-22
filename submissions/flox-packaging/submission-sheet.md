# Flox — Member of Technical Staff, Nix Packaging

Remote · full time · reports to the VP of Engineering · **USD 180,000–250,000** published.
**Applied 2026-11-21** per the apps DB (Ashby, tailored CV, `flox-senior-software-engineer-packaging`).

**Two things about provenance, before anything else.**

1. This folder held **no job description**. `job-description.txt` is now reconstructed from the retired
   `Flox_Packaging_Submission_Sheet.txt`, which recorded the live Ashby form and the posting's own wording — it is faithful to what shipped,
   but it is not a fresh fetch.
2. The retired packet was filed under the sibling title **Senior Software Engineer, Packaging** (Ashby `7d38cdf7-cc13-43e1-b276-972e954fc3aa`).
   This dossier is addressed to the title in the instruction, **Member of Technical Staff, Nix Packaging**; same Secure Packages team, same
   technical content. If the live requisition uses the other title, the letter's subject line is the one line to change.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1137 | 0 | `1307aec7eb397f66` |
| `anschreiben.pdf` | 1 | 437 | 0 | `0934eee8054db28e` |

Plus `lebenslauf.typ`, `anschreiben.typ`, `job-description.txt` and this sheet. Retired in this rebuild:
`Matt_Ji_Resume_Flox_Packaging.pdf` (`6d5b0a34…`), `Flox_Packaging_Anschreiben.pdf` (`1e0d6f7c…`), the plain-text duplicates
`Flox_Packaging_Cover_Note.txt` and `Flox_Packaging_Submission_Sheet.txt`, and `selection.json`.

## What changed

The legacy CV was a 15-of-36-highlight projection: three fleet bullets, four projects, and nothing about flakes, overlays, the module system
or the failure modes of a package bump — on a requisition whose whole subject is packaging. The native CV leads with the parts that are
specific to Nix work: an evaluation gate that covers the whole host rather than the package, hermetic sandboxed builds with the network
closed, remote builders and a shared cache, overlays instead of forks, the module system as a contract with options, types and assertions,
repeated shapes collected into `lib/` functions, and one module set that evaluates for NixOS and nix-darwin from the same tree.

The letter does the same job in prose and keeps the line that matters: *a change that looks right passes a syntax check; a change that is
right survives an evaluation of the whole host and a sentinel that notices when the service stops reporting.* That is Flox's own
"packaging judgment" made operational rather than asserted.

## Gaps, in both documents

No nixpkgs upstream commits and no package maintained in the official set. No RPM, deb or apk packaging. No npm, Cargo or PyPI registry work
beyond consuming them. No ownership of a large C/C++ build system. The build farm is one fleet with remote builders and a cache, not a
multi-tenant package service. **nixpkgs** appears in the CV only inside the sentence declining it; the scan confirms no other mention.

## Fit

**3 of 5.** Deep, inspectable Nix work: flakes and pins, overlays, module-system patterns, hermetic builds, build-farm operations, and
cross-platform evaluation across Linux and Darwin. Thin exactly where the posting is thin on most candidates: no upstream package-set
history and no OS-packaging breadth.

## Compensation and route

USD 210,000 staged (inside the published band, above its midpoint). The Ashby form has seven controls and no free-text field, so the letter
carries the argument; the salary is answered when a human asks, not volunteered. Availability 01.12.2026, remote in CET from Germany.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Unsupported packaging claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native rebuild; all five legacy artefacts removed in the same commit |
