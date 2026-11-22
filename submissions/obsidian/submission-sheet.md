# Application — Obsidian Systems, Functional Software Engineer

Reconstructed: 22 November 2026
Fit: 3
Language: English
Status: **already applied** — Ashby, 21 November 2026. This packet is the archived record.

## Role

| Field | Value |
| :--- | :--- |
| Employer | Obsidian Systems — software engineering consultancy for capital markets |
| Role | Functional Software Engineer |
| Location | Remote, USA East Coast |
| Domain | Canton Network, market infrastructure, financial institutions |
| Source | Ashby posting API, board `obsidiansystems`, HTTP 200 on 22.11.2026; published 2026-10-20, still live |
| Application | `https://jobs.ashbyhq.com/obsidiansystems/0a44c74d-4519-4cce-9596-dd75c5ecbdd5/application` |
| Compensation | USD 150–180k, the range given in the Ashby form |
| Advert text | `job-description.txt`, retrieved from the board API |

## Documents

| Document | File | Note |
| :--- | :--- | :--- |
| Cover letter | `anschreiben.pdf` | One page, English |
| CV | `lebenslauf.pdf` | Two pages, English |
| Sources | `lebenslauf.typ`, `anschreiben.typ` | Typst, standalone, **0 warnings** |
| Dossier | `dossier.md` | Ten sections, including the record of what this packet cannot prove |
| Certificates | none | still missing |

## Measured artifacts

| File | Pages | Bytes | Words | SHA-256 (first 16) | Fill |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 38884 | 748 | `a37ca6b028a1ddb9` | 95 % / 84 % |
| `anschreiben.pdf` | 1 | 24155 | 542 | `66a7ba89cf811735` | 85 % |

Typeset at 11.5 pt, 0.70 em leading, 1.6 cm × 1.9 cm margins (CV); 10 pt, 0.58 em, 2.0 cm × 2.2 cm (letter). Both rebuild byte-identically.

## Legacy files: none existed

This task was to retire older pre-Typst files (`Matt_Ji_Resume_Obsidian.pdf` and similar) into git history and record their hashes. **There were none, and there are no hashes to record.** Checked three ways on 2026-11-22:

- `ls submissions/obsidian/` — no such directory before this packet created it.
- `find . -ipath '*obsidian*'` outside `.git` — no match anywhere in the tree.
- `git log --all --diff-filter=A --name-only -- '*Obsidian*' '*obsidian*'` — empty; no such file was ever added on any branch.
- `git log --oneline --all -- 'submissions/obsidian*'` — empty.

So nothing was deleted and no history was rewritten. The directory holds only files created today, and the DB row had `folderPath` empty, which is consistent: the Ashby submission never had a packet behind it.

What was uploaded to Ashby on 21 November was a tailored CV that the repository does not preserve (`resumeUrl` and `folderPath` were both empty). The CV here is rebuilt from `lib/matt/resume.json`, the canonical source the personal site renders from. It documents the application; it cannot be byte-identical to the uploaded file, and the dossier says so.

## Requirement check

| Requirement | Evidence | Assessment |
| :--- | :--- | :--- |
| 5+ years production software | 2020–2025, Go service and fleet, built and run alone | Met |
| Engineering fundamentals, data structures, algorithms, testing | fibtransponder state machine and corpus benchmark; content addressing; CI gates | Strong |
| Functional programming, professional or substantial projects | Nix: lazy, pure, typed module options; thirteen hosts as one value | Partly |
| Type systems, algebraic data types, pattern matching | Typed module options; Go structs and interfaces; no ADT-native language | Partly |
| Distributed and concurrent systems, backend | Multi-host fleet, services over a tailnet, event log, PostgreSQL/Redis in the stack | Partly |
| Immutable data structures | bountystash: immutable content-addressed spec, append-only log | Strong |
| Correctness-critical domain | Valuation models that passed bank audits; energy trading risk for EWE Trading | Strong |
| Nix or reproducible environments | The whole stack: flakes, pinned inputs, reproducible builds, rollback | Strong |
| Consultancy and direct client work | Bountystash advisory; O3 work with banks, brokers and clients | Met |
| Haskell, Scala, OCaml, F#, Clojure | not present | **Gap** |
| Daml, Canton, blockchain | not present | **Gap** |
| Property-based testing | not present; benchmarks and corpus falsification instead | **Gap** |
| Capital-markets infrastructure | energy trading instead, a different market | **Gap** |

## Fit: 3

Three, because the shop sells Haskell engineers and the record has none. What carries the score: Nix is a preferred requirement and is the entire stack here; immutability and content addressing are real and used in anger; the financial-correctness instinct exists (models that passed bank audits, trading risk with a counterparty at the other end); and the fibtransponder story is exactly the kind of engineering judgement the posting says it values.

Not 4, because the first preferred line — a functional language — is a gap, and no amount of Nix closes it. Not 2, because the posting explicitly allows functional experience "through substantial projects" and names Nix, and because a consultancy hiring for client work can use someone who debugs production systems and argues from measurements.

## Open points

1. **Already applied.** Do not submit twice; this is the record and the interview document.
2. **Reconstruction caveat.** The uploaded CV is not preserved, so this one differs in wording. Said plainly in the dossier.
3. **Piece table.** The brief asked to ground the dossier in a piece-table implementation. No piece table, gap buffer, rope or CRDT exists in the repository, the canonical resume, or any project description, so it is not claimed anywhere. fibtransponder takes that slot honestly.
4. **Certificates** still missing.
5. Fit 3 set today; the DB had none.

## Packet

| File | Content |
| :--- | :--- |
| `job-description.txt` | Full advert plus source line and fit note. |
| `dossier.md` | Situation, role, evidence, gaps, route, risks. |
| `lebenslauf.typ` / `.pdf` | CV source and two-page PDF. |
| `anschreiben.typ` / `.pdf` | Letter source and one-page PDF. |
| `submission-sheet.md` | This overview. |
