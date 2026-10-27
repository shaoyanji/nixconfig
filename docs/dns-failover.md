# DNS failover (HC-3)

## The gap

frieren is the fleet's **only** resolver. It serves `*.frieren.lan`
(`address=/frieren.lan/192.168.3.25`), does ad-blocking (`pihole-ftl`, blocklists)
and forwards to a recursive `unbound` on `127.0.0.1#5335`. Every client that points
at `192.168.3.25` loses name resolution the moment frieren is down, and there is no
second answer to fall back to.

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

A floating `192.168.3.53` was declared on frieren and minyx and withdrawn the same
day, after a 04:00 autoUpgrade took the LAN's DNS down. Three separate mistakes, all
worth keeping written down:

* **The address was never chosen, it was copied.** `192.168.3.53` came from the
  `virtualIp` option's `example`, which itself is a mnemonic ("53 = DNS"). Nothing
  reserved it: not the router's pool, not `inventory.toml`, not `hosts/`. An
  unreserved address is one the DHCP server is free to hand to a phone, and a VIP
  copied from a doc example is how a duplicate-address outage happens. The example is
gone from the option for that reason.
* **Multicast VRRP splits brain on this LAN.** The instances used the default
  multicast (`224.0.0.18`) with no `unicastPeers`. Two nodes that cannot hear each
  other both elect themselves MASTER, so one address sits on two MACs and every ARP
  for it alternates. The module now *asserts* `unicastPeers` whenever `virtualIp` is
  set, rather than describing it as preferable.
