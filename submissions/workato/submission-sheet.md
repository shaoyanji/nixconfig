# Workato — Senior Infrastructure Engineer (PostgreSQL DBA)

Greenhouse **8842211002** · REQ **2960** · posted 2026-11-15, Greenhouse copy updated 2026-11-20 · Berlin · Frankfurt · Munich · no remote per the listing.
No band published; target **EUR 130,000–150,000** (USD 140,000–165,000).

**Status:** applied 2026-11-21 through Greenhouse 8842211002. This rebuild keeps the submitted claims, adds the schema detail that was missing, and names
the scale gaps the posting actually probes for.

## Legacy packet, now genuinely in git history

All five files were untracked, so they were committed unchanged first (`appflow(workato): stage the pre-Typst packet before the rebuild`) and retired in the
rebuild commit:

| Artefact | sha256 (first 16) | What it was |
| :--- | :--- | :--- |
| `lebenslauf.pdf` | `83f17bbc4f8869cc…` | Nix CV, "Infrastructure and database engineer", no schema detail |
| `anschreiben.pdf` | `9906a00e9d20cef2…` | Nix letter, claimed PostgreSQL operations without naming a single table decision |
| `selection.json` | `a2de81a7a5fd034c…` | selector output (budget, JD, projects, skills) |
| `submission-sheet.md` | `2e10f775c5a0927b…` | the 2026-11-21 sheet, this file's predecessor |

`job-description.txt` is kept: a real capture of the posting.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1110 | 0 | `746dd43481c0e77a` |
| `anschreiben.pdf` | 1 | 473 | 0 | `6de07b493b6b5921` |

## What the posting asks for, against the repository

| Requirement (JD) | Evidence | Verdict |
| :--- | :--- | :--- |
| Index and schema design, schema reviews | generated `tsvector` over subject/sender/body with a GIN index; `message_id` upsert key; classifier primary key `(message_id, classifier)` in `modules/services/email-archive.sql` | strong, at my scale |
| Data migrations and upgrades | ordered migration files applied by the service; a failed step leaves the previous version serving | strong for app-schema change; no `pg_upgrade` |
| Backups, DR, proving restores | `postgresqlBackup` on the archive host, `pg_dump` in the stack, and EXP-042 (`postgres-backup-drill.nix`): ephemeral cluster, `gzip -dc … | psql` replay, restored table count and entity rows asserted | strong |
| Observability for the data layer | Sentinel ledger: disk and inode percentages per path with a named degrade reason, PSI, job state, page on bad state and silence | adjacent (host level, not `postgres_exporter`) |
| Aurora/RDS operations, parameter groups, failover | none | **gap** |
| PgBouncer connection pooling | none | **gap** |
| Logical replication, major-version upgrades | none | **gap** |
| Multi-TB and partitioned tables, dozens of clusters | single-node, one instance per service, largest table in gigabytes | **gap** |
| Terraform/Ansible automation | Nix, task control plane, pre-commit gates | **partial** — transferable habits, different tool |
| Linux, scripting (Bash/Python/Go) | thirteen-host NixOS fleet; Go services and CLI tooling; Python and Bash for checks | strong |

## Gaps, in both documents

Single-node PostgreSQL by design: no streaming replicas, no failover, no pooler. No Aurora or RDS production experience. No major-version upgrade with
`pg_upgrade`, no logical replication, no multi-terabyte partitioned tables, no fleet of dozens of clusters, no company-scale database on-call rotation.
Infrastructure-as-code is Nix rather than Terraform or Ansible. The CV says "gigabytes rather than the multi-terabyte partitioned tables this role tunes" —
that sentence is the honest distance, not a hedge.

## Route

Applied through Greenhouse 8842211002 on 2026-11-21; the duplicate row is annotated rather than deleted. Relocation to Berlin, Frankfurt or Munich is stated
because the listing says no remote; no sponsorship needed (US citizen, German permanent residence); start 01.12.2026; target EUR 130–150k, unchanged from the
submitted version and recorded here because Workato publishes no band.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page (asserted before commit) |
| `**` in sources | 0 |
| Curly quotes | 0 |
| Unsupported stack (Aurora/RDS/PgBouncer/Terraform/Ansible/pg_upgrade) | only inside the gap paragraph |
| `task checks:prose` | exit 0 |
| Legacy artefacts | staged first, retired in the rebuild, hashes above |
