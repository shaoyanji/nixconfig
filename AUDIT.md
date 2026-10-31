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
### 2026-10-31 — Dux bump, and Ryoku piloted on fern (CI build blocked)
- **Shell inputs moved to Dux Labs.** `dms` → `github:duxlabs-dev/dux-shell/stable`, `dank-greeter` →
  `github:duxlabs-dev/dux-greeter` (DMS 2.0 rebrand, 2026-10-20). Option and flake-output names are
  compatibility-preserved (`programs.dank-material-shell`, `nixosModules.dank-material-shell`), so only
  URLs moved; `dms/dank-qml-common` is still the transitive pin name. Evidence: `task checks:host HOST=fern`
  rc=0, 1976 assertions (32.8 s / 1 415 MiB, before the Ryoku change).
- **Ryoku pilot on fern, branch `ryoku-pilot-fern` (NOT deployed, main untouched).** Ryoku replaces the
  shell, so the host takes a new chain `globalModulesRyoku` (globalModulesNixos minus dms/dank-greeter) and
  `fleet.dankShell.enable = false` keeps the DMS/niri home modules out of HM. Gate: `task checks:host
  HOST=fern` rc=0, 1976 assertions, 112 s / 2 469 MiB (second nixpkgs in the graph).
- **What broke:** Ryoku enables `power-profiles-daemon`, which the NixOS assertion refuses beside
  `laptop.nix`'s `auto-cpufreq`; the profile resolves it in Ryoku's favour. Nothing else failed evaluation.
- **Closure delta unmeasured: CI cannot fetch a fixed-output source.** `nixcachix` run 41192471687 fails
  deterministically on `xaf4dh5an…-source.drv` (`github:neur0map/ryomotion@60ea129`) with codeload 404s,
  for both `ryoku-keysounds` and `ryoku-hyprland-plugins`. The same URL answers 200 from frieren, so it is
  runner-IP rate limiting, not a dead pin. Baseline (current DMS/niri fern, same commit) was built on
  `fern-baseline` and measured from narinfo: **18.35 GiB NAR / 2 401 paths**.
- **Also observed:** `task checks:nix:format` is red at HEAD on `flake/policies.nix` (not touched here).

### 2026-10-30 — agent turns: one token per holder, and the mirror that nearly ate them
- **One token per holder, so a revocation is one holder.** `services.agentTurns.additionalTokens`
  declares `-netbook`, `-muse` and `-vesper` beside the fleet token; the shim compares every name
  without short-circuiting, and the append log names the one that authenticated
  (`append token=agent-turns-token-vesper source=vesper`), so a turn is attributable to a holder
  rather than to "someone with a token". Four distinct values, `0400 xs-agent-turns`, each reads
  `200`, a bogus bearer `401`.
- **`modules/secrets.yaml` is a mirror, and writing to it fails silently.** `SECRETS=modules/secrets`
  plus `infra:secrets:sync` regenerate the parent file from the submodule, so a token set with
  `sops set modules/secrets.yaml` survives until the next secrets edit and then disappears — and
  because the shim loads its token set at start, the holder keeps working until the following
  switch and then gets `401` with nothing in the diff to explain it. All four tokens were in the
  mirror only, which the drift gate reports as *missing keys* rather than changed ones; they now
  live in `modules/secrets/secrets.yaml` (`8e851f1`) and the mirror is regenerated from it.
  `docs/agent-turns.md` had pointed rotation at the mirror, which is how it happened.
- Evidence: drift gate green on 7 files including mirror-vs-source (both plaintexts
  `840dd35e76e570f9`); first turn from a non-fleet holder landed and read back —
  `xs-endpoint:vesper-first-turn`, frame `9fa45743`, 21:13:54Z, authenticated by vesper's token
  (minted as `-muse1`, renamed once the holder turned out to post as `vesper`).

### 2026-10-30 — an Always Free OCI demo with a private database
- **OCI ignores `cpu_core_count` and `data_storage_size_in_tbs` on a free database.** `is_free_tier`
  is the switch and ECPU is the shape (2 ECPU = 1 OCPU), so `projects/oci-always-free-demo` pins it in
  code with a validation instead of trusting a console checkbox.
- **`subnet_id` on the ADB is what removes the public listeners.** SQL\*Net and ORDS stop answering
  outside the VCN in place, so operator access moves to a bastion `create-port-forwarding` session,
  and `scripts/adb-sql.sh` rewrites the descriptor host to the tunnel while keeping the wallet's
  `ssl_server_cert_dn` so TLS identity stays pinned.
- **Imported certificate material needs provider 9.x.** 7.32's `certificate_config` has no
  `certificate_pem`, so the floor is `>= 9.0.0`; the default self-signed certificate is RSA because
  the load balancer's default cipher suite will not negotiate ECDSA.
- **APEX page metadata has no DDL equivalent.** `sql/apex/f100.sql` is wired but empty until one Page
  Designer build and `--apex export`; `--apex-check` compares content rather than timestamps, because
  importing an app bumps its `last_updated_on`.
- **Evidence:** `terraform validate` clean on `oracle/oci` 9.11.0, shellcheck clean on four scripts,
  the Flask app exercised under its test client. No `plan` has run against a tenancy, so the ACME DNS
  hook, SQLcl `apex export` inside a script and the bastion flag names stay unproven.

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
