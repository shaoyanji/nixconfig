# DNS failover (HC-3)

## The gap

frieren is the fleet's **only** resolver: `*.frieren.lan`
(`address=/frieren.lan/192.168.3.25`), ad-blocking through `pihole-ftl`, and a
recursive `unbound` on `127.0.0.1#5335`. Every client that points at `192.168.3.25`
loses name resolution the moment frieren is down, and there is no second answer.

## The module

`modules/net/dns/failover.nix` owns the **mechanism** — the unbound +
pihole-ftl resolver core, the wildcard zone, the LAN firewall hole, and (optionally)
VRRP. Host **policy** stays on the host and is passed in, so the module never guesses:

| Option | Meaning |
| :--- | :--- |
| `role` | `"primary"` (frieren) or `"secondary"` |
| `backend` | `"pihole"` (unbound + pihole-ftl) or `"blocky"` (one Go process) |
| `lanInterface` | interface FTL answers on / DNS is opened on / VRRP runs on |
| `zone`, `zoneAddress` | the wildcard record, e.g. `frieren.lan` → `192.168.3.25` |
| `resolvers` | ordered resolver addresses clients should be given, primary first |
| `extraDnsmasqLines` | host lines (pihole backend only): `interface=tailscale0`, PXE proxyDHCP |
| `customRecords` | static A records every role must answer the same way (name → address) |
| `blocklists` | URLs the `blocky` backend blocks; the pihole backend uses `services.pihole-ftl.lists` |
| `virtualIp`, `virtualRouterId`, `unicastPeers` | optional VRRP failover (see below) |
| `primaryPriority`, `secondaryPriority` | VRRP priority; primary must outrank secondary |

The host keeps what is not mechanism: blocklists, `queryLogDeleter`, the Pi-hole web
UI, the `tailscaled` ordering, `systemd-resolved` stub handling, `tailscale0` DNS, and
the PXE `67`/`4011` firewall holes.

## Current state

frieren declares the primary role in `hosts/frieren/dns.nix`:

```nix
profiles.dnsFailover = {
  enable = true;
  role = "primary";
  lanInterface = "enp1s0";
  zone = "frieren.lan";
  zoneAddress = "192.168.3.25";
  resolvers = ["192.168.3.50"];      # the VIP clients are configured with
  virtualIp = "192.168.3.50";        # reserved, outside the DHCP pool
  virtualRouterId = 50;
  unicastPeers = ["192.168.3.3"];    # minyx; unicast, never multicast
  primaryPriority = 200;             # minyx is 1
  extraDnsmasqLines = [ ... ];
};
```

**The second member is minyx** (`hosts/minyx/dns.nix`): `role = "secondary"`,
`backend = "blocky"`, priority 1. It was declared, withdrawn and reinstated on
2026-10-27 — the withdrawal is the useful part of the story (*The 2026-10-27 outage*
below), and the reinstatement is gated on the address rules in *Choosing the VIP*.

The reason for the backend split is weight, not preference: minyx is a 1 GiB Pi 3B
whose root is a USB stick with no TRIM, so pihole-ftl's query database and unbound's
recursion are the wrong shape for a node whose only job is to answer while frieren is
gone.

The backend is a host property, not a preference. `pihole` keeps the unbound +
FTL stack above; `blocky` is a single process that answers the same zone from
local records (`customDNS.mapping`, apex and wildcard) and blocks the same two
lists. Both are rendered from the same `zone` / `zoneAddress` / `customRecords`
inputs, so the two nodes cannot answer a fleet name differently.

What blocky cannot do is dnsmasq's conditional forward (`server=/domain/…`). The
tailnet zone and `gok` resolve through frieren only — the same shape of gap delphi's
crab-hole has, and documented here so it is not discovered during an outage. A
blocky node would still cover what LAN clients actually use: `*.frieren.lan` and the
static `eisen.lan` / `laya.lan` / `tts.lan` records.

The backend lives on in the module, tested (config validated by `blocky --config …
validate`, and the rendered YAML served the zone, the custom records and the two
blocklists on a spare port); no host declares it until there is a node to declare it
on.

fern briefly ran the same stack as `role = "secondary"`; `8bd17500` (2026-10-15)
removed pihole-ftl, unbound and dns-failover from it, so a roaming laptop stops
carrying a resolver it cannot serve.

