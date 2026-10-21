# delphi — OCI Ampere A1 provisioning & verification

Contract: `inventory.toml [hosts.delphi]`, `flake/host-inventory.nix`.
Config: `hosts/delphi/{configuration,disko,hardware-configuration}.nix`.
Nothing here is executable truth — the commands are the runbook, the flake is the config.

**Target:** OCI `VM.Standard.A1.Flex`, **2 OCPU / 11 GiB** (measured; the 4 OCPU / 24 GB
figure was the shape ceiling, not what was created), aarch64-linux, 200 GB paravirt
boot volume on `/dev/sda` (GPT/UEFI, confirmed by `lsblk`).
Reached as `ubuntu@92.5.115.103` pre-install, `devji@92.5.115.103` after.

Three jobs: **webserver** (nginx + `/healthz`), **hermes agent** (CLI + gateway,
own Telegram bot), **tailnet resolver** (crab-hole on the shared `10.99.0.53`).

## Phase 0 — facts first (measured 2026-10-20)

```bash
ssh -i ~/.ssh/'ssh-key-2026-10-20(1).key' ubuntu@92.5.115.103 \
  'uname -m; nproc; free -h | head -2; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT; cat /proc/sys/kernel/kexec_load_disabled'
```

Settled facts: `aarch64`; **2 cores / 11 GiB** (the whole build budget — never compile
locally); boot disk `/dev/sda`; `CONFIG_KEXEC_FILE=y`, `kexec_load_disabled=0`, no
lockdown → nixos-anywhere can kexec; no IPv6 uplink (why crab-hole's upstreams are
IPv4 DoT).

## Phase 1 — sops bootstrap (before any install)

`sops-install-secrets` fails *activation* when a declared key cannot be decrypted, and
a failed activation aborts the install. Two paths exist:

- **OCI images already ship host keys** at `/etc/ssh/ssh_host_*` (used here, 2026-10-20).
  Derive the recipient and keep the identity:
  ```bash
  ssh ... 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub' | nix run nixpkgs#ssh-to-age
  ```
  then carry the same files into the install with `--extra-files` (below).
- A fresh keypair is only needed if the image has none — `ssh-keygen` on the box, same
  conversion.

Add to `.sops.yaml`: `- &delphi age1…` under `keys:` **and** `- *delphi` in
`creation_rules[0].age`. Then `sops updatekeys` every file (the `infra:sops:update-keys`
task also commits and pushes the private secrets repo — do that deliberately, or run
`sops updatekeys` by hand and commit yourself).

`delphi` needs two keys beyond the fleet-wide ones: `hashedPassword` (exists) and
`delphi-telegram` (`TELEGRAM_BOT_TOKEN=…`, its own bot — frieren already polls the
first one and two pollers on one token fight). `delphi-private-key` already exists.

## Phase 2 — install

disko comes from the flake (`flake/host-inventory.nix`), so there is no `--disko` flag;
nixos-anywhere runs it. Verification of *this host* build happens on the host:

```bash
mkdir -p /tmp/delphi-extra/etc/ssh
scp -i ~/.ssh/'ssh-key-2026-10-20(1).key' \
  ubuntu@92.5.115.103:/root/.ssh/ssh_host_* /tmp/delphi-extra/etc/ssh/     # sudo: use `ssh … 'sudo cat …' > file`

nix run github:nix-community/nixos-anywhere -- \
  --flake .#delphi \
  --target-host ubuntu@92.5.115.103 \
  -i ~/.ssh/'ssh-key-2026-10-20(1).key' \
  --extra-files /tmp/delphi-extra \
  --build-on remote        # frieren is x86_64: local build of an aarch64 closure is impossible
```

`--build-on remote` evaluates and builds on the kexec'd aarch64 installer. Most of the
closure substitutes from cache.nixos.org / cache.numtide.com; only what is missing
compiles, on two cores. The LAN cache (`192.168.3.25`) is unreachable from OCI and only
costs a 5 s probe per miss.

**Recovery, and it matters:** if the flake fails *after* disko has wiped the disk (the
2026-10-20 run failed twice this way), the installer keeps SSH — nixos-anywhere copies
the target's `~/.ssh/authorized_keys` to `/root/.ssh` before kexec, so the OCI key still
opens `root@`. The disk stays formatted and mounted at `/mnt`, so skip the destructive
phases:

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#delphi \
  --target-host root@92.5.115.103 -i ~/.ssh/'ssh-key-2026-10-20(1).key' \
  --extra-files /tmp/delphi-extra --build-on remote --phases install,reboot
