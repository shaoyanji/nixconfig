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
| Tailnet DNS | global `100.97.61.65, 10.99.0.53`, Override on, split empty — second entry is unroutable for three hosts | `ops:tailnet:dns` |

## Ledger

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
- The same edit left globals as `[10.99.0.53]` alone — a subnet route aristotle/eisen/fern
  cannot reach — so non-fleet names have no resolver there. `ops:tailnet:dns` now FAILS on
  a routed-only list (hosts read from the repo, not hardcoded); fix = put `100.97.61.65`
  back in globals, since the split rule covers only the zone.

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

### 2026-10-19 — Graph queries, and the decision model's real accuracy

- `ops:ask Q=…` / `scripts/task/kg-ask.sh`: English question → intent → jq over
  `.#knowledgeGraph.file` (new 49 KB store artifact). Routing is **deterministic**;
  the model is recorded, not obeyed: measured on the in-repo engine, 6-way intent
  `choice` scored 2/8 right with equal-length options and 0.20–0.44 confidence
  otherwise, because `engine.py` is a hash-embedding heuristic, not mmBERT.
- `ops:context` is the trigger side: sentinel status + the graph context for the
  host. Advisory — the monitor detects, it never acts.
- `ops:bench:kg` settled the router question with labelled sets, because one was
  not honest: keyword 14/14 rule-shaped / 6/10 paraphrase / 4/9 naming no node,
  Jev 13/14 / 9/10 / 7/9 at ~330 ms, in-repo `systemone-decision` 5/14 / 1/10 /
  4/9. A single-sentence "keyword wins 14/14" would have been a rigged
  conclusion drawn from the set phrased in the rules' own vocabulary. On the
  last set the rules lose but DECLINE (UNKNOWN) where Jev answers wrong.
- Policy that replaced it: when no rule matches, `ops:ask` returns the **context
  bundle** of the node the question names (`route: bundle`, neighbours in
  `related`) — a superset, so it cannot mis-pick a relation, offline at 0 ms
  against Jev's ~330 ms. The paraphrase gain (6/10 → 10/10) is **partly
  circular**: four labels name only a node, and "a node-naming question means
  that node's context" is the policy being tested, so those matches confirm it
  against itself. `ops:bench:kg` prints the bundle count beside the score.
- The query surface is explicit and gated: six patterns
  (`ops:kg:host|skill|doc|tag|comention|stats`, `FORMAT=json` throughout) plus
  `checks:kg`, which fails on a renamed field or node type or a dropped anchor.
- Two bugs the bench found rather than a review: a question naming a **host** was
  routed skill-oriented by the word "mention" (subject-override table was
  asymmetric), and a configured-but-unreachable endpoint aborted the query under
  `set -e` instead of degrading (now `|| out=""`, verified against a closed port).
- Jev wiring: `ops:ask:jev` reads the key from sops in-process, never prints it,
  and the output records `model.name` — so a result says whether a model spoke.
- eisen's Laya/Kev-4B endpoints were unreachable during the bench (all three
  timeouts), so those runners are SKIPPED, not scored.

> Retired to history on 2026-10-20 to keep this document inside its 150-line budget:
> context plane mk2 (10-19), rebuild-path de-bloat and `nom` opt-in (10-19),
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
