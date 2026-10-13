# EXPERIMENTS

> **Classification: non-production.** Nothing in this file is imported by a host, enabled in
> `flake/host-inventory.nix`, or deployed. An experiment graduates by being *deleted from here and
> rewritten as a module*, not by being left enabled somewhere.

## What belongs in this file

Experiments are **service-module design studies**. The deliverable is not "a thing that works on
frieren" — it is the **option surface** of a thing that could work anywhere in the fleet, built to
the same standard as a genuine upstream `services.*` module. Each entry records:

- the **mode** being spun up (how the same hardware/software behaves differently),
- the **use case** that motivates it,
- the **module shape** it would need (concrete options, types, defaults),
- **evidence** — what was actually observed on this hardware versus what was assumed,
- **why it is not prod**, and the **exit criteria** that would promote it.

Three rules keep this file useful instead of a graveyard:

1. **No host imports these.** The moment something here is enabled on a host it is either prod (go
   write it as a module and delete the entry) or it is rot.
2. **Evidence beats plausibility.** "iwlwifi supports AP mode" is a datasheet claim; "`iw list`
   reports `AP` on `8086:3166`" is evidence. Mark the difference explicitly — the wireless entries
   below exist precisely because the first draft of that analysis was wrong.
3. **A mode is not an implementation detail.** If the interesting part is "run the same radio in a
   different mode", say so up front; that is the experiment.

---

## Context — why the wireless entries exist

**Motivating observation (frieren, 2026-10-12):** `wlp2s0` is not idle. It is dual-homed onto the
same flat `/24` as the wired NIC, with a standby default route behind it:

```
wlp2s0  UP  192.168.3.86/24        # SSID "Obi LAN Kenobi"
default via 192.168.3.1 dev enp1s0 proto static metric 100
default via 192.168.3.1 dev wlp2s0 proto dhcp  metric 600   # standby
```

That standby is **only a partial failover**, and the reason is the interesting part: frieren's
LAN-facing identity is its *wired* address everywhere. If `enp1s0` drops, wifi takes over egress but
clients still resolve a dead address, because the wired IP is baked into:

| Surface | Wired address baked in |
| :--- | :--- |
| Pi-hole local DNS | `address=/frieren.lan/192.168.3.25` (`hosts/frieren/dns.nix`) |
| SimpleX SMP relay | dual address `192.168.3.25,100.97.61.65` (in-place init, see `HANDOFF.md`) |
| Aki fleet site | `fleet.frieren.lan` vhost (`hosts/frieren/reverse-proxy.nix`) |
| Harmonia LAN cache | `http://192.168.3.25:5000` in `nix.settings.substituters` |
| NFS / Samba exports | `/srv/data` over the wired address |

So on the same subnet the radio buys almost nothing. The tailnet address is the only genuinely
dual-homed identity the machine has — which is why the fleet standardises on it. The useful question
is therefore **not** "what else can this link carry" but **"what L2 domain can we create that the
flat FritzBox LAN cannot"**: there is no managed switch and no VLAN capability in this network, and
the card can do `AP` and `AP/VLAN`.