delphi answers DNS at the fleet's shared address (`10.99.0.53` / `100.97.61.65`),
but with crab-hole, which has no static-record or zone support: it resolves the
internet and NXDOMAINs every `.lan` name, so it fails over public DNS only.
`hosts/delphi/configuration.nix` lists the three ways to close that gap; replicating
this zone on an always-on host is the one that makes failover real, and minyx does
that — deliberately in a different shape (blocky, not crab-hole) precisely because
crab-hole cannot carry the zone.

### The 2026-10-27 outage

A floating `192.168.3.53` was declared and withdrawn the same day, after a 04:00
autoUpgrade took the LAN's DNS down. Each mistake is a check now, not a note:

* The address came from the `virtualIp` option's `example`, not a reservation, and
  the router was already leasing it. The example is gone; `checks:dns:pool` enforces
  the rules in *Choosing the VIP*.
* The instances used default multicast VRRP, so two nodes that cannot hear each
  other both claimed MASTER. The module asserts `unicastPeers` whenever `virtualIp`
  is set.
* `openFirewall` rendered `extraStopCommands` that `iptables -D`d rules the running
  firewall did not have, and `firewall-reload` runs those under `set -e` right after
  inserting DROP-all, so the switch exited 4 and left INPUT dropping. The module
  opens `vrrp` from the firewall's start path (`extraInputRules` under nftables, else
  `extraCommands`), which is rebuilt each start and cannot half-delete itself.

A VIP buys one address, configured once on the router, that survives losing a node.
It is not `.25`: every `*.frieren.lan` record points there, so floating it would drag
the NAS along.

### Choosing the VIP

The address is the part that broke, so it has rules, and they are checks rather than
conventions:

1. **Outside the router's DHCP pool.** A VIP has no MAC to reserve, so the only
   structural protection is that the pool cannot reach it. Verify with
   `task checks:dns:pool POOL=<start>-<end>` — exit 0 means every declared address
   (resolvers, `zoneAddress`, `virtualIp`) is clear of it.
2. **Not an address a node already holds.** `192.168.3.53` was rejected for exactly
   this: the router was already leasing it to the Pi, so "failover" meant two MACs
   answering for one address. The VIP is `.50` — not frieren's `.25`, not minyx's
   `.3`.

   A reservation is per MAC, and this board has two MACs (built-in wifi and the USB
   ethernet adapter), so one reservation covers one link. Whichever link carries the
   role must have its own reservation, and that is the address `unicastPeers` names.
3. **Not the zone target.** `.25` is what every `*.frieren.lan` record points at, so
   floating it would drag the NAS along with the resolver.
4. **Written down here, never copied from an option's `example`.** The `example` is
   gone from the `virtualIp` option for that reason.

With the pool at `.100`–`.200`, `.25`, `.9` and `.50` all sit in the static block
and the gate passes; the same command with `POOL=192.168.3.20-192.168.3.200` exits 1
and names `.25` and `.50` as inside it.

`unicastPeers` is asserted, so a group that would split brain does not evaluate. The
appliance `gok` cannot join at all (no systemd, no keepalived, same board as minyx).

### What the router hands out today (measured 2026-10-27)

Option 6 carries `192.168.3.25` and `9.9.9.9`. The second is a public resolver, so a
client that falls back keeps the internet and **loses the zone**: every
`*.frieren.lan` name NXDOMAINs and the blocklists stop applying.

```
$ task checks:dns:failover RESOLVERS="192.168.3.25 9.9.9.9"
OK    192.168.3.25 answers hc3-check.frieren.lan -> 192.168.3.25
FAIL  9.9.9.9 answered '<no answer>' for hc3-check.frieren.lan (expected 192.168.3.25)
ERROR: resolvers did not answer the zone: 9.9.9.9        # exit 1
```

That is a trade, not an oversight — partial degradation beats no internet — with a
symptom worth recognising: a client that rotates entries (`options rotate`, some
Android stacks) fails `.lan` names intermittently while frieren is healthy.

A zone-aware second entry would be the `gok` appliance at `192.168.3.4`: blocky, the
same zone, the same lists. It lacks the `eisen.lan` / `laya.lan` / `tts.lan` static
records, needs its address reserved rather than leased, and was offline for ~10 h on
2026-10-27 while its declaration read as working.

