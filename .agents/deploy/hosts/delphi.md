# delphi — OCI Ampere A1 provisioning & verification

Contract: `inventory.toml [hosts.delphi]`, `flake/host-inventory.nix`.
Config: `hosts/delphi/{configuration,disko,hardware-configuration}.nix`.
Nothing here is executable truth — the commands are the runbook, the flake is the config.

**Target:** OCI `VM.Standard.A1.Flex`, **2 OCPU / 11 GiB** (measured; the 4 OCPU / 24 GB
figure was the shape ceiling, not what was created), aarch64-linux, 200 GB paravirt
boot volume on `/dev/sda` (GPT/UEFI, confirmed by `lsblk`).
Reached as `ubuntu@92.5.115.103` pre-install, `devji@92.5.115.103` after.

Four jobs: **webserver** (nginx + `/healthz`), **hermes agent** (CLI + gateway,
own Telegram bot), **tailnet resolver** (crab-hole on the shared `10.99.0.53`), and
the **`sandbox` microVM guest** that `/microvm/*` is served from.

## Guest layer — the `sandbox` microVM

Declared in `hosts/microvms/guests.nix`; rationale and the traps that shaped it are
in the `AGENTS.nix` note `microvm-guests` (`task ops:notes:show ID=microvm-guests`).

| What | From a workstation | From delphi |
| :--- | :--- | :--- |
| Guest root shell | not reachable (bridge is host-local) | `ssh sandbox`, or `task microvm:ssh NAME=sandbox` |

`ssh delphi.bountystash.com` is the **host** shell as `devji`. `sandbox` resolves only
from delphi because `192.168.83.0/24` is host-local.

The terminal deck (`slides`) is **off**: it is a development facility, not a service,
and it leaked a TUI per abandoned login — under TCG three of them were 0.65 of the box's
two cores. `slidesUser = "slides"` plus `exposeSsh = 2222` in
`flake/host-inventory.nix` brings it back; the module side is still in
`hosts/microvms/guests.nix`.

HTTP lives in the guest too: `/microvm/one/` and `/microvm/two/` (busybox stubs) on
both hostnames, `/microvm/stirling/` on the tailnet only (public answers 302).

## Install (moved)

The fresh-install walkthrough — phases 0 to 5, including the OCI security-list
traps and the HTTPS/autoUpgrade path — is [`docs/delphi-install.md`](../../../docs/delphi-install.md).
What a running delphi needs instead is below: the guest layer, the tailnet mounts,
the compiled surfaces, and the traps.


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

## Tailnet service mounts (one port per service)

Everything reachable from the tailnet is a loopback listener plus a
`tailscale serve` mount; nothing here is added to the public vhost. tailscaled
terminates TLS, so there is no certificate to own per service.

| Port | Service | Unit | Upstream |
| :--- | :--- | :--- | :--- |
| 8443 | DeepSeek Harness | `tailscale-serve-dsh` | `127.0.0.1:3080` |
| 8444 | System One decisions (`/v1/systemone`) | `tailscale-serve-systemone` | `127.0.0.1:8091` |
| 8445 | Stirling PDF | `tailscale-serve-pdf` | `127.0.0.1:7351` |
| 8446 | Service console (the compiled tailnet portal) | `tailscale-serve-portal` | `127.0.0.1:8082` |

Both the mounts and the console are compiled from `services.servicePortal` in
`hosts/delphi/configuration.nix`: add a mount and its card appears, remove one and
the card goes. Nothing on this page is hand-written — `data/services.json`
carries the same list for a TUI or a probe, and the asserts in
`modules/services/service-portal.nix` fail the build when a mount has no card, a
card has no owner, two mounts share a port, an upstream is not loopback, or a
`requires` names a unit that does not exist.

## The two surfaces: a dossier and a console (`lib/delphi-site.nix`)

Delphi serves two documents, and they are two projections of ONE evaluated
structure — not two pages kept in step by hand:

| Surface | Address | What it is |
| :--- | :--- | :--- |
| Dossier | `https://delphi.bountystash.com` | The portfolio page: the project, the machine, what runs here, the operating envelope, and the fleet it belongs to |
| Console | `https://delphi.cloudforest-kardashev.ts.net:8446` · `http://delphi.cloudforest-kardashev.ts.net/` | The tailnet service list: every mount, its port, and the unit it waits on |

