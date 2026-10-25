# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-22)

Rows carrying a command were re-measured 2026-10-22 with it. The live-system rows
(observation, knowledge, backups, DNS, tailnet) were last confirmed 2026-10-20.

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 34 devices: 18 active (11 NixOS, 1 home-manager, 6 external), 16 preserved | `nix eval .#inventory.hosts`, `.#inventory.derived` |
| Host gates | per-host eval (assertions) and per-host VM boot to stage-2, one process each | `.#hostChecks.x86_64-linux.<host>`, `.#hostBootChecks.aarch64-linux.delphi` |
| Known red gates | `minyx` (kernel conflict), `cassini` (xdg.desktopEntries on darwin) — both dormant | `task checks:host HOST=minyx MODE=eval` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | frieren pihole+unbound owns the zone; delphi crab-hole answers public DNS only, same address | `task checks:dns:failover` (exit 2: no zone secondary) |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger

### 2026-10-25 — stark joins atuin
- `stark` (Steam AIO) had the sops-rendered key and `atuin 18.23.0` but no session: `atuin login`
  (mnemonic from `atuin/key`, not the base64 key file), `import nu-hist-db` + `import bash`, `sync` →
  **24,520 items** (5,383 bash / 19,116 nu), converged with `frieren`; server `store` **24,522** (the
  constant +2 is bookkeeping rows, not history). Proof: both hosts report the same count, cross-host
  history is readable in `atuin search` (frieren's `cd /Volumes/data/`), 22 bash functions and 3
  `_atuin_*` nushell commands on stark, key file byte-identical to the sops secret.

### 2026-10-25 — fern joins atuin; the NAS mirror moves onto the exported lane
- `fern` rebuilt and logged in (`atuin 18.23.0`; the key is rendered by `modules/sops.nix`, so the
  host only needed `atuin login`): `import nu-hist-db` + `import bash` then `sync` → **24,282 items**
  (5,208 bash / 19,074 nu), server `store` at **24,284**. Proof: the two imports, `atuin sync`
  complete, the postgres count on frieren, and 3 `_atuin_*` commands visible in fern's nushell.
- `burgernas-library-sync` writes `/volume1/peachcable` — the only NFS export — instead of
  `/volume1/Shared Library`, where the DietPi/Raspberry Pi clients could never see it. 48 files that
  existed only on the NAS were rescued into `/Volumes/data/{bin-x86,bin-aarch64,bin-script}` first,
  and the legacy paths are relative symlinks to the export (an NFS symlink resolves client-side, so it
  cannot split the lane). Proof: one run to exact name parity 80/66/20/66, six hashes equal, ~10 G of
  duplicate freed, same counts through frieren's `vers=4.1` mount. Live on frieren's next rebuild;
  the timer is weekly (Sun 03:32).
- Commentary gate: `scripts/task/nix-prose-lint.sh` fails a commit when 8+ **added** comment lines
  cite no home (docs, skill, policy, `task`, `.#`, repo path) — the diff, not the corpus, so it bites
  now instead of demanding a rewrite of the 58 existing blocks that `MODE=all` reports. Folded into
  the existing `nix-header-budget` policy rather than a second rule for one topic; `checks.policies`
  reports 44 holding.

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