```

Never `--phases kexec,disko` again on a host that already lost its disk: that is a second
wipe for no reason. Rapid SSH probes from one source trip the installer's
`MaxStartups` ("Not allowed at this time") — space the attempts out.

## Phase 3 — first boot repairs (only on a fresh install)

1. **`~/.config` is root-owned**, so `home-manager-devji` fails with
   `mkdir: cannot create directory '/home/devji/.config/…': Permission denied`.
   `sudo chown -R devji:users /home/devji/.config`, then `systemctl restart home-manager-devji`.
2. **The user secret plane needs an age identity — now declarative.** `modules/sops.nix`
   declares ten Home-Manager secrets (`ghsudo`, `ssh_user_ca_private_key`, …) against
   `~/.config/sops/age/keys.txt`, which a fresh VM does not have; the user
   `sops-nix.service` then failed with `0 successful groups required, got 0` and took HM
   activation with it. This host has no `~/.ssh/id_ed25519` (logins are CA certs), so
   there was nothing to derive from by hand. `profiles.sopsUserIdentity.enable = true`
   now derives the identity from `/etc/ssh/ssh_host_ed25519_key` during activation, which
   is **exactly** the `&delphi` recipient already in `.sops.yaml` — no new key, no rekey.
   Verified: `age-keygen -y ~/.config/sops/age/keys.txt` → `age1fg8xy2g…`, `sops -d`
   succeeds as `devji`. The one-time manual copy it replaced (frieren's identity) is gone.
   Procedure and the general case: [`docs/sops-rekey.md`](../../../docs/sops-rekey.md).

## Phase 4 — cloud-side work no config can do

- **OCI security list — OPEN as of 2026-10-20 10:32.** Public `http://92.5.115.103/healthz`
  → `200`; `/` → `200`, `<title>delphi</title>`; `tcpdump` on `enp0s6` shows the full
  SYN → SYN-ACK → ACK handshake from the WAN address. 443 arrives and is answered with a
  **RST** — `Connection refused`, not a timeout: open at the edge, no listener behind it
  yet, which is the correct shape. The host firewall was never involved
  (`iptables -S nixos-fw`: `--dport 80` and `--dport 443` both `ACCEPT`).

  **The trap that cost the first attempt:** the ports were entered in **Source** Port Range
  instead of **Destination**. An inbound connection arrives at port 80 *from* a client's
  ephemeral port, so "source port 80" matches nothing and every packet is dropped
  silently — no host-side symptom at all. Correct shape: Ingress · Stateless **No** ·
  Source type CIDR `0.0.0.0/0` · source port **All** · destination port **`80,443`** · TCP.
  The console splits `80,443` into two rules; the API needs two `tcpOptions` entries,
  because `min:80,max:443` would also open 81–442.

  Ingress is **not** paywalled on Always Free — 80/443 are closed only because the VCN's
  default security list ships with 22. If the VNIC is in a **Network Security Group**, the
  rule must exist there too: SL and NSG are both filters, not alternatives.

  ```bash
  # CLI equivalent (needs an API key; console is fine without one)
  oci network security-list list --compartment-id <tenancy-ocid> --vcn-id <vcn-ocid>
  oci network security-list update --security-list-id <sl-ocid> \
    --ingress-security-rules '[{"source":"0.0.0.0/0","protocol":"6","isStateless":false,
      "tcpOptions":{"destinationPortRange":{"min":80,"max":80}}}]'
  # update replaces the WHOLE list — read it first and append, or you drop the 22 rule
  ```

  **Decisive test — host-side or edge-side?** Watch the wire while probing from outside:
  a `tcpdump` with **0 captured packets** means OCI dropped it before the NIC, so stop
  looking at nftables (`http://example.com` from the same source is the control that the
  probe path is sound). A SYN that arrives and gets no reply is a host or service problem.
  If 0 packets reappear, the rule is attached to the wrong object — check, on the VNIC
  page for
  `10.0.0.57` in subnet `10.0.0.0/24`, check in this order (VNIC OCID:
  `ocid1.vnic.oc1.eu-frankfurt-1.abtheljt4apsgmwin4cm5ueifx3xlipze3o7gtbqbdrk3pmk4wteeaoi2vsq`):
  1. the **Security Lists** link — a subnet can use a *custom* list, in which case
     editing the VCN's *Default* Security List changes nothing;
  2. the **Network Security Groups** link — an attached NSG allows nothing unless the
     rule is there too (SL and NSG are both filters, not alternatives);
  3. that it is an **Ingress** rule with source type *CIDR* `0.0.0.0/0` (not *Service*),
     protocol TCP, and the ports in **Destination** Port Range;
  4. that the rule is on the VCN this instance is actually in (eu-frankfurt-1, subnet
     `10.0.0.0/24`), not a second VCN in the tenancy.

  Two OCI facts that bite later: **outbound TCP 25 is blocked tenancy-wide** (spam policy,
  no opt-out on free tier — use a relay on 587 if hermes ever sends mail), and the
  **ephemeral public IP changes on stop/start** unless it is reserved — pin it before
  pointing DNS or ACME at it. Nothing listens on 443 yet: nginx has a :80 vhost only, so
  443 is opened for the future TLS vhost, not for a live service.
