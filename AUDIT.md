# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-27)

Rows carrying a command were re-measured 2026-10-27 with it. The live-system rows
(observation, knowledge, backups, DNS, tailnet) were last confirmed 2026-10-20.

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 35 devices: 20 active (13 NixOS, 7 external), 15 preserved, 0 wip | `nix eval .#inventory.derived`, `task dev:inventory:counts` |
| Host gates | per-host eval (assertions) and per-host VM boot to stage-2, one process each | `.#hostChecks.x86_64-linux.<host>`, `.#hostBootChecks.aarch64-linux.delphi` |
| Known red gates | `cassini` (xdg.desktopEntries on darwin), dormant. `minyx` passes its gate on its own arch (`ARCH` now resolves per host, so no flag); its hardware is the shortfall, not its config: continuous under-voltage in `dmesg` | `task checks:host HOST=minyx` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | frieren pihole+unbound owns the zone, minyx blocky+keepalived is the secondary behind VIP `192.168.3.50` (priority 200/1, unicast peers); delphi crab-hole answers public DNS only, same address | `task checks:dns:failover`, `docs/dns-failover.md` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-10-30 — a NixOS build tracker runs on Always-Free AWS alone
- **The artifact is the reproducible unit, not the host.** `projects/nix-build-tracker/flake.nix`
  compiles the Go API to a static `linux/amd64` `bootstrap` in `installPhase` — `buildGoModule` pins
  `GOOS`/`GOARCH` to the build host and `go install` relocates a cross build to `bin/linux_amd64/` —
  then zips it with normalised mtimes, so `nix build --rebuild` reproduces the same store path on
  this aarch64 machine.
- **A Function URL with `AuthType=NONE` still 403s without two resource-policy statements:**
  `InvokeFunctionUrl` keyed on `lambda:FunctionUrlAuthType` and `InvokeFunction` keyed on
  `InvokedViaFunctionUrl`. The CLI creates neither, and the first alone never reaches the function.
- **This account cannot honour a reserved-concurrency guard.** Its Lambda ceiling is 10 in every
  region (AWS default 1000) and a reservation may not leave fewer than 10 unreserved, so
  `deploy.sh` reports the 5-execution guard as unapplied and exits 1 after finishing everything else;
  Service Quotas refuses any value at or below the 1000 default, so only AWS support can lift it.
- Evidence: `deploy.sh` run twice from `nix develop` and idempotent throughout (budget, table 5/5 ACTIVE,
  pool/client/domain, role, function, bucket, distribution reused); a real Cognito user saved and listed
  a build over the public URL (`201`/`200`), `401` with no token and with a forged one, `400` on a bad
  hash, CORS preflight `200`, direct S3 `403` (OAC only), CloudFront serving the injected page.

### 2026-10-30 — OCI CLI credentials come from sops, not a hand-made `~/.oci`
- **The credential survives the instance.** `modules/sops.nix` renders `~/.oci/config` (0600)
  from four `oci/*` secrets and writes `~/.oci/oci_api_key.pem` (0600), the same shape as
  `~/.aws/credentials`, so a fresh host authenticates without a copy step.
- **The five values are one unit** — a fingerprint from one keypair against another key file
  reads as `NotAuthenticated` and names neither half — so the doc's rotation procedure
  replaces both, in `modules/secrets.yaml` and the submodule mirror.
- **The template is 0600** because the CLI warns "Permissions on <config> are too open" on
  every command at 0644.
- Evidence: authenticated from a config assembled only from decrypted sops values
  (`oci iam region list`); PEM round-trips byte-identical to the key on disk; `task
  checks:sops:drift` green with the mirror check; `task checks:host HOST=delphi` rc=0, 8.2 s.

### 2026-10-29 — the fleet docs answer over Gemini on 1965
- **One projection, two protocols.** `hosts/frieren/gemini.nix` runs molly-brown on
  `gemini.frieren.lan:1965` serving `lib/gemtext.nix`'s conversion of the same markdown the HTTP site
  renders (56 pages), with CGI under `/cgi-bin`; the firewall entry reads `services.molly-brown.port`
  and the certificate is the existing `*.frieren.lan` wildcard, so nothing was re-issued.
- **molly-brown is overlaid to master** (`9627852`, 2026-05-25): upstream publishes no tags or
  releases, and the go module set is unchanged from nixpkgs' 2023 pin, so only `src`/`version` differ.
- **`CGIPaths` is relative on purpose** — `config.go` joins a relative entry to `DocBase` and leaves
  an absolute one alone, so `/cgi-bin` could never match and `cgi-bin` does.
- Evidence: `20 text/gemini` on `/`, `20` with `query: x=1` on `/cgi-bin/hello?x=1`, `51` on a
  missing page, `53` on a foreign host, TLS verified against the LAN CA; `hostChecks` green.

### 2026-10-29 — `/admin` on the Pi-hole vhost answers again, and FTL's bind stays closed
- **The bookmark path works; a route FTL lacks still doesn't.** FTL 6.7.1 serves its UI at `/`
  (`webhome`), so `/admin` was FTL's own 404. `hosts/frieren/reverse-proxy.nix` rewrites `/admin[/…]`
  onto the UI's own routes and leaves FTL on `127.0.0.1:8080`: `/admin`, `/admin/`, `/admin/queries` and
  `/admin/groups` = 200, `/admin/login` = 302 (as `/login`). `/admin/settings` stays 404 because 6.7.1
  has no `/settings` — the inline comment that claimed otherwise is corrected, and no rewrite can
  invent a route.
