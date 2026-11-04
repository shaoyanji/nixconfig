# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. An entry older
> than a week rolls into the agent turn log — `task ops:audit:roll` posts it as an
> xs event and removes it here, because what happened is a turn, not a document.
> Design rationale lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`). Budget:
> 300 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-27)

Rows with a command were re-measured 2026-10-27; live-system rows (observation,
knowledge, backups, DNS, tailnet) last confirmed 2026-10-20.

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 35 devices: 20 active (13 NixOS, 7 external), 15 preserved, 0 wip | `nix eval .#inventory.derived`, `task dev:inventory:counts` |
| Host gates | per-host eval (assertions) and per-host VM boot to stage-2, one process each | `.#hostChecks.x86_64-linux.<host>`, `.#hostBootChecks.aarch64-linux.delphi` |
| Known red gates | `cassini` (xdg.desktopEntries on darwin), dormant. `minyx` passes its gate on its own arch (`ARCH` now resolves per host, so no flag); its hardware is the shortfall, not its config: continuous under-voltage in `dmesg` | `task checks:host HOST=minyx` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | frieren pihole+unbound owns the zone, minyx blocky+keepalived is the secondary behind VIP `192.168.3.50` (priority 200/1, unicast peers); delphi crab-hole answers public DNS only, same address | `task checks:dns:failover`, `docs/dns-failover.md` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-11-04 — downloads-sort stops calling a dead download "in flight"
- **The unit was red for a bug, not a decision.** `strata-probe.bin` (39.7 GB, preallocated, one
  `IQ3_XXS-00001` header and none of its bytes) carried an `.aria2` control file from 11-03 that
  aria2 had no record of (`tellActive`/`tellWaiting`/`tellStopped` all `[]`); the sorter tested the
  control file alone, so it printed `INFLIGHT` hourly forever and staging never emptied.
- **That case is `STALLED`**; with aria2 unreachable a control file still means INFLIGHT.
  `*SUMS`/`*.sha256`/`*.md5`/`*.log` are `SIDECAR`, and `.gguf` routes to `software/models/` after the
  classifier answered "software" and moved 149 GB mid-job — sizes match HF, nothing truncated.
- **Staging is empty:** corpse and companions in `downloads/.stale/` (38 GB); `Result=success`,
  `/sentinel/status.json` `{"state":"ok"}`, gatus green.

### 2026-11-04 — the duplicate monitors leave frieren; the alert sink stays behind
- **Retired, and nothing was lost by it.** frieren's `gatus` and `uptime-kuma` are gone, with the
  `status.`/`monitors.frieren.lan` vhosts and the 3001/8181 holes. Both kuma databases held **zero
  monitors** (`select count(*) from monitor` = 0 on each: 37 MiB of dashboard, 0 checks), so the
  checks that existed were gatus's ten endpoints.
- **They moved to delphi**, where `services.fleetMonitors` probes the NAS across the tailnet —
  jellyfin `:8096`, immich `:2283`, home assistant `:8123`, harmonia `:5000`, audiobookshelf by
  `Host: audiobooks.frieren.lan`, paperless on `127.0.0.1:28981` — each port one frieren's
  `serviceExposure` registry already opens on tailscale0. The Steam cache (loopback only) and the
  resolver check (`10.99.0.53` is delphi's own failover address) cannot be carried by a probe.
- **The alert path inverted.** delphi has the checks and no SimpleX identity; frieren has the
  identity (`~/.simplex`) and no gatus. `alerting.address`/`url` are options now: frieren keeps the
  bridge on `0.0.0.0:5226`, opened only on tailscale0, and delphi's gatus posts to
  `100.97.61.65:5226/alert` — proved by a POST and by gatus's own triggered alert arriving.
- **Also:** the 05:00 scorecard reads delphi's API; exposure, portal, restic paths and
  `docs/frieren-access.md` dropped the dead units. `checks:host` green on both (delphi 1973
  assertions, frieren 23.7 s), both switches landed, `is-system-running` = `running`.

### 2026-11-04 — the agent-suite loss is the engine's prefill guard, and IQ1_M answers it too
- **The tier question is closed, and not the way the docs first said.** IQ2_XS at
  `--max-context 16384` loaded with `636 MiB of VRAM free` and 50.9 GB RSS, then aborted on the
  **4K prompt** stage; `--no-ple` is refused outright under `--native` ("the PLE key is native
  too"), so the PLE table in the larger packs is not a ~28 GB shard that can be dropped. Both
  hypotheses for making 68/76 GB fit are dead.
- **Then the served pack lost the engine the same way.** `tools/strata_bench.py --runs 3` on
  IQ1_M at 16384 stalled in 3 of 3 agent runs, turn 3 of 6, always `layer 1 of the prompt chunk
  from token` 9076 / 9121 / 9063, with the engine's own guard (`no progress for 60 s`, exit -6)
  and the wrapper respawning it. `oom_kill` 0, no kernel line, 636 MiB VRAM free at load: it is
  the prefill path, not memory, not VRAM and not the quant.
- **Context 16384 was reverted.** It truncates the session at turn 3, so the KV it saves buys
  nothing: served is IQ1_M at `--max-context 32768`, `--kv int8`, MTP on, 24 engine threads.
  The 16K baseline stands as the number to beat — chat median 11.30 tok/s, 4K prompt 166.8 tok/s,
  agent cache hit 55.8 %, per-turn first token 93.77 s, agent decode 8.40.
- **Also landed:** `LimitCORE = "0"` on `strata.service` (a 2026-11-04 abort spooled ~50 GB into
  systemd-coredump's temp file and took `/` from 44 to 94 GB for five minutes); the runbook now
  carries the transient-unit retest recipe plus the two traps (`.venv/bin/python` needs the FHS
  env, no `/bin/bash` on this host); `hosts/eisen/MANUAL.md` §7 carries the tier table, the 16K
  baseline and the stall; `strata-quant-tier` was distilled to the 30-line budget and the engine
  work split into `strata-engine-bump-retest` (0.1.56 rebuild, the prefill rework is the prize).
- **Upstream:** reported as [Niko1221/Strata#5229](https://github.com/Niko1221/Strata/issues/5229)
  (the guard's own message cites the closed #29) with the three stall sites, the build
  fingerprint and the four questions; cross-commented on #4566 and #3807, which track the same
  family on 0.1.46/0.1.47 and on gfx1031.
- **Verified:** `git push` gates (docs budget, docs links, task-graph digest pin) green on every
  push; the switch landed (`/run/current-system` = `d5g8xiyw…`, `strata` active, `n_ctx` 16384 at
  the time, later 32768, `LimitCORE=0`); eisen was then powered off on request.

## Open debt (`task ops:notes`)

1. `cassini`'s darwin assertion (`xdg.desktopEntries`) — dormant, reproducible
   with `MODE=eval`; `minyx`'s kernel conflict is gone (the board evaluates,
   passes its gate and is active since 2026-10-27).
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
