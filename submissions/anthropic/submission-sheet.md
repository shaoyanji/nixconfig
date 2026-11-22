# Anthropic — Staff+ Software Engineer, Data Infrastructure

Greenhouse **5114768008** · https://job-boards.greenhouse.io/anthropic/jobs/5114768008 · published 2026-02-13.
Remote-friendly with travel · San Francisco · Seattle · New York · hybrid **25% in office**.
Published band **USD 405,000 – 485,000**; the recorded ask is **USD 405,000 – 440,000**, anchored at the floor.

**Status:** applied 2026-11-21 through Greenhouse (confirmation code `32082413`). This rebuild keeps the submitted claims and fixes the salutation, which
addressed the Nebius Compute Node team.

## Legacy packet, now genuinely in git history

All five files were untracked, so they were committed unchanged first (`appflow(anthropic): stage the pre-Typst packet before the rebuild`) and retired in
the rebuild commit:

| Artefact | sha256 (first 16) | What it was |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `b9a359e4ac794e78…` | Nix-built CV, generic "Site Reliability Engineer" header |
| `anschreiben.pdf` | `b09a8aab3e34807b…` | Nix-built letter, salutation **"Dear Nebius Compute Node team"** — wrong company |
| `selection.json` | `2c3d8226ccf3f36b…` | selector output, carrying the stale USD 280–340k example band |
| `submission-sheet.md` | `a5d189d520724675…` | the 2026-11-21 sheet, this file's predecessor |

`job-description.txt` is kept: a real capture of the posting.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1199 | 0 | `31b64968c674605c` |
| `anschreiben.pdf` | 1 | 493 | 0 | `fa22f1ad3131794f` |

## The four pillars the posting asks for, against the repository

| Pillar | Evidence in this repo | How the documents use it |
| :--- | :--- | :--- |
| PostgreSQL operational management | `services.postgresql` per service (`email-archive.nix`, `mail-atlas.nix`, `paperless-fork.nix`), `postgresqlBackup` on `frieren`, settings generated from Nix | full claim: instance, role, database and settings declared, never hand-edited on a host |
| Ordered migrations, searchable archive | Archive schema: ordered migrations, stored `tsvector` behind a GIN index, upsert keyed on `message_id`, SQL endpoints generated from annotated queries, real mail, not fixtures | full claim, used as the concrete example in both documents |
| Audit-by-restore drills | `modules/services/postgres-backup-drill.nix` (EXP-042): ephemeral PostgreSQL cluster, `gzip -dc … | psql` replay, restored table count against `assertMinimumTables` (default 20), Immich entity rows, timer after the backup window | full claim — this is the "audit drill" the letter leads with |
| Access control and integrity | Short-lived SSH certificates from the fleet CA, per-host sops/age keys, per-service users and hardened units, validate-before-write, append-only events, content-addressed specs | claim limited to fleet-scale access discipline; no IAM-at-scale claim |

Two claims from the first draft were cut after checking the repository: a "documented retention window" (no retention policy exists for the archive) and an "encrypted archive" (the database sits on the host with no at-rest encryption configured). What remains is what a grep can show: a sops-managed database role, no standing credentials, and the mail in one place instead of many inboxes. The "fourteen months" figure carried by earlier packets could not be re-verified from the repository, so the duration is gone from both documents and they say "real mail, not fixtures" instead.

Adjacent, and said so: disk and inode percentages per path with a named degrade reason, PSI/job-state/generation-age ledger paging on bad state and silence.

## Gaps, stated in both documents

No BigQuery, BigTable, Airflow, dbt or Spark operations. No petabyte-scale GCS/S3 replication or disaster recovery. No IAM policy, ACL or audit-logging design
at thousands-of-users scale (the fleet's access story is certificates and per-host keys, which is a different problem). No Staff-level scope across several
teams; team leadership and platform direction come from a founder role, not a Staff title. Storage work is single-host and small-fleet. Fit stays at 3 with the
honest distance recorded here — the earlier duplicate row said 2 and that judgement is preserved in the DB note.

## Route

27 live Greenhouse labels including the "Why Anthropic?" essay and the arbitration agreement. Relocation answered yes with `relocating` as the work address,
25% in-office accepted, sponsorship not required (US citizen), start from 01.12.2026, coding interview in Python. The essay and the arbitration
acknowledgement are the applicant's own wording; the sheet keeps the previous text rather than inventing a new one.

**Compensation:** USD 405,000–440,000, named in the letter because the submitted version carried a figure and a rebuild that silently drops it changes the
signal. The selector's USD 280–340k example was below the published band and is not used.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page (asserted before commit) |
| `**` in sources | 0 |
| Curly quotes | 0 |
| Unsupported stack (BigQuery/BigTable/Airflow/dbt/Spark/GCS/S3) | only inside the gap paragraph |
| `task checks:prose` | exit 0 |
| Legacy artefacts | staged first, retired in the rebuild, hashes above |
