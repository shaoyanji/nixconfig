# Canonical — Lead Linux Kernel Engineer, Ubuntu

Greenhouse **6010955** · https://job-boards.greenhouse.io/canonical/jobs/6010955 · home-based, any timezone · no published band.
Posting updated 2026-08-05, fetched 2026-11-21.

**Applied 2026-11-22** per the apps DB (kernel CV plus cover note, email code verified). The previous sheet said "staged, not submitted";
the DB row is the later record.

Native English Typst rebuild, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1130 | 0 | `5fbdd7e404b1fc36` |
| `anschreiben.pdf` | 1 | 391 | 0 | `783dba906fd4c4b3` |

`lebenslauf.typ`, `anschreiben.typ`, `job-description.txt`, this sheet. Retired in this rebuild: `Matt_Ji_Resume_Canonical_Kernel.pdf`,
`Canonical_Kernel_Cover_Note.pdf` and `selection.json` — the standard filenames now come from the sources in this directory.

## What changed

The submitted CV was 553 words over two pages and spent a paragraph on a hedging model, then closed with the standard database
skills block: Kubernetes, AWS, Azure, Google Cloud, React, Next.js, MySQL, Django, Laravel, Kotlin, Lua. For a kernel requisition that
block was not just unsupported, it was disqualifying in the other direction — nothing in it suggests a person who reads kernel
configuration for a living.

The native CV is built around what is actually true and actually relevant: the kernel as a declared input (6.12 LTS where NVIDIA drivers
demand it, latest stable elsewhere, modules and parameters per host, canary guests booted before rollouts), packaging as a discipline
(one module per service, named dependencies, builds without network access, a gate CI and the machine share), C++ instrument software
that captured and processed optical measurement data, the Go service with canonical-JSON hashing and append-only events, the PostgreSQL
archive with tsvector and GIN, KEV tooling, and fibtransponder's benchmark that falsified its own claim.

Submitted bytes: `Matt_Ji_Resume_Canonical_Kernel.pdf` `2e412fa39a1e559a…` (2 pages, 553 words),
`Canonical_Kernel_Cover_Note.pdf` `71a154de453357e9…` (1 page, 359 words).

## Fit

**3 of 5.** Genuine distribution-layer kernel work: track pinning per host, module and parameter configuration, canary rollout, hermetic
packaging, systemd and cgroups and PSI. Real gaps, all named in the CV and the letter: no mainline patch series, no Debian source
packages or debhelper/lintian, no SRU carried, no driver or BSP authorship, no silicon or cloud partner engagements, and the posting's
15-year guideline is not met at ten years of systems work. The letter says the archive policy and release cadence would be learned, not
claimed.

## Form answers (live labels, read 2026-11-21)

| Field | Id | Staged answer |
| :--- | :--- | :--- |
| Name / email / phone | `first_name`, `last_name`, `email`, `phone` | Matt / Ji / matt@bountystash.com / +49 1733281570 |
| Resume, cover letter | `resume`, `cover_letter` | both PDFs above — this posting does expose the optional letter field |
| Own-words / no-AI attestation | `question_48346139` | **Hold.** Drafted with AI assistance; must be made yours before ticking yes |
| High-school mathematics / native language | `question_48346140`, `…41` | **Cannot recall — provisional.** No rank, SAT or ACT on file |
| Bachelor's result | `question_48346143` | 3.2/4.0 GPA, Petroleum Engineering, Colorado School of Mines 2010; MSc 1.8/5.0 Freiburg 2014 |
| Kernel experience | `question_48346146` | Linux at the distribution layer: declared kernel tracks, per-host modules and parameters, canary guests. No mainline patches, no RTOS |
| HW-level programming | `question_48346145` | C++ instrument capture and optical processing at Fraunhofer ISE; no driver, BSP or firmware authorship |
| OSS links | `question_48346147` | github.com/shaoyanji/{nixconfig,bountystash,fibtransponder} — public and tested, not upstream kernel commits |
| Travel, twice a year | `question_48346148` | Yes |
| Companies in the past ten years | `question_55241689` | 2 — O3 Energy, Bountystash (EWE and Landvest contracted under it) |
| Salary | none on the form | EUR 140,000–160,000 base staged; Canonical publishes no band, so raise it at the first call |
| Self-ID | `question_55378799`, `…65030203`, `…65030213` | prefer not to say / American / prefer not to say |

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| Unsupported claims | 0 — the database skills block is gone entirely |
| `task checks:prose` | exit 0 |
| Commit | native rebuild; old-named PDFs and `selection.json` removed in the same commit |

## Before anything else is sent

The own-words attestation is the one thing a rebuild cannot satisfy: Canonical requires that the free-text answers be the applicant's
own words, and the packet was drafted with AI assistance. Read the CV and letter, rewrite the passages that are not yours, then tick it.
The two high-school questions are still unanswered.