* **`openFirewall` broke the switch itself.** keepalived's option renders
  `extraStopCommands` that `iptables -D` its own rules; NixOS's `firewall-reload`
  runs those under `set -e` right after inserting a DROP-all rule, so the first
  switch that adds them found nothing to delete, aborted mid-reload, and left INPUT
  dropping every packet. frieren's 04:00 switch exited 4 (`Failed to reload
  firewall.service`), the generation went live half-activated, and the LAN lost DNS
  until the firewall was restarted by hand. The module now opens `vrrp` from the
  firewall's **start** path (`extraInputRules` under nftables, else `extraCommands`),
  which is rebuilt from scratch each start — there is no `allowedProtocols` option in
  this nixpkgs, and a start-path rule cannot half-delete itself.

What a VIP buys when it is done properly: one address, configured once on the router,
that survives losing a node — without clients having to implement fallback. It is
still not `192.168.3.25`, because that address is the target of every
`*.frieren.lan` record and floating it would drag the NAS along.

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

With the pool at `.100`–`.200`, `.25`, `.9` and `.50` all sit in the static block and
the gate above passes. Tested both ways: the same command with
`POOL=192.168.3.20-192.168.3.200` exits 1 and names `.25` and `.50` as inside it.

Unicast is the other half of doing it properly: `unicastPeers` is asserted by the
module, so a group that would split brain does not evaluate. The appliance `gok`
cannot join this group at all (no systemd, no keepalived — and it is the same board
as minyx, different boot), so it is not an alternative member.

### What the router hands out today (measured 2026-10-27)

Option 6 carries `192.168.3.25` and `9.9.9.9`. The second entry is a public resolver,
so a client that falls back keeps the internet and **loses the zone**: every
`*.frieren.lan` name NXDOMAINs and the blocklists stop applying. Measured, not
assumed:

```
$ task checks:dns:failover RESOLVERS="192.168.3.25 9.9.9.9"
OK    192.168.3.25 answers hc3-check.frieren.lan -> 192.168.3.25
FAIL  9.9.9.9 answered '<no answer>' for hc3-check.frieren.lan (expected 192.168.3.25)
ERROR: resolvers did not answer the zone: 9.9.9.9        # exit 1
```

That is a trade, not an oversight — partial degradation beats no internet. It has a
symptom worth recognising: a client that rotates between entries (`options rotate`,
some Android stacks) fails `.lan` names *intermittently* while frieren is healthy, and
ads appear only sometimes.

A zone-aware second entry would be the `gok` appliance at `192.168.3.4`: blocky, the
same zone, the same two lists. Two gaps before it is a real substitute — it does not
carry the `eisen.lan` / `laya.lan` / `tts.lan` static records, and on 2026-10-27 it was
**offline for ~10 h** while its declaration read as working. It also needs its address
reserved rather than leased, or the router hands out a secondary that moves.

frieren's own `192.168.3.25` is likewise a reservation rather than a Nix-static address
(`networking.interfaces` is empty and `useDHCP` is true), which is why it is the only
address the fleet hardcodes: it is the NAS and the subnet router, and every
`*.frieren.lan` record points at it. The reservation is bound to `enp1s0`'s MAC
(`54:E1:AD:D5:EC:FF`), not to the dock's USB NIC, so a dock lease can never be handed
the resolver address.

A reservation is a binding, not a range. The lowest address seen in use on the LAN is
`.26`, one above the resolver, so whether `.25` sits inside the dynamic range depends
on the pool's lower bound — and the binding is then the only thing keeping the
resolver address out of circulation. `checks:dns:pool` makes that overlap explicit;
narrowing the router's pool (e.g. `.100`–`.200`) makes the separation structural
instead of procedural.

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
carries only that. Either way the
secondary answers the same zone from the same records, so a client that falls back
gets the same answers — which is the property that makes it a failover rather than a
second resolver.

### Failover mode: client-side vs VRRP

* **Client-side (`virtualIp = null`).** No floating address. Clients must be
  configured with both resolvers (DHCP secondary, or `networking.nameservers`). To
  make this real for LAN clients the **Huawei router** (`192.168.3.1`, the DHCP
  server — the FRITZ!Box is one of its clients, not the DHCP server) must hand out
  both addresses — a manual router change, not something Nix owns. Not the fleet's
  choice as of 2026-10-27: many clients only fall back after a full timeout, and some
  never try the second entry at all.
* **VRRP (`virtualIp` + `virtualRouterId` + `unicastPeers`).** keepalived advertises
  one address that both hosts share; clients keep pointing at the single VIP. A
  DNS-aware `vrrp_script` demotes a node whose resolver stops answering (not just one
  whose NIC flaps). `unicastPeers` is required, not preferred (the 2026-10-27 split
  brain), and the VIP must be an address **reserved on the router, outside its DHCP
  pool** — never one copied from an option's `example`. Withdrawn 2026-10-27; see
  *The 2026-10-27 outage*.

Split brain is prevented structurally: the `role` enum makes a host one of
primary/secondary, `virtualRouterId` is required once `virtualIp` is set (two hosts
under different router ids are two one-node groups that both become MASTER — the
assertion rejects this), and `primaryPriority` must exceed `secondaryPriority`.

## The failover test

```bash
task checks:dns:failover                 # reads the group from frieren's declaration
task checks:dns:failover RESOLVERS="192.168.3.25 192.168.3.26"
```

Exit codes: **0** = group answers the zone and is redundant; **1** = a listed resolver
failed to answer, or the VIP answered from two MACs (split brain); **2** = failover
cannot be evaluated (fewer than 2 members *and* no VIP that answered with a single
owner).

Redundancy has two shapes and the check must not confuse them: with a VIP, `resolvers`
holds **one** address by design, so a single entry is correct and the proof is that
address answering the zone while exactly one MAC owns it. Without a VIP, one entry is
a single point of failure and the check says so.

The member list is not enumerable from one host's config (the secondary's own address
is DHCP), so after a switch prove both nodes directly — this is the real end-to-end
test, and the only one that shows the takeover:

```bash
task checks:dns:failover RESOLVERS="192.168.3.25 192.168.3.3"   # both answer the zone
```

A resolver address that a client can be *leased* is a resolver a client can lose to
another device, so the pool is checked separately. It reads `.resolvers`, the zone
address and `virtualIp`, so the VIP is covered without being listed twice. The pool
bounds are router state, so they are an input, never a guess:

```bash
task checks:dns:pool POOL=192.168.3.100-192.168.3.200   # 0 = .25 is outside the pool
task checks:dns:pool POOL=192.168.3.20-192.168.3.200    # 1 = .25 is inside it
```

Exit **0** = every declared address is outside; **1** = one is inside (or the range is
misordered); **2** = cannot evaluate (no pool or bad input).

The check probes a **subdomain** (`hc3-check.<zone>`), not the apex, and routes a query
to a resolver that *is* the local host through `127.0.0.1`. Both are deliberate:

* The apex can carry a local override — on frieren `frieren.lan` answers `127.0.0.1`
  (TTL 0) while `photos.frieren.lan` answers `192.168.3.25`. A wildcard's job is
  subdomains; use `NAME=frieren.lan` to test the apex anyway and see the override.
* A query to the host's own LAN address arrives on `lo`, where dnsmasq's
  `interface=enp1s0` scoping drops it (`@192.168.3.25` times out, `@127.0.0.1` answers),
  so the LAN path cannot be exercised from the host itself — the check says so rather
  than implying the LAN path works.

Manual cross-check from a **client** host (the real test):

```bash
dig +short @192.168.3.25 photos.frieren.lan   # 192.168.3.25
dig +short @<secondary>  photos.frieren.lan   # same answer => failover target is real
```

Two things are not failover and must not be reported as it: "it built" and "it was
declared". The takeover has to be observed in **both** directions — a VIP that moves
out and stays out is half a failover:

```bash
# 1. before: .50 lives on frieren, minyx is BACKUP
ip -br addr show enp1s0 | grep 192.168.3.50        # on frieren
ssh minyx 'ip -br addr show wlan0'                 # no .50 here