frieren's `.25` is a DHCP reservation on `enp1s0`'s MAC, not a Nix-static address,
which is why it is the one address the fleet hardcodes: the NAS, the subnet router
and the target of every `*.frieren.lan` record. A reservation binds one MAC and this
board has two links, so whichever link carries a role needs its own reservation —
that is the address `unicastPeers` names.

## Bringing up a secondary

On an always-on host, the resolver is a short opt-in — the module derives the rest:

```nix
imports = [../../modules/net/dns/failover.nix];

profiles.dnsFailover = {
  enable = true;
  role = "secondary";
  backend = "blocky";              # pihole on a host with the RAM for FTL
  lanInterface = "enp0s3";          # that host's LAN NIC
  # zone/zoneAddress default to frieren.lan / 192.168.3.25
  customRecords = { … };            # mirror the primary's static records
  blocklists = [ … ];               # mirror the primary's lists
};
```

Without a VIP, add the secondary's address to frieren's `resolvers` list so clients
are handed both, **and** add that address to the router's DHCP option 6 — the list
alone is a declaration, not a deployment. With a VIP (`virtualIp` + `virtualRouterId`
+ `unicastPeers` on **both** hosts), clients are handed one address and `resolvers`
carries only that. Either way the secondary answers the same zone from the same
records, so a client that falls back gets the same answers — the property that makes
it a failover rather than a second resolver.

### Failover mode: client-side vs VRRP

* **Client-side (`virtualIp = null`).** Clients must be configured with both
  resolvers (DHCP secondary or `networking.nameservers`), so the Huawei router
  (`192.168.3.1`, the DHCP server) has to hand out both addresses — a manual router
  change, not something Nix owns. Not the fleet's choice since 2026-10-27: many
  clients only fall back after a full timeout, and some never try the second entry.
* **VRRP (`virtualIp` + `virtualRouterId` + `unicastPeers`).** keepalived advertises
  one address both hosts share, and clients keep pointing at it. A DNS-aware
  `vrrp_script` demotes a node whose resolver stops answering, not just one whose NIC
  flaps. `unicastPeers` is required, not preferred, and the VIP must be an address
  reserved outside the DHCP pool — never one copied from an option's `example`.

Split brain is prevented structurally: `role` makes a host primary or secondary,
`virtualRouterId` is required once `virtualIp` is set (two hosts under different ids
are two one-node groups that both become MASTER), and `primaryPriority` must exceed
`secondaryPriority`.

## The failover test

```bash
task checks:dns:failover                 # reads the group from frieren's declaration
task checks:dns:failover RESOLVERS="192.168.3.25 192.168.3.3"   # both must answer the zone
```

Exit **0** = the group answers the zone and is redundant; **1** = a listed resolver
did not answer, or the VIP answered from two MACs (split brain); **2** = cannot be
evaluated (fewer than two members and no VIP that answered with a single owner).

