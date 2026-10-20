# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Narrative
> history lives in [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md);
> design rationale lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
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

### 2026-10-20 — The tree matches the module graph

- Deleted what nothing consumed: `modules/niri.nix`, `roles/heim.nix`, `hm/niri.nix`,
  `wezterm/`, `nixos/k3s/`, `user/ai/gemini-cli.nix`, `lib/pie-menu.nix` (334 lines,
  zero callers); `roles/portable-home.nix` is three lines in `hosts/penguin.nix`.
- `modules/shell/{bash,tmux}.nix` merged into `base.nix` (behaviour proven identical:
  eisen's `programs.tmux.enable`, the same 322 B `.bash_aliases`); `flake/` lost six
  wiring-only files, 14 → 7, one consumer each.
- 236 → 219 `.nix`. 26 configurations still evaluate (23 nixos + 3 home), `checks:host`
  green on frieren/mtfuji/demo, `penguin MODE=eval` 4.5 s / 482 MiB.

### 2026-10-20 — Hostname comes from the inventory, chains come from `|>`

- `mkNixosHost` sets `networking.hostName` from the inventory key (`mkDefault`), so 22 host
  files lost the line repeating their own directory name: 23/23 configs resolve to their key
  and `checks:host` is green on frieren/mtfuji/demo. `|>` is now the preferred chain form
  (CI sets `pipe-operators` explicitly, since a runner without it cannot parse the tree).

### 2026-10-20 — The design record gets edges, and a way in

- Notes gained two directed fields, `from` (what this idea grew out of) and `supersedes`;
  `ancestors`/`descendants`/`replacedBy` are derived by `lib/agents-notes.nix`. The gate
  rejects a cycle, a self-edge, a `supersedes` target that is not `SUPERSEDED`, and a
  `SUPERSEDED` note nobody claims.
- `ops:notes:near Q=` is the novel-task entry (~1 s): ranked hits with `match n/total`,
  lineage and refs. `ops:notes:lineage ID=` both directions; `ops:notes:doc` the fourth
  reverse index (157 notes, 63 leaves, 4 edges). Rendered in `.#docs` and the site.
- Seeded only edges the prose already claimed: `exp-113 ← exp-107`,
  `decision-determinate-nix-fleet ← exp-determinate-nix-trial → nix-binary-upgrade-2026-10`,
  `open-flake-bump-2-35-3 ← nix-binary-upgrade-2026-10`.

### 2026-10-20 — A check cannot offload its evaluation, only its build

- `checks:host` gained three build-routing modes so the gate can never drift into spending
  builder budget, one question each: default `--builders ""` (compile locally, nixbuild
  unreachable), `STRICT=1` (substitute-or-fail: "is this host warmed?"), `OFFLOAD=1`
  (`--max-jobs 0` + `/etc/nix/machines`). Measured on fern: default 10.56 s / 958 MiB;
  OFFLOAD 12.68 s wall with the remote build itself **746 ms**.
- **The reason that matters: nixbuild runs derivations, it does not evaluate.** A
  hostCheck's derivation is a three-line `runCommand` echo, so ~10.5 s of a 10.6 s gate is
  local module-system + 1961 assertions and no flag moves it. The real offload for
  evaluation is CI, one runner per host: `task dev:ci:trigger:<host>`.
- `oom-guard.sh` aborted on **inherited** pressure: absolute PSI thresholds killed a 1.1 s
  `nix build --dry-run` because frieren sat at io full avg10 61 % from unrelated work, so
  the gate became unrunnable exactly when the host was busy. Limits are now
  `max(threshold, baseline + 5)` with the baseline sampled before the command and printed
  beside the peak; a 3-host run completed at baselines of 52-73 %.
- Shellcheck-clean, `checks:tasks` green, `checks:host HOST=frieren` and
  `HOSTS="fern frieren"` rc=0.

### 2026-10-20 — Tailnet DNS is on, and its redundancy is not what it looks like

- Live: global `[100.97.61.65, 10.99.0.53]`, Override on, split DNS empty. Both answer
  (`photos.frieren.lan → 192.168.3.25`) and filter (`doubleclick.net → 0.0.0.0`).
- **A subnet-route nameserver is invisible to hosts that refuse routes.** eisen, fern and
  aristotle set `--accept-routes=false` deliberately (table 52 hijacks their LAN traffic),
  so `10.99.0.53` is unreachable from them and `100.97.61.65` is their only resolver — a
  frieren outage is total DNS loss there, Override or not.
- **Route failover is node-level, not service-level.** crab-hole stopped on delphi — then
  the `/32` primary — for 32 s and the route never moved: the node was online, the
  resolver was not. There is no tailnet equivalent of the VRRP `vrrp_script`; the second
  nameserver entry is what kept queries alive.
- **delphi cannot be an equivalent resolver.** crab-hole has no static-record or zone
  support (blocklist/downstream/upstream/api only), so `*.frieren.lan` is NODATA there —
  and the `/32` is on delphi right now, so fleet names break for anyone using tailnet
  DNS. `ops:tailnet:dns` fails on exactly this; split DNS for the zone is the cheap fix,
  a dnsmasq zone front-end the equivalent-resolver one.
- Recommended shape: list both resolver *node* addresses (`100.97.61.65`, `100.123.145.53`)
  — routable without `--accept-routes`, and a service crash is covered by client retry
  instead of a route takeover. `10.99.0.53` stays for LAN clients that hardcode it.
- New gate `ops:tailnet:dns`: classifies each entry (node vs subnet route), probes the
  zone and a blocked domain, probes every node advertising a listed address on its own
  node IP, and marks `local-bind` when the reporting host answers its own probe.
- Fix chosen: **split DNS** `frieren.lan → 100.97.61.65`, so the zone never reaches the
  global list. Console-only (`dns:core` write; the OAuth client answers `403`). Applied
  2026-10-20: the gate now reports the pin and stops faulting delphi for that zone.
- That edit briefly left globals as `[10.99.0.53]` alone — a subnet route the three
  route-refusing hosts cannot reach. `ops:tailnet:dns` now FAILS on a routed-only list
  (hosts read from the repo, not hardcoded); `100.97.61.65` is back, gate rc=0. Residual:
  those hosts keep one usable resolver, so a frieren *service* failure still blinds them.

## Open debt (tracked in TODO.md)

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
