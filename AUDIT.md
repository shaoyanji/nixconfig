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
### 2026-10-21 — Delphi cloud workspace seeder, Freebuff mainframe, & Antigravity gateway

- Fixed `seed-workspace` on delphi: added `gh` to `delphi-seed-workspace` with
  `url."https://github.com/".insteadOf "git@github.com:"` rewrite and `gh repo clone`
  so recursive submodule clones do not block on missing GitHub SSH keys.
- Deployed `freebuff` and `freebuff-headless` to Delphi; re-pointed `freebuff-remote`
  away from frieren to `delphi.bountystash.com`.
- Enabled 24/7 `antigravity-cli-daemon` (`agy remote-control serve`) on Delphi
  under user lingering for persistent connectivity on `antigravity.google.com`.
- Fixed direnv cached devShell progcomp bug: added `bashInteractive` to `nativeBuildInputs`
  in `flake/devshells.nix` so interactive subshells retain completion builtins.
- Factored Dell D6000 Universal Dock (DisplayLink / EVDI) into reusable profile
  `modules/profiles/dell-dock.nix` (`profiles.dell-dock.enable`); enabled for both
  frieren and fern, registered knob in `modules.toml`.

### 2026-10-21 — the harness is a worker service behind HTTPS, not a tunnel

- `services.dshWeb` runs `dsh web` on the worker (systemd, loopback `:3080`,
  `--public-url`, `--trusted-host`) and is **tailnet only**: `tailscale serve`
  terminates TLS at the MagicDNS name on 8443 and proxies there, preserving
  `Host` (measured), so the public vhost carries only the landing page.
- `dsh-remote` is a client: it reads the signed-in URL from the worker's journal,
  proves the ingress from this machine, then opens it. No `ssh -L`, so the tab
  outlives the command and the URL is bookmarked; `--url/--status/--restart/--log`.
- Unsigned worker: measured — it still boots and serves (`200`), but upstream
  takes the OAuth callback only on a loopback origin, so `--login` forwards one
  and `--sync-auth` imports a client credential; the launcher says which.
- Evidence: token `303` → cookie `200` (37,512 B), `/deepseek/api/remote.mux`
  upgrade `401` → **`101`**; `checks:host HOST=delphi MODE=eval` rc=0 (1,841).
- A turn needs the **model** key too (sops → `EnvironmentFile`); harness tailnet-only,
  delphi runs `systemone-decision` (24 MiB); minyx refreshed for a reflash, and the
  builder / exit-node / staging / ingest / gateway ideas are `exp-115`..`exp-120`.

### 2026-10-21 — Pi research is dumped, and there is no 2.0 to design against

- Checked against npm and GitHub: 60 published versions, **no `2.x`**, newest tag and
  `latest` are `v1.3.0` (2026-10-15). The "MCP coding mode" is `codemode`, which
  ships in 1.x (QuickJS sandbox, `tools.*` including namespaced MCP tools, only the
  script's output reaches the model).
- [`docs/pi-harness.md`](docs/pi-harness.md) holds the source material — versions, codemode limits, config
  surfaces (`models.json`, `PI_CODING_AGENT_DIR`), the eisen three-layer shape,
  scenarios, and the open questions — so none of it needs re-fetching. Proposal:
  `AGENTS.nix` `pi-eisen-ondemand`.

### 2026-10-21 — fern's battery is healthy; btop cannot read a rate

- `BAT0` is present and reports fine: `energy_full == energy_full_design == 35.199 Wh`
  (**100 % health**, 0 % wear), 316 cycles, Li-ion, charging at 59 %.
- `power_now` exists in sysfs but **reads ENODEV** (no `current_now` either), so the
  firmware reports no rate and btop 1.4.7 hides the battery rather than draw one
  without a rate. Not a kernel regression — a rollback changes nothing here.
- `services.upower.enable` landed 2026-10-20 (`90f4bc7d`), but fern boots a
  2026-10-05 generation, so the unit is `not-found` on the host today; upower
  samples `energy_now` and is the missing health/rate source. A rebuild, not a
  kernel change, is the fix.

### 2026-10-21 — Strata MANUAL stops claiming 40–50 tok/s on this card

- `hosts/eisen/MANUAL.md` §3/§5 carried 40–48 / 40–50 tok/s decode, which is Strata's
  16 GB RX 9070 XT reference table, not a measurement here. Both now mark the speed
  column as an upper bound and point at §7 (14.6–21.0 tok/s decode, 167 tok/s prefill).
- `hosts/eisen/llm-server.nix`: two comments still named llama-swap as the upstream;
  nginx :80 proxies Strata :8085. No behaviour change.

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
- **Retry with the copy-back isolated went through**: the same drv under
  `--option builders ssh://eu.nixbuild.net` completed in **60 s** (rc=0), goal
  `0rwkkb2d…-nixos-system-fern`. Seven paths came back from the builder and every
  copy-back was ≤ **0.21 s** — the initrd 0.12 s, `linux-7.2.10-modules-shrunk`
  0.21 s. Copying the toplevel alone (`--no-recursive`) is 254 KB NAR in 2.4–3.2 s,
  i.e. `nix` process start-up, not transfer.
- So the stall was neither build nor copy-back cost: it was one remote build that
  never reported. The 141.6 MiB modules pair is still fetched **locally** even with
  `builders-use-substitutes true`, so the flag does not move this host's cost.

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