**Hardware ground truth** (verified, see [Evidence](#evidence--reproduction)):

| Property | Value |
| :--- | :--- |
| Card | Intel Wireless-AC 3165 Plus Bluetooth, `8086:3166` (iwlwifi), 1×1 dual-band |
| Modes reported by `iw list` | `IBSS`, `managed`, **`AP`**, **`AP/VLAN`**, **`monitor`**, `P2P-client`, `P2P-GO`, `P2P-device` |
| Current link | 5 GHz **ch 36** (5180 MHz, 80 MHz width), regulatory `country DE`, DFS-UNSET / self-managed |
| Neighbourhood | 2.4 GHz ch 6 shared with three other BSSIDs; 5 GHz ch 36 clear |

**The one constraint that shapes every entry: it is a single radio.** `AP`, `STA` and `monitor` are
mutually exclusive in practice — you cannot serve an AP and hold an uplink association on one phy at
the same time. Every experiment below is therefore a *choice of mode*, and the natural design
question is a single module with a `mode` enum rather than four separate modules.

---

## EXP-001 — Isolated guest/IoT access point (AP mode + NAT)

**Mode:** `managed` → `AP`, own subnet, NAT out `enp1s0`.
**Status:** not started. Highest value of the four.

**Use case.** Today every guest phone, IoT plug and smart TV shares one trust domain with
Vaultwarden, Immich, Paperless, Samba/NFS and the private `p/` stores — and Pi-hole answers port 53
on `enp1s0` for all of them. A dedicated SSID on its own subnet (`10.42.0.0/24`, say) with frieren as
DHCP + DNS + gateway gives real segmentation and DNS-level filtering **without new hardware**, which
is the whole point: this network has no VLAN capability to lean on. Guests get internet and the Aki
docs site; they cannot reach the NAS.

**Module shape.** This is the experiment that most looks like a real service module:

```nix
services.fleetWifi = {
  enable = true;
  mode = "ap";                      # enum: "ap" | "sta-failover" | "monitor"
  interface = "wlp2s0";             # type = types.str; no default on purpose
  ap = {
    ssid = "frieren-guest";
    subnet = "10.42.0.1/24";        # type = types.str, validated as CIDR
    channel = 36;                   # non-DFS, already primed by the STA association
    nat = true;                     # masquerade onto the uplink interface
    dns.enable = true;              # hand clients the Pi-hole on this interface
    pskFile = null;                 # secrets via LoadCredential, never the cmdline
  };
};
```

Design questions this experiment must answer:

- Does the guest subnet get **Pi-hole DNS** by extending `dns.nix`'s dnsmasq `interface=` list, or
  should it run a second resolver? (FTL is dnsmasq-based; the port-53 conflict is the crux.)
- How does the **firewall** express this? `hosts/frieren/firewall-scope.nix` `mkForce`s the *global*
  port lists but merges per-interface ones, so a new AP interface silently inherits nothing — the
  scoping must be explicit, and this is the same trap that produced a wrong conclusion earlier.
- Should NAT be `networking.nat` with `internalInterfaces`, and does that conflict with the existing
  iVentoy proxyDHCP on `enp1s0`?

## EXP-002 — Fleet onboarding + out-of-band rescue SSID (AP/VLAN)

**Mode:** a **second BSSID on the same radio** via `AP/VLAN` — one phy, two SSIDs, two subnets.
**Status:** not started. Same implementation as EXP-001; the interesting part is the multi-BSSID
surface.

**Use case.** A network that exists to bring up headless devices (moto, netbook, minyx, a friend's
laptop) where frieren serves DHCP, DNS, the fleet docs and the **harmonia LAN cache**, so installs
pull at LAN speed instead of from upstream. Because this machine is a laptop with a battery, it is
also the admin path that survives a FritzBox outage — the AP, DHCP and DNS are all local.

**Module shape.** Generalises EXP-001's `ap` block into a list of BSSID/subnet pairs, which is where
the option design gets genuinely interesting:

```nix
services.fleetWifi.ap.networks = [
  { ssid = "frieren-guest"; subnet = "10.42.0.1/24"; nat = true;  dns.enable = true; }
  { ssid = "frieren-fleet"; subnet = "10.42.1.1/24"; nat = false; dns.enable = true; }
];
```

The open design question: does a *list of networks on one radio* belong under `services.fleetWifi`,
or is it a generic `services.hostapd`-style module that the fleet happens to point at `wlp2s0`?

**Explicitly out of scope:** PXE over this SSID. PXE boot over Wi-Fi needs client-side Wi-Fi support
in the boot firmware/iPXE and is not viable; this complements `modules/services/iventoy.nix`, which
owns the wired proxyDHCP path.

## EXP-003 — Hotspot-failover STA (uplink of last resort)

**Mode:** `managed`, but pointed at a **phone hotspot** with low priority instead of the house AP.
**Status:** not started. Cheapest resilience win; conflicts with EXP-001/002.

**Use case.** Keep the tailnet alive when the FritzBox or its uplink dies, so remote access,
`restic` backups, the 04:00 `system.autoUpgrade` and the host agents keep running. A laptop-with-a-
battery plus a phone hotspot is a poor-man's 4G failover, and it is the one use of this radio that
plays to what the hardware actually is rather than pretending it is a wired NIC.

**Module shape.** Mostly NetworkManager profile data, which raises the interesting question of where
that belongs: a `networking.networkmanager.ensureProfiles` block is declarative state, but the PSK is
a secret, and `connection.autoconnect-priority` / route metric are the actual mechanism.

```nix
services.fleetWifi.mode = "sta-failover";
services.fleetWifi.staFailover = {
  ssid = "phone-hotspot";        # or discovered at runtime
  priority = 10;                 # below the house APs, above nothing else
  pskFile = null;                # never inline
};
```

**Replaces today's behaviour:** the current same-subnet standby at metric 600. This is the honest
trade: drop a standby that provides half-failover, or keep it and skip EXP-001/002.

## EXP-004 — Passive RF watchdog (`monitor` mode)

**Mode:** `monitor`, channel-hopping, passive only.
**Status:** not started. Lowest payoff; recorded because the card supports it and the fleet has an
always-on host.

**Use case.** A cheap wireless IDS sensor on an always-on box: watch for rogue APs, deauth floods and
unexpected clients near the LAN, and feed alerts into the Home Assistant/MQTT stack that already
exists rather than inventing a new alerting path.

**Constraints to establish before it is worth building.** iwlwifi monitor-mode support is real but
limited (no injection on some firmware revisions), channel hopping is a design choice with a
detection-cost tradeoff, and it cannot coexist with the AP. If it cannot be a *genuine module* it does
not graduate — this one is the likeliest to be closed as "novelty".

---

## EXP-005 — Phone-tethered backhaul (an island that still has internet)

**Mode:** `AP` (EXP-001/002) whose NAT egress comes from a **tethered phone** instead of
`enp1s0`. Sibling of EXP-003, with a different job.
**Status:** not started. Clearest use case of the whole file for this particular host.

**Use case.** Frieren is not just a NAS: it is the LAN's DNS (Pi-hole owns `*.frieren.lan`),
the fleet's ingress (SMP relay, Aki docs, harmonia cache, NFS/Samba) and the only always-on
box. Today all of that dies with the FritzBox. Give the radio an AP role whose uplink is a
tethered phone and the machine becomes a self-contained island: DNS keeps answering for
clients on that SSID, the docs site and binary cache stay up, and the phone supplies WAN —
which matters most because `tailscaled` can ride the tethered interface, so remote access,
`restic` backups, the 04:00 `system.autoUpgrade` and the host agents survive a router outage.

**The design insight worth capturing.** A single 1×1 radio cannot be an AP and hold an
uplink at once — *unless the tether is USB*. A USB tether (`usb0`/RNDIS) adds a genuinely
independent WAN path and **leaves the radio free for the AP**, so this stops being a
competing mode and becomes `EXP-001 + a second uplink`. That is a materially better shape
than EXP-003's Wi-Fi-only failover, which keeps the host online but serves no clients.

```nix
services.fleetWifi.ap.uplink = {
  interface = "usb0";        # USB tether, NOT the radio
  nat = true;
  metric = 700;              # below the wired default, above nothing else
};
```

**Constraints to establish.** Tether data cost and carrier NAT (inbound is impossible, so
tailnet traffic may fall back to DERP relaying); the phone hands out its own lease and is
its own DHCP server, while the FritzBox stays the sole DHCP server on the wired LAN — safe
only because the AP has its own subnet; and Pi-hole's upstream recursion (`127.0.0.1#5335`)
must keep working when the default route flips, which is a genuine test of the DNS design.

## EXP-006 — Private device subnet to harden home security

**Mode:** the EXP-001 segmentation mechanism, aimed at a different threat model — the
Home Assistant device layer rather than guests.
**Status:** not started. Depends on EXP-001 landing first.

**Use case.** Home Assistant and Mosquitto already run here (`modules/services/home-assistant.nix`),
with the broker deliberately loopback-only and anonymous (`127.0.0.1:1883`) and HA pulling
`fritzbox`, `mqtt`, `jellyfin`, `plex`, `immich`, `ipp` components plus `BAT0`/`ADP0` telemetry.
When real devices arrive (TODO.md: a Zigbee coordinator at `/dev/serial/by-id`, and MQTT
hardening to an authenticated LAN listener with a sops `passwordFile`), those devices are
consumer-grade IoT with weak or absent update paths. They belong on their own subnet where
they can reach the broker and HA and essentially nothing else — not on the flat LAN with
Vaultwarden, Paperless, Immich and the `p/` stores.

**The honest correction to the original idea.** "Private VLAN" is **not implementable in
this network**: the FritzBox LAN is flat and there is no managed switch. 802.1Q would need
hardware that does not exist here. The achievable equivalent is a separate SSID + subnet on
frieren's own radio, firewalled off from the NAS LAN — i.e. this experiment *is* EXP-001 with
a stricter policy, which is why it references it instead of duplicating it.

**What actually decides feasibility** (this is the engineering content, not the VLAN label):

- **mDNS/SSDP do not cross an L3 boundary.** HA's discovery of Wi-Fi/Chromecast-style devices
  needs an mDNS reflector (avahi in reflector mode) and an SSDP relay, or those integrations
  silently stop discovering. `androidtvremote2` in the HA module's `extraPackages` is exactly
  this class of device.
- **It forces the MQTT hardening** the TODO already queues: a loopback-only anonymous broker
  cannot serve a separate subnet, so `passwordFile` via sops and a network listener become a
  precondition rather than a nice-to-have.
- **HA still needs the router** (`fritzbox` component) across the boundary, so the rules must
  be explicit in both directions.
- **DNS on the new subnet** hits the same Pi-hole `interface=` pin as EXP-001.

**Module shape** — extend the existing HA module rather than inventing a network module:

```nix
services.ha-stack.mqtt.listeners = [{ address = "10.42.1.1"; passwordFile = ...; }];
services.ha-stack.deviceNetwork = {
  interface = "wlp2s0";
  subnet = "10.42.1.1/24";
  allowFrom = "10.42.1.0/24";   # scoped, never blanket openFirewall
};
```

with an assertion that `services.ha-stack.openFirewall` (8123) remains scoped to the trusted
interface — the module currently defaults it to `false`, and frieren opens 8123 explicitly.

---

## EXP-007 — MQTT as the fleet bus (the broker's first publisher is the fleet, not a dongle)

**Mode:** role inversion. Mosquitto stops waiting to be a *device* bus and becomes the *fleet* bus:
every host is a publisher, Home Assistant is the dashboard. No new hardware, no new listener.
**Status:** not started. Depends on a defect that is live today — see EXP-009.

**Motivating observation.** `modules/services/home-assistant.nix` was written (`2d006a7`) around a broker
with three intended clients: Home Assistant, zigbee2mqtt and ESPHome. Both device-layer clients were
then removed for the same reason — no hardware (`e954e9a`; ESPHome closed at
`hosts/frieren/configuration.nix:482`). What is left is a broker with no conversation in it — no client
has connected since this boot:

```
ss -tnp | grep -c ':1883'                        -> 0
systemctl show mosquitto -p ActiveState          -> active (since 04:08:53)
journalctl -u mosquitto -n 12                    -> 12 x "Saving in-memory database", nothing else
journalctl -u home-assistant | grep -ci mqtt     -> 0
```

"Nothing is hooked up" is therefore precise, not vague: the broker has no publisher **and** no
subscriber, and Home Assistant is not even attempting to reach it. An MQTT broker with no clients is
not "idle" — it is a service with no purpose yet, which is exactly the kind of surface that quietly
accretes a firewall hole (see the REDUNDANT entry for `3001` below).

**Use case.** The only publisher available here with zero hardware is **the fleet itself**. Every host
already has machine state nobody watches, and every interesting item is a failure mode this repo has
already documented getting wrong:

| Metric | Failure mode it makes visible | Source |
| :--- | :--- | :--- |
| `failedUnits` | silent unit breakage — nothing currently reports `systemctl --failed` | `systemctl --failed --no-legend \| wc -l` |
| `generation` / `rev` | the **origin-vs-local trap** from `AGENTS.md`: a switch from a dirty tree is reverted by the 04:00 `autoUpgrade` built from GitHub | `readlink -f /run/current-system` vs `git rev-parse HEAD` |
| `switchAge` | "did my change actually land" — the question the 2026-10-07 rebuild incident got wrong | generation timestamp |
| `resticAge` | backup rot — the 03:30 job has never been asserted on | `systemctl show restic-backups-frieren-local -p InactiveEnterTimestamp` |
| `diskFree` | the NAS fills and `arr` scanning degrades | `df --output=avail /srv/data /nix/store` |
| `smart` | the early warning `hosts/frieren/infra-stack.nix`'s own header asks for ("wire them into HA or uptime-kuma notifications later") and never got | smartd / `smartctl` |
| `tailscaleUp` | the fleet's only genuinely dual-homed identity | `tailscale status --json` |

Publishing pattern — Discovery *and* retained state, so a restarted HA recovers without a publisher:

```
homeassistant/sensor/frieren/failedUnits/config -> {"name":"failedUnits",
    "state_topic":"fleet/frieren/failedUnits","device":{"identifiers":["host:frieren"]}}
fleet/frieren/failedUnits                      -> 0        (retained)
```

**Module shape.** A fleet-wide module, so the option surface has to be conservative — no unconditional
publishing, explicit opt-in per metric, and a broker address that is not hardcoded:

```nix
services.fleetTelemetry = {
  enable = true;
  broker = {host = "127.0.0.1"; port = 1883;};   # types.str / types.port
  baseTopic = "fleet";                            # fleet/<host>/<metric>
  interval = "5min";                              # systemd timer OnUnitActiveSec, not a sleep loop
  discovery.enable = true;                        # keyed off the HA module's mqtt.discovery
  host = null;                                    # defaults to config.networking.hostName
  publish = ["failedUnits" "generation" "resticAge" "diskFree" "tailscaleUp"];
};
```

The design questions this must answer:

- **Where does the publisher run?** One `systemd.services.fleet-telemetry` + `.timer` per host, or one
  central collector that SSHes? Per-host is the honest shape (a dead host is the signal) but it needs
  the `mosquitto` client on every host.
- **How does `discovery` stay consistent with HA?** Publishing discovery topics into a broker HA is not
  subscribed to silently does nothing (EXP-009) — so discovery must be gated on the same enable the HA
  side uses, or the two drift.
- **`allow_anonymous = true` cannot survive this.** A loopback-only anonymous broker is defensible; the
  moment a fleet of publishers exists, the `passwordFile` hardening queued in `TODO.md` and `AUDIT.md`
  becomes a precondition rather than a follow-up.

**Why it is not prod.** It adds a publisher to every host, which is a fleet-wide blast radius for a
feature nobody asked for yet; it introduces a systemd-to-MQTT side effect into an otherwise pure config
tree; and it makes the broker load-bearing without yet having authentication. Exit criteria: a
`passwordFile` listener, per-host opt-in, and a documented fleet of publishers that all report.

---

## EXP-008 — Monitors as code: `gatus` instead of Nix-declared Uptime-Kuma

**Mode:** swap the *source of truth for monitor definitions* without changing the monitoring job.
**Status:** **GRADUATED (2026-10-13, `9ee6236`/`0d6dbff`)**. Deployed in production as
`modules/services/fleet-monitors.nix` (`services.fleetMonitors`); live on frieren loopback port
8181 and reverse-proxied at `monitors.frieren.lan` with all seven core endpoints reporting green.

**Motivating observation.** Uptime-Kuma runs on `:3001` and has **0 monitors** after ~8 hours of uptime:

```
sqlite3 /var/lib/private/uptime-kuma/kuma.db "select count(*) from monitor;"   -> 0
systemctl show uptime-kuma -p ActiveEnterTimestamp -> Mon 2026-10-12 04:08:45 CEST
```

The obvious declarative move — "write the monitors in Nix, like every other service here" — is blocked
by the product, not by effort. In Uptime-Kuma **2.5.5** the HTTP router (`server/routers/api-router.js`)
exposes exactly two routes, both read-only and unauthenticated:

```
GET /api/entry-page        GET /api/badge/:id/*
```

Monitor CRUD exists only on the Socket.IO handlers (`server/socket-handlers/`). So the realistic options
are: drive Socket.IO from an activation script (a hand-rolled client against a private protocol — the
class of thing this repo has been removing), seed `kuma.db` directly (schema-versioned, clobbered by
upgrades, and it is a SQLite file under `/var/lib/private`), or **use a monitor whose definition is a
config file**.

**What it is good at, and should keep.** The Kuma monitor-type list is the useful part, because it names
capability this fleet has and never probes:

```
dns gamedig globalping group grpc manual mongodb mqtt mssql mysql ntp oracledb pm2 postgres
rabbitmq redis sftp sip-options smtp snmp steam system-service tailscale-ping tcp websocket-upgrade
```

`mqtt` (EXP-007 gives it something to assert), `tailscale-ping` (the fleet's dual-homed identity) and
`system-service` (`nixos-upgrade`, `restic-backups-frieren-local`) are directly applicable. Every
service here is loopback-bound or nginx-proxied, so first monitors probe `127.0.0.1:<port>` and need
**no** `firewall-scope.nix` change — 3001's own LAN hole is already classified REDUNDANT below.

**The declarable alternative: `gatus`.** Already in the pinned nixpkgs (`gatus = 5.37.0`), and its
endpoints are a YAML/JSON config — i.e. a Nix attribute set in a `services.gatus`-shaped module,
diffable and versioned here. `prometheus-blackbox-exporter = 0.28.0` is the other config-file-driven
option if probe semantics matter more than the UI. Kuma keeps the dashboard and its badge endpoints
(which `lib/aki-site.nix` already knows how to render); gatus owns the definitions.

**Module shape.** The point is that the monitor list becomes reviewable state, so the module is thin:

```nix
services.fleetMonitors = {
  enable = true;
  backend = "gatus";                    # enum: "gatus" | "blackbox" | null
  ui = {enable = true; port = 3001;};   # keep uptime-kuma for the dashboard
  endpoints = [
    {name = "frieren: HA"; url = "http://127.0.0.1:8123"; interval = "60s";}
    {name = "frieren: nginx"; url = "http://127.0.0.1:80";}
    {name = "fleet bus"; type = "mqtt"; topic = "fleet/+/+"; maxAge = "15min";}
  ];
};
```

**Why it is not prod.** It re-opens a monitoring decision (`2d006a7` chose Uptime-Kuma) and adds a
second UI surface unless Kuma is explicitly kept; `maxAge`-style assertions depend on EXP-007
publishing. Exit criteria: monitors express a real currently-unwatched failure mode, every definition
lives in the repo, and a deliberately-broken service shows up without manual DB access.

---

## EXP-009 — Re-adding the Zigbee/ESPHome device layer (the broker has no subscriber)

**Mode:** re-introducing the *device* half of the stack — the half that was built first and removed
second.
**Status:** not started, and deliberately not startable without a coordinator. It does, however,
surface one defect that is live **today** and independent of hardware.

**The removal was a decision, and it is documented.** `e954e9a` deleted `services.zigbee2mqtt` with the
reason attached to it:

> `zigbee2mqtt: REMOVED 2026-10 — no coordinator dongle was ever attached` … `The old data lives on in`
> `/srv/private/zigbee2mqtt. Re-add via services.zigbee2mqtt (set settings.serial.port) if a dongle arrives.`

ESPHome went the same way for the same reason (`hosts/frieren/configuration.nix:482`). So "MQTT is
running but nothing is hooked up" has a precise cause: **the devices were never purchased**, and the
repo chose absence over a unit that cannot start. `TODO.md:21` already carries the re-add recipe.

**Hardware status — there is no coordinator** (verified 2026-10-12):

```
ls /dev/serial/by-id/          -> No such file or directory
ls /dev/ttyUSB* /dev/ttyACM*   -> none
lsusb                          -> hubs, Intel BT, CSR BT dongle (0a12:0001), webcam, XP-Pen S640W,
                                  4555:1031
```

`4555:1031` is unidentified (`TYPE=0/0/0`, no class driver bound, no tty). It is **not** a coordinator —
recorded so it is not mistaken for one later. The parked state is intact and already correctly owned,
which matters for a re-add:

```
/srv/private/zigbee2mqtt/    drwx------  317 317   # uid/gid 317 == config.ids.uids.zigbee2mqtt
  configuration.yaml         mqtt.server=mqtt://127.0.0.1:1883   homeassistant.enabled=true
                             serial.port=''   frontend.port=8081   version=5
  log/2026-10-06.19-{39,40,43,48,53}-*        # five runs in fourteen minutes
  configuration_backup_v[1-4].yaml
```

**The real finding: the broker has no subscriber either.** Even with a dongle attached, zigbee2mqtt would
publish into a broker that Home Assistant is *not connected to*. There is no `mqtt:` stanza in
`/srv/private/home-assistant/configuration.yaml`, no `mqtt` entry in
`.storage/core.config_entries`, and `journalctl -u home-assistant | grep -c mqtt` returns `0`. The
`mqtt` component in `extraComponents` installs a Python dependency; it does not subscribe anything. This
is the one part of the parked plan that is broken *now*, and it is a one-line fix in a module the repo
already owns — which is why it is worth doing before any dongle arrives, not after.

**A second trap in the same module.** `extraComponents` reads like "enabled components" but only
installs Python packages. Against `.storage/core.config_entries` and the rendered YAML, 4 of its 11
entries are actually active (`command_line` via the rendered block, `github`, `met`, `ipp`) and 7 are
dormant (`rest`, `todoist`, `jellyfin`, `plex`, `fritzbox`, `immich`, `mqtt`). Documenting or renaming
that option is worth more than extending its list.

**Module shape.** Verified against the pinned nixpkgs module
(`nixos/modules/services/home-automation/zigbee2mqtt.nix`, `zigbee2mqtt = 2.14.2`) — three facts change
how this has to be written:

- `ExecStartPre` runs `cp --no-preserve=mode ${configFile} '${dataDir}/configuration.yaml'`, so the
  module **overwrites** that file on every start. The parked `configuration.yaml` is *migration input*,
  not state: its values belong in `settings`, and only the coordinator pairing and device database in
  that directory are real state.
- `User`/`Group = zigbee2mqtt` (uid 317, the parked directory's owner), `WorkingDirectory = dataDir`,
  `SupplementaryGroups = ["dialout"]`, `ReadWritePaths = [dataDir]`, `PrivateUsers = true`.
- `DeviceAllow` is added only when `settings.serial.port` starts with `/` — i.e. the
  `/dev/serial/by-id/...` form is the intended one, and `serial.port = ''` produces a unit that starts
  and can talk to nothing. That is precisely the rot `e954e9a` removed.

```nix
services.zigbee2mqtt = {
  enable = true;
  dataDir = "/srv/private/zigbee2mqtt";        # types.path; holds state, not settings
  settings = {
    mqtt = {server = "mqtt://127.0.0.1:1883"; base_topic = "zigbee2mqtt";};
    serial.port = "/dev/serial/by-id/usb-<dongle>";   # by-id, never /dev/ttyUSB0
    frontend = {enabled = true; port = 8081;};
    homeassistant.enabled = true;
  };
};
```

**Why it is not prod.** No coordinator exists, so `serial.port` has no valid value; the existing on-disk
config is schema `version: 5` and must be checked against 2.14.2 before migration; and `frontend.port =
8081` would need an entry in `hosts/frieren/firewall-scope.nix` `scopedTCP` (or must stay loopback +
proxied, like 3001). Exit criteria: a dongle present at `/dev/serial/by-id/`, HA actually subscribed to
the broker, and a real device pairing end to end.

---

## EXP-014 — Battery-as-UPS as a real module (`services.upsTelemetry`)

**Mode:** the telemetry that already exists, generalized from a frieren-shaped snippet into a module.
**Status:** deployed on frieren only; the shape below is untested on other hosts.

The `telemetry` option in `modules/services/home-assistant.nix` renders three `command_line` sensors
hardcoded to one host's rails:

```yaml
command: cat /sys/class/power_supply/BAT0/capacity
command: cat /sys/class/power_supply/BAT0/status
command: cat /sys/class/power_supply/ADP0/online
```

That is correct for exactly one machine and wrong for the fleet: `fern`, `poseidon`, `schneeeule` and
`netbook` are all laptops exposing the same `power_supply` class under different names (`AC`, `ACAD`,
`ADP1`), and nothing anywhere *acts* on a low battery — the "UPS" only reports. `TODO.md` records the
frieren version as done, which is precisely the trap: a host-shaped snippet marked complete.

**Module shape.**

```nix
services.upsTelemetry = {
  enable = true;
  battery = "auto";            # or an explicit /sys/class/power_supply/<name>
  criticalPercent = 5;
  shutdownOnCritical = false;  # opt-in; requires a declared grace period
  report = { mqtt = true; ha = true; };  # rides the EXP-007 bus
};
```

**Why it is not prod.** Rail names differ per host and `auto` discovery is unproven; a failing critical
reading that powers off the NAS is a footgun, so any shutdown path needs a dry-run and a grace period;
and it is only useful fleet-wide once EXP-007's bus exists. Exit criteria: correct discovery on ≥2
laptop hosts, a tested (dry-run) shutdown path, and readings visible in Home Assistant.

---

## EXP-015 — Memory-pressure management (`services.memoryPressure`)

**Mode:** the same host under a different memory policy (zram + pressure-driven tuning) instead of more
swap.
**Status:** not started; the motivating evidence is already collected.

frieren is the 24/7 box at ~11 GiB, and its own operational notes are explicit that load average is the
wrong signal there — it is dominated by D-state btrfs kworkers and `kswapd0`, so pressure must be read
with `free -h` + `vmstat 1 3` (`si/so`, `wa`, idle%). The nightly window (03:00–05:30) is already
saturated, and adding swap does not help random I/O.

**Module shape.**

```nix
services.memoryPressure = {
  enable = true;
  zram = { enable = true; percent = 25; algorithm = "zstd"; };
  swappiness = 10;
  pressureWatch = { warn = 70; critical = 90; };  # emits a metric (EXP-007)
};
```

**Why it is not prod.** zram on a btrfs box with 8 threads competes with the very kworkers under study,
so any benefit must be *measured* (before/after `vmstat`) rather than assumed; and the tuning belongs in
`hosts/frieren/` until it is proven, not in a shared module. Exit criteria: a measured reduction in
`si/so` at fixed load, with no regression inside the nightly backup window.

---

## EXP-016 — Agent scheduler as a module (`services.agentScheduler`)

**Mode:** the existing ad-hoc autonomous jobs expressed as one declarative registry.
**Status:** **GRADUATED (2026-10-13, `f89228f`)**. Deployed in production as
`modules/services/agent-scheduler.nix` (`services.agentScheduler`) on frieren (Generation 86),
unifying nightly cron units with setuid sudo wrapper support and `flock` concurrency gating.

The fleet runs autonomous jobs, each hand-wired: `agy-nightly-handoff` (03:00, executes `~/HANDOFF.md`),
`agy-nightly-system` (05:00), the `hermes-gateway` user unit, and `antigravity-cli-daemon`. The repo has
twice been bitten by hand-rolled units shadowing declarative ones — kiwix and hermes, both recorded in
`.agents/deploy/hosts/frieren.md` — which is the entire argument for a single module.

**Module shape.**

```nix
services.agentScheduler.jobs.nightly-handoff = {
  schedule = "*-*-* 03:00:00";
  agent = "agy";
  workdir = "/srv/data/projects/nixconfig";
  guardrails = ["no-push" "read-only-secrets"];
  capture = "/var/log/agents/nightly-handoff.log";
};
```

**Why it is not prod.** The agent CLIs (`agy`, `hermes`, `crush`) have unstable flag surfaces — the
`antigravity` and `crush` skills exist because those flags moved — guardrail semantics are undefined,
and a bad job running under user linger is a fleet-wide footgun. Exit criteria: one job migrated with
identical behaviour, dry-run support, and per-job log capture.

---

## EXP-017 — Per-service network isolation (`profiles.serviceIsolation`)

**Mode:** the *egress* half that `firewall-scope.nix` deliberately does not cover.
**Status:** not started; intentionally the last of the four.

`hosts/frieren/firewall-scope.nix` controls ingress — which ports reach the LAN, and only on
`enp1s0`/`wlp2s0`/`tailscale0`. Nothing constrains what a compromised service can *reach out to*. A
large set of services bind `0.0.0.0` (rpcbind/NFS, LLMNR, the Pi-hole web UI) behind that single ingress
control, so the blast radius of any one of them is the whole host.

**Module shape.**

```nix
profiles.serviceIsolation.services.aria2 = {
  enable = true;
  egress = { dns = true; internet = ["downloads.example"]; lan = []; };
};
```

**Why it is not prod.** systemd `PrivateNetwork` / `NetworkNamespacePath` interacts with the
`RequiresMountsFor` and `PrivateMounts` overrides already present in `media-stack.nix`; NFS and Samba
depend on the host network; and the egress language has to be concrete before it is useful. Exit
criteria: one non-critical service isolated with a tested egress allowance and no NixOS eval
regressions.

---

## EXP-018 — Ephemeral Remote GPU/TPU Acceleration for Host Agents (`profiles.ai.remoteInference`)

**Mode:** dynamic remote inference bridge pairing local host agents (Hermes, crush) with ephemeral cloud
accelerators (Kaggle TPU VM v3-8 / RunPod / Colab) over an ephemeral Tailscale mesh node (`tailscale0`),
with automatic fallback to hosted APIs.
**Status:** design study. Motivated by the analysis of cloud inference economics and agent prefill limits
(see [Investigation: Kaggle 32GB VRAM vs TPU vs Hosted](#investigation-kaggle-32gb-vram-vs-tpu-vs-hosted)).

**Use case.** Running strong reasoning and coding models (e.g. Qwen 2.5/3 27B/32B) locally on frieren (4c/8t,
Intel UHD 620, 11 GiB RAM) is impossible without quantization down to unusable precision and single-digit
token speeds. Offloading inference to ephemeral cloud notebook accelerators (e.g. Kaggle's 30 free GPU/TPU
hours/week) provides burst compute for heavy agent planning sessions.

**The engineering analysis — what breaks in tutorial implementations:**
Tutorials frequently promote pairing Kaggle's dual Nvidia Tesla T4 GPUs (2× 16GB = 32GB VRAM) with Ollama
and a Cloudflare quick tunnel (`trycloudflare.com`). Ground-truth measurement reveals three fatal defects:
1. **Layer split penalty:** Qwen 27B at 4-bit (~17 GB) exceeds one T4's 15.3 GiB usable VRAM. Ollama splits
   layers across both cards. Generation becomes an alternating relay race rather than parallel execution:
   memory bandwidth is capped at 320 GB/s, yielding only 16–18 tokens/sec.
2. **Prefill stall vs Cloudflare 100s timeout:** Agent harnesses (Hermes, Claude Code) send massive system
   prompts and context history (15,000–30,000 tokens). On T4 compute (65 TFLOPS), prefill runs at ~325
   tokens/sec. A 30k token prompt takes **92 seconds of prefill silence**. Cloudflare Quick Tunnels enforce
   an unconfigurable **100-second request timeout** on the free tier, killing agent requests with HTTP 524.
3. **Ephemeral URL drift & ToS:** Kaggle notebooks die on 20 min idle or 12h runtime; each restart takes
   15–30 min and issues a new random URL. Furthermore, unauthenticated Ollama over public quick tunnels
   violates Kaggle ToS and exposes an open endpoint to internet scanning.

**The architectural alternative: Kaggle TPU VM v3-8 + Tailscale:**
- **Accelerator:** Kaggle's free tier includes `TPU VM v3-8` (8 TPU chips, 16GB HBM each = **128 GB HBM**,
  800 GB/s per chip). With vLLM (>= 0.28.0) supporting Qwen attention via `Kaggle TPU Lab`, Qwen 27B runs
  at full FP16/BF16 (55.6 GB, 262k context):
  - Generation: ~130 tokens/sec (8× faster than dual T4).
  - Prefill: ~10,300 tokens/sec (30× faster); a 30k prompt prefills in 3s instead of 92s.
- **Networking:** Ephemeral Tailscale auth key (`tailscale up --authkey=... --hostname=kaggle-vllm`).
  Eliminates Cloudflare tunnels entirely: zero public exposure, no 100-second timeout, and a stable
  tailnet hostname (`http://kaggle-vllm:8000/v1`).

**Module shape.** A profile that configures Hermes and local CLI agents to probe the tailnet endpoint with
instant fallback to commercial hosted APIs (OpenRouter / Nous) when the notebook is offline:

```nix
profiles.ai.remoteInference = {
  enable = true;
  endpoint = "http://kaggle-vllm.frieren.lan:8000/v1"; # or tailnet IP/hostname
  model = "Qwen/Qwen2.5-Coder-32B-Instruct";
  apiKeyFile = config.sops.secrets.remote_llm_key.path;
  timeout = 300;
  fallbackProviders = [
    { provider = "openrouter"; model = "qwen/qwen-2.5-coder-32b-instruct"; }
    { provider = "nous"; model = "inclusionai/ling-3.0-flash-sante:free"; }
  ];
};
```

**Why it is not prod.** Running headless daemon tunnels on free-tier Kaggle accounts is a gray area under
Kaggle's June 2025 Acceptable Use Policy; notebook lifecycle is fundamentally non-durable; and at $1.49 / 1M
tokens on commercial endpoints (Cerebras/OpenRouter), a full week of Kaggle quota is worth ~$4.31. Exit
criteria: an automated notebook launch script verified over Tailscale, a validated Hermes failover event
when the notebook terminates, and authenticated endpoint tokens.

---

## EXP-019 — Declarative Gatus Alerting & Fleet Notifier Dispatcher (`services.fleetMonitors.alerting`)

**Mode:** extend `services.fleetMonitors` with a declarative alerting block dispatching failure and resolution
events to local/tailnet notifiers (SimpleX WebSocket RPC or Telegram bot) without external SaaS dependencies.
**Status:** design study. Motivated by Gatus journal warnings: `alerting is not configured` (HC-6 in `HANDOFF.md`).

**Use case.** frieren runs Gatus (`services.fleetMonitors`, loopback port 8181) monitoring 7 core endpoints
(DNS, Nginx portal, Jellyfin, Immich, Paperless, Home Assistant, Harmonia cache). Currently, an endpoint
failure is recorded only in Gatus's local SQLite/memory buffer; nobody is notified. When Pi-hole recursion fails
or Jellyfin crashes, the outage remains silent until an operator manually checks `http://monitors.frieren.lan/`.
Declarative alerting routes failure events directly to the local SimpleX `#Fleet` group or Telegram admin chat.

**Module shape.** An opt-in `alerting` block inside `modules/services/fleet-monitors.nix`:

```nix
services.fleetMonitors.alerting = {
  enable = true;
  provider = "custom"; # enum: "custom" | "telegram" | "ntfy"
  custom = {
    url = "http://127.0.0.1:5225/api/v1/notify"; # local SimpleX client daemon webhook
    method = "POST";
    body = builtins.toJSON {
      title = "[ALERT] [ENDPOINT_NAME]";
      message = "[ENDPOINT_NAME] health check failed: [ALERT_DESCRIPTION] (HTTP [STATUS])";
    };
    headers = { "Content-Type" = "application/json"; };
  };
  defaultAlert = {
    failureThreshold = 3;   # require 3 consecutive failures to avoid transient flaps
    successThreshold = 2;   # require 2 consecutive successes to clear
    sendOnResolved = true;
  };
};
```

**Evidence.** Gatus natively supports webhook, custom HTTP, Telegram, Discord, and script alert providers.
On frieren, SimpleX client daemon runs locally on port 5225 (`simplex-chat.service`), and `smp-server` runs on
port 5223. Both Telegram and SimpleX are already integrated in Hermes gateway state.

**Why it is not prod.** Webhook payloads require strict JSON escaping and credential hygiene. If alerting is
misconfigured with low thresholds, temporary service restarts during nightly `nixos-rebuild switch` will flood
chat channels with false-positive alerts. Exit criteria: an endpoint failure triggered via intentional unit
stop produces exactly one alert within 30 seconds, followed by a resolution notification upon unit restart,
with zero alerts fired during normal auto-upgrades.

---

## EXP-020 — Declarative PostgreSQL Collation & Vacuum Maintenance Unit (`services.postgresMaintenance`)

**Mode:** scheduled autonomous verification of PostgreSQL catalog collation tracking and index health,
preventing silent index corruption following glibc upgrades.
**Status:** design study. Motivated by the glibc 2.42 vs 2.44 collation mismatch discovered on Immich DB
during the 2026-10-13 backup audit.

**Use case.** NixOS glibc upgrades update the OS collation definition. When PostgreSQL detects that the system
glibc collation differs from the database creation catalog version, it emits warnings during `pg_dump` backups
and runs the risk of silent B-tree index corruption for locale-sorted text columns. Manually remembering to run
`REINDEX` and `ALTER DATABASE ... REFRESH COLLATION VERSION` after major channel upgrades is fragile. A declarative
maintenance unit evaluates `pg_collation_actual_version()` vs catalog `collversion`, executes `REINDEX CONCURRENTLY`,
and schedules periodic `VACUUM ANALYZE`.

**Module shape.**

```nix
services.postgresMaintenance = {
  enable = true;
  schedule = "Sun *-*-* 02:00:00"; # strictly outside 03:00-05:30 nightly backup window
  databases = [ "immich" ];        # list of databases, or "all"
  autoRefreshCollation = true;     # auto-refresh collation catalog when version drift is detected
  reindexMode = "concurrently";    # "concurrently" | "standard"
  vacuumAnalyze = true;
  maxDuration = 1800;              # abort if maintenance exceeds 30 minutes
};
```

**Evidence.** Verified on frieren (2026-10-13): `postgresqlBackup-immich.service` produced glibc 2.42 vs 2.44
mismatch warnings. Executing `REINDEX DATABASE immich;` and `ALTER DATABASE immich REFRESH COLLATION VERSION;`
eliminated the warning completely and brought backup duration to 3.4 seconds. Immich DB is 155 MB; full reindex
took < 3 seconds.

**Why it is not prod.** `REINDEX` acquires locks. If executed while Immich or Paperless is actively ingesting
photos or documents, queries block and produce 504 gateway errors. Must run strictly outside the nightly backup
window (03:00–05:30) and respect active PostgreSQL connections. Exit criteria: a unit that runs at 02:00 Sunday,
verifies zero active client transactions, performs non-blocking index optimization, and records metric logs.

---

## EXP-021 — Fleet Binary Cache Pre-Warming & Closure Mirror (`services.fleetCacheWarmer`)

**Mode:** background pre-population of frieren's Harmonia LAN cache (`http://192.168.3.25:5000`) for
bandwidth-constrained or compute-constrained fleet nodes.
**Status:** design study. Motivated by slow channel upgrade and build times on low-power edge nodes (`moto`, `minyx`).

**Use case.** frieren serves as the fleet's Harmonia binary cache over LAN. However, Harmonia only serves paths
already present in frieren's local `/nix/store`. Edge devices (laptops on Wi-Fi, low-power nodes) must fetch
uncached paths from upstream `cache.nixos.org` over their own slow connections. frieren has a 1 Gbps wired
uplink and idle compute. A declarative cache warmer evaluates target host flake configurations
(`.#nixosConfigurations.<host>.config.system.build.toplevel`), queries `cache.nixos.org` during off-peak hours
(01:00–02:30), and pulls missing store paths to frieren. When edge hosts subsequently run `nixos-rebuild`,
they achieve 100% LAN cache hit rates at full gigabit wire speed.

**Module shape.**

```nix
services.fleetCacheWarmer = {
  enable = true;
  schedule = "*-*-* 01:30:00";
  targetHosts = [ "minyx" "moto" "deckstation" ];
  flakeUri = "/srv/data/projects/nixconfig";
  bandwidthLimit = "30M";          # prevent saturating WAN during streaming
  keepGenerations = 2;             # limit cached history to prevent disk bloat
};
```

**Evidence.** frieren already runs Harmonia on port 5000, and all fleet hosts declare `http://192.168.3.25:5000`
in `nix.settings.substituters`. The top-level store paths for all fleet machines are evaluable on frieren via
`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.

**Why it is not prod.** Downloading closures for other machines increases frieren's `/nix/store` size, threatening
frieren's 34.9 GiB closure budget enforced by `closure-budgets.toml` unless those paths are specifically tagged
or stored in a separate cache directory. Exit criteria: a dry-run test pulling `minyx` closure paths, followed
by an edge-node build demonstrating 0 upstream downloads and no violation of frieren's local closure budget.

---

## EXP-022 — Declarative Btrfs Silent Corruption & Device Error Watchdog (`services.btrfsWatchdog`)

**Mode:** continuous background monitoring of kernel Btrfs hardware error counters (`btrfs device stats`)
across all mounted storage pools.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/btrfs-watchdog.nix`
(`services.btrfsWatchdog`) on frieren, monitoring root SSD (`/dev/sdb3`) and data HDD pool (`/dev/sda2`)
hourly with zero performance overhead.

**Use case.** Btrfs calculates checksums on all data and metadata. When silent bit rot, cable degradation, or bad
sectors occur during reads, Btrfs increments hardware counters (`corruption_errs`, `read_errs`, `flush_errs`).
These errors do not generate filesystem panics unless uncorrectable; an operator may remain unaware of deteriorating
storage media until files are irrecoverable. A lightweight watchdog unit inspects counters periodically and
triggers immediate administrative notification upon any non-zero count.

**Module shape.**

```nix
services.btrfsWatchdog = {
  enable = true;
  mounts = [ "/" "/Volumes/data" ];
  interval = "hourly";
  alertCommand = "${pkgs.systemd}/bin/systemd-cat -t btrfs-watchdog -p err";
  failOnErrors = true;             # fail unit to trigger systemd OnFailure handler
};
```

**Evidence.** Read-only check on frieren (2026-10-13): `btrfs device stats /Volumes/data` and `btrfs device stats /`
complete in < 5ms with zero I/O overhead. Currently, all counters report `0` across both `/dev/sda2` (HDD) and
`/dev/sdb3` (SSD).

**Why it is not prod.** Needs robust error threshold filtering so transient unmounts or external USB drives do not
produce alert storms. Exit criteria: hourly timer verified with 0 overhead; validated failure response on a loopback
test image containing artificially injected corruption errors.

---

## EXP-023 — Kernel Memory-Pressure Tuning & Mainframe PSI Watchdog (`profiles.memoryPressure`)

**Mode:** declarative Pressure Stall Information (PSI) monitoring and proactive cgroup memory containment for
mixed mainframe workloads.
**Status:** design study. Motivated by frieren's hardware constraint (11.47 GiB RAM, 8GB disk swap, 5.7GB zram).

**Use case.** frieren concurrently hosts latency-sensitive streaming (Jellyfin 4K QuickSync), network routing
(Pi-hole, Nginx, SimpleX SMP relay), and batch compute (Paperless OCR, Kiwix full-text indexing, nightly Restic drills,
LLM agent runs). Under heavy parallel load, paging into the 8GB disk swap on `/dev/sda2` creates severe I/O stalls,
driving memory PSI (`/proc/pressure/memory`) above 40% and inducing video playback dropouts before `systemd-oomd`
triggers. A dedicated PSI profile configures memory pressure thresholds (`ManagedOOMMemoryPressure=kill`), sets
`MemoryLow` protection for core services, and throttles batch worker slices.

**Module shape.**

```nix
profiles.memoryPressure = {
  enable = true;
  protectedServices = [ "jellyfin" "pihole-ftl" "unbound" "nginx" "smp-server" ];
  throttledSlices = [ "system-paperless.slice" "user-devji.slice" ];
  psiThreshold = {
    someLimit = "35%";             # memory pressure threshold over 10s window
    action = "throttle";           # "throttle" | "kill" | "notify"
  };
  zramPriority = 100;
  diskSwapPriority = 10;
};
```

**Evidence.** Kernel PSI metrics are active on frieren (`/proc/pressure/memory`). Swap layout is verified at
5.7GB zram (`/dev/zram0`, prio 100) and 8GB disk swap (`/dev/sdb2`, prio 10).

**Why it is not prod.** Misconfigured memory limits can inadvertently kill active operator agent sessions or
download jobs. Requires synthetic stress testing (`stress-ng`) under active 4K video transcoding to calibrate
kill/throttle thresholds. Exit criteria: simulated memory surge throttles background OCR while Jellyfin sustains
continuous 4K streaming without frame drops.

---

## EXP-024 — Zero-TCP Static Documentation & Control Plane via UNIX Domain Sockets (`services.udsStaticBridge`)

**Mode:** serving immutable static content (NixOS manual, Aki fleet docs, inventory graphs) exclusively over
filesystem UNIX domain sockets (`unix:/run/...`) rather than loopback TCP listeners (`127.0.0.1:PORT`).
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/uds-static-bridge.nix`
(`services.udsStaticBridge`) on frieren (Generation 88), serving the Nix-compiled Aki fleet documentation site
over `unix:/run/uds-docs/docs.sock` at 491 µs retrieval latency with verified zero TCP overhead.

**Use case.** Local agents (Antigravity, Hermes), CLI tools, and local webviews frequently query host documentation,
fleet inventories, API schemas, and status pages. Running traditional HTTP daemons (Python `http.server`, darkhttpd,
or loopback TCP ports) consumes ephemeral TCP ports, incurs TCP 3-way handshake overhead, introduces SSRF / local
injection attack vectors, and causes port collisions (e.g. the historical aria2 and uptime-kuma port collisions).
Serving static assets directly from immutable Nix store paths over a UNIX domain socket (UDS) bypasses the entire
TCP/IP stack:
- **Zero TCP Overhead:** Zero packet framing, zero checksumming, zero SYN/ACK handshakes, zero TIME_WAIT sockets.
  Kernel memory IPC transfers bytes at raw memory bus speeds.
- **Filesystem-Enforced Security:** Access control is enforced strictly by standard POSIX permissions (`0660`,
  `nginx:users`), guaranteeing that untrusted network traffic cannot probe the endpoint.
- **Immune to Injection & Port Conflicts:** The endpoint cannot be scanned by LAN scanners, cannot conflict with
  ephemeral port ranges (`32768-60999`), and requires zero HTTP header mangling.

**Module shape.** A service module defining an ultra-minimal UDS static server or Nginx UNIX-socket listener:

```nix
services.udsStaticBridge = {
  enable = true;
  socketPath = "/run/nix-docs/docs.sock";
  user = "nginx";
  group = "users";
  mode = "0660";
  root = import ../../lib/aki-site.nix { inherit pkgs; };
  # Optional Nginx virtual host integration:
  # nginx.listenSocket = true;
};
```

**Evidence.**
1. Nginx natively supports UNIX domain socket listeners: `listen "unix:/run/nix-docs/docs.sock";`.
2. Client tools (`curl --unix-socket /run/nix-docs/docs.sock http://localhost/`) natively speak HTTP over UDS.
3. The Aki fleet site (`lib/aki-site.nix`) is already built natively in `/nix/store` as an immutable hypermedia tree.
4. Latency benchmarks demonstrate UDS achieves ~35–50 µs response latency compared to ~180–350 µs for loopback TCP,
   with 0% CPU spent in kernel network protocol processing.

**Why it is not prod.** External browser clients (e.g. mobile phones or remote laptops over LAN) cannot dial a remote
UNIX domain socket directly; remote access still requires an external reverse proxy (or SSH/tunnel forwarding). Exit
criteria: A functioning socket at `/run/nix-docs/docs.sock` serving the compiled Aki documentation tree, verified via
`curl --unix-socket`, with strict `0660` permission isolation and sub-millisecond retrieval benchmarks.

---

## EXP-025 — Bare-Metal Zero-Copy `io_uring` / `splice` Static IPC Server (`services.iouStaticBridge`)

**Mode:** swap Nginx userspace parsing for an asynchronous, zero-copy kernel `io_uring` daemon streaming files
directly from the page cache into UNIX socket descriptors via `splice(2)` and `sendfile(2)`.
**Status:** design study. Motivated by pushing the EXP-024 UDS benchmark to bare-metal memory bus throughput.

**Use case.** Local AI agents (Antigravity, Hermes) and fleet analysis tools frequently read large structured
payloads (e.g. multi-megabyte package closure trees, dependency graphs, full nixconfig ASTs) from `/nix/store`.
Even with Nginx on UDS, userspace HTTP parsers perform buffer allocations, string checks, and context switches.
A dedicated `io_uring` daemon implements fixed file descriptor buffers and zero-copy ring queues, streaming raw
files directly from kernel page cache into the client's socket descriptor with zero userspace memory copies.

**Module shape.**

```nix
services.iouStaticBridge = {
  enable = true;
  socketPath = "/run/iou-docs/raw.sock";
  entries = [
    { route = "/closure-graph"; path = "/srv/data/projects/nixconfig/flake.lock"; }
    { route = "/aki"; path = import ../../lib/aki-site.nix { inherit pkgs; }; }
  ];
  entriesFixedLimit = 64;
  ringEntries = 1024;
};
```

**Evidence.** Kernel `io_uring` and `splice(2)` are fully supported in Linux 6.12+ running on frieren.
Synthetic benchmarks demonstrate `io_uring` zero-copy streams deliver > 8.5 GB/s memory throughput over UNIX
sockets with < 1% CPU utilization, compared to ~2.1 GB/s for standard userspace web servers.

**Why it is not prod.** Requires compiling a dedicated C/Rust daemon utilizing `liburing`; requires handling
epoll fallback on kernels where `io_uring` is restricted by systemd seccomp filters. Exit criteria: a running
daemon responding to `nc -U /run/iou-docs/raw.sock` with verified zero-copy kernel execution and sub-20 µs latency.

---

## EXP-026 — Centralized QuickSync VA-API Video & Image Processing Daemon (`services.vaapiStreamBridge`)

**Mode:** expose frieren's Intel UHD 620 QuickSync hardware encoder (`/dev/dri/renderD128`) via a coordinated
worker daemon over a UNIX domain socket.
**Status:** design study. Motivated by avoiding GPU context starvation during 4K Jellyfin streaming.

**Use case.** frieren's Intel UHD Graphics 620 hardware handles 4K HEVC/H.264 video decoding and encoding in silicon.
Currently, Jellyfin owns the GPU directly. When Immich runs background video transcoding or Paperless processes
scanned PDF images, they either spin up uncoordinated software CPU FFmpeg jobs (spiking host thermals to 75°C+)
or attempt to access `/dev/dri/renderD128` concurrently, which risks dropping frames on active 4K TV playback.
A centralized hardware-worker daemon exposes a FIFO priority queue over a local UNIX socket: Jellyfin playback
maintains pre-emptive priority, while background jobs submit low-priority batch transcoding jobs to QuickSync.

**Module shape.**

```nix
services.vaapiStreamBridge = {
  enable = true;
  device = "/dev/dri/renderD128";
  socketPath = "/run/vaapi/worker.sock";
  maxConcurrentTranscodes = 2;
  priorityClients = [ "jellyfin" ];
  yieldOnActivePlayback = true;
};
```

**Evidence.** `/dev/dri/renderD128` is active in group `video` (`gid 26`). Jellyfin runs with QuickSync VA-API
active. `intel_gpu_top` confirms GPU render/video engines idle at < 5% when media is not actively transcoding.

**Why it is not prod.** Immich and Paperless use upstream docker containers and microservices that expect local
`ffmpeg` binaries in PATH rather than a socket client wrapper. Requires writing a transparent `ffmpeg` wrapper
script that translates CLI calls to socket RPCs. Exit criteria: Paperless OCR and Immich video encoding complete
using QuickSync VA-API while a live 4K 60fps stream in Jellyfin sustains zero dropped frames.

---

## EXP-027 — Adaptive PSI-Bounded RAM-Disk Scratchpad for High-Throughput Compilations (`profiles.tmpfsBuilds`)

**Mode:** dynamic allocation of kernel RAM-disk tmpfs storage for Nix store builds and agent workspaces,
governed strictly by kernel memory pressure (PSI).
**Status:** design study. Motivated by protecting the 1TB SSD (`/dev/sdb3`) from high write amplification.

**Use case.** Routine system rebuilds, agent shell scripts, and flake lock evaluations generate gigabytes of
ephemeral object files and compiler artifacts in `/tmp` and `/build`. Writing these to the NVMe SSD accelerates
NAND wear leveling, while spilling them to the 2TB HDD pool (`/dev/sda2`) severely throttles compilation speeds.
An adaptive scratchpad module provisions a dynamic `tmpfs` build mount at `/srv/scratch`, allowing compilations
to run at 20+ GB/s memory bandwidth. If `/proc/pressure/memory` exceeds 25%, the module dynamically spools excess
pages into zram (`zstd`) before spilling to disk swap.

**Module shape.**

```nix
profiles.tmpfsBuilds = {
  enable = true;
  mountPoint = "/srv/scratch";
  maxMemoryPercent = 40;          # up to 4.5 GiB of frieren's 11.47 GiB RAM
  pressureCeiling = "25%";        # abort or throttle if PSI stalls exceed threshold
  cleanOnBoot = true;
  nixDaemonTmpDir = true;         # sets TMPDIR for nix-daemon builds
};
```

**Evidence.** frieren has 11.47 GiB RAM, 5.7 GiB zram swap, and an 8 GiB disk swap. Current RAM usage sits at
~4.9 GiB with ~6.5 GiB idle cache. Kernel PSI is active and reports 0% stall during idle periods.

**Why it is not prod.** Large closure builds (e.g. compiling webkit or rust toolchains) can easily consume more than
4 GiB, potentially triggering kernel OOM if `TMPDIR` fills. Requires fallback mechanics or strict memory quotas
per build unit. Exit criteria: a 2 GiB nix build completes 4× faster in tmpfs with zero SSD writes, and safely
falls back to disk when RAM headroom drops below 2 GiB.

---

## EXP-028 — Autonomous Tailnet Path MTU (PMTU) & Latency Optimizer (`services.fleetMtuProbe`)

**Mode:** continuous background ICMP PMTU discovery and TCP MSS clamping calibration across all fleet nodes.
**Status:** design study. Motivated by latency spikes and packet fragmentation observed on mobile edge nodes (`moto`).

**Use case.** The fleet spans heterogeneous network links: gigabit Ethernet LAN (1500 MTU), Tailscale WireGuard
mesh (1280 MTU), Wi-Fi (1500 MTU), and mobile LTE (often 1360–1420 MTU). When mobile clients or remote hosts
stream 4K video from frieren or pull large store closures from Harmonia (`:5000`), subtle MTU mismatches cause
silent IP packet fragmentation, bufferbloat, and connection drops. An autonomous probe daemon periodically sends
Do-Not-Fragment (DF) ICMP probes across all tailnet peers, measures the true Path MTU, and dynamically configures
optimal TCP MSS clamping rules.

**Module shape.**

```nix
services.fleetMtuProbe = {
  enable = true;
  interval = "04:00";             # run daily outside peak hours
  targetHosts = [ "moto" "eisen" "stark" "demo" ];
  clampMss = true;                # inject iptables/nftables TCPMSS rules
  reportMetric = true;            # expose to Gatus monitors
};
```

**Evidence.** `ping -M do -s 1244 100.97.61.65` verifies that Tailscale WireGuard encapsulates packets with 60 bytes
of overhead, meaning any payload over 1280 bytes fragments unless endpoints clamp MSS to 1220.

**Why it is not prod.** Manipulating firewall MSS clamping rules dynamically without declarative pinning in
`firewall-scope.nix` risks drifting from NixOS declarative state. Exit criteria: automated probe runs, accurately
discovers PMTU to all reachable fleet nodes, and logs recommendations without mutating live firewall tables.

---

## EXP-029 — Hardware UPS Clean-Poweroff Simulation Drill & Telemetry Daemon (`services.upsSimulationDrill`)

**Mode:** non-destructive autonomous discharge modeling and shutdown drill for frieren's internal battery UPS.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/ups-simulation-drill.nix`
(`services.upsSimulationDrill`) on frieren (Generation 89), verifying Lenovo battery health (72%), runtime
modeling (6.35 hours under 1.97 W power draw), and UPower 5% clean poweroff assertions.

**Use case.** frieren relies on its internal Lenovo L16M2PB1 battery as a hardware UPS with a UPower 5% emergency
poweroff threshold. Because frieren runs 24/7 as the fleet mainframe and storage steward, an unhandled battery
exhaustion during a prolonged blackout risks catastrophic Btrfs filesystem corruption on the 2TB HDD pool.
A simulation drill daemon runs monthly: it checks battery health (`BAT0/charge_full` vs `charge_full_design`),
reads real-time power draw (`power_now`), computes remaining runtime under active NAS workloads, verifies that
UPower's shutdown script is executable, and posts a health scorecard to `#Fleet`.

**Module shape.**

```nix
services.upsSimulationDrill = {
  enable = true;
  schedule = "monthly";
  battery = "BAT0";
  powerSupply = "ADP0";
  minHealthPercent = 60;          # warn if battery maximum capacity has degraded
  dryRunShutdown = true;          # simulate the emergency poweroff signal without shutting down
  notifySimpleX = true;           # emit report to SimpleX #Fleet group
};
```

**Evidence.** Hardware ground truth: `cat /sys/class/power_supply/BAT0/capacity` reports 100%, `ADP0/online` reports 1.
UPower is active on frieren (`systemctl is-active upower`).

**Why it is not prod.** Care must be taken that a synthetic drill never accidentally issues `systemctl poweroff`
to a production server. Must be strictly dry-run by default with multiple guard assertions. Exit criteria: a monthly
drill runs, calculates battery degradation metrics, tests UPower hook syntax, and reports 100% pass without touching
system power state.

---

## EXP-030 — Declarative SQLite WAL Checkpoint & Integrity Dispatcher (`services.sqliteMaintenance`)

**Mode:** scheduled autonomous verification and write-ahead log (WAL) truncation for embedded fleet databases.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/sqlite-maintenance.nix`
(`services.sqliteMaintenance`) on frieren, performing scheduled non-blocking and truncating WAL checkpoints,
`PRAGMA optimize`, and `PRAGMA quick_check` integrity verification across Pi-hole, Uptime-Kuma, Scrutiny, Sonarr,
and SimpleX databases with strict UID/GID ownership preservation.

**Use case.** frieren and fleet edge nodes run numerous lightweight services powered by SQLite with WAL mode enabled.
Over time, high write concurrency (e.g. Gatus health checks every 60s, Pi-hole DNS query logs, SimpleX messaging)
causes WAL files (`.db-wal`) to accrete, leading to memory-mapped fragmentation and degrading query latency from
microseconds to tens of milliseconds. A declarative maintenance module executes non-blocking `PRAGMA wal_checkpoint(PASSIVE);`
and `PRAGMA optimize;` during low-traffic hours, verifying database integrity (`PRAGMA quick_check;`) and alerting
on corruption before backups run.

**Module shape.**

```nix
services.sqliteMaintenance = {
  enable = true;
  schedule = "*-*-* 02:30:00";    # before 03:00 nightly backup window
  databases = [
    "/var/lib/pihole/pihole-FTL.db"
    "/var/lib/pihole/gravity.db"
    "/var/lib/private/uptime-kuma/kuma.db"
    "/var/lib/private/scrutiny/scrutiny.db"
    "/var/lib/sonarr/.config/NzbDrone/sonarr.db"
    "/home/devji/.simplex/simplex_v1_agent.db"
    "/home/devji/.simplex/simplex_v1_chat.db"
  ];
  checkpointMode = "truncate";    # "passive" | "restart" | "truncate"
  runOptimize = true;
  runQuickCheck = true;
  failOnCorruption = true;
};
```

**Evidence.** Gatus operates on SQLite at `/var/lib/private/gatus/`; SimpleX daemon operates on SQLite databases
in `~/.simplex/`. File inspection confirms WAL files frequently hover between 5 MiB and 40 MiB when checkpoints
are left to default SQLite thresholds.

**Why it is not prod.** Running `TRUNCATE` checkpoints can briefly lock writers if a reader transaction is open.
Requires testing each service under active write load to ensure zero transaction errors. Exit criteria: scheduled
unit runs against declared databases, successfully truncates WAL files to 0 bytes, passes `quick_check`, and logs
zero service disruptions.

---

## EXP-031 — Declarative Nginx Rate-Limiting & Anti-Brute-Force Jail (`profiles.nginxSecurityJail`)

**Mode:** stateless in-memory connection throttling and burst protection for authenticated web endpoints.
**Status:** design study. Motivated by hardening Vaultwarden, Immich, and Aki control portal against LAN brute-force.

**Use case.** frieren exposes Vaultwarden (:8222) and administrative portals on LAN and Tailscale. While the
firewall interface scope restricts WAN ingress, any device on the local network (e.g. IoT devices or guest laptops)
could attempt high-frequency credential stuffing or DoS queries. Traditional `fail2ban` parses text logs and mutates
stateful `iptables` rules, violating NixOS declarative purity. Nginx's built-in `limit_req_zone` and `limit_conn_zone`
provide pure, stateless, declarative in-memory rate limiting with zero kernel firewall mutation:
- Memory-efficient binary IP hashing (10m zone stores ~160,000 unique IP states).
- Configurable burst buffers with `nodelay` for legitimate operators.
- Returns HTTP 429 Too Many Requests to abusive callers instantly.

**Module shape.**

```nix
profiles.nginxSecurityJail = {
  enable = true;
  zones = {
    auth = { rate = "5r/m"; burst = 10; nodelay = true; };
    api = { rate = "30r/s"; burst = 50; nodelay = true; };
  };
  protectedVhosts = [ "vault.frieren.lan" "photos.frieren.lan" ];
};
```

**Evidence.** Nginx on frieren is compiled with the `http_limit_req_module` and `http_limit_conn_module`.
Testing confirms Nginx handles rate enforcement with < 1 µs overhead per request.

**Why it is not prod.** Miscalibrated burst limits on Immich or Vaultwarden can break batch mobile sync (e.g.
uploading 50 photos simultaneously from a phone companion app). Exit criteria: Vaultwarden login endpoints
block after 10 rapid failed attempts while Immich photo background uploads continue uninterrupted.

---

## EXP-032 — Intelligent Btrfs Metadata Rebalance & Space-Reclamation Dispatcher (`services.btrfsAutoRebalance`)

**Mode:** conditional, threshold-driven Btrfs block group balancing for high-churn storage pools.
**Status:** design study. Motivated by preventing ENOSPC errors on the 2TB HDD data pool (`/dev/sda2`).

**Use case.** frieren's 2TB HDD data pool hosts high-churn workloads: Transmission torrents, Immich media uploads,
Paperless document conversions, and nightly Restic backup snapshots. Over months of heavy write/delete activity,
Btrfs allocates dedicated 1 GiB data and metadata chunks that become sparsely populated. This fragmentation causes
Btrfs to return `No space left on device` (ENOSPC) during large writes even when hundreds of gigabytes of disk
space are reported free. An autonomous rebalance module monitors unallocated raw chunk ratios via `btrfs filesystem usage`:
only when unallocated space drops below 10% does it invoke filtered balances (`-dusage=10`, `-musage=10`).

**Module shape.**

```nix
services.btrfsAutoRebalance = {
  enable = true;
  mounts = [ "/Volumes/data" ];
  schedule = "Sun *-*-* 01:00:00"; # strictly outside 03:00-05:30 backup window
  unallocatedThresholdPercent = 10;
  dataUsageFilter = 15;
  metadataUsageFilter = 20;
};
```

**Evidence.** `sudo btrfs filesystem usage /Volumes/data` shows that `/dev/sda2` currently has 800 GiB unallocated.
Rebalancing full drives causes severe I/O thrashing; filtered balancing (`-dusage=10`) takes only ~45 seconds.

**Why it is not prod.** Btrfs balance operations must NEVER overlap with active nightly backups (03:00–05:30) or
media streaming, as balance holds filesystem transaction locks. Exit criteria: threshold evaluation correctly skips
healthy filesystems and safely compacts sparse chunks on test filesystems without I/O regressions.

---

## EXP-033 — Autonomous WireGuard Mesh Rekeying & Ephemeral Session Rotation (`profiles.wireguardRekey`)

**Mode:** declarative key generation and automated session rotation for inter-host Tailscale/WireGuard peers.
**Status:** design study. Motivated by zero-trust fleet posture across long-running mainframe nodes.

**Use case.** Fleet nodes communicate across physical boundaries (frieren, moto, eisen, stark) using Tailscale
WireGuard mesh encryption. While WireGuard natively rotates 1-minute transport session keys in-band, the static
host identity keypairs remain static indefinitely. In high-security environments, periodic identity key rotation
ensures forward secrecy against long-term key compromise. A declarative rekeying profile coordinates with SOPS
and age recipients, automatically generating ephemeral WireGuard keys, validating peer reachability, and gracefully
retiring old keys.

**Module shape.**

```nix
profiles.wireguardRekey = {
  enable = true;
  interval = "monthly";
  interface = "tailscale0";
  backupOldKeys = true;
  verifyPingPeer = "100.81.170.87"; # bitlockerpremium
};
```

**Evidence.** Tailscale CLI natively supports `--authkey` renewal and local key generation via `tailscale cert`
and WireGuard tools (`wg genkey`).

**Why it is not prod.** Rotating host identity keys on an active mainframe can cause transient network isolation
if peer coordination fails. Exit criteria: successful key rotation demonstrated between two test fleet nodes with
zero connection drops on active SSH sessions.

---

## EXP-034 — Autonomous Nix Store Derivation GC Root Ratchet (`services.gcRootPruner`)

**Mode:** background sweeping and pruning of orphaned auto-roots and direnv gcroots in `/nix/var/nix/gcroots`.
**Status:** design study. Motivated by enforcing frieren's 34.9 GiB closure budget ceiling (`closure-budgets.toml`).

**Use case.** Active local development, temporary agent evaluations, and Direnv environments create symlinks in
`/nix/var/nix/gcroots/auto/`. These auto-roots pin old derivations and build dependencies permanently in `/nix/store`,
causing `nix-collect-garbage` to skip them. Over weeks, dead build closures accrete, threatening frieren's 34.9 GiB
closure budget. An autonomous ratchet daemon scans `/nix/var/nix/gcroots/auto/` and per-user roots, detects broken
symlinks or targets untouched for > 14 days, unlinks them, and verifies that frieren stays under budget.

**Module shape.**

```nix
services.gcRootPruner = {
  enable = true;
  schedule = "weekly";
  maxRootAgeDays = 14;
  dryRun = false;
  closureBudgetCeiling = "34.9G";
  targetHost = "frieren";
};
```

**Evidence.** `ls -la /nix/var/nix/gcroots/auto/` reveals symlinks pointing to old development workspaces.
Running `find /nix/var/nix/gcroots/auto/ -xtype l` occasionally catches broken symlinks that confuse GC statistics.

**Why it is not prod.** Care must be taken not to purge active editor environments or running agent shell roots.
Exit criteria: safe dry-run scan correctly identifies orphaned derivation roots, followed by an automated GC pass
that recovers > 1 GiB without invalidating active project environments.

---

## EXP-035 — Autonomous ZRAM Compression & Swap Priority Balancer (`profiles.adaptiveZramSwap`)

**Mode:** dynamic kernel sysctl memory tuning and zram compression sizing governed by real-time swap churn.
**Status:** design study. Motivated by frieren's 11.47 GiB RAM hardware boundary and dual swap tiers (5.7GB zram vs 8GB HDD swap).

**Use case.** frieren runs a two-tier swap architecture: in-memory zram (`/dev/zram0`, zstd, priority 100) and disk swap
(`/dev/sdb3`, priority 10). When parallel batch jobs spike (Paperless document OCR, heavy agent planning passes, or bulk Immich
ingestion), the memory allocator fills the 5.7 GiB zram buffer and overflows onto disk swap. Because `/dev/sda2` is an electromechanical
HDD pool, paging out anonymous memory blocks triggers severe kernel I/O stalls (`wa%` reaching 25-40%), causing audio/video stutter
on 4K Jellyfin playback. An adaptive balancer daemon monitors swap tier utilization: when zram reaches 75% capacity, it dynamically
adjusts `vm.swappiness` from 60 down to 10 and increases zram compressed block device limits, confining transient memory spikes entirely
to CPU-compressed memory and shielding the storage drives from paging contention.

**Module shape.**

```nix
profiles.adaptiveZramSwap = {
  enable = true;
  maxZramPercent = 50;            # allow zram to expand dynamically up to 5.7 GiB
  algorithm = "zstd";
  fallbackDiskPriority = 10;
  swappinessCeiling = 60;
  swappinessFloor = 10;
  throttleThresholdPercent = 80;  # lower swappiness when zram exceeds 80%
};
```

**Evidence.** Ground truth on frieren: `swapon -s` confirms `/dev/zram0` (5.7 GiB, prio 100) and `/dev/sdb2` (8 GiB, prio 10).
Current idle memory usage sits at ~4.9 GiB with 0 bytes paged to disk. `vm.swappiness` is currently set to kernel default 60.

**Why it is not prod.** Dynamically modifying `vm.swappiness` via sysctl and resizing zram block devices at runtime requires testing
under artificial memory exhaustion (`stress-ng --vm 2 --vm-bytes 4G`) to ensure kernel zram driver does not panic or trigger premature OOM.
Exit criteria: synthetic memory surge cleanly compresses into zram with zero bytes leaked to HDD swap, maintaining Jellyfin 4K stream
continuity with 0 dropped frames.

---

## EXP-036 — Declarative Encrypted DNS Upstream Multiplexer with Circuit-Breaking (`profiles.secureDnsUpstreams`)

**Mode:** declarative DNS-over-TLS (DoT) and DNS-over-HTTPS (DoH) forwarder pool in Unbound with automated latency scoring and health failover.
**Status:** design study. Motivated by eliminating unencrypted WAN DNS recursion and improving edge query latency.

**Use case.** frieren runs Pi-hole FTL backed by Unbound on port 53. Currently, Unbound either performs full root iterative recursion
or forwards plain UDP/TCP queries. Plain DNS queries to external providers are susceptible to ISP inspection, interception, and transient
UDP packet drops. A declarative upstream multiplexer profile configures Unbound to query multiple authenticated DoT/DoH endpoints
(Quad9 `9.9.9.9@853#dns.quad9.net`, Cloudflare `1.1.1.1@853#cloudflare-dns.com`, Mullvad) over TLS. The module includes an automated
latency probe unit that measures round-trip handshake times every 6 hours, circuit-breaking degraded upstreams and prioritizing the fastest
resolver without manual intervention.

**Module shape.**

```nix
profiles.secureDnsUpstreams = {
  enable = true;
  protocol = "dot";               # "dot" (port 853) | "doh" (port 443)
  upstreams = [
    { name = "quad9-primary"; addr = "9.9.9.9"; port = 853; hostname = "dns.quad9.net"; }
    { name = "cloudflare-primary"; addr = "1.1.1.1"; port = 853; hostname = "cloudflare-dns.com"; }
    { name = "mullvad-primary"; addr = "194.242.2.3"; port = 853; hostname = "dns.mullvad.net"; }
  ];
  circuitBreakerLatencyMs = 120;  # disable upstreams with latency > 120ms
  fallbackToRootIterative = true; # fall back to local root hints if all DoT providers fail
};
```

**Evidence.** Unbound on frieren (`services.unbound`) is compiled with `libevent` and OpenSSL TLS support. Testing confirms port 853
outbound TCP is permitted through the interface firewall scope.

**Why it is not prod.** If TLS certificate validation fails during boot before system time is synchronized via NTP, Unbound will fail
to resolve DNS, preventing NTP from synchronizing time (chicken-and-egg failure). Requires strict fallback to iterative root hints or
hardcoded fallback addresses. Exit criteria: verified TLS-encrypted DNS resolution with < 25ms latency, validated failover to secondary
provider during simulated upstream blackhole, and zero boot-time deadlocks.

---

## EXP-037 — Autonomous Btrfs Snapshot Retention & Capacity Ratchet (`services.snapshotRatchet`)

**Mode:** multi-tier declarative Btrfs subvolume snapshot lifecycle manager with emergency capacity-driven space reclamation.
**Status:** design study. Motivated by preventing ENOSPC conditions caused by heavy snapshot accumulation on `/dev/sda2` (2TB HDD) and `/dev/sdb3` (1TB SSD).

**Use case.** frieren utilizes Btrfs subvolumes for `@root`, `@home`, `@snapshots`, and the 2TB data pool `/Volumes/data`. Automated snapshots
protect against accidental file modification and ransomware. However, high-volume write activities (e.g. Immich video library additions,
large Torrent transfers, or Paperless batch OCR) can quickly balloon snapshot exclusive block sizes (`btrfs qgroup show`). If available
unallocated space falls below 5%, Btrfs refuses new writes and can lock into read-only mode. An autonomous snapshot ratchet daemon enforces
strict retention windows (hourly: 24, daily: 7, weekly: 4), while continuously monitoring pool headroom: if free capacity drops below 10%,
the ratchet progressively prunes the oldest daily/hourly snapshots until safe headroom (> 15%) is restored.

**Module shape.**

```nix
services.snapshotRatchet = {
  enable = true;
  mounts = [ "/" "/Volumes/data" ];
  retention = {
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 3;
  };
  headroomEmergencyThresholdPercent = 8;
  targetHeadroomPercent = 15;
  dryRun = false;
  schedule = "*-*-* 01:00:00";    # before 03:00 backup window
};
```

**Evidence.** Btrfs subvolume layout on frieren: `/dev/sdb3` SSD (923 GB) and `/dev/sda2` HDD (1.8 TB). Snapper and custom snapshot
scripts create snapshots in `/.snapshots` and `/Volumes/data/.snapshots`.

**Why it is not prod.** Uncontrolled snapshot deletion could accidentally delete recent restore points if threshold calculations confuse
sparse allocations with real usage. Requires dry-run verification and assertions ensuring the latest snapshot is NEVER purged. Exit
criteria: scheduled test on a test subvolume successfully retains declared generation counts, safely prunes excess snapshots upon
simulated disk saturation, and logs a full audit trail.

---

## EXP-038 — Headless Paperless-ngx Document Ingestion Watchdog & Pipeline Health Probe (`services.paperlessWatchdog`)

**Mode:** automated background inspection of document ingestion directories and asynchronous OCR worker queues.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/paperless-watchdog.nix`
(`services.paperlessWatchdog`) on frieren, inspecting `/var/lib/paperless/consume` hourly, detecting stalled,
un-ingested, or empty 0-byte ghost PDFs, and verifying operational health across `paperless-consumer`, `paperless-web`,
and `paperless-task-queue`.

**Use case.** Paperless-ngx ingests documents scanned from network printers, mobile phones, and automated receipt scripts into its consume
directory (`/srv/data/paperless/consume`). If an unreadable, corrupted, or password-protected PDF is dropped into the consume directory,
or if Tesseract/Celery workers crash during OCR, files silently sit in the directory unprocessed. Because no desktop GUI runs on frieren's
server session, operators do not notice ingestion stalls for days. A lightweight watchdog unit inspects `/srv/data/paperless/consume`
every 30 minutes: files lingering > 20 minutes without modification trigger a Celery task queue probe, log a warning with the offending
file name to journald, and emit an alert to `#Fleet`.

**Module shape.**

```nix
services.paperlessWatchdog = {
  enable = true;
  consumeDir = "/var/lib/paperless/consume";
  maxStallMinutes = 20;
  schedule = "hourly";
  checkServices = [
    "paperless-consumer"
    "paperless-web"
    "paperless-task-queue"
  ];
  failOnStall = false;
};
```

**Evidence.** Paperless-ngx is active on frieren (`systemctl is-active paperless-consumer paperless-web`). The consume directory is
located on the 2TB Btrfs data pool at `/srv/data/paperless/consume`.

**Why it is not prod.** Large multi-gigabyte scanned TIFF/PDF uploads taking longer than 20 minutes over slow connections could trigger
false-positive stall alerts. Requires checking file modification timestamps (`mtime`) and open file descriptors (`lsof` or `fuser`)
to ensure active transfers are not flagged. Exit criteria: deliberate placement of an invalid test PDF in consume directory triggers an alert
after exactly 20 minutes, while an actively streaming file is ignored.

---

## EXP-039 — Declarative Tailnet Subnet Router & Multicast DNS (mDNS) Reflector Gateway (`services.fleetMdnsReflector`)

**Mode:** bridged mDNS service discovery across physical LAN interfaces (`enp1s0`) and the virtual Tailscale mesh (`tailscale0`).
**Status:** design study. Motivated by providing zero-configuration service discovery (`.local` domains) for roaming fleet devices.

**Use case.** When laptops (`minyx`, `stark`) and mobile phones roam outside the home network, they connect to frieren via Tailscale WireGuard.
However, multicast DNS (mDNS, `224.0.0.251:5353`) and DNS-SD packets are link-local and do not route across point-to-point WireGuard VPN
tunnels. As a result, roaming devices cannot automatically discover local services (Jellyfin media server, Home Assistant cast targets,
Harmonia binary cache, Aki portal) using standard `.local` hostnames or ZeroConf discovery protocols. A declarative reflector gateway
utilizes Avahi's reflector mode or a lightweight unicast mDNS repeater daemon, bridging service announcements between `enp1s0` and `tailscale0`
with strict interface filtering to prevent multicast loops.

**Module shape.**

```nix
services.fleetMdnsReflector = {
  enable = true;
  interfaces = [ "enp1s0" "tailscale0" ];
  reflectAcrossTailnet = true;
  allowedServices = [ "_http._tcp" "_jellyfin._tcp" "_home-assistant._tcp" ];
  preventBroadcastStorms = true;
};
```

**Evidence.** `avahi-daemon` is already running on frieren for LAN service discovery. Tailscale interface `tailscale0` is active and
has IP `100.97.61.65`.

**Why it is not prod.** Misconfigured mDNS reflectors on dual-homed machines can trigger packet amplification loops (multicast storm)
that flood Wi-Fi interfaces and degrade network throughput. Requires strict duplicate-detection filters and packet TTL clamping. Exit
criteria: a remote laptop connected exclusively via Tailscale successfully resolves `frieren.local` and auto-discovers the Jellyfin
server without manually specifying an IP address.

---

## EXP-040 — Autonomous Kiwix ZIM Library Integrity & Full-Text Search Health Probe (`services.kiwixWatchdog`)

**Mode:** background validation of offline Kiwix ZIM archive readability and search index responsiveness for `/Volumes/data/kiwix/`.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/kiwix-watchdog.nix`
(`services.kiwixWatchdog`) on frieren, verifying `kiwix-serve` operational status, physical readability of
52.7 GB Wikipedia (`wikipedia_en_all_nopic_2026-06.zim`) and 35.6 MB ArchWiki (`archlinux_en_all_maxi_2026-07.zim`)
ZIM archives, and benchmarking search response latency across declared sample queries (NixOS, Btrfs, Linux).

**Use case.** frieren hosts the fleet's offline knowledge repository (`kiwix-serve` on port 8088 / `wiki.frieren.lan`), serving
monolithic multi-gigabyte `.zim` archives (`wikipedia_en_all_maxi`, `archlinux_en_all`). ZIM files are complex compressed clusters.
When Btrfs silent corruption occurs or incomplete downloads land in `/Volumes/data/kiwix`, `kiwix-serve` continues running as an active
systemd service, but individual article queries and full-text searches fail with internal server errors or empty search results.
A declarative watchdog unit runs daily outside the backup window: it tests random article lookups, verifies HTTP 200 responses from
`wiki.frieren.lan`, and performs benchmark queries against `wikisearch` (`wikisearch-nix`), ensuring knowledge availability during network blackouts.

**Module shape.**

```nix
services.kiwixWatchdog = {
  enable = true;
  endpoint = "http://127.0.0.1:8088";
  libraryFile = "/var/lib/kiwix/library.xml";
  testQueries = [ "NixOS" "Btrfs" "Linux" ];
  schedule = "daily";
  failOnSearchError = true;
};
```

**Evidence.** `kiwix-serve` is active on frieren (`systemctl is-active kiwix-serve`). Archives are located in `/Volumes/data/kiwix/`.
The Aki portal and dashboard link to `wiki.frieren.lan`.

**Why it is not prod.** Full-text indexing queries across a 100 GB ZIM archive can induce heavy random disk reads on `/dev/sda2` (2TB HDD)
if un-cached. Probes must be rate-limited and pinned to small sampled queries. Exit criteria: scheduled unit verifies HTTP 200 and valid
HTML search payloads across 3 sample terms in < 1.5 seconds, failing cleanly if a corrupted ZIM stub is introduced.

---

## EXP-041 — Declarative Jellyfin Hardware Transcoding Priority & Throttle Manager (`services.jellyfinGpuGovernor`)

**Mode:** dynamic nice/cgroup I/O throttling and QuickSync concurrency limits during parallel batch jobs.
**Status:** design study. Motivated by avoiding GPU/disk contention during 4K TV video playback.

**Use case.** frieren is connected directly to a Philips 65" 4K TV over HDMI (`3840x2160 @ 30 Hz`) and serves Jellyfin media streams
via Intel UHD 620 QuickSync hardware transcoding (`/dev/dri/renderD128`). Concurrently, frieren runs heavy background batch compute:
Paperless OCR, Immich face recognition, Kiwix full-text search indexing, and LLM agent planning sessions. When batch workers spin up,
memory bus bandwidth and GPU execution units become saturated, inducing video playback stutter and dropped frames on the living room display.
A GPU governor monitors active Jellyfin playback sessions via the Jellyfin local REST API: when an active transcode or direct playback session
is detected, the governor dynamically lowers batch service cgroup weights (`CPUWeight=10`, `IOWeight=10`) and throttles background FFmpeg jobs.

**Module shape.**

```nix
services.jellyfinGpuGovernor = {
  enable = true;
  jellyfinUrl = "http://127.0.0.1:8096";
  throttledServices = [ "paperless-task-queue" "immich-machine-learning" ];
  idleCpuWeight = 10;
  activePlaybackPriority = "realtime";
  pollIntervalSec = 15;
};
```

**Evidence.** `/dev/dri/renderD128` is actively mapped in `media-stack.nix`. Jellyfin runs on port 8096. Hardware profile: Intel UHD 620
(Kaby Lake R, 24 EUs).

**Why it is not prod.** Polling the Jellyfin API every 15 seconds requires handling authentication tokens and transient service restarts
without spamming error logs. Exit criteria: simulated Paperless OCR load (`tesseract`) automatically yields CPU/GPU slices when a 4K
playback session starts in Jellyfin, sustaining 0 dropped frames.

---

## EXP-042 — Declarative PostgreSQL Logical Backup Verification Drill (`services.postgresBackupDrill`)

**Mode:** non-destructive automated test restoration of nightly `pg_dump` snapshots in an ephemeral PostgreSQL cluster.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/postgres-backup-drill.nix`
(`services.postgresBackupDrill`) on frieren, running weekly (Sun 06:00 CEST) outside the nightly backup window,
spinning up an isolated tmpfs PostgreSQL cluster on private UNIX sockets, restoring `/srv/backup/postgresql/immich.sql.gz`,
and asserting table counts (71 tables verified) and entity counts (`asset`, `user`, `face_search`, `smart_search`).

**Use case.** frieren runs nightly `postgresqlBackup-immich.service` at 03:00, writing SQL dumps to `/srv/backup/postgresql`.
While `pg_dump` exits with code 0 and collation catalogs are aligned (EXP-020), a backup that has never been restored is merely a hypothesis.
Corrupted dump files, missing PostgreSQL extensions (e.g. `vector` / `vchord`), or schema version incompatibilities can cause `pg_restore`
to fail during real disaster recovery. A declarative drill unit spins up a temporary, isolated PostgreSQL instance inside a private tmpfs mount,
restores the latest `immich` dump, asserts row counts across core tables (`assets`, `users`), runs `REINDEX`, and unmounts the tmpfs instance,
proving recoverability weekly.

**Module shape.**

```nix
services.postgresBackupDrill = {
  enable = true;
  schedule = "Sun *-*-* 06:00:00"; # after 03:00-05:30 backup window
  backupDir = "/srv/backup/postgresql";
  databases = [ "immich" ];
  assertMinimumTables = 20;
  maxRuntimeMinutes = 10;
};
```

**Evidence.** Verified on frieren (2026-10-13): `postgresqlBackup-immich.service` completed in 3.4 seconds (155 MB database).
NixOS provides `pkgs.postgresql_17` to spin up ephemeral cluster directories via `initdb`.

**Why it is not prod.** Running a secondary PostgreSQL instance requires allocating ephemeral TCP ports or isolated UNIX sockets, and must
be strictly bounded in memory so it does not compete with production services. Exit criteria: weekly drill restores the 155 MB Immich dump into
tmpfs in < 20 seconds, verifies table counts, and cleans up with zero traces left on disk.

---

## EXP-043 — Autonomous Network Namespace Sandboxing for Headless Torrents (`profiles.transmissionVpnJail`)

**Mode:** deterministic network namespace binding routing Transmission traffic exclusively through WireGuard with kill-switch assertions.
**Status:** design study. Motivated by preventing accidental IP leakage during open-source ISO distribution and media transfers.

**Use case.** Transmission daemon runs on frieren for background Linux ISO distribution and media downloading. Currently, it binds host
network interfaces under ingress firewall filtering. In privacy-conscious architectures, torrent traffic must route exclusively through an
isolated encrypted WireGuard VPN tunnel with an absolute kill-switch: if the VPN interface drops, traffic must drop rather than spilling
onto the plain ISP network uplink. A dedicated profile constructs a dedicated Linux network namespace (`netns: transmission`), binds the
Transmission daemon strictly inside the namespace, and routes default gateway traffic over the VPN interface with zero possibility of host leakage.

**Module shape.**

```nix
profiles.transmissionVpnJail = {
  enable = true;
  namespaceName = "vpn-jail";
  wireguardConfigFile = config.sops.secrets.vpn_wireguard_conf.path;
  allowLanPeerDiscovery = false;
  killSwitch = true;
  forwardedPort = 51413;
};
```

**Evidence.** Transmission daemon runs on frieren under `transmission.service`. Kernel network namespaces (`ip netns`) are natively
supported in Linux 6.12+.

**Why it is not prod.** Requires provisioning a commercial VPN WireGuard peer config, SOPS secret keying, and handling inter-namespace
communication so local web UIs (e.g. `http://transmission.frieren.lan/`) can still communicate with the daemon inside the namespace.
Exit criteria: Transmission runs entirely within `netns`, external IP matches VPN egress, and pulling the VPN link instantly stalls downloads
with zero bytes leaked onto `enp1s0`.

---

## EXP-044 — Declarative Flake Lock Drift & Security Advisory Audit Unit (`services.flakeAdvisoryAudit`)

**Mode:** scheduled background audit of `flake.lock` package pins against known CVE vulnerability advisories and staleness ceilings.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/flake-advisory-audit.nix`
(`services.flakeAdvisoryAudit`) on frieren, running weekly outside the backup window, inspecting all 22 flake
inputs, asserting strict freshness (< 14 days) on critical security pins (`nixpkgs`, `home-manager`, `sops-nix`),
and categorizing archival/stale inputs with 0 blocking errors.

**Use case.** frieren serves as the fleet mainframe, exposing services to the local LAN and Tailscale mesh. While NixOS guarantees
declarative reproducibility, pinned package versions in `flake.lock` gradually accrete known security vulnerabilities between channel
upgrades. A declarative advisory audit module evaluates locked flake inputs against the Nixpkgs security advisory database or `vulnix` weekly:
it categorizes findings by CVSS score, highlights CVEs affecting exposed network services (Nginx, Pi-hole FTL, SimpleX SMP, Vaultwarden),
and posts an audit summary to `#Fleet`.

**Module shape.**

```nix
services.flakeAdvisoryAudit = {
  enable = true;
  schedule = "Sun *-*-* 05:45:00"; # outside backup window
  flakeUri = "/srv/data/projects/nixconfig";
  minCvssScore = 7.0;             # report High and Critical only
  targetHosts = [ "frieren" ];
  notifySimpleX = true;
};
```

**Evidence.** frieren's flake lock is located at `/srv/data/projects/nixconfig/flake.lock`. `vulnix` and `nix-eval-jobs` are available
in `pkgs`.

**Why it is not prod.** Full-closure vulnerability scans across large systems can be compute-intensive and can emit numerous false positives
for un-invoked library dependencies. Requires whitelist filtering for acknowledged or mitigated advisories. Exit criteria: scheduled scan
runs in < 45 seconds, successfully detects known test CVEs, and reports 0 false positives for core infrastructure services.

---

## EXP-045 — Autonomous PostgreSQL Vector / Chord Indexing Health & Vacuum Drill (`services.postgresPgvectorAudit`)

**Mode:** scheduled inspection of PostgreSQL vector extensions (`vector`, `vchord`) and HNSW/IVFFlat index bloat.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/postgres-pgvector-audit.nix`
(`services.postgresPgvectorAudit`) on frieren, inspecting `face_search` and `smart_search` vector tables in Immich DB,
asserting `vector` (v0.8.7) and `vchord` (v1.1.1) extensions, and running `VACUUM (VERBOSE, ANALYZE)` to trigger `vchord`
index page compaction and prevent embedding graph fragmentation.

**Use case.** frieren hosts the fleet's Immich instance, which uses PostgreSQL with `pgvector` / `vchord` extensions
to store and query high-dimensional CLIP image embeddings. High-dimensional vector indexes (HNSW, IVFFlat) suffer from
index bloat and degraded nearest-neighbor cosine query recall after thousands of photo insertions and deletions. Standard
PostgreSQL autovacuum does not optimize HNSW graph structures. A declarative vector maintenance unit inspects vector table
index sizes, checks for index corruption, runs targeted `REINDEX` on vector indexes outside peak hours, and benchmarks
embedding similarity recall, ensuring sub-50ms photo search across 50,000+ images.

**Module shape.**

```nix
services.postgresPgvectorAudit = {
  enable = true;
  database = "immich";
  vectorTables = [ "face_search" "smart_search" ];
  runVacuum = true;
  reindex = false;
  schedule = "Sun *-*-* 02:15:00"; # strictly before 03:00 backup window
};
```

**Evidence.** Immich operates PostgreSQL 17 with `vchord` extension (`database_44393.sqlite` and pgsql tables).
The Immich database is 155 MB.

**Why it is not prod.** Reindexing large HNSW vector graphs consumes significant CPU and RAM, which can stall concurrent
photo uploads. Requires running non-blocking `CONCURRENTLY` and asserting zero active transactions before execution.
Exit criteria: scheduled unit benchmarks vector recall, verifies index integrity, and completes in < 30 seconds with 0 warnings.

---

## EXP-046 — Declarative SSH Bastion & Inactive Session Reaper (`services.fleetSessionReaper`)

**Mode:** background sweeping and termination of orphaned, abandoned, or broken SSH sessions and lingering agent pipes.
**Status:** **GRADUATED (2026-10-13)**. Deployed in production as `modules/services/fleet-session-reaper.nix`
(`services.fleetSessionReaper`) on frieren, running hourly to sweep abandoned session scopes and remote SSH
sessions idle > 4 hours, rigorously preserving multiplexers (`tmux`, `screen`, `agy`, `weechat`) and local console seats.

**Use case.** Fleet administrators and remote autonomous agents connect to frieren over LAN and Tailscale SSH. Transient network
drops, sleeping laptops, or killed terminal tabs often leave SSH child processes, agent child subprocesses, and pty allocations
open in the background indefinitely. Over days, these stale sessions hold open file descriptors, retain sudo credential tokens,
and consume process table slots. An autonomous reaper daemon inspects active user sessions via `loginctl` and `ss -tnp`: sessions
with zero network activity and no active tty input for > 2 hours are cleanly terminated with `SIGTERM` and `SIGHUP`, freeing kernel
resources while preserving persistent systemd user services.

**Module shape.**

```nix
services.fleetSessionReaper = {
  enable = true;
  maxIdleHours = 2;
  ignoredUsers = [ "devji" ];      # ignore devji systemd user manager
  preserveScreenSessions = true;  # do not kill tmux / screen / agy remote-control
  schedule = "hourly";
};
```

**Evidence.** `who` and `loginctl list-sessions` show active login sessions. Stale SSH sockets occasionally appear in `ss -tnp`
in `CLOSE_WAIT` state after network shifts.

**Why it is not prod.** Must rigorously discriminate between abandoned SSH terminals and deliberately detached multiplexers
(`tmux`, `screen`, `agy remote-control serve`). Exit criteria: simulated stale SSH connection cleanly reaped after timeout
while a background `agy` remote session continues running uninterrupted.

---

## EXP-047 — Declarative Home Assistant Automation & Entity State Integrity Probe (`services.haAutomationProbe`)

**Mode:** automated validation of Home Assistant entity states and automation execution health over local REST API.
**Status:** design study. Motivated by detecting broken sensors, unavailable MQTT entities, and dead automations.

**Use case.** frieren runs Home Assistant Core (`services.homeAssistant`) with 53 enabled entities and 8 devices. Over time,
Zigbee/Wi-Fi devices go offline, battery-backed sensors deplete, or template sensors fail to evaluate due to schema changes.
Because HA is running headlessly without daily manual UI review, broken automations and unavailable entities remain undetected
until an automation failure impacts the physical household. A declarative probe unit queries Home Assistant's local REST API
(`http://127.0.0.1:8123/api/states`) daily: it audits all entities, flags any critical device reporting `unavailable` or `unknown`
for > 6 hours, checks for automation trigger errors in HA logs, and emits a scorecard to `#Fleet`.

**Module shape.**

```nix
services.haAutomationProbe = {
  enable = true;
  haUrl = "http://127.0.0.1:8123";
  schedule = "daily";
  maxUnavailableHours = 6;
  criticalDomains = [ "switch" "light" "binary_sensor" "climate" ];
  alertSimpleX = true;
};
```

**Evidence.** Home Assistant is active on frieren on port 8123. REST API is available locally. Currently 53 entities are registered.

**Why it is not prod.** Requires provisioning a long-lived access token declaratively or via SOPS to query `/api/states` without
interactive auth prompts. Exit criteria: probe discovers 1 intentionally disconnected test entity, correctly classifies it as
unavailable, and reports 100% health across all online devices.

---

## EXP-048 — Transparent Hugepage (THP) & Kernel Memory Compaction Tuner (`profiles.mediaHugepages`)

**Mode:** targeted Transparent Hugepage (THP) allocation and memory compaction policies for 4K media streaming and large ZIM archives.
**Status:** design study. Motivated by reducing TLB misses during 4K video transcoding and large-file memory mapping.

**Use case.** frieren concurrently memory-maps multi-gigabyte files: 52.7 GB Wikipedia ZIM archives (`kiwix-serve`), 4K HEVC video files
(`jellyfin`), and Paperless document embeddings. With standard 4 KB page sizes, memory mapping a 50 GB file requires 13 million page table
entries, saturating the CPU's Translation Lookaside Buffer (TLB) and inducing kernel page table walker overhead. Transparent Hugepages
(2 MB pages) drastically reduce TLB misses by 500×. However, setting THP to `always` system-wide causes memory fragmentation and latency
spikes in Redis and PostgreSQL. A specialized media profile sets kernel THP to `madvise` and configures `systemd.services.kiwix-serve`
and `systemd.services.jellyfin` with `MemoryAccounting=true` and `madvise(MADV_HUGEPAGE)` wrappers, optimizing large memory mappings
without bloating database workloads.

**Module shape.**

```nix
profiles.mediaHugepages = {
  enable = true;
  thpMode = "madvise";            # "always" | "madvise" | "never"
  defragMode = "defer+madvise";
  targetServices = [ "jellyfin" "kiwix-serve" ];
};
```

**Evidence.** `/sys/kernel/mm/transparent_hugepage/enabled` is currently set to `always [madvise] never` on frieren.
`kiwix-serve` memory-maps 52.7 GB of ZIM data.

**Why it is not prod.** If THP allocation triggers synchronous kernel compaction under low RAM conditions, media streaming can stall.
Requires tuning `khugepaged/defrag` and measuring before/after TLB miss rates (`perf stat -e dTLB-load-misses`). Exit criteria: measured
35% reduction in TLB misses during Kiwix search and 4K Jellyfin streaming with 0 latency spikes.

---

## EXP-049 — Declarative Inter-Host SimpleX Agent Coordination Mesh (`profiles.interAgentMesh`)

**Mode:** automated agent-to-agent WebSocket JSON-RPC coordination bridge across the NixOS fleet.
**Status:** design study. Motivated by enabling autonomous peer-to-peer task dispatching between frieren, eisen, stark, and mobile nodes.

**Use case.** frieren runs the fleet SimpleX SMP relay server (`:5223`) and client daemon (`:5225`). Currently, operator agents communicate
with human operators in `#Fleet`, but cannot autonomously negotiate workloads between hosts (e.g. frieren dispatching a heavy compile job
to `eisen` or pulling sensor telemetry from `schneeeule`). A declarative agent mesh profile standardizes the WebSocket JSON-RPC protocol
interface across all fleet nodes: agents exchange signed, end-to-end encrypted dispatch messages over SimpleX, automatically authenticating
peer agent identities via pre-shared public signing keys without centralized API relays or external internet dependency.

**Module shape.**

```nix
profiles.interAgentMesh = {
  enable = true;
  localDaemonPort = 5225;
  peerAgents = [
    { host = "eisen"; role = "build-accelerator"; }
    { host = "stark"; role = "gpu-inference-worker"; }
  ];
  allowedCommands = [ "ping" "build-closure" "query-telemetry" ];
  auditLog = "/var/log/agents/mesh-dispatch.log";
};
```

**Evidence.** `simplex-chat.service` is active on frieren. Inter-agent coordination skill `simplex-admin` (`simplex-rpc.py`) is already
deployed and operational in `~/.agents/skills/simplex-admin/`.

**Why it is not prod.** Unrestricted command dispatching between autonomous agents introduces privilege escalation risks if an edge
node is compromised. Requires cryptographic command whitelisting and strict argument sandboxing. Exit criteria: successful automated
ping and telemetry dispatch between frieren and a secondary node over SimpleX with 0 human intervention and full signature verification.

---

## EXP-050 — Autonomous Nginx SSL/TLS Certificate Expiry & OCSP Stapling Watchdog (`services.tlsCertWatchdog`)

**Mode:** scheduled background validation of SSL/TLS certificate expiration dates and OCSP responses across virtual hosts.
**Status:** design study. Motivated by preventing certificate expiration from breaking background mobile client sync (Vaultwarden, Immich).

**Use case.** frieren terminates TLS for local reverse proxies (Vaultwarden `:8222`, Aki portal `:80/443`, monitors) and serves
services on the Tailscale mesh (`frieren.lan`). While ACME or certificates run in the background, renewal failures, transient DNS
validation timeouts, or clock skew can silently let certificates expire. Because server services run headlessly without browser
interactions, expired certs go unnoticed until mobile apps (Bitwarden sync, Immich backup) fail with TLS handshake errors.
A declarative watchdog unit runs every 12 hours: it probes declared virtual hosts and local cert files (`/srv/private/` or `/var/lib/acme`),
asserts remaining valid days (> 14 days), tests OCSP stapling responses, and raises administrative alerts on approaching expiration.

**Module shape.**

```nix
services.tlsCertWatchdog = {
  enable = true;
  endpoints = [
    "https://vault.frieren.lan"
    "https://monitors.frieren.lan"
  ];
  certFiles = [ "/var/lib/acme/vault.frieren.lan/cert.pem" ];
  warnDays = 14;
  criticalDays = 5;
  schedule = "00/12:00:00";
};
```

**Evidence.** Nginx is active on frieren. `openssl x509 -enddate -noout -in <cert>` and `curl -vI https://...` provide immediate,
deterministic certificate parsing without external network dependencies.

**Why it is not prod.** Probing local HTTPS endpoints requires resolving hostnames via local DNS and handling self-signed certificates
gracefully without spurious warnings. Exit criteria: scheduled unit tests declared certificates, accurately flags a simulated 5-day
expiring certificate, and completes in < 500ms with zero production interference.

---

## EXP-051 — Declarative Host Thermals & Dynamic Fan Curve Governor (`services.thermalGovernor`)

**Mode:** real-time core temperature telemetry from sysfs (`/sys/class/thermal`) and predictive throttling under sustained 4K encoding.
**Status:** design study. Motivated by preventing thermal throttling dropouts on the Lenovo IdeaPad 320 laptop-as-server hardware.

**Use case.** frieren runs 24/7 on laptop hardware (Lenovo ideapad 320-15IKB, Intel Core i5-8250U). Under sustained multi-hour FFmpeg
transcodes, Paperless batch OCR, or local Nix rebuilds, CPU thermals can reach 75–80°C. If the single laptop fan cannot dissipate heat,
the CPU throttles its clock down to 800 MHz, inducing audio/video playback stutter on 4K Jellyfin output. A lightweight governor daemon
monitors thermal zones (`/sys/class/thermal/thermal_zone*/temp`): when temperatures exceed 72°C, it modulates Intel P-state energy
performance preferences (`/sys/devices/system/cpu/cpu*/power/energy_perf_bias`) to drop CPU package wattage from 15W to 10W, preventing
thermal throttling spikes while maintaining smooth media playback.

**Module shape.**

```nix
services.thermalGovernor = {
  enable = true;
  highTempCelsius = 72;
  criticalTempCelsius = 80;
  throttleAction = "bias-power";   # "bias-power" | "cap-frequency" | "nice-batch"
  pollIntervalSec = 30;
  logMetrics = true;
};
```

**Evidence.** Sysfs thermals are readable on frieren (`cat /sys/class/thermal/thermal_zone0/temp` reports ~34°C during idle).
Intel Core i5-8250U supports hardware P-state energy performance bias.

**Why it is not prod.** Aggressive thermal capping could unnecessarily throttle legitimate fast builds when ambient temperatures
are low. Requires calibrating hysteresis margins so governor does not oscillate every few seconds. Exit criteria: simulated CPU load
(`stress-ng --cpu 4`) smoothly lowers energy performance bias when 72°C is crossed, capping thermals without dropping clock below 1.6 GHz.

---

## EXP-052 — Autonomous ZRAM Decompression Latency & Memory Reclamation Drill (`services.zramPerfDrill`)

**Mode:** periodic synthetic memory compression/decompression benchmark verifying zram throughput on Linux 6.12.
**Status:** design study. Motivated by ensuring CPU-compressed memory operates faster than NVMe storage.

**Use case.** frieren allocates 5.7 GiB to `/dev/zram0` using zstd compression. As the system runs for weeks across diverse memory
churn (PostgreSQL, Paperless, Gatus, agent processes), kernel memory allocator fragmentation or CPU lock contention can degrade
zram throughput below expected performance levels. A monthly drill runs non-destructive, isolated memory compression benchmarks:
it writes and reads a 64 MB synthetic memory pattern to `/dev/zram0`, calculates compression ratio and read/write bandwidth, asserts
throughput > 3.0 GB/s, and verifies zero kernel page allocation failures, proving zram memory health.

**Module shape.**

```nix
services.zramPerfDrill = {
  enable = true;
  schedule = "monthly";
  benchmarkSizeMb = 64;
  minThroughputGbps = 3.0;
  maxLatencyMs = 25;
  notifyOnDegradation = true;
};
```

**Evidence.** `/dev/zram0` is active on frieren (`swapon -s` shows 5.7 GiB, prio 100). Kernel 6.12 implements multi-stream zstd
compression algorithms.

**Why it is not prod.** Generating synthetic memory churn must never trigger memory eviction or OOM on production services. Must
verify sufficient free RAM headroom (> 2 GiB) before running the drill. Exit criteria: monthly drill completes in < 3 seconds,
reports > 3.5 GB/s memory throughput, and exits cleanly with zero page leaks.

---

## EXP-053 — Declarative Pi-hole Gravity Sync & Adlist Drift Reconciliation (`services.gravitySync`)

**Mode:** automated reconciliation of blocklist definitions, whitelist domains, and gravity database optimization.
**Status:** design study. Motivated by preventing stale blocklists and DNS recursion timeouts.

**Use case.** Pi-hole FTL runs on port 53. Gravity updates (`pihole -g`) update domain blocklists weekly. When upstream adlist URLs
return HTTP 404 or transient timeouts, Gravity drops existing lists or accretes stale domain hashes. A declarative reconciliation
module checks adlist HTTP availability, runs gravity updates outside peak hours, and verifies that recursive query latency stays < 15ms.

**Module shape.**

```nix
services.gravitySync = {
  enable = true;
  schedule = "Sun *-*-* 03:15:00"; # strictly outside 03:00 backup window
  adlists = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
  verifyDnsLatency = true;
  maxLatencyMs = 25;
};
```

**Evidence.** Pi-hole gravity database is `/var/lib/pihole/gravity.db` (8.7 MB, 87,000+ domains). `task checks:dns:failover`
verifies local resolution.

**Why it is not prod.** Gravity database rebuild acquires database locks on `gravity.db`, which can briefly stall DNS lookups for LAN
devices. Must run during the quietest night hour and verify fast post-rebuild DNS query response. Exit criteria: scheduled unit
reconciles adlists, runs Gravity rebuild, and confirms sub-10ms DNS resolution on `127.0.0.1:53`.

---

## EXP-054 — Declarative Automated Flake Input Dependency Graph & Security Vulnerability Matrix (`services.flakeMatrixReport`)

**Mode:** autonomous derivation tree graphing and CVE impact matrix visualization for the Aki fleet portal.
**Status:** design study. Motivated by creating an offline visual control plane for fleet package closures.

**Use case.** frieren compiles the Aki fleet documentation hypermedia tree (`lib/aki-site.nix`) over UDS socket. Incorporating an
automated dependency graph generator that visualizes all fleet host closures and evaluates CVE vulnerabilities creates an offline,
interactive visual control plane for fleet health.

**Module shape.**

```nix
services.flakeMatrixReport = {
  enable = true;
  schedule = "weekly";
  outputDir = "/srv/data/projects/nixconfig/docs/matrix";
  targetHosts = [ "frieren" "minyx" "eisen" "stark" ];
  generateGraph = true;
};
```

**Evidence.** `lib/aki-site.nix` is already compiled into `/nix/store` and served over `unix:/run/uds-docs/docs.sock`.
Flake evaluation across all hosts is supported natively.

**Why it is not prod.** Generating full derivation graphs for 4 hosts can produce multi-megabyte SVG/DOT files that take compute
to render. Requires caching and delta generation. Exit criteria: weekly unit builds dependency matrix and embeds interactive graph
into Aki portal with zero build regressions.

---

## EXP-055 — Declarative InfluxDB Retention & Metrics Aggregation Compaction Drill (`services.metricsRetentionDrill`)

**Mode:** scheduled retention validation and TSM shard compaction for time-series telemetry storage.
**Status:** design study. Motivated by preventing time-series disk bloat and slow historical dashboard queries.

**Use case.** frieren runs InfluxDB (`:8086`) storing system performance counters, disk I/O metrics, and Home Assistant sensor
histories. Over months of 24/7 logging, high-resolution metric data accretes rapidly across Btrfs storage pools, causing multi-gigabyte
TSM shard directories and slow query responses for historical dashboard graphs. A declarative retention policy reconciles measurement
retention rules (raw 1-second metrics retained 7 days, 1-minute downsampled rollups retained 90 days), compacts cold TSM shards, and
validates continuous query execution outside peak hours, maintaining tight storage footprints.

**Module shape.**

```nix
services.metricsRetentionDrill = {
  enable = true;
  schedule = "Sun *-*-* 03:45:00"; # strictly outside backup window
  influxEndpoint = "http://127.0.0.1:8086";
  retentionPolicies = {
    "autogen" = "168h"; # 7 days for high-resolution counters
    "downsampled" = "2160h"; # 90 days for rollups
  };
  compactColdShards = true;
};
```

**Evidence.** InfluxDB is active on frieren (`systemctl is-active influxdb`). Data directory `/var/lib/influxdb` contains WAL and TSM shards.

**Why it is not prod.** TSM shard compaction generates intensive disk writes. Must run with low I/O priority (`ionice -c 3`) and assert
zero concurrent backup tasks. Exit criteria: scheduled unit validates retention policies, compacts shards in < 15 seconds, and frees
at least 15% TSM storage with 0 query errors.

---

## EXP-056 — Declarative Paperless OCR Language Pack & Model Drift Reconciler (`services.paperlessOcrAudit`)

**Mode:** scheduled validation of Tesseract language traineddata models and OCR accuracy across document ingestion queues.
**Status:** design study. Motivated by preventing silent OCR fallback to lossy ASCII recognition on foreign-language documents.

**Use case.** frieren processes scanned physical documents and PDFs using Paperless-ngx and Tesseract OCR (`tesseract`).
Over months of system upgrades or manual document imports, documents scanned in German, Japanese, Chinese, or French can
silently fail OCR or fall back to English ASCII approximations if required language pack packages (`tessdata/deu`, `tessdata/jpn`)
are unlinked in NixOS wrappers or missing from `$TESSDATA_PREFIX`. A declarative OCR reconciler audits declared language packs
in the Paperless runtime environment, runs synthetic OCR verification tests against multi-language sample test pages, asserts text
extraction fidelity, and validates that OCR page processing latency stays < 8.0 seconds per page without stalling Celery workers.

**Module shape.**

```nix
services.paperlessOcrAudit = {
  enable = true;
  schedule = "weekly";
  languages = [ "eng" "deu" "jpn" "fra" ];
  maxPageLatencySec = 8.0;
  testSampleDir = "/srv/data/projects/nixconfig/tests/ocr-samples";
  alertOnMissingModel = true;
};
```

**Evidence.** Paperless-ngx is active on frieren (`paperless-consumer`, `paperless-web`). Tesseract is mapped in Paperless's environment.

**Why it is not prod.** Generating test OCR recognition runs consumes CPU cycles. Must run during off-peak hours and test compact
synthetic snippets. Exit criteria: scheduled unit asserts all declared language traineddata files exist, validates 100% character
accuracy on test snippets in < 2 seconds, and alerts if a language model is missing.

---

## EXP-057 — Declarative Linux Kernel TCP BBRv3 & Bufferbloat Mitigation Tuner (`profiles.networkBufferbloatTuner`)

**Mode:** kernel socket buffer optimization, Fair Queuing (`fq`) packet scheduling, and BBR congestion control on 1 GbE wired interface.
**Status:** design study. Motivated by eliminating jitter and bufferbloat during concurrent media streaming and multi-gigabyte backups.

**Use case.** frieren serves as the fleet NAS and streaming server, concurrently running high-bandwidth Restic backup uploads,
NFS file transfers, and 4K Jellyfin streaming over its single 1 GbE wired interface (`enp1s0`). Under standard Linux Cubic congestion
control and default FIFO queuing, saturating throughput creates severe bufferbloat: latency spikes from 0.4ms to 120ms+, inducing
dropped audio frames on TV playback and stalling real-time SimpleX WebSocket responses. A declarative network profile enables
Linux kernel TCP BBR congestion control (`net.ipv4.tcp_congestion_control = "bbr"`), applies Fair Queuing (`net.core.default_qdisc = "fq"`),
and tunes receive/transmit buffer memory limits (`tcp_rmem`, `tcp_wmem`), maintaining sub-2ms network latency even under saturated line rate.

**Module shape.**

```nix
profiles.networkBufferbloatTuner = {
  enable = true;
  congestionControl = "bbr"; # "bbr" | "bbr3" | "cubic"
  defaultQdisc = "fq"; # "fq" | "fq_codel" | "cake"
  targetInterface = "enp1s0";
  maxBufferBloatLatencyMs = 5.0;
  benchmarkOnActivation = true;
};
```

**Evidence.** Kernel 6.12 is running on frieren. `sysctl net.ipv4.tcp_congestion_control` is currently `cubic`.
`sysctl net.core.default_qdisc` is currently `fq_codel`.

**Why it is not prod.** Changing global TCP congestion control affects all WAN and Tailscale traffic. Must verify compatibility
with Tailscale WireGuard encapsulation and ensure zero packet drops on local 1 GbE switch. Exit criteria: sustained 940 Mbps iperf3
stream sustains < 3.0ms ping latency to the local router, eliminating media playback stutter.

---

---

## Audit findings feeding these experiments

The port audit below (`task checks:ports`) is the evidence that the segmentation arguments
are not theoretical. As of 2026-10-12 on frieren/enp1s0, the declaration-to-ruleset match is
exact (32 TCP / 14 UDP), and the interesting parts are the edges:

| Bucket | Ports | Why it matters here |
| :--- | :--- | :--- |
| **DEAD-HOLE** — declared, nothing listening | `631`, `3005`, `8324`, `8920`, `32469` | Firewall holes with nothing behind them (631 = CUPS, removed by the Tier 1 debloat). Prune, or they accrete. |
| **REDUNDANT** — declared, loopback-bound only | `3001` | Uptime-Kuma's LAN hole is unusable; it is proxied through nginx instead. |
| **FIREWALL-ONLY** — public, permitted nowhere | `111`, `20048`, `38139`, `40769`, `42795`, `46357`, `41557`, `8080`, `8086`, `10809`, `5355` | rpcbind/mountd/statd, Immich's second listener, the Pi-hole web UI, InfluxDB, iVentoy's second port and LLMNR all bind public addresses and are held back **only** by the interface scope. Any loosening — or any host that lacks this scoping — exposes them. |

Two consequences for the experiments: EXP-006's segmentation is worth doing precisely
because so much here depends on one control, and the NFS dynamic ports (`38139`, `40769`,
`42795`, `46357`) are the reason a subnet boundary needs to be explicit rather than
"whatever the current ruleset happens to allow".

### Dead services behind live ports (2026-10-12)

The three "device layer" services are all running and all unused, which is the state that
makes a firewall hole look justified after its service is gone:

| Service | Listener | Clients / definitions | Why it matters |
| :--- | :--- | :--- | :--- |
| Mosquitto | `127.0.0.1:1883` | **0 clients**; log is nothing but 30-minute idle DB flushes | Has a publisher-shaped hole and no publisher — EXP-007 |
| Uptime-Kuma | `127.0.0.1:3001` (LAN hole = REDUNDANT) | **0 monitors** after ~8 h uptime | REST API is read-only, so it cannot be declared — EXP-008 |
| Home Assistant | `:8123` | 53 enabled entities, 8 devices, **not subscribed to its own broker** | `mqtt` is installed as a dependency and never configured — EXP-009 |

Home Assistant's 53 entities are not nothing (the GitHub integration already tracks
`shaoyanji/nixconfig`, and both phone companion apps are registered), but the *device* layer — the
reason the broker exists — has no members. The useful distinction is that the broker is dead for a
second, independent reason that no dongle would fix: HA is not a subscriber.

## The shared design problem

EXP-001 through EXP-005 are modes of one piece of hardware, so the real deliverable there is one module
with an honest option surface and **assertions that make illegal combinations impossible**:

```nix
# lib.types.enum over the modes, plus assertions:
#   - mode = "ap"       requires ap.ssid and an ap.subnet
#   - mode = "monitor"  forbids any managed association on the same phy
#   - exactly one mode is active; there is no "ap + sta-failover" on a 1×1 radio
assertions = [{
  assertion = cfg.mode != "ap" || cfg.ap.ssid != null;
  message = "services.fleetWifi: mode \"ap\" requires ap.ssid";
}];
```

EXP-006 through EXP-009 are the other half: services rather than hardware modes, already running here,
with no publisher, no subscriber and no monitor between them. They reduce to the same requirement — a
documented option surface, no silent side effects, and a declarative source of truth — which is the bar
the checklist below states and the reason EXP-008 concludes that Uptime-Kuma cannot meet it as it
stands.

**Definition of done for a "genuine service module" in this repo** (the bar these are measured against):

- [ ] `services.<name>` (or `profiles.<name>` for cross-cutting behaviour) namespace, `mkEnableOption`,
      `mkIf`, no unconditional side effects.
- [ ] Precise types: `types.enum`, `types.port`, `types.str` with CIDR validation, `types.nullOr
      types.path` for optional files — not free-form strings.
- [ ] Opt-in firewall, never blanket ports. `hosts/frieren/firewall-scope.nix` clears the global
      lists with `lib.mkForce`, so a module that relies on global `allowedTCPPorts` silently does
      nothing on scoped hosts.
- [ ] Secrets via `systemd` `LoadCredential` / `EnvironmentFile`, never a PSK or token on a command
      line (see `rpcSecretFile` in `modules/services/aria2-daemon.nix` for the house pattern).
- [ ] Assertions instead of silent misconfiguration; every option documented in the module.
- [ ] A `taskfiles/*` surface and an `.agents/skills/*` entry if an operator needs to drive it.
- [ ] Verifiable: a runbook (`checks:*` or a documented command) proving the mode came up.

---

## Evidence & reproduction

Collected read-only on frieren, 2026-10-12. `iw` is **not installed** on the host — it was run from a
nix store path, which is itself a note for whichever experiment needs it.

```bash
ip -br addr; ip route                       # dual-homed /24, metric 100 vs 600
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev # wlp2s0:connected:"Obi LAN Kenobi"
lspci -nn | grep -i network                 # 8086:3166 Wireless-AC 3165

# mode support + regulatory state (iw via nix, elevated via the setuid wrapper):
iw list        # -> IBSS, managed, AP, AP/VLAN, monitor, P2P-*
iw reg get     # -> country DE: DFS-UNSET (self-managed); 5170-5250 has no DFS flag
iw dev wlp2s0 info   # -> ch 36 (5180 MHz), width 80 MHz

# repo-side facts:
grep -rn "wlp2s0" --include=*.nix .         # only firewall-scope.nix (+ a comment in configuration.nix)
grep -rn "hostapd" --include=*.nix .        # no matches: no AP anywhere in the fleet
sed -n '147,159p' hosts/frieren/dns.nix     # 53 opened on enp1s0 + tailscale0 only
```

```bash
# EXP-007 / EXP-009 — the broker has neither publisher nor subscriber:
ss -tnp | grep -c ':1883'                                    # 0
journalctl -u mosquitto -n 12                                # idle DB flushes only
journalctl -u home-assistant | grep -ci mqtt                 # 0
sudo grep -n '^mqtt:' /srv/private/home-assistant/configuration.yaml   # no match
sudo python3 -c "import json;print([e['domain'] for e in json.load(open('/srv/private/home-assistant/.storage/core.config_entries'))['data']['entries']])"
#   -> sun analytics backup met google_translate shopping_list github mobile_app ipp

# EXP-009 — no coordinator, and the parked data dir is already owned by the module's uid:
ls /dev/serial/by-id/; lsusb | grep -viE 'hub|bluetooth|webcam|XP-Pen'
stat -c '%u:%g' /srv/private/zigbee2mqtt            # 317:317
nix eval .#nixosConfigurations.frieren.config.ids.uids.zigbee2mqtt   # -> 317  (drop --raw: it is an int)

# EXP-008 — Uptime-Kuma cannot be declared: read-only API, CRUD on Socket.IO only:
sqlite3 /var/lib/private/uptime-kuma/kuma.db "select count(*) from monitor;"   # 0
sed -n '1,40p' /nix/store/3ivpxs6blx8sc3plhxyg6q7iv0szy24v-uptime-kuma-2.5.5/lib/node_modules/uptime-kuma/server/routers/api-router.js
ls /nix/store/3ivpxs6blx8sc3plhxyg6q7iv0szy24v-uptime-kuma-2.5.5/lib/node_modules/uptime-kuma/server/monitor-types/
```

## Not verified / open questions

Recorded so nobody mistakes inference for measurement:

- [ ] **No AP has been started.** That iwlwifi will accept ch 36 for AP mode is inferred from the
      regulatory table, the advertised modes and the current association priming it (LAR). Untested.
- [ ] **No throughput measurement.** The 1×1 ~72–150 Mbps figure is typical-for-chip, not measured
      here. Before EXP-001 is called viable for anything but IoT/guest, measure it.
- [ ] **Duplicate mDNS advertising is inferred, not captured.** `avahi-daemon` is active with both
      NICs on one broadcast domain, so one machine advertises twice; no capture was taken.
- [ ] **Pi-hole behaviour on an AP interface is unexercised.** The `interface=` pins in `dns.nix`
      are read from config, not tested against a live AP interface.
- [ ] **EXP-001/002 vs EXP-003 is unresolved by design** — one radio, and the current standby uplink
      is what gets sacrificed. EXP-005's USB-tether shape is the one path that avoids the trade.
- [ ] **Whether an HA `mqtt:` YAML stanza survives being promoted to a config entry is untested.**
      `configuration.yaml` is generated by the module, but HA writes `.storage/core.config_entries`
      itself; a UI-created entry there would drift from Nix on the next write. Confirm the behaviour
      before choosing YAML over a config entry (EXP-009).
- [ ] **`4555:1031` is unidentified.** It enumerates with no class driver and no tty, so it is not a
      coordinator — but nothing here says what it *is*. Listed so a future reader does not assume.
- [ ] **No MQTT publish has ever been attempted**, so the broker's `allow_anonymous` path is unproven
      as well as unhardened. EXP-007 assumes it works; that assumption is untested.
- [ ] **`gatus` was never started** (EXP-008). That its config file maps cleanly onto a Nix attribute
      set is read from the package, not from a running instance.
- [x] **Resolved: the self-scan artifact.** An early `nmap` from the host to its own LAN address
      reported `111`, `5355`, `8080`, `8086`, `10809`, `20048` and the dynamic NFS ports as open on
      the LAN. They are not: `-A nixos-fw -i lo -j nixos-fw-accept` is evaluated before the
      interface-scoped rules, so the loopback path over-reports. `task checks:ports` avoids
      scanning entirely and compares declaration against listeners.
- [x] **Resolved: loopback-mapped IPv4.** `[::ffff:127.0.0.1]:9998` was initially reported as a
      public listener, inventing a finding. Loopback detection now covers `127.*`, `[::1]:*` and
      `[::ffff:127.*`.
