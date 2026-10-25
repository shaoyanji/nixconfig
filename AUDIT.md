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
| Host gates | per-host eval (assertions) and per-host VM boot to stage-2, one process each | `.#hostChecks.x86_64-linux.<host>`, `.#hostBootChecks.aarch64-linux.delphi` |
| Known red gates | `minyx` (kernel conflict), `cassini` (xdg.desktopEntries on darwin) — both dormant | `task checks:host HOST=minyx MODE=eval` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | frieren pihole+unbound owns the zone; delphi crab-hole answers public DNS only, same address | `task checks:dns:failover` (exit 2: no zone secondary) |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger

### 2026-10-25 — fern joins atuin; the NAS mirror moves onto the exported lane
- `fern` rebuilt and logged in (`atuin 18.23.0`; the key is rendered by `modules/sops.nix`, so the
  host only needed `atuin login`): `import nu-hist-db` + `import bash` then `sync` → **24,282 items**
  (5,208 bash / 19,074 nu), server `store` at **24,284**. Proof: the two imports, `atuin sync`
  complete, the postgres count on frieren, and 3 `_atuin_*` commands visible in fern's nushell.
- `burgernas-library-sync` writes `/volume1/peachcable` — the only NFS export — instead of
  `/volume1/Shared Library`, where the DietPi/Raspberry Pi clients could never see it. 48 files that
  existed only on the NAS were rescued into `/Volumes/data/{bin-x86,bin-aarch64,bin-script}` first,
  and the legacy paths are relative symlinks to the export (an NFS symlink resolves client-side, so it
  cannot split the lane). Proof: one run to exact name parity 80/66/20/66, six hashes equal, ~10 G of
  duplicate freed, same counts through frieren's `vers=4.1` mount. Live on frieren's next rebuild;
  the timer is weekly (Sun 03:32).
- Commentary gate: `scripts/task/nix-prose-lint.sh` fails a commit when 8+ **added** comment lines
  cite no home (docs, skill, policy, `task`, `.#`, repo path) — the diff, not the corpus, so it bites
  now instead of demanding a rewrite of the 58 existing blocks that `MODE=all` reports. Folded into
  the existing `nix-header-budget` policy rather than a second rule for one topic; `checks.policies`
  reports 44 holding.

### 2026-10-23 — delphi's guest becomes a service tier: named volumes, Stirling, a deck on port 22
- `persist` in `hosts/microvms/guests.nix` mounts one labelled ext4 image per name at
  `/var/lib/<name>` (hermes, stirling, dsh); Stirling PDF runs on the 4 GiB one behind
  `/microvm/stirling/` (tailnet-gated, public name 302s there). Proof: 200 through the tailnet vhost,
  403 for a public client spoofing the tailnet Host, 302 on `https://delphi.bountystash.com/…`.
- The deck is reachable at `ssh -p 22 slides@delphi.bountystash.com` — the edge carries 22, not 2222 —
  through a host account whose login is a hop into the guest's forced command. Proof: rendered from
  frieren over the public IP and the public hostname.
- Two guest faults fixed on the way: udev's eth0→enp0s7 rename landed after networkd matched the link
  (`usePredictableInterfaceNames = false`), and `Match`'s `AuthorizedKeysFile` replaced the default that
  names `/etc/ssh/authorized_keys.d/%u`.

### 2026-10-22 — the boot gate boots a host's own config, and is not a hygiene instrument
- `hostBootChecks.<arch>.<host>` runs the host's real module list in a VM and fails unless the console
  shows `Reached target Multi-User System`; CI `boot-canary` for `modules/services/**`. Proof: delphi reached
  stage-2, a missing root device fails; hardware (eMMC/NVIDIA/TPM) is out of reach.
- `checks:boot` now refuses before its first eval unless `/dev/kvm` is usable, and `boot-gate-needs-kvm`
  checks the probe precedes the build. Eight TCG boots of the same guest, after doc edits that could not
  change it, pegged a core of a host answering `delphi.bountystash.com` and ssh — an outage, not a slow test.
- The exception is the host being switched: `checks:boot:self` / `BOOT=1` boots `$(hostname)` under TCG
  (one vCPU, `nice -n 19`, watchdog) because a bad stage-1 there cannot be diagnosed from outside.

### 2026-10-22 — skills audit: 19 files, −732 lines, and a gate against the pattern
- Measured first: verbatim duplication against `AGENTS.md` and between skills is zero, so
  the bloat was structural — rows restating a task's `desc`, facts copied from their source.
- Rewrote `infra` (dropped the fleet host matrix AGENTS.md bans), `home-assistant`,
  `frieren-offload`, `knowledge-base`, `services`, `dev`, `agents`, `serv00`, `envs`,
  `dragoncourt`, `moto`, `bountystash`, `apps`, `data`, `checks`, `burgernas`, `tmux`,
  `calendar`, `agents-notes`: 4,946 → 4,214 lines across 50 skills.
- `checks.<system>.skills-task-mirror` fails a skill whose rows restate a `desc` (≥70 % of
  its tokens, ≤1.5x its length, three rows): calibrated on the old tree at 13 skills / 78
  rows, proven with a planted row that threw, wired into `ops:skills:check` and
  `checks:quick`.
- Corrections: `home-assistant` pointed at `hosts/frieren/media-stack.nix` (no HA config);
  `frieren-offload` cited a missing `scripts/agy-offload` and claimed the 03:00 runner
  deletes `HANDOFF.md` (it preserves it, gated on triage); `infra` misstated
  `store:collect-garbage` (it is `-d`, every generation).

### 2026-10-22 — netbook imports the shared boot and NAS profiles instead of copies
- `profiles/boot.nix` (`profiles.boot.efi = false`) + `profiles/nas-client.nix` replace a hand-rolled fstab entry
  and an inbound `2049` a client never needed: LAN→tailnet failover, recovery timer, gc-root guard. Gen `h9pvpjyr…`.

### 2026-10-22 — netbook's sops identity is its TPM, not an SSH key
- `&tpmnetbook` (`age1tag1q…`) generated on the host as `alice` via `sg tss`, registered in `.sops.yaml`, all
  6 files rekeyed additively. Proven (`436f477d…` == frieren's digest; handles hidden 128, because a
  `/nonexistent` `SOPS_AGE_KEY_FILE` falls back to `keys.txt`). Bare `sops -d` works; no sops-nix plane yet.

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