# 2. stop the primary's resolver (not the host)
ssh frieren 'sudo systemctl stop pihole-ftl'

# 3. within fall x interval (~10 s): .50 leaves frieren, appears on minyx,
#    and the VIP still answers the zone from blocky
dig +short @192.168.3.50 photos.frieren.lan         # 192.168.3.25

# 4. restore: priority 200 must pull the VIP back, not leave it on the backup
ssh frieren 'sudo systemctl start pihole-ftl'
```

If the VIP moves but the answer is NXDOMAIN, blocky is up and its zone is not — check
`customRecords`, not keepalived. If it never moves, the group is not talking: check
`unicastPeers` on both sides, then `journalctl -u keepalived` on both (a rejected
`track_script` reads as "track script dns not found, ignoring" and leaves the instance
running with no health check at all). `checks:dns:failover` reports a VIP that answers
from two MACs as split brain.

The DNS-aware `vrrp_script` is what makes this work: a node whose *resolver* stopped
answering is demoted even though its NIC never flapped. It probes a synthesized name
under the zone wildcard and requires it to equal the zone address — `dig` exits 0 on
NXDOMAIN, and the zone apex is answered from the host's own record (frieren answers
`frieren.lan` with `127.0.0.1`), so neither an empty reply nor the apex is evidence
that the resolver is healthy.

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

```
before (2026-10-20)   delphi   OFFERED 0.0.0.0/0,10.99.0.53/32,::/0   APPROVED 0.0.0.0/0,::/0
                      frieren  OFFERED 192.168.3.0/24,10.99.0.53/32    APPROVED 192.168.3.0/24
now                   delphi   APPROVED 0.0.0.0/0,10.99.0.53/32,::/0
                      frieren  APPROVED 192.168.3.0/24,10.99.0.53/32
```

### Approving is a policy rule now, not a click

The live policy carries `autoApprovers.routes` for both fleet prefixes, so a
device authenticated by an admin (`autogroup:admin`) may advertise them and be
approved on the spot — no console, no write credential, and it survives a node
being re-keyed:

```jsonc
"autoApprovers": {
  "exitNode": ["autogroup:admin"],
  "routes": {
    "10.99.0.53/32": ["autogroup:admin"],
    "192.168.3.0/24": ["autogroup:admin"],
  },
}
```

**The trap: `autoApprovers` fires when a route is advertised, not when the rule
lands.** A prefix that was already pending stays pending forever, which is why the
pair still showed both routes unapproved *after* the rule existed. Re-offering the
prefix fixes it — and only the /32 has to be withdrawn:

```bash
# on frieren: drop just the /32 from the offer (the LAN /24 keeps advertising)
sudo tailscale set --advertise-routes=192.168.3.0/24
sudo tailscale set --advertise-routes=192.168.3.0/24,10.99.0.53/32
# 5 s later: APPROVED 192.168.3.0/24,10.99.0.53/32
```

On delphi (no LAN route of its own) park the offer on an unused prefix, then
restore it — `10.99.0.54/32` is never bound, so nothing is reachable in between:

```bash
sudo tailscale set --advertise-routes=10.99.0.54/32
sudo tailscale set --advertise-routes=10.99.0.53/32
```

Fallbacks, if a route ever needs approving without a matching rule:

```bash
task ops:tailnet:routes                 # gate: OFFERED/APPROVED/UNAPPROVED, non-zero on drift
task ops:tailnet:approve HOST=frieren   # [destructive] needs write scope — see below
```

The measurement goes through the sops OAuth client, whose scope is **`all:read`**:
enough to report, and `--approve` against it answers
`HTTP 403 calling actor does not have enough permissions`. To use that path
either export a write token for one command, or give the fleet a durable one:

```bash
# one command, nothing stored
TAILSCALE_API_TOKEN=tskey-api-… task ops:tailnet:approve HOST=frieren

