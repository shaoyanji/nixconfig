# Flox — Member of Technical Staff, Core Systems

Remote (posting carries a US address) · full time · reports to the VP of Engineering ·
**USD 160,000–210,000 base + equity**, published 2026-11-17.

**Nothing was submitted.** The retired sheet is explicit: packet staged, manual Ashby submission never made. This row is `prep`, not
`applied`, and the DB is corrected accordingly.

## Three provenance facts

1. **No job description on file.** `job-description.txt` is reconstructed from the retired `Flox_MTS_Submission_Sheet.txt`, which recorded
   the live posting and its Ashby GraphQL schema on 2026-11-21, plus the retired cover note's reading of the requirements. Faithful to what
   was verified that day; not a fresh fetch.
2. **The requisition was posted as plain "Member of Technical Staff (Engineering)"** — Ashby `b74cb64c-2fee-4edb-a6ed-fb9aee044ee3`. This
   dossier is addressed to the title in the instruction, **Core Systems**; same team, same requirements. If the live posting keeps the
   generic title, the letter's subject line is the single line to change.
3. **The DB row was pointing at a different job.** `flox-mts-infrastructure-operations` describes requisition `87f6bc08` — production Nix
   fleet, remote builders, binary caches, Terraform/AWS, Tailscale/Cloudflare, on-call — fitted 5. That is a separate posting from this
   folder's, and conflating them would have been the easiest wrong thing to do here. This packet has its own row,
   `flox-mts-core-systems`.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1116 | 0 | `a0ea77db0e2432ae` |
| `anschreiben.pdf` | 1 | 449 | 0 | `a3e0a0c7dc6cbc9a` |

Plus both `.typ` sources, `job-description.txt` and this sheet. Retired: `Matt_Ji_Resume_Flox_MTS.pdf` (`376c8be5f7e37b5a…`),
`Flox_MTS_Cover_Note.pdf` (`7926494969bac5e3…`), and the plain-text duplicates `Flox_MTS_Cover_Note.txt` and `Flox_MTS_Submission_Sheet.txt`.

## The five things the letter argues

- **Systems programming.** tokenloom: a Rust workspace where a piece table holds the document and a ripple re-tokeniser touches only the
  changed span, with `tests/acceptance.rs` holding the invariant and a 5 ms gate keeping a keystroke honest. Before that a C++ instrument
  driver at Fraunhofer, a Go fuzzer generating adversarial geometry, and a bounded-work state machine that treats an unbounded step as a
  latency bug.
- **Developer environments.** `nix develop` gives a human, CI and an agent the same shell; toolchain skew stops being able to look like a bug.
- **Reproducibility.** Pinned inputs, sandbox with the network closed, content-addressed store, cache-served rebuild, generation as a
  pointer. Tested for, not assumed.
- **Cross-platform.** One declaration evaluated for NixOS and nix-darwin, per-system inputs in the lock file, platform pieces behind
  conditions rather than forked trees.
- **CLI tooling.** Typed arguments, dry-run before the destructive path, JSON on request, one exit code per outcome, no hidden state between
  runs — which is what lets an agent drive the same commands a human does.

The retired CV called itself "Developer Tools Engineer" and led with a summary; this one leads with the five claims and puts the evidence
underneath each. The retired cover note is largely preserved in substance, because it was honest and well-aimed; it lost the volunteered
salary figure and gained the cross-compilation gap.

## Gaps, stated in both documents

Not five years as a technical lead inside a product organisation. No team-wide AI-assisted development practice (agents operate my own fleet;
that is not the same thing). No TypeScript or Angular. AWS without Terraform-and-platform depth. **No foreign-architecture cross-compilation** —
a grep of the flake finds no `crossSystem`, `pkgsCross` or `extra-platforms`; the cross-platform claim is one declaration for Linux and
Darwin, nothing more. Rust is the newest language on the CV and is described as a workspace, not a decade.

## Fit and route

**3 of 5.** Genuine and inspectable on environments, reproducibility and CLI design; thin on the leadership tenure, the Rust years and the
AWS/Terraform stack the posting names.

**Location risk, unresolved:** the posting says Remote but carries a United States address. A US citizen living in Germany is not
automatically payable on a US-remote arrangement — payroll, tax and work-location eligibility are separate questions from citizenship. The
letter asks this directly rather than assumes it.

**Compensation:** USD 210,000 base + equity staged as the target (top of the published band). Not volunteered in the letter; answered when a
human asks. Availability 01.12.2026, US hours from Germany.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Salary in letter | 0 mentions (sheet only) |
| Cross-compilation claimed | 0 (`crossSystem`/`pkgsCross` absent from the flake) |
| `task checks:prose` | exit 0 |
| Legacy artefacts | all four removed in the same commit |
