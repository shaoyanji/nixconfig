# frieren service access runbook

How to reach the services on `frieren` (NAS / core services host) from each network
context. Source of truth for the wiring: `hosts/frieren/reverse-proxy.nix` (nginx
vhosts), `hosts/frieren/dns.nix` (FTL DNS + tailscale), `hosts/frieren/configuration.nix`
(firewall), `modules/profiles/desktop-client.nix` (client-side accept flags).

## Host facts

| Fact | Value |
|------|-------|
| LAN address | `192.168.3.25` |
| Tailnet address | `100.97.61.65` |
| MagicDNS name | `frieren.cloudforest-kardashev.ts.net` |
| Subnet router | advertises `192.168.3.0/24` (approved; `tailscale set --advertise-routes` at boot via `extraSetFlags`) |
| Exit node | **None** — internet traffic never routes through frieren |
| No-exposure policy | No port forwards, no DDNS, no tunnels — the box is unreachable from the public internet by design |

## Network contexts

| Context | Name resolution | How to reach services |
|---------|-----------------|----------------------|
| Same LAN (`192.168.3.0/24`) | FTL answers `*.frieren.lan → 192.168.3.25` (any DHCP client pointing at frieren for DNS; router DNS still resolves the bare IP) | `http://<name>.frieren.lan` or `http://192.168.3.25:<port>` |
| Tailnet device with subnet route accepted | Same as LAN (queries go through frieren's FTL or local resolver) | Same `*.frieren.lan` URLs — the route installs `192.168.3.0/24` via tailscaled |
| Tailnet device without accept-routes | MagicDNS only | Direct tailnet addresses: `http://100.97.61.65:<port>` (nginx vhosts key on `Host`, so use the port, not a hostname) |
| Off-LAN, non-tailnet | — | **No access.** Temporary door: `sudo tailscale funnel <port>` on frieren, revoked with `sudo tailscale funnel off` |

Client-side, `--accept-routes=true` is set via `tailscale.extraSetFlags` on all
desktop-client hosts and eisen (works on already-authenticated nodes; `extraUpFlags`
only apply with `authKeyFile`, which no host uses). Tailscaled skips installing the
route on hosts that are physically on the LAN — their native path wins.

## Service matrix

### Via nginx (vhost `*.frieren.lan` on port 80, firewall open LAN-wide)

| Service | URL (LAN / route-accepted tailnet) | Direct tailnet | Backend |
|---------|-----------------------------------|----------------|---------|
| Portal landing page | `http://frieren.lan` (also `nas.frieren.lan`, `nas.lan`, `frieren`) | `100.97.61.65:80` | static page |
| Immich | `http://photos.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:2283` |
| Paperless-ngx | `http://docs.frieren.lan` | `100.97.61.65:80` | delphi `:28981` over the tailnet (moved 2026-11-02) |
| Jellyfin | `http://media.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:8096` |
| Stirling PDF | `http://pdf.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:7351` |
| AriaNg | `http://aria.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:6801` |
| Home Assistant | `http://ha.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:8123` |
| Fleet monitors (gatus) | `http://100.123.145.53:8181/` (delphi, tailnet only) | — | moved off this host 2026-11-04 |
| Scrutiny | `http://smart.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:8124` |
| Vaultwarden | `http://vault.frieren.lan` | `100.97.61.65:80` | delphi `:8222` over the tailnet (moved 2026-11-02) |
| Harmonia (nix cache) | `http://cache.frieren.lan` | `100.97.61.65:80` | `127.0.0.1:5000` |

### Direct ports (bypass nginx; firewall-open per `configuration.nix` / stack modules)

| Service | Port | Reachable from |
|---------|------|----------------|
| Jellyfin | 8096 | LAN + tailnet (device discovery / DLNA prefer the raw port) |
| Paperless-ngx | 28981 | **delphi** only, tailnet (moved 2026-11-02) |
| Stirling PDF | 7351 | LAN + tailnet (declared in `hosts/frieren/networking.nix`) |
| Home Assistant | 8123 | LAN + tailnet |
| AriaNg | 6801 | LAN + tailnet |
| Fleet monitors (gatus) | 8181 | delphi, tailnet only (no equivalent port here since 2026-11-04) |
| Scrutiny | 8124 | LAN + tailnet |
| SMB / NFS | 445, 139 / 2049 | NFS on both; SMB LAN only (the roaming mount is NFS) |

Link-local discovery and provisioning stay on the wire and open no mesh hole:
mDNS/SSDP/WS-Discovery, NetBIOS `137`/`138` and Chromecast `32410-32414`, plus
DHCP/PXE `67`/`69`/`4011` (nothing on a tailnet broadcasts). SMB `139`/`445` is LAN
only too: the roaming mount is NFS, and `profiles.nas-client` falls back to
`mount -t nfs` over the tailnet — which is why NFS `2049` stays open on both.

### Loopback-only (no firewall opening)

| Service | Port | Access |
|---------|------|--------|
| Pi-hole admin (FTL webserver) | 8080 | `https://pihole.frieren.lan/admin` (nginx vhost, also a card on the portal); off-LAN via `ssh -L 8080:localhost:8080 frieren` then `http://localhost:8080/admin` |

DNS itself is reachable by design: UDP/TCP 53 is open on `enp1s0` (LAN) and
`tailscale0` (tailnet), so any client can use `192.168.3.25` or `100.97.61.65`
as its resolver and get FTL filtering.

## Client quick reference

```bash
# One-off on a tailnet client without persistent config:
sudo tailscale set --accept-routes=true

# Verify the LAN route is active on a client:
tailscale status --json | jq -r '.Self.PrimaryRoutes'
ip route show table 52   # tailscaled's route table

# Temporary public door (non-tailnet guest), revoked afterwards:
sudo tailscale funnel 7351   # https://frieren.<tailnet>.ts.net/...
sudo tailscale funnel off
```

## Gotchas

- **nginx keys vhosts on `Host`** — hitting `http://100.97.61.65` with no hostname
  lands on the default portal page, not the named services. Use ports for direct
  tailnet access.
- **`*.frieren.lan` records live in FTL** (`misc.dnsmasq_lines` in `dns.nix`) —
  they only answer for clients whose resolver path goes through frieren. A client
  using the router's DNS on a remote network gets NXDOMAIN; use the tailnet IP.
- **No global nameserver is set in the Tailscale admin console yet** — adding
  `100.97.61.65` there (plus `--accept-dns=true`, already declared via
  `extraSetFlags`) would give every tailnet client FTL filtering and `*.frieren.lan`
  resolution automatically.
- **Nothing here is internet-exposed.** If that ever changes, put an auth layer
  (Tailscale Funnel + identities, or Cloudflare Tunnel + Access) in front — do not
  port-forward.

## aria2 / AriaNg

AriaNg boots from a config object rendered at runtime, because the RPC secret
must not be baked into the store. The template pre-seeds the connection with the
base64 secret AriaNg's `getCurrentRpcSecret` expects; `ariang-site.service`
replaces the placeholder from sops.

AriaNg stores this object at localStorage `AriaNg.Options`, with the fields
directly on it and no `rpcList` key. `language` is load-bearing: the language
guard runs before the per-key default backfill, so an object without it throws in
`getCurrentRpcUrl` and the app dies before the first RPC call. The symptom is a
blank pane in a fresh browser while an already-open tab keeps working.
