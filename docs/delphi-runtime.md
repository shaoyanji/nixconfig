# delphi — runtime layer: harness, mounts, offloads, capsule, surfaces

What runs on delphi and how to verify it. How to reach the host, the `sandbox`
guest and what the install fixed stay in
[`.agents/deploy/hosts/delphi.md`](../.agents/deploy/hosts/delphi.md).

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
  reached the upstream verbatim). Two things depend on it: dsh fences `/api` on the
  authority, and the session cookie is keyed to it.

Verify from a *client*, not from the host:

```bash
getent hosts delphi.cloudforest-kardashev.ts.net    # must resolve (see below)
dsh-remote --status                                 # service + ingress + real probe
curl -s -o /dev/null -w 'public=%{http_code}\n' https://delphi.bountystash.com/deepseek/   # 404
```

**An unsigned worker has exactly two ways in.** Upstream
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

Stopping `dsh-web` takes the app down for tailnet clients too, and the front then
answers `502`; `sudo systemctl stop tailscale-serve-dsh` removes the entry point.

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
Cachix, which is also why `8f7cd042` decoupled it.

`tailscale serve` cannot take 443 on the tailnet address while nginx holds
`0.0.0.0:443` (`bind: address already in use`, 2026-10-21), hence 8443 — a port
visible only inside the tailnet.

## Tailnet service mounts (one port per service)

**Prove they answer, not that their units are up.** `services:validate:host:delphi`
asks systemd for the host's state, so a unit can be `active` behind a mount that
returns 502 — that is the failure this page's port table exists to notice:

```bash
task checks:delphi:endpoints                  # one line per mount, exit 1 on any refusal
task checks:delphi:endpoints FORMAT=toon
task checks:delphi:endpoints EXPECT=200        # strict: a 4xx becomes a failure
```

The list comes from `services.servicePortal.mounts`, so it cannot drift from the
config; the probe is the tailnet URL a person clicks. A 5xx, a refused connection
or a timeout fails, and a 4xx passes because auth-gated mounts (`radicale`) and
machine-facing ones (`email-archive`) refuse `/` by design.

Everything reachable from the tailnet is a loopback listener plus a `tailscale
serve` mount, never a public vhost; tailscaled terminates TLS, so no cert per service.

The port map — every tailnet mount and its loopback upstream, compiled in
`services.servicePortal.mounts` (`hosts/delphi/configuration.nix`):