Where the values come from — all of them evaluated at build time:

| Fact | Source |
| :--- | :--- |
| role, hardware, notes, traits, constraints, declared services | `inventory.toml` via `lib/inventory.nix` |
| device / status / kind / arch counts, skills, docs, edges | `lib/knowledge-graph.nix` + `lib/skills.nix` |
| the cards, their ports, upstreams and `requires` | `config.services.servicePortal.cards` (the same declaration that generates the mount units) |
| public name, tailnet name, tailnet address | `inventory.toml [hosts.delphi.network]` |
| resolver address | `config.profiles.tailnetDnsAddress.address` |
| NixOS release | `config.system.nixos.release` |

Markup lives in files (`lib/delphi/{shell,public,tailnet}.html`, `juno.css`,
`juno.js`), and `render` in the compiler throws on an unbound `{{hole}}`, so a
renamed field fails the build instead of shipping braces. `data/delphi.json` is
the compiled structure itself, for a TUI, a probe or an agent.

Three rules the pages are built to keep:

- **A tailnet address never appears on the public page.** The console prints
  `host:port`; the dossier prints the *count* of tailnet services and their names,
  with the addresses withheld.
- **The pages never claim liveness.** They are structure, not telemetry: a card
  says where a service is, never that it is up. No value is sampled, so nothing
  can look live while being stale.
- **The `tailnet name` at the root is source-restricted, not authenticated.**
  nginx holds `0.0.0.0:443` for the public ACME vhost, so tailscaled cannot take
  443 (measured 2026-10-21: `bind: address already in use`). The console's TLS
  entry point is therefore the `:8446` mount, and the MagicDNS name also answers
  on `:80` behind `allow 100.64.0.0/10; deny all;` — the client's tailnet address
  is what admits it, so the name is inert from the internet even though the
  listener is the same one the public vhost uses.

Preview it without touching the host:

```bash
nix eval --raw .#delphi-site.outPath    # the tree nginx serves, cards included
nix build .#delphi-site --print-out-paths
```

`.#delphi-site` **is** `config.system.build.delphiSite` — the host's own
instantiation, with `services.servicePortal.cards` — so the preview cannot be a
second page wearing the same name. It is defined for `aarch64-linux` only, and
because it is a host evaluation it costs one to evaluate; building it needs an
aarch64 builder (or this host). Without the card registry the compiler throws at
eval instead of rendering a console with no services in it.

A deploy can still leave the previous tree serving (a boot-only activation, a
rollback, a flake ref that did not move). The vhosts emit `X-Site-Path`, so ask
the server instead of trusting the log:

```bash
task checks:site:path                   # exit 1 = the live tree is not this tree
```

It sends one request with a timeout — no ssh, so it cannot hang on an interactive
auth check — and compares the header with `nix eval --raw .#delphi-site.outPath`.
Exit 2 means nobody answered or the serving generation predates the header.

A port is the mount, not a path: `tailscale serve` proxies a whole origin, so a
new service takes the next free number rather than a location under an existing
one.

**Stirling is a JVM.** After a switch `stirling-pdf.service` reports `active`
while `tailscale serve` still answers **502** for about a minute; measured
2026-10-21, first 200 at ~60 s. Read the log for `Stirling-PDF Started.` rather
than trusting `ActiveState`, and do not treat the 502 as a broken mount. It was
moved off frieren because it is stateless — the old bookmark `pdf.frieren.lan`
now points at a closed port on frieren, so the URL is the tailnet one above.

Verify the whole set at once:

```bash
ssh delphi 'sudo tailscale serve status'
getent hosts delphi.cloudforest-kardashev.ts.net      # the name must resolve
curl -s https://delphi.cloudforest-kardashev.ts.net:8444/health
```

The decision envelope is the standard-library engine, not eisen's Laya:
`POST /v1/systemone` with `{"state": …, "questions": {id: {type, instructions,
criteria}}}` returns `answers` + `usage`, and `GET /` or `/health` is the probe.
It answers in under a millisecond because it is a deterministic scoring pass, not
a transformer inference — so it is a fallback for shape, not for Laya's accuracy.

## DNS failover topology

Why `10.99.0.53`, what a VIP buys and how the pair is approved: `docs/dns-failover.md`.
delphi is the only member today — frieren binds its own tailnet address only — so the
/32 is served by delphi alone.

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
