# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-22)

Rows carrying a command were re-measured 2026-10-22 with it. The live-system rows
(observation, knowledge, backups, DNS, tailnet) were last confirmed 2026-10-20.

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 34 devices: 18 active (11 NixOS, 1 home-manager, 6 external), 16 preserved | `nix eval .#inventory.hosts`, `.#inventory.derived` |
| Host gates | per-host module system + assertions, one host per process | `nix build .#hostChecks.x86_64-linux.<host>` |
| Known red gates | `minyx` (kernel conflict), `cassini` (xdg.desktopEntries on darwin) — both dormant | `task checks:host HOST=minyx MODE=eval` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | resolver pair: frieren pihole+unbound, delphi crab-hole, one shared `10.99.0.53` | `task checks:dns:failover` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-10-22 — netbook's sops identity is its TPM, not an SSH key
- `&tpmnetbook` (`age1tag1q…`) generated on the host as `alice` via `sg tss`, registered in `.sops.yaml`,
  all 6 files rekeyed additively. Proven there against the rekeyed file (`436f477d…` == frieren's digest;
  no-identity control 128). Capability: `security.tpm2`, `alice` in `tss`, `age-plugin-tpm`, gen
  `2gl0wd10…`. No sops-nix plane yet, so it is used by hand; the rule now has 37 recipients.

### 2026-10-22 — netbook on the fleet nixpkgs; the boot pin is the initrd, not nixpkgs
- `hosts/netbook/configuration.nix`: fleet nixpkgs kernel (`pkgs.linuxPackages`, 6.18.56) plus
  `boot.initrd.systemd.enable = false` and `boot.consoleLogLevel = 7`. Running gen 51 `jfw8ir…`, 0 failed
  units, niri session up; loader default moved to it and the broken gen 50 entry deleted.
- Cause of the gen-50 no-boot: NixOS 26.11 defaults `boot.initrd.systemd.enable` to `true`, so dropping
  `inputs.nixpkgs_25_11` changed the kernel *and* stage 1 at once. gen 50 (systemd-initrd) reached no
  stage-2 — **no journal entry for that boot**, blank console at `loglevel=3` — while the same 6.18.56
  kernel boots under the scripted stage-1. Both initrds carried `f2fs`/`mmc_block`/`sdhci-acpi` and matched
  their store paths, so no initrd was ever missing: the kernel was not the fault.
- `nixpkgs_25_11` pruned from `flake.nix` and `flake.lock` — nothing references it now. The lock diff is
  that node and its root entry only; no other input moved. `nix eval .#agentSkills.count` (50) and
  `.#inventory.hosts.netbook.role` both evaluate after the prune.
- Registry and runbook rewritten to match (`inventory.toml` role/notes/traits, `docs/inventory-schema.md`,
  `.agents/fleet-matrix.md`, `.agents/deploy/hosts/netbook.md`). Gates: `checks:host HOST=netbook` rc=0
  (1521 assertions), `ACTION=verify` rc=0.

### 2026-10-22 — netbook deploy: build ladder on frieren, and a half-activation is now detectable
- The deploy's build step became a ladder instead of one flag: `BUILD=auto` (default) substitutes on
  frieren with `--max-jobs 0 --builders ""` and only escalates to nixbuild.net when a path is missing;
  `local` compiles on frieren; `remote` (`REMOTE_ONLY=1`) is nixbuild.net only. Measured: unchanged tree
  = seconds (pure substitution), `remote` 2m28s.
- **A half-activation is now caught.** `switch-to-configuration` links `/etc` and `/run/current-system`
  *before* it talks to systemd, so with a dead system bus the host looks current while every changed unit
  keeps running the old config. Measured end to end: gen 49 moved `current` while `dbus-daemon` rejected
  every uid-0 message to `org.freedesktop.systemd1`/`login1` (identical `/etc/dbus-1` policy before and
  after, so not a config difference). The deploy now asks the bus for its unit list after the switch
  (exit 5) and reports a non-zero switcher with a live bus (exit 6). Recovery: restart `dbus.service`,
  re-run the switch, reboot if a desktop session died — the bus restart was what restored `Subscribe`.
- Verified on the host after the reboot: booted `vraa14k5…` with kernel 7.1.2 (the pinned chain), 0 failed
  units, greetd + alice session on seat0, substituters = harmonia + cachix + numtide, flakes enabled.
  Full `infra:apply:host:netbook` rc=0 with the boot-chain guard matching and the closure pushed over the
  LAN. `ACTION=preflight` now also reports whether harmonia actually serves the running system.

### 2026-10-22 — netbook becomes a flake host without touching its boot chain
- `flake.nix` gains `nixpkgs_25_11`, pinned to `b6018f87da91` — the exact rev the netbook boots — and
  `outputs.nix` can now give a host its own nixpkgs (`mkNixosHostWith`; passing `nixpkgs` into the
  assembler's second call was silently dropped by `...`, which is why the first attempt still produced
  `linux-7.2.10`). With the pin, `.#nixosConfigurations.netbook` resolves kernel `kvi34z8k…-linux-7.1.2`
  and initrd `mbsmjy1ld…` — the two store paths the host is already running.
- Deploy is a push: `infra:apply:host:netbook` stages the tree on frieren, builds there (4m22s wall / 8s
  CPU — substitution, not compilation), `nix copy`s the closure over the LAN, and activates the built
  system with nix-env + switch-to-configuration, so nothing is evaluated or compiled on the Celeron.
  Guards run on the target before the copy: boot chain (exit 3) and `/etc/nixos` drift (exit 4).
