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

### 2026-10-25 — three skills become one command each; eisen's stack gets a read
- `.agents/skills/{stt,voice-loop,google-drive}/scripts/` now hold the procedure: `stt.sh`
  normalizes to 16 kHz mono and picks local voxtype or eisen, `voice-loop.sh` says/hears/
  roundtrips and scores the loop by word overlap, `drive-auth.sh` runs the OAuth handshake and
  tears its funnel down on exit. `task infra:status:eisen` replaces the prose probe list.
- **The eisen skill was describing a stack that no longer runs.** `llama-swap` is dormant and
  `strata` serves `:8085` (`hosts/eisen/llm-server.nix`); the task reports both, reads socket
  units rather than `/health` so it never wakes an idle model, and exits 2 when the host is off.
- Proof: stt — stub *voxtype* local path with `--out`, ffmpeg rejection of non-audio, 2.1 s
  fast-fail off a cold host; voice-loop — `default` rejected before any request, overlap scores
  1.00 / 0.75 / 0.00; drive-auth — `verify` against the live remote (5 TiB, 17 dirs), URL
  extraction, wait budget and process teardown against a stub; status — unreachable exit 2 plus
  human and JSON renders over ssh. **Not exercised:** a real transcription, a real TTS call, and
  the OAuth consent step — eisen is powered off and consent needs a browser.
- Gates: `ops:skills:check`, `checks:tasks` (460 tasks, exact name parity), `checks:docs:links`,
  `docs-budget.sh`, `shellcheck -S warning` on all four scripts.

### 2026-10-25 — atuin bring-up is one script, not five commands
- `.agents/skills/atuin/scripts/atuin-bootstrap.sh` does the whole host: key-shape
  preconditions, login, a marked one-time seed, two syncs, and an `--expect` count check.
  Idempotent on purpose — `atuin import` is not (measured 1,940 → 3,880 rows on a second
  `import bash`), and a host without `modules/shell/atuin.nix` would log into `api.atuin.sh`
  and report `invalid credentials`, which reads like a wrong sops password.
- Proof: exit 2/3/4/5 paths exercised against stubs, and a sandbox happy path that logged in,
  seeded nothing and matched 24,520 on the real server with the server count unchanged; a
  re-run reported `login skipped / seed skipped`. `stark` was done by hand before the script
  existed (24,520 items).

### 2026-10-25 — the skill-mirror gate survives a null `desc` and backticks
- `skills-task-mirror` aborted with *expected a string but found null* on any doc whose table
  named the `exit` task (it has no `desc`, and `task.desc or ""` returns null for an attr that
  exists and is null), then died in its own `runCommand` because the warning text carried
  backticks. Both fixed; gate green at 52 skills, one advisory warning (`microvm`, 2 rows).

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
