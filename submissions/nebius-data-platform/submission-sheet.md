# Nebius — Senior Site Reliability Engineer (Data Platform)

Greenhouse **5040676101** · Amsterdam · **Berlin** · Israel · London · Prague · Remote · first published 2026-11-17, updated 2026-11-18.
The platform is one multi-tenant YTsaurus ecosystem — roughly **10 PB compressed across ~500 servers and ~20k cores** — carrying financial pipelines and
training datasets. **No band published**; target EUR 130,000–160,000, ask EUR 140,000–155,000.

**Status:** applied 2026-11-21 per the apps DB (Greenhouse confirmation on file). Both documents are a faithful rebuild for the CV screen or a resend.

## Legacy packet, now genuinely in git history

All five files were **untracked**, so they were committed unchanged first (`appflow(nebius-data-platform): stage the pre-Typst packet`) and retired in the
rebuild commit:

| Artefact | sha256 (first 16) | What it was |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `a3e473a7bfcbcb9c…` | Nix-built CV, "Site Reliability Engineer", three fleet bullets |
| `anschreiben.pdf` | `374dc2b5095a92bb…` | Nix-built letter, salutation **"Dear Nebius Compute Node team"** — wrong team |
| `selection.json` | `442289038853f1ac…` | selector output |
| `submission-sheet.md` | `5533f5dbcc99df40…` | the 2026-11-21 sheet, this file's predecessor |

`job-description.txt` is kept unchanged: a real capture of the posting, not a reconstruction.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1268 | 0 | `625be620c6b6dc1f` |
| `anschreiben.pdf` | 1 | 444 | 0 | `f3714a3d5326e798` |

## The five pillars, against the repository

| Pillar | Evidence | In the documents as |
| :--- | :--- | :--- |
| PostgreSQL operational management | `services.postgresql` declared per service (`email-archive.nix`, `mail-atlas.nix`, `paperless-fork.nix`); `postgresqlBackup` on `frieren`; `pg_dump` in `infra-stack.nix`; settings generated from Nix rather than edited on the host | claimed in full |
| Versioned schema migrations | Migrations applied in order by the service; the archive's schema adds the stored `tsvector` behind a GIN index and an upsert keyed on `message_id`, so a replay cannot become a second row; a failed step leaves the previous version running | claimed in full |
| Restore drills | `modules/services/postgres-backup-drill.nix` (EXP-042) starts an ephemeral PostgreSQL cluster, replays each logical dump into it with `gzip -dc … | psql`, then asserts the restored table count against `assertMinimumTables` (default 20) and, for Immich, the core entity row counts; it runs on a timer after the backup window, where a broken dump fails the job rather than waiting for the day someone needs the data. The replay uses `psql`, not `pg_restore`, which is why a grep for `pg_restore` in this repository returns nothing | claimed in full |
| Storage growth alerting | `fleet-sentinel` records disk percentage for `/`, `/nix/store` and `/srv/data` plus inode counts, and degrades the host with a named reason at `degradeOnDiskPct` instead of waiting for a failed write; PSI and generation age in the same ledger | claimed in full |
| High-integrity data handling | Validate before write, append-only event state, content-addressed specifications, and a fourteen-month archive of real mail as the non-synthetic test load | claimed in full |

## Gaps, in both documents

No YTsaurus, Hadoop, Spark, ClickHouse or Kafka operations. No production Kubernetes at five-hundred-server scale and no operator development. No
multi-petabyte cluster. No formal capacity planning for a multi-tenant platform. Storage work is single-host and small-fleet. The earlier sheet judged
the honest fit "closer to 2 than 3" on the big-data bonus list; the row stays at 3, and the letter says the first months would go into the platform's Go
operators and diagnostic tooling.

## Route

Sixteen live Greenhouse labels, **no cover-letter file slot** — the letter goes in the application email or the Additional-context block. Country
Germany, location Gutach im Breisgau with Berlin/remote noted; authorization yes (US citizen, unbefristete Niederlassungserlaubnis); prior Nebius
employment no.

**Compensation:** EUR 140,000–155,000, named in the letter because the submitted version carried it and dropping a figure in a rebuild changes the
signal.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page (asserted before commit) |
| `**` in sources | 0 |
| Curly quotes | 0 |
| Unsupported claims (YTsaurus/Hadoop/Spark/ClickHouse/Kafka) | 0 outside the gap paragraph |
| `task checks:prose` | exit 0 |
| Legacy artefacts | staged first, retired in the rebuild, hashes above |
