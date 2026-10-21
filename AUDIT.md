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
### 2026-10-21 — Strata MoE (Qwen3.8-Flash-Next 125B) running on Eisen RX 5700

- Deployed Niko1221/Strata MoE inference on Eisen's AMD Radeon RX 5700 (`gfx1010`) via
  an isolated FHS wrapper (`strata-fhs`) and AMD TheRock ROCm 7.14 wheels on `/mnt/storage/strata`.
- Configured systemd service `strata.service` on port 8085; Nginx port 80 proxy and
  `tailscale-serve-node` routed to `:8085`; `llama-swap` made dormant.
- SubZeroClaw harness (`~/.subzeroclaw/config`) verified on `:8085` executing tool-calling
  file creation (`echo 'write me a hello.txt in home directory' | subzeroclaw`).
- Measured: 167 tok/s prompt prefill, 14.6–21.0 tok/s decode, 87.5% MTP speculative drafting
  acceptance (70/80 tokens accepted) with 32K context and INT8 KV cache. Documented in `hosts/eisen/MANUAL.md`.
- `AGENTS.nix` note `open-strata-eisen-rx5700` marked `DELIVERED`.

### 2026-10-21 — A doc-only push now has a gate

- `docs-budget` CI job builds `checks.<system>.docs-budget` on every push; the
  budgets live once, in `scripts/task/docs-budget.sh` (task, check and job run
  it), and `[[flake/policies.nix#ci-doc-budget]]` fails if the job disappears.
- Evidence: padded-copy build exits 1 (`AGENTS.md: 1300 > 1200`), policies green.

### 2026-10-21 — A remote host closure is transfer-bound, not build-bound

- One `fern` toplevel, profiled phase by phase: eval **133 s** (2.38 GiB peak,
  oom-guard); plan 14,804 store paths, 56 derivations to build and 37 paths to
  fetch (159.5 MiB); local substitution of 36 paths in **36 s**; 3 small paths
  uploaded; 4 remote builds, the three nixbuild.net reported **finished in 0.8 s,
  4 s, 2 s** (1–2 CPUs). Then 27 min of silence waiting for the remote
  `initrd-linux-7.2.10` build — no completion report, no error; killed.
- `--option builders-use-substitutes true` on a re-run still fetched the 141.6
  MiB modules pair **locally**, so the flag does not move this host's cost. No
  end-to-end completion: the copy-back phase was never reached, and a fair A/B
  needs a cold builder store that nixbuild.net does not expose.

### 2026-10-21 — Exit codes are a gate; prose has its own digest

- The 33 summaries naming an exit code were cross-checked against the script their
  task invokes (25 script-backed, 8 inline by hand): **0 over-promise**. The two
  real drifts were already fixed — `checks:ports` lost `1 = STRICT drift`,
  `checks:kg:sidecar` read the engine's 404 as its own status.
- That audit is now `exitDrift` (fatal): a code a `summary` promises that no script
  or inline command emits. `0` is never a claim, `fail=1 … exit "$fail"` counts,
  and a task
  that just runs `nix build` is `opaque` (nothing to compare). Membership is asked
  of `readDir` — `pathExists` answers false for an unrealised lazy flake path.
- `graph.json` now carries the prose surface verbatim, and the artifact name holds
  both digests (`taskfile-graph-<version>-p<prose>`), so a prose-only edit is
  addressable. Measured: version unchanged, prose `c0e18535aacf → ce94226f319a`,
  new path; reverting restored the original path byte for byte.
- Evidence: `checks:tasks` rc=0 (437 tasks, 17 buckets, 0 hard violations),
  selftest 17 buckets / 16 tasks, `checks:quick` rc=0.

### 2026-10-21 — The 2026-10-20 ledger entries are archived

- Seven entries (task graph compiled, gotcha essays, two gates sharper,
  secrets as a page, CI without a matrix, the storage table, rules in code)
  moved verbatim to `docs/history/audit-2026-10.md`; `AUDIT.md` had reached
  159 of its 150-line budget. Content unchanged, only the home moved.

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