| Port | Service | Required unit | Upstream |
| :--- | :--- | :--- | :--- |
| 8327 | Free-model gateway (OpenAI-compatible relay, bearer key under `~/.dsh/openai-gateway/`) | `dsh-free-models.service` | gateway port |
| 8443 | Free models dashboard (dsh's retired port, reused) | `dsh-free-models.service` | web port |
| 8444 | System One decisions (`/v1/systemone`) | `systemone-decision-serve.service` | `127.0.0.1:8091` |
| 8445 | Stirling PDF | `stirling-pdf.service` | `127.0.0.1:7351` |
| 8446 | Service console (the compiled tailnet portal) | `nginx.service` | `127.0.0.1:8082` |
| 8447 | SearXNG | `searx.service` | `127.0.0.1:8888` |
| 8448 | **free** — uptime-kuma retired 2026-11-26 (zero monitors; the checks are `services.fleetMonitors` on 8181) | — | — |
| 8449 | Agent turns (xs) — POST/GET `/v1/events`, bearer | `agent-turns-shim.service` | agent-turns port |
| 8450 | Email archive (NpgsqlRest; machine-facing, no `/` page) | `npgsqlrest.service` | `127.0.0.1:8080` |
| 8451 | **reserved** — the archive's document benchmark | — | — |
| 8452 | Mail atlas | `nginx.service` | mail-atlas port (`8085`) |
| 8453 | Zettel graph | `zettel-graph.service` | `127.0.0.1:8083` |
| 8454 | Mataroa console | `mataroa-console.service` | `127.0.0.1:8095` |
| 8455 | Miniflux | `miniflux.service` | `127.0.0.1:8098` |
| 8456 | Umami | `umami.service` | `127.0.0.1:8061` |
| 8457 | Radicale (CalDAV/CardDAV) | `radicale.service` | `127.0.0.1:5232` |
| 8458 | ntfy push | `ntfy.service` | `127.0.0.1:8096` |
| 8459 | Vikunja tasks | `vikunja.service` | `127.0.0.1:8097` |
| 8460 | Agent turns dashboard | `turns-dashboard.service` | `127.0.0.1:8099` |
| 8461 | Media relay (browse page + fuzzy search, range-served library) | `nginx.service` | `127.0.0.1:8094` |
| 8463 | Job pipeline board (appflow) | `nginx.service` | `127.0.0.1:8462` |
| 8464 | Job database (scraper, SQLite FTS5 search and JSON API) | `job-db-scraper.service` | `127.0.0.1:8101` |
| 8465 | Private deals (products, watchlists, price history and FTS5 deal search) | `private-deals.service` | `127.0.0.1:8102` |
| 8466 | Inventory site (fleet/personal assets, warranties, serials, value and FTS5 search) | `inventory-site.service` | `127.0.0.1:8103` |
| 8467 | Clanker runner (InstaBox VM state, wake/exec, Nix and agent-browser jobs with FTS5 history) | `clanker-runner.service` | `127.0.0.1:8104` |
| 8468 | Link vault (bookmark/research archive, extraction, collections, read states and FTS5 search) | `link-vault.service` | `127.0.0.1:8106` |

8462 is the board's loopback vhost, not a mount — `tailscale serve` and nginx
both bind, so a mount and its upstream never share a number. Mounts are a
sequential namespace: a retired mount's number stays free until a new service
argues for it, and collisions that happened are in note `delphi-ops-traps`.

Both the mounts and the console are compiled from `services.servicePortal`, and
`modules/services/service-portal.nix` fails the build when a mount has no card, no
owner, a shared port, a non-loopback upstream or a missing `requires`. A bound port
is a `profiles.serviceExposure` row (`tailnet` required; loopback-only = REDUNDANT,
which fails `checks:ports`), while a mount counts as SERVED-SERVE — not a hole.

## Offloaded services (2026-11-02)

Three services moved up from the NAS. They are **not** portal mounts and not
public: each binds every interface, is opened on `tailscale0` only, and its only
client is frieren's nginx one hop away. The names stayed on frieren, which is what
makes the move reversible — `docs/service-offload.md` is the procedure.

| Port | Service | State | Reached as |
| :--- | :--- | :--- | :--- |
| 28981 | paperless-ngx (`hosts/delphi/paperless.nix`) | `/var/lib/paperless`, SQLite + media | `http://docs.frieren.lan` |
| 8222 | vaultwarden (`hosts/delphi/vaultwarden.nix`) | `/var/lib/vaultwarden`, SQLite; websockets ride 8222 since 1.30 | `https://vault.frieren.lan` |
| 27701 | anki sync (`hosts/delphi/anki-sync.nix`) | `/var/lib/anki-sync-server` | `http://anki.frieren.lan` |

anki's only account takes its password from sops (`anki-sync/password`), rendered
as a systemd credential, not a plaintext option; the proof is
`systemctl show -p LoadCredential anki-sync-server`.

That account is **`devji`** and it is the only one. `bob` was the plaintext
placeholder and answers `403` on `/sync/hostKey` (measured 2026-11-06), so a
client still configured with `bob` fails at login, not at sync. The collection
was empty until 2026-11-06 — what a server looks like when no desktop has ever
synced to it. It was seeded by posting the 2018 schema-11 `collection.anki2`
from `/srv/data/german/audio/B1_Wortliste_DTZ_Goethe_vocabsentensesaudiotranslation.apkg`
to `/sync/upload`; the download now serves `B1_Wortliste_DTZ_Goethe` (5,264
cards, no media — every `[sound:…]` resolves to nothing). `decks/*.toml` —
connectors, drills, telc briefing, timed mock — are compiled by `anki-author`
and merged over it by `scripts/german/anki-push.sh --base <apkg> decks/…`: six
decks, 5,376 cards on 2026-11-06. Sequence and traps: `docs/service-offload.md`.

Protocol note for a scripted client: version 11 is an `anki-sync` JSON header
(`v`/`k`/`c`/`s`) plus a zstd body, `meta` needs `{"v":11,"cv":…}`, and a bare
JSON body is rejected with an unexplained `400` — what `deutsch-srs -backend
anki-sync` implements.

Complete since 2026-11-02: frieren's closure carries the three vhosts, proxying
`docs`/`vault`/`anki.frieren.lan` to this host's tailnet address, and
`offload-tunnel` is deleted. Nothing binds those ports on frieren — a client still
complaining about `host:27701` is pointing at the NAS instead of the name.

Nightly, `offload-bridge-push.timer` (03:10) mirrors the three trees to
`frieren:/srv/backup/offload/` with each SQLite database replaced by a
`sqlite3 .backup` snapshot, and `offload-bridge-ingest.timer` (every 10 min) pulls
`/srv/data/paperless/consume` — the scanner still drops into the NAS share.

Two traps: the first `nixos-rebuild switch` after a move starts the services on
an **empty** dataset (the archive arrives from `offload-migrate.sh`, which stops
them, copies, verifies and starts them again), and an aarch64 paperless build is
**~41 minutes** on this box — 20 derivations nothing substitutes, with spacy's
thinc/blis compiling C++ for a quarter of an hour. That is also why nothing here
narrows tesseract's languages: upstream's paperless module would re-apply the
narrowing to `package`, so both hosts import `modules/services/paperless-fork.nix`
instead.

## The Gemini capsule (`hosts/delphi/gemini.nix`)

The portfolio is also a capsule, compiled by `lib/gemini-portal.nix` from the
same `portfolio.json` the HTTPS page renders: `/index.gmi` and `/de/index.gmi`
(the profile, work, stack and record sections the index page shows), one
`/work/<slug>.gmi` per case study, and the two machine-readable documents
`/resume.json` and `/lebenslauf.json`.

| Name | Port | Certificate | Reachable from |
| :--- | :--- | :--- | :--- |
| `delphi.bountystash.com` | 1965 | the nginx vhost's ACME cert (`/var/lib/acme/delphi.bountystash.com`) | the internet (verified from frieren 2026-10-29; OCI's security list is console-side, so check it first if a client times out) |
| `delphi.cloudforest-kardashev.ts.net` | 1966 | `tailscale cert`, issued by `gemini-tailnet-cert.service` and renewed by its timer | the tailnet only (a `tailscale0` firewall rule) |

