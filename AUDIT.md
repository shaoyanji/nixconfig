# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-20)

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 34 devices: 11 active Nix, 6 active external, 1 WIP, 16 preserved | `.#inventory`, `docs/generated/fleet-inventory.md` |
| Host gates | per-host module system + assertions, one host per process | `nix build .#hostChecks.x86_64-linux.<host>` |
| Known red gates | `minyx` (kernel conflict), `cassini` (xdg.desktopEntries on darwin) — both dormant | `task checks:host HOST=minyx MODE=eval` |
| Formatting | alejandra, 100 % of tracked `.nix` | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 6 SOPS files, zero drift | `task checks:sops:drift` |
| Skills | 43, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | resolver pair: frieren pihole+unbound, delphi crab-hole, one shared `10.99.0.53` | `task checks:dns:failover` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-10-20 — The gotcha essays become a page

- The 110-line "Nix Patterns & Gotchas" section is now `docs/nix-patterns.md`:
  yq/format traps, non-obvious Nix, the two uncached overrides, ten agent failure
  modes. The manual keeps the TOML rule line and four citations.
- New gate `paperless-closure-traps` (stock `pkgs.tika` in an inline unit, stubbed
  gotenberg chromium) — verified to fail on `services.tika.enable = true`.
- Evidence: `checks.policies` rc=0 (24), `docs:links` 115, `fmt`/`lint` 219 clean.

### 2026-10-20 — Two gates get sharper

- `secrets-are-encrypted` is **per value**: any key before the `sops:` block that is
  not `ENC[...]` (or declared `_unencrypted`) fails, and the error names the key, never
  the value. Verified with one plaintext value among 32 encrypted ones.
- `ca-only-user-access`: no `.nix` outside the three key sources (`authorized-keys`,
  `ssh-ca`, `nixbuild-client`) and the out-of-flake hosts may hold an `ssh-ed25519`
  literal; verified with a stray key added to `hosts/demo`.
- Ledger archived: the five entries older than today moved to `docs/history/`.
- Evidence: `checks.policies` rc=0 (23), `docs:links`, `docs-budget`.

### 2026-10-20 — Secrets are a page and three predicates

- The secrets table, key locations, SSH-CA workflow and bootstrap moved from
  AGENTS.md into `docs/sops-rekey.md`, which already owned the two sops planes.
- Gates: `secrets-are-encrypted` (a plaintext sops file fails),
  `secrets-submodule-declared` (the submodule *and* its mirror are named),
  `ssh-ca-declarative` (`rotate-ssh-cert` + `ssh.ca.enable`) — each verified to fail
  when broken. Evidence: `checks.policies` rc=0 (22), `docs:links`, `docs-budget`.
### 2026-10-20 — CI has no matrix

- The CI section moved to `docs/ci-pipeline.md`, and `lifecycle:ci:enable-host` /
  `disable-host` were deleted: they `sed`-ed a `machine:` list the pipeline stopped
  reading when detection became inventory-driven, and README pointed at them.
- Gates: `ci-matrix-is-inventory`, `ci-dormant-hosts-excluded`,
  `ci-builds-config-and-gate`; evidence `checks.policies` rc=0 (19), `docs:links` 114.
### 2026-10-20 — The storage table has one home

- The `/srv/data` table, media-isolation rules and security-directory notes left
  AGENTS.md for `docs/storage-taxonomy.md`, which absorbed `download-taxonomy.md`
  (ingest doors, torrent policy); the manual keeps a six-line pointer.
- Replaced by `taxonomy-one-home`, `media-tree-isolation` and
  `private-trees-restricted` — each verified to FAIL when its condition breaks.
- Evidence: `checks.policies` rc=0 (16), `docs:links` 113, `docs-budget`,
  `site-assets`, `qmd:docs` (the new page is top hit for its own vocabulary).
### 2026-10-20 — Prose is not where a rule lives

- 1 145 comment lines removed from 104 `.nix` headers; `nix-header-budget` (≤3
  lines) makes the one-line contract a gate instead of a convention.
- qmd combs the nix tree (`**/*.{nix,md}`, 220 files); a mask is registration-time
  state, so the index script re-registers a collection whose mask changed.
- Deleted `docs/vision.md` (byte-identical to `control-plane-vision.md`) and
  `docs/fleet-operations-recommendations.md` (rules already in this manual);
  `no-orphan-docs` makes an unlinked page a gate failure.
- Evidence: `checks.policies` rc=0, `hostChecks` frieren+mtfuji rc=0, `.#docs`,
  `docs:links` 113, `nix:format` 219 clean.

## Open debt (`task ops:notes`)

1. `minyx` kernel conflict and `cassini` darwin assertion — both dormant, both
   reproducible with `MODE=eval`.
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