# durable: the console's Trust credentials page. Tailscale scopes are per-operation,
# so route approval needs `devices:core` write and the policy endpoint `policy_file`;
# the fleet client today is `all:read`. Keep the secret in sops, not in the shell:
#   recreate the OAuth client with those scopes -> TAILSCALE.CLIENT.ID/SECRET, or
#   generate an API key (90-day expiry) -> TAILSCALE.API.KEY
sops set modules/secrets/apikeys.yaml '["TAILSCALE"]["API"]["KEY"]' '"tskey-api-…"'
task infra:secrets:sync
```

Neither is needed to approve a route covered by `autoApprovers` — only to post a
policy change from here.

### The policy file lives in the repo

`modules/config/tailnet-policy.hujson` mirrors the live policy, so the rules that
decide approval are reviewable like everything else:

```bash
task ops:tailnet:policy           # [gate] semantic diff (comments/order ignored), exit 1 on drift
task ops:tailnet:policy:apply     # [destructive] POST the file; needs write scope
```

`apply` replaces the **whole** policy (a console edit not mirrored here is
reverted), so it refuses to touch anything outside `.autoApprovers.routes` unless
`FORCE=1`, and sends `If-Match` with the ETag it read — a concurrent console edit
fails as `412` instead of being overwritten. Posting it is the one operation that
still needs a write credential: Tailscale has no API for minting API keys or
editing OAuth clients, so that scope is a console step by construction. Route
approval no longer needs it at all.

### Point clients at it (the second switch)

Approval only makes `10.99.0.53` **reachable**. Clients still resolve through
their own resolvers until the tailnet DNS page says otherwise:

* **Split DNS for `frieren.lan` → the resolvers.** Narrow: only `*.frieren.lan`
  lookups leave the device's own resolver.
* **Global nameservers + Override DNS servers.** Every tailnet query goes through
  the fleet's resolvers and gets the ad-blocking, at the cost of depending on
  them for *all* name resolution.

**Live since 2026-10-20** — global `[10.99.0.53, 100.97.61.65]`, split DNS
`frieren.lan → 100.97.61.65`, Override on, MagicDNS on. Through the stub:
`photos.frieren.lan → 192.168.3.25`, `example.com`/`github.com` resolve,
`doubleclick.net → 0.0.0.0`. The pair is still not the redundancy it looks like,
for two measured reasons:

1. **A subnet-route nameserver is invisible to hosts that refuse routes.**
   `10.99.0.53` is a route, and `--accept-routes` is *deliberately* off on eisen,
   fern and aristotle (accepting frieren's `192.168.3.0/24` puts every LAN
   connection into table 52 and hijacks it — Steam Link and LAN SSH both broke).
   On those hosts the only working entry is `100.97.61.65`, so a frieren outage
   is a total DNS outage there, Override or not.
2. **Route failover is node-level, not service-level.** Stopping crab-hole on
   delphi — then the `/32` primary — for 32 s left the route exactly where it
   was, because the *node* was still online and Tailscale has no idea the
   resolver behind it died. Only the second nameserver entry kept queries alive.
   There is no tailnet equivalent of the VRRP `vrrp_script` that demotes a host
   whose resolver stopped answering.

**The shape that survives both:** list the two resolver *node* addresses.

```
100.97.61.65     frieren   (always routable — a node address needs no route)
100.123.145.53   delphi    (idem, and the second implementation: crab-hole)
```

Node addresses need no `--accept-routes`, so every client gets two real
resolvers and a service crash on either is covered by the client's own retry —
no route takeover, no 32 s hole. Keep `10.99.0.53` advertised for what it is
actually for: **LAN clients** configured by hand (or DHCP) and anything that
hardcodes one stable address. It is not the tailnet's failover mechanism.

Check the live list with `task ops:tailnet:dns` — it classifies each entry,
probes it for the zone and for a blocked domain, and flags `local-bind` when the
reporting host answers the probe itself. It also probes every node that
*advertises* a listed address on its own node IP, which is the only way to see
what the `/32` currently resolves through.

### delphi is not an equivalent resolver (measured, and it cannot be one)

`task ops:tailnet:dns` fails today, and this is why:

```
@100.97.61.65     photos.frieren.lan -> 192.168.3.25   doubleclick.net -> 0.0.0.0
@100.123.145.53   photos.frieren.lan -> (no answer)    doubleclick.net -> NXDOMAIN
```

crab-hole is an ad-blocking **forwarder**, not an authoritative server: its config
has `[blocklist]`, `[[downstream]]`, `[[upstream]]` and `[api]` — there is no
static-record or zone feature, so `*.frieren.lan` cannot exist there at all. The
`/32` is served by delphi right now, which means every fleet name that lands on
`10.99.0.53` comes back NODATA.

That also makes the pair non-interchangeable in the failover sense: losing
frieren does not degrade to "the same answers", it degrades to "the internet
resolves, the fleet's names do not".

**Chosen 2026-10-20: option 1 below** — pin the zone with split DNS. It is a
console change (a write to this needs a `dns:core` credential; the fleet's OAuth
client is `all:read` and answers `403`):

```
DNS page -> Add nameserver -> 100.97.61.65 -> "Restrict to search domain" frieren.lan
# API equivalent
POST /api/v2/tailnet/-/dns/split-dns
{"frieren.lan": ["100.97.61.65"]}
```

After that, `*.frieren.lan` never reaches the global list, so delphi's missing
zone stops mattering, and `ops:tailnet:dns` reports the pin instead of faulting
the members:

```
split DNS: frieren.lan -> 100.97.61.65  (photos.frieren.lan=192.168.3.25)
  delphi  ...  n/a — frieren.lan is pinned to 100.97.61.65