Two ports, not one: molly-brown's config has `Port` and `Hostname` but no listen
address (measured on `56d8dde`), so a second name needs a second instance. The
public one keeps the protocol's port.

**`gemini://bountystash.com` is not this capsule.** The apex is a Cloudflare
Pages site, so port 1965 there reaches an edge that does not speak Gemini. The
capsule answers on the host's own name: it already resolves here and already has
a certificate, while a `gemini.` label would need a new A record and a new ACME
line.

Verify from a client — the first line must be `20 text/gemini; charset=utf-8`.
This host's OpenSSL prints nothing for `s_client -quiet` (measured 2026-11-08),
so the working probe is the Python one in [`docs/gemini-mail.md`](gemini-mail.md).

### The two live readers, on the tailnet instance only

1966 is the portfolio plus two CGI readers, `/mail/` (`lib/gemini-mail.nix`) and
`/turns/` (`lib/gemini-turns.nix`), both linked from the index; 1965 still serves
the portfolio alone, with no trees and no `CGIPaths`. Mounting traps and the turn
token: [`gemini-mail.md`](gemini-mail.md), [`gemini-turns.md`](gemini-turns.md).

A renewed ACME certificate restarts `molly-brown` (`reloadServices`); the tailnet
certificate is re-issued by the daily `gemini-tailnet-cert` timer, which only
renews inside a 30-day window (`--min-validity=720h`). Logs:
`/var/log/molly-brown/` and `/var/log/molly-brown-tailnet/`.

## The compiled surfaces (`lib/delphi-site.nix`)

Delphi serves three documents, all projections of ONE evaluated structure — not
pages kept in step by hand:

| Surface | Address | What it is |
| :--- | :--- | :--- |
| Dossier | `https://delphi.bountystash.com` | The portfolio page: the project, the machine, what runs here, the operating envelope, and the fleet it belongs to |
| Terminal | the same name, asked with `curl`/`wget`/`nushell`/… | The dossier as one ANSI `text/plain` document: same counts, no address |
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
renamed field fails the build instead of shipping braces. `/data/delphi.json`
and `/data/services.json` on the console are the structure and cards, tailnet-
only: the dossier JSON names the tailnet address the public page withholds.

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

### The terminal edition

A command-line user agent (`curl`, `wget`, `httpie`, `xh`, `nushell`, `aria2`, the
library defaults) gets `/` as one ANSI `text/plain` document from `terminalDoc`,
rendered from the same `site`; every other client gets the HTML, because the match
is positive — a crawler must not lose the page. The list is `terminalClients`,
compiled into `$delphi_terminal` in `hosts/delphi/configuration.nix`:
`curl -s -A curl/8 <name>/ | head -3`, and `-A 'Mozilla/5.0'` must answer `text/html`.

Preview it without touching the host:

```bash
nix eval --raw .#sites.delphi-site.outPath    # the tree nginx serves, cards included
nix build .#sites.delphi-site --print-out-paths
```

`.#sites.delphi-site` **is** `config.system.build.delphiSite` — the host's own
instantiation, with `services.servicePortal.cards` — so the preview cannot be a
second page wearing the same name. It is `aarch64-linux` only and costs one host
evaluation; without the card registry the compiler throws at eval instead of
rendering a console with no services in it.

A deploy can still leave the previous tree serving (a boot-only activation, a
rollback, a flake ref that did not move). The vhosts emit `X-Site-Path`, so ask
the server instead of trusting the log:

```bash
task checks:site:path                   # exit 1 = the live tree is not this tree
```

One request with a timeout, no ssh: it compares the header with
`nix eval --raw .#sites.delphi-site.outPath` (exit 2 = nobody answered, or the
serving generation predates the header).

A port is the mount, not a path: `tailscale serve` proxies a whole origin, so a
new service takes the next free number rather than a location under an existing one.

**Stirling is a JVM.** After a switch `stirling-pdf.service` reports `active`
while `tailscale serve` still answers **502** for about a minute (measured
2026-10-21, first 200 at ~60 s): read the log for `Stirling-PDF Started.`, do not
treat the 502 as a broken mount. It lives here because it is stateless — the old
bookmark `pdf.frieren.lan` points at a closed port on frieren now.

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
