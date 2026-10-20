# DNS failover (HC-3)

## The gap

frieren is the fleet's **only** resolver. It serves `*.frieren.lan`
(`address=/frieren.lan/192.168.3.25`), does ad-blocking (`pihole-ftl`, blocklists)
and forwards to a recursive `unbound` on `127.0.0.1#5335`. Every client that points
at `192.168.3.25` loses name resolution the moment frieren is down, and there is no
second answer to fall back to.

## The module

`modules/profiles/dns-failover.nix` owns the **mechanism** — the unbound +
pihole-ftl resolver core, the wildcard zone, the LAN firewall hole, and (optionally)
VRRP. Host **policy** stays on the host and is passed in, so the module never guesses:

| Option | Meaning |
| :--- | :--- |
| `role` | `"primary"` (frieren) or `"secondary"` |
| `lanInterface` | interface FTL answers on / DNS is opened on / VRRP runs on |
| `zone`, `zoneAddress` | the wildcard record, e.g. `frieren.lan` → `192.168.3.25` |
| `resolvers` | ordered resolver addresses clients should be given, primary first |
| `extraDnsmasqLines` | host lines: extra `address=` records, `interface=tailscale0`, PXE proxyDHCP |
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
  resolvers = ["192.168.3.25"];
  extraDnsmasqLines = [ ... ];
};
```

**fern is now the second member**: `hosts/fern/configuration.nix` declares the same
stack as `role = "secondary"` (its own `lanInterface = "wlo1"`), answering the same
`frieren.lan` wildcard and the same upstream chain (`127.0.0.1#5335` unbound), so a
client that falls back gets identical answers.

`virtualIp` is still **null**, so failover is **client-side**: nothing floats, and
clients must be handed both resolvers (FritzBox DHCP secondary, or a client's
`networking.nameservers`). There is no VIP to answer if a node dies silently.

### fern's address is deliberately NOT in `resolvers`

fern's LAN address is **DHCP**, so it is not written anywhere in the flake: it belongs
in the router's DHCP reservation (or a tailnet name), not as a literal. Consequence to
expect: `checks:dns:failover` reads the group from frieren's declaration, so while fern
is still an unlisted member the check reports the **exit 2 "cannot be evaluated"**
state it always has. That is correct, not a regression — it becomes a real two-member
group once fern's address is reserved and listed.

frieren's own `192.168.3.25` is likewise a reservation rather than a Nix-static address
(`networking.interfaces` is empty and `useDHCP` is true), which is why it is the only
address the fleet hardcodes: it is the NAS and the subnet router, and every
`*.frieren.lan` record points at it.

## Bringing up a secondary

On an always-on host, the resolver is a three-line opt-in — the module derives the
rest:

```nix
imports = [../../modules/profiles/dns-failover.nix];

profiles.dnsFailover = {
  enable = true;
  role = "secondary";
  lanInterface = "enp0s3";          # that host's LAN NIC
  # zone/zoneAddress default to frieren.lan / 192.168.3.25
};
```

Then add its address to frieren's `resolvers` list so clients are handed both. The
secondary answers the same wildcard zone with the same upstream chain, so a client that
falls back to it gets the same answers.

### Failover mode: client-side vs VRRP

* **Client-side (default, `virtualIp = null`).** No floating address. Clients must be
  configured with both resolvers (DHCP secondary, or `networking.nameservers`). To
  make this real for LAN clients the **FritzBox** (`192.168.3.1`, the DHCP server) must
  hand out both addresses — that is a manual router change, not something Nix owns.
* **VRRP (`virtualIp = "192.168.3.53", virtualRouterId = 53`).** keepalived advertises
  one address that both hosts share; clients keep pointing at the single VIP. A
  DNS-aware `vrrp_script` demotes a node whose resolver stops answering (not just one
  whose NIC flaps). Prefer `unicastPeers` over multicast if the network filters
  `224.0.0.18`. Pick a VIP **outside** the router's DHCP pool.

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
cannot be evaluated (fewer than 2 members — the state today).

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

To actually observe a takeover (non-trivial: it stops DNS for the NAS), stop the
resolver on the primary and confirm clients still resolve via the secondary/VIP:

```bash
sudo systemctl stop pihole-ftl        # on frieren — clients must keep resolving
sudo systemctl start pihole-ftl
```

## The tailnet layer: approval, DNS, and the two switches that are not one

A tailnet resolver pair adds two switches that look related and are not. Both are
**tailnet state**, so no host eval can prove either — the config can be perfect
while the pair serves nothing.

| Switch | Where it lives | What it decides | Today (2026-10-20) |
| :--- | :--- | :--- | :--- |
| **Route approval** | `enabledRoutes` on the device | whether packets to `10.99.0.53` are delivered at all | **approved on both** (via `autoApprovers`) |
| **Nameservers** | tailnet DNS settings | whether tailnet clients *ask* `10.99.0.53` | none: `global: []`, `split DNS: {}`, MagicDNS on |

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
their own resolvers until the tailnet DNS page says otherwise, and there are two
shapes with different blast radius:

* **Split DNS for `frieren.lan` → `10.99.0.53`.** The narrow one: only
  `*.frieren.lan` lookups go to the pair, everything else keeps the device's own
  resolver. Do not enable *Override DNS servers*. This is the default choice.
* **Global nameserver `10.99.0.53` + Override DNS servers.** Every tailnet query
  then depends on frieren or delphi, and you get the ad-blocking tailnet-wide.
  Two consequences: a phone on hotel Wi-Fi loses DNS when both nodes are down,
  and devices using an exit node use the **exit node** for DNS unless that
  nameserver is marked *Use with exit node* (delphi is an exit node — see below).

Tailscale cannot order nameservers deterministically, so do not list
`192.168.3.25` and `10.99.0.53` expecting fallback: a client may query either
first. That is why the pair shares one address instead of being two entries.

### Traps that belong to this design

* **`--accept-routes` on a member.** Tailscale's own HA guidance warns that a
  standby router which accepts routes can accept *its own* advertised prefix from
  the primary — traffic hairpins through the other node. delphi sets
  `--accept-routes=true` deliberately (it wants the LAN `192.168.3.0/24`); the
  local `lo` bind is what keeps a direct query from looping.
* **delphi is an exit node** (`advertiseRoutes` empty, `exitNode = true`):
  `0.0.0.0/0,::/0` are approved, so OCI egress is a bandwidth decision there.
* **The advertisement is now composed, not written.**
  `profiles/tailnet-dns-address.nix` appends the service `/32` to
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

* `modules/profiles/dns-failover.nix` — the module
* `modules/profiles/tailnet-dns-address.nix` — the `lo` bind + composed advertisement
* `modules/config/tailnet-policy.hujson` — the tailnet policy mirror (`autoApprovers`)
* `scripts/task/tailnet-routes.sh` — `ops:tailnet:routes` / `ops:tailnet:approve`
* `scripts/task/tailnet-policy.sh` — `ops:tailnet:policy` / `ops:tailnet:policy:apply`
* `scripts/task/lib/tailnet-api.sh` — token resolution shared by both
* `scripts/task/dns-failover-check.sh` — the check behind `checks:dns:failover`
* `hosts/frieren/dns.nix` — the primary declaration
* `docs/frieren-access.md` — service-access matrix
