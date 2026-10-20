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
| Knowledge | qmd (prose) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | resolver pair: frieren pihole+unbound, delphi crab-hole, one shared `10.99.0.53` | `task checks:dns:failover` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger

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

### 2026-10-20 — Tailnet route approval is tailnet state, not host state

- `10.99.0.53/32` was advertised on **both** nodes and approved on **neither**, so the
  "failover pair" served nothing off-host: an advertisement is an offer, and no eval can
  see whether it landed. Both are approved now.
- `autoApprovers.routes` (`autogroup:admin`) covers it and `192.168.3.0/24`, but fires
  only when a route is **advertised** — a prefix already pending stays pending, so a
  re-offer finished it (withdraw just the /32, re-add; approved in 5 s on frieren,
  parked on `10.99.0.54/32` on delphi). A reboot re-offers, so the pair now self-heals.
- The policy is in the repo: `modules/config/tailnet-policy.hujson`, with `ops:tailnet:policy`
  (semantic diff gate) and `ops:tailnet:policy:apply` (If-Match, refuses non-route edits
  without `FORCE=1`). `ops:tailnet:routes` is the drift gate; both rc=0.
- Token resolution is shared (`scripts/task/lib/tailnet-api.sh`): the sops OAuth client is
  `all:read`, so reads work and policy **writes** still need a widened scope or
  `TAILSCALE.API.KEY`. Approval itself needs no credential any more.
- `profiles/tailnet-dns-address.nix` composes `--advertise-routes` from `advertiseRoutes`
  + the service `/32` and owns `exitNode`, asserting exactly one such flag reaches
  `tailscale set`; eval'd flags byte-identical on both hosts.
- Tailnet DNS is a separate, still-empty switch (`global: []`, `split: {}`): approval
  makes the address reachable, nameservers decide whether clients ask it.

### 2026-10-20 — delphi: the user sops plane is derived, not copied

- `modules/profiles/sops-user-identity.nix` (new, opt-in): activation derives
  `~/.config/sops/age/keys.txt` from the host SSH key (a CA-only host has no user
  keypair; `generateKey` mints an unregistered one → `0 successful groups`). The derived
  identity IS `&delphi`, so no rekey. Verified on the host.
- `docs/sops-rekey.md` (new): the two identity planes, anchor convention, rekey steps,
  and the submodule `.sops.yaml` copy trap.
- First offload: `services.fleetMonitors` on delphi (gatus, tailnet-only `:8181`, public `:8181`
  refused) — an out-of-LAN vantage point frieren's loopback probes cannot be. 3/3 endpoints ok.
- Public web: `https://delphi.bountystash.com` → `200`, Let's Encrypt chain, `:80` → `301`.
  The first ingress attempt dropped with **0 packets** (ports in *Source* Port Range); ACME's
  404 was a local nginx listen-group bug, not DNS. Runbook Phase 4/4c.
- delphi self-updates (`autoUpgrade` 04:30) and both hosts bind + advertise `10.99.0.53/32`
  through one shared module; frieren's advertisement awaits console approval. Also fixed:
  `vdirsyncer` ran on every Linux host with no credentials (a red unit every 15 min).

> Retired to history on 2026-10-20 to keep this document inside its 150-line budget:
> the graph-query/`ops:ask` bench (10-19), context plane mk2 (10-19),
> rebuild-path de-bloat and `nom` opt-in (10-19),
> closure-budget baseline (10-17), the `nix flake check` eval-granularity defect
> EXP-114 (10-15), and the NAS path governor (10-14).
> See `docs/history/audit-2026-10.md`.

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