- **Tailscale login:** backend starts in `NeedsLogin`.
  `sudo tailscale up --accept-dns=false --accept-routes=true --advertise-exit-node --advertise-routes=10.99.0.53/32`
  prints the `https://login.tailscale.com/a/…` URL; approve it, then approve the exit
  node **and** the `10.99.0.53/32` route in the admin console.
- **Tailnet DNS:** the global nameserver list is `10.99.0.53` only (override local DNS).
  Tailscale does not fail over between two nameservers, so listing frieren and delphi
  separately loses DNS when the first dies.

## Phase 4d — the 10.99.0.53 failover pair (done 2026-10-20)

Both hosts bind `10.99.0.53/32` on `lo` through
`modules/profiles/tailnet-dns-address.nix` (one module, not a copy) and both
advertise it. Tailscale has no floating address: two nodes advertising the SAME
subnet route become a failover set, and the route moves to the survivor in
~15 s. Listing two nameservers in the tailnet settings does **not** work — a
client that loses the first one does not retry in time.

```bash
ip -4 addr show lo | grep 10.99.0.53        # both hosts: 10.99.0.53/32
sudo tailscale debug prefs | jq .AdvertiseRoutes   # both list 10.99.0.53/32
sudo tailscale status --json | jq .Self.PrimaryRoutes  # APPROVED routes only
dig +short @10.99.0.53 example.com          # whoever currently holds the route
```

Three things that are not obvious:

- **`extraSetFlags` is a boot-time oneshot (`tailscaled-set.service`).** A
  `nixos-rebuild switch` does not re-run it, so after changing the flag run
  `sudo tailscale set --advertise-routes=…` by hand or the declaration is only
  true after the next boot.
- **One comma-separated `--advertise-routes` flag, not two.** `tailscale set`
  replaces the whole route set, so a second flag would silently drop the first.
- **Approval is per node and not declarable from here.** `PrimaryRoutes` is the
  only honest check — `AdvertiseRoutes` shows what was offered, not what the
  tailnet accepted. There is no Tailscale API key in sops, so approve it in the
  admin console (Machines → the node → Edit route settings), or add a
  `autoApprovers` block to the tailnet policy file to stop doing this per host.

## Phase 4c — HTTPS (done 2026-10-20)

`publicDomain = "delphi.bountystash.com"` in the host config is the whole switch:
`enableACME` + `forceSSL` generate the :443 server, the :80 redirect and the ACME
renewal timer. The only non-declarable step is the **DNS record**: a **DNS-only**
A record to the instance (`proxied = false`). A proxied (orange-cloud) record
cannot work — HTTP-01 would be answered by Cloudflare, not the origin.

```bash
# created via the API, token in sops CLOUDFLARE.API.TOKEN (modules/secrets/apikeys.yaml)
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
  -d '{"type":"A","name":"delphi","content":"92.5.115.103","ttl":300,"proxied":false}'
```

**The trap that cost an hour:** do not declare `listen = [{port = 443; ssl = true;}]`
on the vhost by hand. It suppresses the `listen` on the *generated* :80 redirect
block, so that block lands in a different listen group from the IP-addressed
default vhost; the exact `server_name` then never matches, HTTP-01 gets **404
while the token sits in `/var/lib/acme/acme-challenge`**, and the journal reads
"your DNS records are set up incorrectly" — which is a lie. Let `forceSSL`
generate both blocks.

Diagnose with the server-selection test, not with DNS:
`curl -o /dev/null -w '%{http_code} %{redirect_url}' -H 'Host: delphi.bountystash.com' http://127.0.0.1/`
must answer `301`; a `200` means the default vhost is catching the request and
ACME can never succeed.

## Phase 4b — rebuilding from the pushed flake (the autoUpgrade path)

Once a change is on `main`, the host can update itself exactly the way the daily
job will:

```bash
ssh delphi 'sudo nixos-rebuild switch --refresh --flake github:shaoyanji/nixconfig#delphi'
```

