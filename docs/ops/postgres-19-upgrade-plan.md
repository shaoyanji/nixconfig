TASK: PostgreSQL 19 upgrade on delphi (next epoch, nixpkgs unstable swap)

GOAL: Upgrade delphi's PostgreSQL from PG 17 → PG 19 when the fleet swaps to nixpkgs unstable. This is a major-version upgrade requiring data migration, not just a package bump.

CONSTRAINTS:
- Do NOT attempt until the fleet has moved to nixpkgs unstable (current channel 26.05 only carries PG 17)
- PG 19 in unstable is currently 19rc2 — wait for 19.0 final before production cutover
- Must not break: email archive, miniflux, umami, zettel-graph, mataroa (all on delphi's postgres)
- Must not break: postgres-pgvector-audit, postgres-backup-drill modules
- Verify: `nix eval .#inventory.hosts.delphi.role` passes before and after
- xs turn: claim SUBJECT=delphi:postgres-19-upgrade, log outcome

WHERE POSTGRES LIVES ON DELPHI:
- Module: modules/services/email-archive.nix (services.postgresql enable = true)
- Databases: email archive (primary), miniflux, umami, zettel-graph, mataroa
- Port 8449 is the agent-turns API (not postgres); postgres listens on loopback 5432
- Backups: modules/services/postgres-backup-drill.nix (tests restore to scratch instance)
- Audit: modules/services/postgres-pgvector-audit.nix (uses pgvector extension)

UPGRADE PLAN (execute in order):

1. PRE-FLIGHT (before touching delphi)
   - Confirm nixpkgs unstable has postgresql_19 at 19.0 (not rc2)
   - Confirm pgvector extension is available/compatible for PG 19
   - Run `pg_dumpall` on delphi's live PG 17, verify backup integrity
   - Run postgres-backup-drill restore test against the backup
   - Create worktree off origin/main

2. VERSION PIN
   - In modules/services/email-archive.nix: `services.postgresql.package = pkgs.postgresql_19;`
   - Consider pinning via `services.postgresql.package` rather than relying on default

3. DATA MIGRATION (choose one)
   - Option A: `pg_upgrade` — needs both PG 17 and PG 19 binaries present; faster
   - Option B: `pg_dumpall` / `psql` restore — slower, safer, cleaner
   - NixOS services.postgresql does NOT auto-run pg_upgrade; orchestrate manually

4. POST-MIGRATION
   - Run ANALYZE on all databases
   - Verify pgvector extension loads in each database that uses it
   - Verify all services (email archive, miniflux, umami, zettel-graph, mataroa) connect
   - Run postgres-backup-drill against the new PG 19 instance
   - `nix eval .#inventory.hosts.delphi.role` ✓

5. COMMIT & PUSH
   - Commit to origin/main, push
   - Post xs turn with OUTCOME=done, commit hash, proving gate

DEFERRED / NOT IN SCOPE:
- Writing directly to .anki2 files (not relevant here)
- Anki sync server write protocol (not relevant)
- Any AGENTS.md changes for this repo (deutsch-srs is a separate repo)

RELEVANT FILES:
- /home/devji/Documents/nixconfig/modules/services/email-archive.nix (services.postgresql decl)
- /home/devji/Documents/nixconfig/modules/services/postgres-backup-drill.nix
- /home/devji/Documents/nixconfig/modules/services/postgres-pgvector-audit.nix
- /home/devji/Documents/nixconfig/hosts/delphi/configuration.nix (service consumers)
- /home/devji/Documents/nixconfig/flake.lock (nixpkgs pin — 26.05 now, unstable next epoch)
