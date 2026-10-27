# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-27)

Rows carrying a command were re-measured 2026-10-27 with it. The live-system rows
(observation, knowledge, backups, DNS, tailnet) were last confirmed 2026-10-20.

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

### 2026-10-27 — the VIP is back: minyx is the backup, and the takeover was observed
- `8d271c31` declared the group again with the address rules that were missing the first time: VIP
  `192.168.3.50` (static block, not `.25`, not the peer's `.3`, and not `.53` — an option `example` the router
  was already leasing to the board), `unicastPeers` asserted by the module, minyx's role bound to **`wlan0`**
  because `enu1u1` is DOWN (verified on the box), and minyx promoted off `preserved`.
- Deployed: minyx by closure push from delphi (`--target-host devji@192.168.3.3`), frieren by
  `nixos-rebuild switch --flake github:…#frieren`. The first frieren run reused a cached tarball and built the
  previous generation — pinned to the exact revision, which is the reliable form.
- **Observed, both directions:** frieren preempted at 09:52:33 (`received lower priority (1) advert from
  192.168.3.3 - discarding` → MASTER); stopping keepalived on frieren moved `.50` to minyx in ~4 s and
  `dig @192.168.3.50 photos.frieren.lan` still answered `192.168.3.25` while `doubleclick.net` stayed `0.0.0.0`;
  restarting frieren pulled it back (`Master received advert … higher priority 200` → BACKUP on minyx). One
  transition each way after 09:52, no flapping. `.25` was never touched, so clients saw no outage.
- The 04:00 failure class did not recur: frieren's switch reloaded `firewall.service` and finished `running`.
  The track script loads on both nodes (`VRRP_Script(dns) succeeded`, zero "track script dns not found").
- Open, and neither is Nix: the router still hands out `.25` + `9.9.9.9` (`.50` is proven free by ARP
  duplicate-address detection but is not yet served to clients), and **poseidon declares `.3` statically** for
  its dock NIC while minyx holds it by reservation — the peer address frieren advertises to.

### 2026-10-27 — the minyx VIP is withdrawn, and the reason the 04:00 switch failed
- `f021660a` made minyx the P1 (priority 1) DNS failover behind a floating `192.168.3.53`. It was wrong on three
  counts and is reverted: the host is inventory `status = "preserved"` (so the closure was never pushed and only the
  primary half went live at 04:00), the VIP was the same address the router was already leasing to that board, and it
  was copied from the `virtualIp` option's `example` rather than reserved anywhere.
- The 04:00 autoUpgrade exited **4**: keepalived's `openFirewall` renders `extraStopCommands` that `iptables -D` rules
  the running firewall did not have yet, and `firewall-reload` runs those under `set -e` right after inserting a
  DROP-all rule — so the reload aborted and INPUT kept dropping. Evidence: `Failed to reload firewall.service`, then
  `switching to … failed (status 4)`; the firewall was restarted by hand at 05:03. The module now opens VRRP from the
  firewall's start path (nftables `extraInputRules`, else `extraCommands`) and never through `openFirewall`.
- Also fixed while reverting: the group's probe requires a non-empty answer that equals the zone address (it probed
  the apex, which frieren answers with `127.0.0.1`, and `dig` exits 0 on NXDOMAIN); `unicastPeers` is now an
  assertion, not advice (multicast VRRP splits brain on a LAN that filters `224.0.0.18`); the default script user
  `keepalived_script` exists, without which the track script was rejected and the instance ran unchecked.
- State now: frieren alone at `192.168.3.25`, no keepalived, `checks:dns:failover` exit 2 (no zone secondary — the
  honest answer). Blocky backend kept in the module. No second member until a non-dormant host has a reserved
  address; see [`docs/dns-failover.md`](docs/dns-failover.md).

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