**Use `--refresh`, or pin the rev, while iterating.** `github:` resolves the branch
with the tarball fetcher, which caches branch→rev for `tarball-ttl` (1 h). A rebuild
that was started and then killed leaves the cache pointing at the OLD rev, so the
next run rebuilds the old tree and reports *its* failures. Measured 2026-10-20: a
run after pushing `90f4bc7d` rebuilt `c109d65a` and failed on `AGENTS-delphi.md.drv`,
an x86_64-pinned derivation that was already fixed — a false failure that costs an
hour of looking in the wrong place. Prefer an explicit rev
(`--flake github:shaoyanji/nixconfig/<rev>#delphi`) when what you want to prove is
"does the pushed tree build"; use `--refresh` for an ordinary update.

A healthy switch ends at generation N with the pushed rev as the configuration
revision — `90f4bc7d` here, 0 failed units, `/healthz` 200 on both loopback and the
public IP.

## Phase 5 — verification

```bash
curl -fsS http://92.5.115.103/healthz                     # needs the security-list hole
ssh devji@delphi 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/healthz'
ssh devji@delphi 'systemctl is-active nginx crab-hole tailscaled; systemctl --failed --no-legend'
ssh devji@delphi 'dig +short @10.99.0.53 github.com'
ssh devji@delphi 'dig @10.99.0.53 doubleclick.net +noall +comments | head -1'   # NXDOMAIN = blocked
ssh devji@delphi 'systemctl --user status hermes-gateway; journalctl --user -u hermes-gateway -n 5'
# Fleet monitors (a second vantage OUTSIDE the LAN). Tailnet-only: bound to
# 0.0.0.0 because the tailnet address is assigned at login, reachable only via
# the tailscale0 firewall rule — :8181 on the public IP is refused by design.
curl -s http://100.123.145.53:8181/api/v1/endpoints/statuses \
  | jq -r '.[] | "\(.group)\t\(.name)\t\(.results[-1].success)"'
# TLS: expect a valid Let's Encrypt chain, 200, and the :80 redirect.
curl -sS --resolve delphi.bountystash.com:443:92.5.115.103 \
  -o /dev/null -w '%{http_code} verify=%{ssl_verify_result}\n' https://delphi.bountystash.com/healthz
```

`task checks:dns:failover` does **not** cover this host: it reads the LAN `resolvers`
group out of frieren's declaration and probes a LAN zone. The tailnet group is verified
with `dig` against `10.99.0.53`.

## DeepSeek Harness (tailnet only)

The harness runs **here** so a thin client can use this host's CPU, disk and
workspaces from its own browser. It is published on the **tailnet only**:
`tailscale serve` terminates TLS at the MagicDNS name and proxies to the loopback
app, so the public vhost carries the landing page and `/healthz` and nothing else.

- `services.dshWeb` — loopback `:3080`, `--public-url
  https://delphi.cloudforest-kardashev.ts.net:8443/`, `--trusted-host` the same
  `host:port`. Mounted at the root, so there is no prefix to strip.
- `tailscale-serve-dsh.service` — `tailscale serve --bg --https=8443
  http://127.0.0.1:3080`. tailscaled issues and renews the certificate (no ACME,
  no cert file to own); 8443 because nginx owns `0.0.0.0:443`.
- `Host` survives the front (measured: `Host: delphi.cloudforest-kardashev.ts.net:8443`
  reached the upstream verbatim), which is load-bearing twice — dsh fences `/api`
  on the authority and keys the session cookie to it.

Verify from a *client*, not from the host:

```bash
getent hosts delphi.cloudforest-kardashev.ts.net    # must resolve (see below)
dsh-remote --status                                 # service + ingress + real probe
curl -s -o /dev/null -w 'public=%{http_code}\n' https://delphi.bountystash.com/deepseek/   # 404
```

**An unsigned worker is not a dead end, but it has exactly two doors.** Upstream
accepts the DeepSeek OAuth callback only on a loopback origin with an explicit
port (`dsh-deepseek-account-platform` `loginOrigin()`, whose own comment reads
"remote domains and path-based proxies are unsupported"; the UI passes
`window.location.origin`). So the in-page Sign-in button cannot complete through
`/deepseek/` — it fails with a protocol error, not a network one. The launcher
covers both working doors:

```bash
dsh-remote --login       # temporary 127.0.0.1:<port> forward; sign in there, and
                         # the forward closes itself when the credential lands
dsh-remote --sync-auth   # import a signed-in client's ~/.dsh credential over ssh
```