Redundancy has two shapes and the check must not confuse them: with a VIP `resolvers`
holds **one** address, so a single entry is correct and the proof is that address
answering while exactly one MAC owns it; without one, a single entry is a single point
of failure and the check says so. The member list is not enumerable from one host's
config (the secondary's address is DHCP), so prove both nodes directly after a switch.

A resolver a client can be *leased* is one it can lose to another device, so the pool
is checked separately. It reads `.resolvers`, the zone address and `virtualIp`, and
takes the router's bounds as input, never a guess:

```bash
task checks:dns:pool POOL=192.168.3.100-192.168.3.200   # 0 = .25 is outside the pool
task checks:dns:pool POOL=192.168.3.20-192.168.3.200    # 1 = .25 is inside it
```

The check probes a **subdomain** (`hc3-check.<zone>`) rather than the apex, and routes
a query aimed at the local host through `127.0.0.1`. Both are deliberate: the apex can
carry a local override (frieren answers `frieren.lan` with `127.0.0.1` while
`photos.frieren.lan` gets `192.168.3.25`), and a query to the host's own LAN address
arrives on `lo`, where dnsmasq's `interface=enp1s0` scoping drops it.

Two things are not failover and must not be reported as it: "it built" and "it was
declared". The takeover has to be observed in both directions — a VIP that moves out
and stays out is half a failover:

```bash
ip -br addr show enp1s0 | grep 192.168.3.50        # 1. .50 is on frieren, minyx BACKUP
ssh minyx 'ip -br addr show wlan0'                 #    no .50 here
ssh frieren 'sudo systemctl stop pihole-ftl'       # 2. stop the resolver, not the host
dig +short @192.168.3.50 photos.frieren.lan        # 3. within ~10 s: 192.168.3.25
ssh frieren 'sudo systemctl start pihole-ftl'      # 4. priority 200 pulls it back
```

If the VIP moves but the answer is NXDOMAIN, blocky is up and its zone is not: check
`customRecords`, not keepalived. If it never moves, check `unicastPeers` on both sides
and `journalctl -u keepalived` on both — a rejected `track_script` reads as "track
script dns not found, ignoring" and leaves the instance running unchecked. The
DNS-aware `vrrp_script` is what makes the takeover work at all: it probes a synthesized
name under the zone wildcard and requires the zone address, because `dig` exits 0 on
NXDOMAIN and the apex is answered from the host's own record.

## The tailnet layer: approval, DNS, and the two switches that are not one

A tailnet resolver pair adds two switches that look related and are not. Both are
**tailnet state**, so no host eval can prove either — the config can be perfect
while the pair serves nothing.

| Switch | Where it lives | What it decides | Today (2026-10-20) |
| :--- | :--- | :--- | :--- |
| **Route approval** | `enabledRoutes` on the device | whether packets to `10.99.0.53` are delivered at all | **approved on both** (via `autoApprovers`) |
| **Nameservers** | tailnet DNS settings | whether tailnet clients *ask* the pair | global `[10.99.0.53, 100.97.61.65]`, split `frieren.lan`, Override on |

`tailscale set --advertise-routes` records an **offer**. Tailscale serves an
offered subnet route only after approval (admin console, API, or an
`autoApprovers` rule), and `tailscale status` on the router shows the offer either
way — which is exactly how a "failover pair" sat configured-but-inert.

### Approving is a policy rule now, not a click

The live policy carries `autoApprovers.routes` for both fleet prefixes, so a device
an admin authenticated may advertise them and be approved on the spot, re-keying
included. `modules/config/tailnet-policy.hujson` mirrors it, and two gates keep the
mirror honest:

```bash
task ops:tailnet:policy           # [gate] semantic diff (comments/order ignored), exit 1 on drift
task ops:tailnet:policy:apply     # [destructive] POST the file; needs write scope
```

**The trap: `autoApprovers` fires when a route is advertised, not when the rule
lands.** A prefix that was already pending stays pending forever, so both routes
still read unapproved *after* the rule existed. Re-offering fixes it, and only the
`/32` has to move — on delphi (no LAN route of its own) the offer is parked on
`10.99.0.54/32`, which nothing binds:

```bash
# frieren: withdraw just the /32, then re-add it
sudo tailscale set --advertise-routes=192.168.3.0/24
sudo tailscale set --advertise-routes=192.168.3.0/24,10.99.0.53/32
# delphi
sudo tailscale set --advertise-routes=10.99.0.54/32
sudo tailscale set --advertise-routes=10.99.0.53/32
```

`task ops:tailnet:routes` is the gate (OFFERED/APPROVED/UNAPPROVED, non-zero on
drift). `ops:tailnet:approve` and `ops:tailnet:policy:apply` need a write token and
the fleet's OAuth client is `all:read`, so those are console steps; a route the
policy covers needs no click at all.

### Point clients at it (the second switch)

Approval only makes `10.99.0.53` **reachable**. Clients keep resolving through their
own resolvers until the tailnet DNS page says otherwise: split DNS for
`frieren.lan`, plus global nameservers.

```
global nameservers: 10.99.0.53, 100.97.61.65      # pair + a node address that works everywhere
split DNS:          frieren.lan -> 100.97.61.65    # the zone never leaves frieren
```

Two measured reasons the pair is not the redundancy it looks like:

* **A subnet-route nameserver is invisible to hosts that refuse routes.**
  `10.99.0.53` is a route and `--accept-routes` is deliberately off on eisen, fern
  and aristotle (accepting frieren's `192.168.3.0/24` puts every LAN connection into
  table 52 and broke Steam Link and LAN SSH), so on those hosts the only working
  entry is `100.97.61.65` and a frieren outage is a total DNS outage.
* **Route failover is node-level, not service-level.** Stopping delphi's crab-hole
  for 32 s left the `/32` exactly where it was, because the node was still online.
  Nothing on the tailnet demotes a host whose resolver died, the way the VRRP
  `vrrp_script` does for the VIP.

The shape that survives both is listing resolver **node** addresses —
`100.97.61.65` (frieren) and `100.123.145.53` (delphi): neither needs a route, so
every client gets two real resolvers and a service crash on either is covered by its
own retry. Keep `10.99.0.53` advertised for what it is for: LAN clients that
hardcode one address. `task ops:tailnet:dns` checks the live list, classifies each
entry, probes it for the zone and a blocked domain, and fails on a routed-only list.

crab-hole is a forwarder with no static-record support, so `*.frieren.lan` cannot
exist on delphi (`@100.123.145.53 photos.frieren.lan -> no answer`). Pinning the zone
with split DNS is what keeps that from mattering; the cost is that the zone does not
fail over, which is accepted because every name in it points at frieren's services.

Tailscale cannot order nameservers deterministically (it queries them in
parallel), so never list two entries expecting "first, then fallback" — and any
public resolver added for safety will win some queries and leak past the block
lists. Override with zero working entries is total DNS loss, including
`login.tailscale.com`.

Devices using an **exit node** resolve through the exit node instead of this
list, unless a nameserver is marked *Use with exit node* in the console. delphi
is the tailnet's exit node and runs crab-hole, so that case is currently
consistent by accident rather than by configuration.

### Traps that belong to this design

* **`--accept-routes` on a member.** Tailscale's own HA guidance warns that a
  standby router which accepts routes can accept *its own* advertised prefix from
  the primary — traffic hairpins through the other node. delphi sets
  `--accept-routes=true` deliberately (it wants the LAN `192.168.3.0/24`); the
  local `lo` bind is what keeps a direct query from looping.
* **delphi is an exit node** (`advertiseRoutes` empty, `exitNode = true`):
  `0.0.0.0/0,::/0` are approved, so OCI egress is a bandwidth decision there.
* **The advertisement is now composed, not written.**
  `net/dns/tailnet-address.nix` appends the service `/32` to
  `advertiseRoutes` and emits the single comma-separated
  `--advertise-routes=` flag (there is an assertion against a hand-written
  second one, because `tailscale set` *replaces* the route set). Eval'd values
  after the refactor are byte-identical to what the hosts carried before:
  `frieren: --advertise-routes=192.168.3.0/24,10.99.0.53/32`,
  `delphi: --advertise-routes=10.99.0.53/32 --advertise-exit-node`.
* **`extraSetFlags` applies at boot**, through `tailscaled-set.service`; a switch
  does not re-run it. Changing routes needs a
  `sudo tailscale set --advertise-routes=…` now plus the reboot-order fix later.
  Re-read `AdvertiseRoutes` vs `PrimaryRoutes`: the first is the offer, the second
  is what is in force.
* **A reboot re-offers, which is now harmless**: `tailscaled-set` advertises the
  composed route set at boot, `autoApprovers` approves it again, so an approved
  pair survives without anyone re-clicking. Without the rule, a re-keyed or
  reinstalled node silently drops back to *advertised, not approved*.

## Related

* `modules/net/dns/failover.nix` — the module
* `modules/net/dns/tailnet-address.nix` — the `lo` bind + composed advertisement
* `modules/config/tailnet-policy.hujson` — the tailnet policy mirror (`autoApprovers`)
* `scripts/task/tailnet-routes.sh` — `ops:tailnet:routes` / `ops:tailnet:approve`
* `scripts/task/tailnet-policy.sh` — `ops:tailnet:policy` / `ops:tailnet:policy:apply`
* `scripts/task/tailnet-dns.sh` — `ops:tailnet:dns` (nameserver set, classification, probes)
* `scripts/task/lib/tailnet-api.sh` — token resolution shared by all three
* `scripts/task/dns-failover-check.sh` — the check behind `checks:dns:failover`
* `scripts/task/dns-pool-check.sh` — the check behind `checks:dns:pool`
* `hosts/frieren/dns.nix` — the primary declaration
* `docs/frieren-access.md` — service-access matrix
