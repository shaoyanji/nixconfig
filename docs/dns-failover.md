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

## Related

* `modules/profiles/dns-failover.nix` — the module
* `scripts/task/dns-failover-check.sh` — the check behind `checks:dns:failover`
* `hosts/frieren/dns.nix` — the primary declaration
* `docs/frieren-access.md` — service-access matrix