- Fixed on the host: harmonia/cachix/numtide substituters (it shipped `cache.nixos.org` only, so the NAS
  cache 3.4 ms away was never used); `nix.gc` options hyphen → `--delete-older-than 30d` (Nix 2.31
  rejects the hyphenated flag, so every weekly GC exited 1); flakes enabled. Runbook:
  `.agents/deploy/hosts/netbook.md`.

### 2026-10-22 — `.#delphi-site` is what serves, and the server says so
- The flake package was a host-free lookalike: same name, same templates, empty `cards` — it printed "no
  mount registry" while the live console listed four mounts. It is now
  `nixosConfigurations.delphi.config.system.build.delphiSite` (aarch64 only, because it *is* that host's
  evaluation), so `.#delphi-site.outPath` equals `/etc/nginx`'s root. `cards` has no default, and an empty
  list throws: a preview that cannot carry the registry fails at eval instead of shipping an apology.
- Each site vhost emits `X-Site-Path`, and `checks:site:path` (`scripts/task/site-drift.sh`) compares it
  with `nix eval --raw .#delphi-site.outPath` — one request with a timeout, one eval under the OOM
  watchdog, no ssh. Proven in three states: rc 2 before the header existed, rc 1 with the tree one newline
  ahead of the deploy (`ady9526…` vs `r68sfyg…`), rc 0 in sync.

### 2026-10-22 — delphi's two surfaces are compiled from one structure; two gates stop needing python
- `lib/delphi-site.nix` renders the public dossier and the tailnet console from ONE evaluated structure
  (`inventory.toml` + knowledge graph + `config.services.servicePortal.cards`); markup in
  `lib/delphi/*.{html,css,js}`, `render` throws on an unbound hole. Replaces the inline page whose public
  surface carried no content at all (every card was tailnet-audience). `cards` is the new read-only
  projection, so the mount declaration and either page cannot drift. Registry truth fixed: `domain`/`tailscale_ip`
  registered (the host reads them), `status_detail`/`key_services`/`notes` corrected. The MagicDNS name
  answers on `:80` behind `allow 100.64.0.0/10; deny all;` — 443 belongs to ACME. Evidence: 1856
  assertions, 4 console cards / 4 withheld names, no tailnet address on the public page. Runbook:
  `.agents/deploy/hosts/delphi.md` § *The two surfaces*.
- `docs-links.sh` and `toon-surfaces.sh` lost their `python3` dependency (awk + `test -e`): a gate that
  fails where no interpreter exists is not a gate. Negative controls prove both still catch a broken link
  and a bare `nix eval --json`. The tools the gates needed are declared, not ad-hoc:
  `profiles.operatorTools` (`modules/profiles/operator-tools.nix`) puts `toon` + `python3` in delphi's
  closure (cache fetches, no build), after which `checks:toon`, `ops:tailnet:policy` and
  `checks:kg:canvas` (static half) pass here; `agent-browser` stays opt-in — that gate skips its click.

### 2026-10-22 — the portable library gets an admission rule, not a bigger disk
- Audited the four store dirs: 178 files, 9.5 GiB, 83 static, glibc floor 2.39, 11 MiB exact duplicates, 92 MiB eget re-fetch residue (`*.1`).
- `data:library`, `:index`, `:fetch` replace ad-hoc eget use: a dynamic download is rejected to
  `.rejected/`, provenance goes to `.library.tsv`; asserts
  [[flake/policies.nix#library-fetch-is-static]] + [[flake/policies.nix#library-crosses-the-wire]],
  note `portable-library`.

### 2026-10-22 — scratch's sops planes unseal through its TPM; the proof moves to the store copy
- scratch is the third TPM-sealed host (`&tpmscratch`) and the first whose **system** plane unseals
  through the chip: `age.keyFile` + `age.plugins`, `sshKeyPaths` forced empty, no SSH-derived recipient
  at all. `switch-to-configuration` exits 0. Audio was firmware, not config (BIOS re-enabled `00:1f.3`).
- `modules/sops.nix` gained `age.plugins` for `tpmHosts`: without it the user unit's
  `Environment=PATH=` is empty and the unseal dies on `0 successful groups required, got 0` —
  measured on frieren, exit 128 with the identity / exit 0 with the plugin. frieren and fern stay
  green only because a software `keys.txt` is still a recipient there, so their `sops -d` says nothing.
- Proof now targets `/nix/store/<hash>-secrets.yaml` through the unit's own manifest, not a checkout:
  both planes decrypt it to the pulled tree's digest, and a no-identity control exits 128. scratch's
  clone sat 2768 commits behind at `~/nixconfig` while `~/Documents/nixconfig` was a store symlink.
  Procedure `docs/sops-rekey.md`; note `tpm-sops-planes`.


### 2026-10-22 — the 2026-10-21 ledger entries are archived
- Eight entries moved to `docs/history/audit-2026-10.md` § *Ledger: 2026-10-21 (continued)*; one link
  re-based to its new depth, which `checks:docs:links` caught.

## Open debt (`task ops:notes`)

1. `minyx` kernel conflict and `cassini` darwin assertion — both dormant, both
   reproducible with `MODE=eval`.
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
