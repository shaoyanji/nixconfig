# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day roll into `docs/history/audit-<YYYY-MM>.md`; design
> rationale lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`). Budget: 150
> lines (`.agents/SCHEMA.md` §2).

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
### 2026-11-02 — the fleet's public cache: R2 behind a GET-only Worker, as a buffer
- **Third tier, not a replacement.** `harmonia` stays the LAN cache and `cachix` the 5 GB WAN one;
  delphi adds a 10 GiB R2 bucket served by `modules/services/nix-cache-edge/` at
  `https://nix-cache-edge.jisifu.workers.dev` (key `delphi.edge-1`), registered after `cachix` in
  `lib/cache-registry.nix`, `lib/cache-policy.nix` and `flake.nix` (`checks:flake:cache` proves it).
- **The bucket holds a delta, never a closure.** `dev:nixcache:push` HEADs every path against every
  non-LAN registry cache first: delphi's 2728-path / 18.48 GiB system closure leaves **365 paths /
  771 MiB** unique (2158 nixos, 167 cachix, 11 nix-community, **27 / 1.40 GiB numtide** — the llm-agents
  tools), so 10 GiB holds ~13 systems. Over `BUDGET_GIB` it refuses before writing and prints the five
  largest survivors.
- **The edge never signs.** narinfo is signed by the pusher (`secret-key=` on a `file://` staging cache)
  and moved with rclone; the Worker reads, so every trap is the pusher's: `nix copy` is recursive by
  default, `--no-recursive` needs valid references (stubs satisfy it, never uploaded), `--to s3://` wrote
  nothing against a fresh bucket and exited 0, `rclone purge` deletes the bucket.
- **Size collects, age only expires.** `dev:nixcache:gc` deletes the oldest until under 75 % of the
  budget; the lifecycle rule is a 365-day backstop that `deploy` reconciles. gc is not scheduled yet.
- **Evidence:** `checks:nixcache:probe` green (info, HEAD, 404, 405, signed narinfo); `nix path-info
  --store <edge> <path>` accepts the signature; `dev:nixcache:check` 17/17. docs/nix-cache-edge.md.

### 2026-11-02 — email archive: NpgsqlRest over PostgreSQL on delphi, tailnet-only
- **The SQL file is the API.** `modules/services/email-archive.nix` packages the v3.21.0 NativeAOT
  `npgsqlrest-linux-arm64` binary (fetchurl + autoPatchelf, no .NET runtime), enables PostgreSQL with
  database `email_archive` and role `npgsqlrest`, and binds loopback `:8080` behind a `tailscale serve`
  mount on **8450**. `email-archive-db-init` re-asserts the role password from sops, sets database
  ownership itself (`ensureDBOwnership` only accepts a role-named database), then applies
  `email-archive.sql` **as the role over TCP**, so a bad `pg_hba` fails activation. Table CRUD left
  upstream in 3.14, hence the three annotated files under `email-archive-endpoints/`.
- **Two keys the examples get wrong.** Uploads are
  `NpgsqlRest.UploadOptions.UploadHandlers.FileSystemPath` (+ `UploadOptions.Enabled`,
  `FileSystemUseUniqueFileName`), not `NpgsqlRest.FileSystemPath`; the password rides the shipped
  `{!PGPASSWORD}` placeholder with `AddEnvironmentVariables=false`.
- **Evidence:** `checks:host HOST=delphi` rc=0; `/health` 200; `api/list-emails` and `api/emails-search`
  200 through the tailnet name on `:8450`; `emails_search_idx` GIN present. The mirror reuses the
  calendar's `ConditionPathExists` rule rather than a second credential. `docs/email-archive.md`.

### 2026-11-02 — the mail sweep decides by rule; needle3 keeps only tool calling
- **A label is a decision, not a tool call.** `mail-agent-sort-tools.json` asked needle3 for a keep/archive
  *classification*. A ten-item labelled battery scored needle3, julia-1 and laya at **3/10 each** (nine of
  ten archive; Go City wrong in the other direction at 0.71/0.84), so the schema is deleted and the sweep
  archives on `BULK_*` + `PROTECTED` + `sweep.trustedSenders` alone; `minConfidence` and `--min-confidence`
  went with it. `hosts/delphi/needle-tools.json` no longer forces a note-kind classification either.
- **Evidence:** `mail-agent --self-test` 10/11 (dispatch unchanged), `mail-agent --sweep` prints `ARCHIVE`
  / `held … sender not in sweep.trustedSenders` with no model call, `checks:host HOST=delphi` green
  (`docs/mail-agent.md`, `AGENTS.nix` exp-128).

### 2026-11-02 — mail-agent: Needle 3 routes mail commands on delphi
- **A sentence in, a himalaya action out.** `mail-agent` (module, harness and tool schemas under
  `modules/services/`) dispatches `search_mail` / `archive_mail` / `mark_read` with the needle3 binary
  delphi already ran for repo routing; a 06:30 systemd user timer sweeps bulk mail. Engine and weights
  live in `modules/scripts/needle-model.nix`, one hash for both consumers.
