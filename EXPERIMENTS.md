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
**Status:** not started. It replaces a plan that is not merely unimplemented but **unimplementable** as
stated.

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
