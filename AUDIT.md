# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Narrative
> history lives in [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md);
> design rationale lives in [`ARCHITECTURE.md`](ARCHITECTURE.md).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-19)

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
| Knowledge | qmd (prose) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | single resolver (frieren) — failover group still 1 member | `task checks:dns:failover` (exit 2 = not evaluable) |

## Ledger

### 2026-10-19 — Rebuild path de-bloated

- `infra:switch:*` no longer runs `warm-host.sh --check` first. That hook forced
  the whole host toplevel (`drvPath`, `outPath`, `nix build --dry-run`) before
  every local switch — a duplicate of the work the switch itself does. The gate
  remains as `checks:build:route` and is CI/operator-only.
- `nom` is now opt-in (`NOM=1`), set by `agents:menu:rebuild` (the human TUI).
  Agent/local rebuilds run plain and preserve the real exit status.
- `checks:quick` is documented as repo hygiene, not a pre-rebuild step; its
  header and the `task-plane` skill carry the rule.

### 2026-10-19 — Context plane mk2

- **Home AGENTS.md is a flake output.** `lib/home-agents.nix` renders
  `.#homeAgents.<host>` (preamble + compiled host card + persona); frieren's
  activation links it to `~/AGENTS.md`. The Python renderer and
  `--home-agents`/`--sync-home` paths were removed; `dev:inventory:home-agents`
  now builds the derivation. Verified: `nix build .#homeAgents.frieren` →
  store path, `~/AGENTS.md` symlink, activation eval includes
  `AGENTS-frieren.md`.

- **Skills are compiled.** `lib/skills.nix` parses `.agents/skills/*/SKILL.md`,
  emits `.#agentSkills` + `.#agentSkillsBundle`, and fails
  `checks.<system>.skills-schema` on name/dir mismatch, missing/oversized
  description, missing heading, or >400 lines. 43 skills indexed in ~0.12 s warm.
- **One materializer.** `modules/user/ai/skills/default.nix` links the union of
  `.agents/skills` and `modules/user/ai/skills` into `~/.agents/skills` and
  `~/.gemini/config/skills`, and links `README.md`/`SCHEMA.md`. Managed names
  are forced, so stale hand copies disappear.
- **Knowledge graph.** `lib/knowledge-graph.nix` projects 34 hosts, 43 skills,
  21 docs, 416 mention edges to `.#knowledgeGraph` (JSON + Cypher).
- **Closed loop.** `modules/services/fleet-sentinel.nix` (frieren) records
  failed units, watched oneshot results, generation age, disk and PSI every
  15 min; serves `status.json` + static dashboard at `sentinel.frieren.lan`;
  gatus asserts `[BODY].state == ok`; SimpleX bridge pages on 3 failures.
- **Docs reclassified.** `ARCHITECTURE.md` (proposals), slim `AUDIT.md` /
  `TODO.md` / `HANDOFF.md`, indexed `EXPERIMENTS.md`, `.agents/SCHEMA.md`.
- **Tasks.** New `ops:*` shard (health, ledger, ledger:toon, skills, kg,
  docs:budget, bench:evals); help map updated.

Evidence: `nix eval .#agentSkills.count` → 43; `.#knowledgeGraph.graph.stats`
→ `{docs:21, edges:416, hosts:34, skills:43}`; `task checks:tasks` clean;
`task ops:skills` lists the index.

### 2026-10-17 — Closure budget baseline corrected

- Fixed the closure measurement cache key (`/run/current-system` was pinned
  before `readlink -f`, so every cached report repeated the first generation).
- Real frieren closure: **29.9 GiB / 3229 paths**; baseline adopted
  `32104328080` bytes, budget +1.0 % (306.2 MiB) headroom.

### 2026-10-15 — Eval-granularity defect (EXP-114)

- `nix flake check` measured 339.78 s / 6078.5 MiB / SIGKILL 137 on frieren.
- `checks.<system>` no longer forces a host; per-host gate moved to
  `hostChecks.<arch>.<host>` (13.16 s / 720 MiB for frieren).
- Agent verification protocol rewritten: whole-toplevel eval per host, never
  `config.networking.hostName` as a "check".

### 2026-10-14 — NAS path governor (EXP-103)

- LAN-first NFS with verified tailnet fallback, `OnFailure` governor, `nix-gc`
  guard for GC roots on an absent NAS. Reboot path still unverified.

### 2026-10-13 — Service modularization & System One prototypes

- `fleet-governor`, `btrfs-watchdog`, `uds-static-bridge`, `ups-simulation-drill`,
  `sqlite-maintenance`, `paperless-watchdog`, `kiwix-watchdog`,
  `postgres-backup-drill`, `flake-advisory-audit`, `postgres-pgvector-audit`,
  `fleet-session-reaper` graduated from `EXPERIMENTS.md` into `modules/services/`.
- System One ensemble prototypes (EXP-065…072, 081, 083, 084, 087, 088, 097)
  wired to `systemone-ensemble` + `task checks:decision:*`; these are
  prototypes, not modules, and are recorded as such in the experiment index.

### 2026-10-08 — Service extraction & lint convergence

- Home Assistant stack, Kiwix, pastebin, iVentoy moved to `modules/services/`.
- 181/181 Nix files alejandra-clean; deadnix/statix clean; SOPS drift zero.
- Duplicate 52 GB Wikipedia ZIM reclaimed; single GC-rooted store path kept.

## Open debt (tracked in TODO.md)

1. `minyx` kernel conflict and `cassini` darwin assertion — both dormant, both
   reproducible with `MODE=eval`.
2. DNS failover group has one member (HC-3); `checks:dns:failover` exits 2.
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