- **Measured, then designed.** Routing battery 10/11; a `trash_mail` tool was never selected, so delete
  left the schema instead of gaining a gate; a dry run over the real inbox approved a Dropbox "connected
  a new app" and a GitHub "new SSH key" at 0.22–0.47, so the sweep archives only from
  `sweep.trustedSenders` and holds the rest with a printed reason.
- **Evidence.** The unit ran 2.6 s / 86 MB and archived 7, all of which left the inbox (one restored from
  All Mail on demand). `~/.local/state/mail-agent/audit.jsonl` records `message-id`, because Gmail
  reassigns uids per mailbox (310172 in INBOX, 621165 in All Mail); 0 failed units on delphi.

### 2026-11-02 — paperless, vaultwarden and anki move off the NAS; the NAS becomes the shelter
- **The shape of an offload is now a module.** `services.offloadBridge` declares what a moved service
  still owes the NAS: a nightly mirror to `/srv/backup/offload` with each SQLite database replaced by a
  `sqlite3 .backup` snapshot (a WAL-mode `db.sqlite3` rsync'd beside a stale `-wal` restores into a
  service that answers wrong), an ingest pull for the drop folder, and the cutover facts.
  `docs/service-offload.md` is the procedure.
- **Measured before moving.** paperless ~520 MiB RSS across four units plus tika and gotenberg, 722 MB of
  SQLite + media and no postgres — a file copy plus one consistent dump. vaultwarden 36 MiB / 4.2 MB,
  `DOMAIN` unchanged so passkeys survive. anki-sync-server held **430 MiB resident for a 4 KB empty
  store**; its placeholder account was plaintext `bob`/`password` in the store, now a 32-character sops
  password via `passwordFile` (a systemd credential), proved on the live server: `/sync/hostKey` returns
  an hkey for the sops password and 403 for `password`.
- **delphi is the only host that built.** paperless needed 20 derivations no substituter carries on
  aarch64 plus 559 MiB fetched: **~41 min on 2 OCPU**, because spacy pulls thinc/blis and those compile
  C++. `wandb` fails its own suite on this arch and is built with checks off via paperless'
  `extraPythonPackageOverrides`; the shared `modules/services/paperless-fork.nix` avoids upstream's
  tesseract narrowing, re-applied on every definition. Nothing compiled on frieren: its config evaluates
  to a toplevel drvPath (81 s / 4.8 GiB) and is unapplied by design.
- **The names stayed.** `docs.frieren.lan`, `vault.frieren.lan` and `anki.frieren.lan` are still
  frieren's vhosts, now proxying delphi's tailnet address; frieren was deployed (2026-11-02), and
  `offload-tunnel` is gone.
- **Evidence:** `checks:host HOST=delphi` 1947 assertions rc=0; state migrated by
  `scripts/task/offload-migrate.sh` (flock, manifest, `integrity_check`, row-count match, health URL),
  run twice to show the second is a no-op; the shelter copy verified under `/srv/backup/offload`.

### 2026-11-02 — Ryoku leaves the pilot: a desktop tier ladder
- **Three regimes, one cutoff each.** Ryoku is the high-end tier — **poseidon, eisen, fern** (fern the
  floor); Dux (`globalModulesNixos`, DMS + greetd) the medium — aristotle, stark; `profiles.dwlDesktop`
  the low end — scratch, netbook. The ladder lives in `inventory.toml` (`desktop_environment` +
  `module_chain`) and nowhere else.
- **The chain swap is the whole change.** `globalModulesRyoku` carries `inputs.ryoku` and no
  dms/dank-greeter, and both hosts import `ryoku-desktop.nix` in place of
  `base-desktop-environment.nix` — not alongside it: that profile `mkForce`s `xdg.portal.config.niri` to
  the GTK backend, so keeping both would strip portals from the shell that owns them.
- **`sddm.enable = false` was the trap.** Ryoku turns SDDM on with `mkDefault`, so a leftover explicit
  `false` wins and the host boots to no display manager. Both blocks are gone; the module owns the
  greeter and its theme.
- **Ryoku pins its session at priority 900** (`ryoku-niri`); poseidon keeps autologin into niri, eisen
  keeps `lib.mkForce "steam"`. `deck-session-switch` restarted greetd only — now whichever of
  greetd/sddm is active (stark keeps greetd).
- **Evidence:** `checks:host MODE=eval` green on every touched host — eisen 2019 assertions (152 s /
  2643 MiB), poseidon 2014 (307 s / 2668 MiB), stark 2002, fern 1979 (67 s); `inventory-schema`,
  `inventory-hosts`, `inventory-modules` build clean. Read back by leaf eval: eisen
  `{ryoku, sddm, theme="ryoku", session="steam", autologin}`, poseidon identical with
  `session="ryoku-niri"`, fern `session="ryoku-niri", autologin=false`. Build mode was not used: it
  aborted at io pressure 60.9 % after 540 s on frieren.
- **Not done:** no host was switched — `infra:deploy:host:<host>` is the operator's call.

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