```

The zone no longer fails over, which is the accepted trade: every name in it
points at frieren's own services, so delphi answering them was never useful.

**The split rule does not replace the node-address entry.** When it was first
applied the global list was cut to `[10.99.0.53]` alone — a subnet route, which
eisen/fern/aristotle cannot reach — leaving every *non-fleet* name with no
resolver on those hosts. `task ops:tailnet:dns` now **fails** on a routed-only
list, naming the hosts it reads from the repo's `--accept-routes=false`
declarations. The current list keeps one of each:

```
global nameservers: 10.99.0.53, 100.97.61.65      # pair + a node address that works everywhere
split DNS:          frieren.lan -> 100.97.61.65    # the zone never leaves frieren
```

Residual risk, and it is structural: the three route-refusing hosts can only use
`100.97.61.65`, so if **frieren's resolver** dies while its node stays up, they
lose DNS (the `/32` is unreachable for them, and the zone is pinned there too).
A third entry — `100.123.145.53`, delphi's node address — gives them a second
usable resolver for general names; measured 5/5 at ~22 ms, `example.com`
resolving, `frieren.lan` still pinned. The zone itself still dies with frieren,
which is acceptable: every name in it points at frieren's services.

Ways out, in increasing effort:

1. **Split DNS for `frieren.lan` → `100.97.61.65`** and leave the globals for
everything else. One console change, removes the NODATA race immediately. (This
is the one taken — see above.)
2. **Put a zone-capable resolver in front of crab-hole on delphi**: dnsmasq on
`:53` with `address=/frieren.lan/192.168.3.25`. This is a type change, not a
config flag — dnsmasq here is an authoritative wildcard server for one zone, not
a second resolver.
3. **Drop delphi from the DNS role**: `advertiseRoutes = []` on the `/32` and no
delphi entry in the tailnet nameservers. delphi stays a tailnet-wide ad-blocker
for public names only.

Until one of those lands, prefer `100.97.61.65` as the nameserver for anything
that needs `*.frieren.lan`, i.e. option 1.

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