- Evidence: `curl -sk -o /dev/null -w '%{http_code}' https://pihole.frieren.lan/admin/` → `200`; the
  note `open-pihole-admin-path` is now `DELIVERED`.

### 2026-10-28 — resolver holds no swap, keeps its 7 days; Steam cache warm; Pi-hole published
- **Swap was glibc arenas, not query history.** 13 threads → 12 anonymous heaps of 64/128 MiB; `VmSize` 2.1 GB against `VmRSS` 132 MB and `VmSwap` 934 MB. `MALLOC_ARENA_MAX=2` + `MemoryHigh=1.2G` (`hosts/frieren/dns.nix`): VmSize 1,229 MB, swap **934 → 0 MB**, box swap 4.47 → 3.34 GB. `DBimport`/`maxDBdays` are ignored on 6.7.1 (measured), so the imported history is not a knob.
- **Retention back to 7 days.** nixpkgs' deleter ran `date('now','-7 day')` nightly and carried `ConditionFileNotEmpty` in `[Service]` (*Unknown key, ignoring*); replaced by an hourly rolling window + `VACUUM` above 4096 free pages. Oldest row 7.04 days, DB 603 → 576 MB.
- **`pihole.frieren.lan` publishes the admin UI** (was SSH-tunnel only) via `hosts/frieren/reverse-proxy.nix` plus a portal card. FTL 6 serves it at `/`, `/admin/` is a 404, and it stays enabled because `services.pihole-ftl.lists` loads blocklists through its API (module assertion). No password either way.
- **Steam cache warm.** Dota 2 linux depots, 33.42 GiB in 35:27, cache 40 → 45 GB, DNS pin scoped to the prefill namespace (`dnsSteer` still `off`). Windows added 2026-10-29: **+7.7 GB** (45 → 53 GB) in ~46 min at ~3 MB/s, then the same selection walked all 33.72 GiB in **8:29 at 569 Mbit/s** off this cache — the `%` counter serves the new chunks first and read 18 % while doing all of the real downloading, so the earlier "0.3 GiB" delta from the manifest total was never the transfer size. `prefill.maxRuntime` 3h → 6h, because one cold 33 GiB set is 2–3.4 h on this line.
- **The prefill recipe is code now.** `modules/services/steam-cache.nix` pins `lancache.steamcontent.com` with five `BindReadOnlyPaths` (`nsswitch.conf`, `host.conf`, `hosts`, `resolv.conf`, empty `/var/run/nscd`) built from store paths, and `prefill.enable` only arms the timer — the unit exists whenever the cache does, so a fill is `systemctl start steam-prefill`. `/var/lib/steam-prefill/pf-dota.sh` is deleted; the unit run reported `Up To Date 1` in 5.9 s and `getaddrinfo` inside its namespace returns `192.168.3.25` alone while the host still returns Valve's public set. The `02:00` window is armed (next elapse `02:01:27`), and a warm-cache run moves 77 KB in / 14 KB out.
- Evidence: `pihole.frieren.lan/` 200 `<title>Pi-hole frieren</title>`, card in `/data/services.json`, `checks:host HOST=frieren` rc=0, all three switches exit 0 with the resolver probe green, gatus dns + steam cache ok.

### 2026-10-29 — a prefill is judged by its bytes, not its percentage
- **Every fill now records itself.** `steam-prefill-baseline.service` (root, before) and `steam-prefill-record.service` (root, after) bracket whichever run happens — timer or `systemctl start steam-prefill` — and append one JSON line to `/var/lib/steam-prefill/runs.jsonl`: cache bytes before/after, growth, and the cache backend's `IPIngressBytes` delta (Valve's reply bodies; LAN hits are egress, so a hit can never read as bandwidth spent). Two root units because the tree is `0700 nginx` and systemd has no per-command user.
- **Calibrated, not assumed.** A real 2 428 561-byte object fetched through the front moved 2372 KiB of cache and 2412 KiB from Valve; a warm fill recorded `tier_growth_bytes: 0, wan_bytes: 406`. Growth is the flash tier's `statvfs` delta (6 ms), not a `du` walk: that cost 36 s cold over 56 GB, twice a night, to report that nothing moved. The newest line rides in `/sentinel/status.json` as `prefill` (`services.fleetSentinel.prefillRuns` → `services.steamCache.prefill.ledger`).
- **The sentinel had been reporting `failed_units: ["loaded"]`.** It parsed column 2 of `systemctl list-units --plain --no-legend`, which is the literal word `loaded`, so `ignoreFailedUnits` never matched and the BurgerNAS mount had no ignore. Fixed to column 1; frieren is `ok` with `failed_units: []`.

## Open debt (`task ops:notes`)

1. `cassini`'s darwin assertion (`xdg.desktopEntries`) — dormant, reproducible
   with `MODE=eval`; `minyx`'s kernel conflict is gone (the board evaluates,
   passes its gate and is active since 2026-10-27).
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