The harness needs no account to *boot*: measured with the credential moved aside,
`dsh-web` stayed active, published its URL and served the page (`200`), and
`--status` reported `account NONE` instead of looking broken.

**It needs a model key as well as the account grant.** A signed-in worker whose
env lacks `DEEPSEEK_API_KEY` fails every turn with `MISSING_CREDENTIAL … no API
key for provider route "deepseek-official"` — the account is fine, the model is
not. `services.dshWeb` renders the key from sops into the unit's
`EnvironmentFile` (`/run/secrets/rendered/dsh-web.env`); a login shell does **not**
inherit it, so reproduce a turn with the unit's env and never with `dsh` alone:

```bash
ssh delphi 'set -a; . /run/secrets/rendered/dsh-web.env; set +a; dsh --profile headless "reply OK"'
ssh delphi 'tr "\0" "\n" < /proc/$(systemctl show -p MainPID --value dsh-web)/environ | grep -c "^DEEPSEEK_API_KEY=sk-"'
```

**Operating it.** It is a systemd unit, not a tmux window — Ctrl+C in a shell
does nothing to it, and an open tab outlives any restart:

```bash
ssh delphi sudo systemctl stop dsh-web       # app down; nginx keeps :443, so /deepseek/ 502s
ssh delphi sudo systemctl disable dsh-web    # stays down across boots (it ships enabled)
ssh delphi sudo systemctl restart dsh-web    # the EnvironmentFile is read at start
```

Stopping `dsh-web` takes the app down for tailnet clients too; the front keeps
listening and answers `502`. `sudo systemctl stop tailscale-serve-dsh` is what
removes the entry point itself — the public vhost never carried it.

**The name does not resolve by default, and that is the one client-side step.**
The fleet resolver pins `~.` to its own DNS, so `*.ts.net` returns nothing
(`getent hosts` on frieren before the 2026-10-21 rebuild: empty). The mapping now
lives in `modules/profiles/base-node.nix` (`networking.hosts`), stated once for
the fleet; `dsh-remote` names a missing entry instead of blaming the worker.

**Why it left the public internet.** The vhost used to publish `/deepseek/`
behind nothing but a bearer token, while the worker runs as `devji`, whose
`~/.ssh/user_ca_key` is the fleet user CA — a leaked URL was fleet SSH authority,
not a chat pane. Measured after the move: public `/deepseek/` **404**, tailnet
page `200` with six sockets to `:3080`. What is still open is the worker's own
shell as `devji`: a dedicated user without a `~/.ssh` is the next step.

**The network is asymmetric and the fleet link is the bottleneck** (measured
2026-10-21): 172 MB/s down (~1.38 Gbps), 54 MB/s up (~430 Mbps), 101 MB/s sync
disk write — but only 50/20 Mbps over WireGuard to frieren. Never point this
host's substituters at the LAN cache: pull from upstream at line rate and push to
Cachix, which is also why `01e9906e` decoupled it.

`tailscale serve` cannot take 443 on the tailnet address while nginx holds
`0.0.0.0:443` (`bind: address already in use`, measured 2026-10-21), which is why
the front listens on 8443. That port is visible only inside the tailnet.

## DNS failover topology (why 10.99.0.53)

Every resolver binds `10.99.0.53/32` on `lo` (`systemd.services.dns-service-address`)
and advertises the **same** /32 as a subnet route; identical /32s form one
active/passive group and Tailscale moves the route when a node disappears (~15 s).
`--accept-dns=false` on the resolver itself, or it resolves through the address it
serves.

**Status: delphi is the only member.** frieren still binds only its own tailnet
address, so `10.99.0.53` is served by delphi alone until frieren also binds and
advertises the /32 — a change to the fleet's only resolver, deliberately not made here.

## Fixed during this install (they were not config typos)

- `disko` has **no `label` option** on a filesystem content — a stable handle comes from
  the partition `name` (`disk-main-root`, `disk-main-ESP`). Caught by `checks:host MODE=eval`.
- **crab-hole v0.1.12 has no `tcp` downstream protocol** (`udp|tls|https|quic`). No
  DNS-over-TCP, so no truncation retry. Caught only by the build (`validate-config`).
- **`.#homeAgents.<host>` was an x86_64-pinned derivation** (`agentDocs.writeText`), so
  no aarch64 host could build its `~/AGENTS.md`; it is pure text and is now
  `builtins.toFile`. Caught only by the build on the target.
- **User lingering was undeclared fleet-wide** (frieren had `loginctl enable-linger` by
  hand). `users.users.devji.linger = true` on delphi is what lets `hermes-gateway`
  survive logout and start at boot.
