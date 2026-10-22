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
### 2026-10-22 — scratch's sops planes unseal through its TPM; the proof moves to the store copy
- scratch is the third TPM-sealed host (`&tpmscratch`) and the first whose **system** plane unseals
  through the chip: `age.keyFile` + `age.plugins`, `sshKeyPaths` forced empty, no SSH-derived recipient
  at all. `switch-to-configuration` exits 0. Audio was firmware, not config (BIOS re-enabled `00:1f.3`).
- `modules/sops.nix` gained `age.plugins` for `tpmHosts`: without it the user unit's
  `Environment=PATH=` is empty and the unseal dies on `0 successful groups required, got 0` —
  measured on frieren, exit 128 with the identity / exit 0 with the plugin. frieren and fern stay
  green only because a software `keys.txt` is still a recipient there, so their `sops -d` says nothing.
- Proof now targets `/nix/store/<hash>-secrets.yaml` through the unit's own manifest, not a checkout:
  both planes decrypt it to the pulled tree's digest, and a no-identity control exits 128. scratch's
  clone sat 2768 commits behind at `~/nixconfig` while `~/Documents/nixconfig` was a store symlink.
  Procedure `.agents/skills/tpm-sops/SKILL.md`; contract `docs/sops-rekey.md`; note `tpm-sops-planes`.

### 2026-10-21 — frieren headless-by-default, governor store references, Caddyfile removal

- Split frieren into two boot personas: `hosts/frieren/configuration.nix` is now the
  headless server default (no niri, greetd, or DisplayLink) and `hosts/frieren/desktop.nix`
  is `specialisation.desktop`. QuickSync/VA-API stays in the base `hardware.nix`, so Jellyfin
  transcodes in both; `media-stack.nix` adds the `jellyfin` user to `video`/`render`.
- Fixed the `builtins.derivation ... references the store path ... without a proper context`
  warning: `modules/services/fleet-governor.nix` used `toString ../..` (and `toString ../..`
  for the S2 `flakePath` default), which strips store context. Both now interpolate a path,
  so `run-fleet-governor` and `fleet-governor-rules.json` have real inputs
  (`nix-store -q --references <drv>` lists `…-systemone` / the flake source; both build with
  `--builders ""`).
- Deleted `modules/config/Caddyfile` (no references in the tree or in history).

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
- Factored Dell D6000 Universal Dock into `modules/profiles/dell-dock.nix` (`profiles.dell-dock.enable`);
  enabled for frieren and fern, registered in `modules.toml`.
- Fixed Fern lid-close sleep deadlock (`AllowSuspend = "no"`), enabled DisplayLink EVDI for
  Samsung 4K TV, removed Wayland-incompatible `caffeine`, and distilled hardware quirks into `inventory.toml`.

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
