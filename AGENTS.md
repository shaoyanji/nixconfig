# AGENTS.md

**Nixconfig** — Personal Nix flake managing NixOS, nix-darwin, and Home Manager across ~25 hosts.

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `taskfiles/README.md` for ownership and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth. Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md` — see `.agents/README.md` for the full index.

---

## Agent entry contract (read this first)

1. **This file is the manual, not the rulebook.** The documentation contract is
   [`.agents/SCHEMA.md`](.agents/SCHEMA.md): one fact one home, budgets, status
   vocabulary, skill frontmatter. Every living doc is bounded on purpose.
2. **Start from intent.** `task help` → `task find:<word>` → the owning shard.
   Never invent a task name; never add one before walking the ladder in the
   `task-plane` skill (eval → jq → Nix lib → check → task → script → Go).
3. **Truth order:** compiled data (`inventory.toml`, `modules.toml`) → host and
   module Nix → taskfiles → docs. A table that exists twice is a liability.
4. **Facts are evaluated, not guessed.** `nix eval .#inventory…` (~0.2 s) or
   `nix eval .#agentSkills…` (~1.2 s). Never evaluate a full host to answer a
   fact question; never run `nix flake check` on this host.
5. **Verification is phased:** eval to catch a config error · build to prove a
   closure · size to plan a build. **Never run `task checks:*` before a local
   rebuild** — the switch already evaluates and builds; a pre-flight check (and
   especially `checks:build:route`) re-instantiates the whole toplevel for no
   extra proof. An eval is not a build, and a build is not a runtime test (use
   the MicroVM canary for units).
6. **This is a live host.** Bounded gates only, one host per process, no
   top-level evals during the 03:00–05:30 window, and no ssh in unattended
   paths. Watch `task ops:health` before blaming the config.
7. **Where to write:** proposal and open work → an `AGENTS.nix` note
   (`task ops:notes`; authoring: `agents-notes` skill); what happened →
   `AUDIT.md`; history → `docs/history/`; procedure → `docs/` or a skill.
   Never a new root markdown file.
8. **The closed loop is real:** `fleet-sentinel` records jobs, generation age,
   disk and PSI every 15 min; gatus pages on `[BODY].state != ok`. A green
   socket is not a successful job — read the ledger.

## Home Initialization & Tautological Control Plane

When an AI agent or developer session initializes from the home directory (`$HOME` / `~`):

1. **Repository Root & Provenance**:
   - The canonical repository path is `~/Documents/nixconfig` (symlink to persistent NAS storage at `/Volumes/data/projects/nixconfig`).
   - All Nix modules, flake definitions, secrets, and taskfiles originate from here.
2. **Tautological Taskfile Control Plane**:
   - `~/Taskfile.yml` includes `~/Documents/nixconfig/Taskfile.yml` with `dir: ~/Documents/nixconfig` and `flatten: true`.
   - Running `task <cmd>` in `$HOME` (or `task -g <cmd>` globally) executes immediately against the repository with correct working directory context. Speculative path discovery or tool calls are unnecessary.
3. **Agent Guidance & Skills Materialization**:
   - `~/.agents/` (`~/.agents/skills/`, `~/.agents/deploy/`, `~/.agents/README.md`) provides guidance and skill shards.
   - The canonical fleet operational manual is `AGENTS.md`. The local host system card + persona is the flake output `.#homeAgents.<host>` (`lib/home-agents.nix`), linked to `~/AGENTS.md` by activation; refresh manually with `task dev:inventory:home-agents`.
4. **Secrets & SOPS State**:
   - Encrypted secrets live in `modules/secrets.yaml` (mirrored from the private `modules/secrets/` submodule).
   - Host and user age keys are registered in `.sops.yaml` and loaded from `~/.config/sops/age/keys.txt`.

---

## Architecture Overview

### Flake Output Assembly

```
flake.nix → flake/outputs.nix (hub)
  ├── nixosConfigurations ← flake/nixos-configurations.nix ← mkNixosHost (lib/mk-nixos-host.nix)
  ├── darwinConfigurations ← flake/darwin-configurations.nix
  ├── homeConfigurations  ← flake/home-configurations.nix
  ├── packages            ← flake/packages.nix
  ├── checks              ← flake/checks.nix
  ├── devShells           ← flake/devshells.nix
  ├── docs                ← lib/docs.nix (generated markdown tree)
  └── fleet-docs-site     ← lib/aki-site.nix (the rendered site)
```

**Host registration flow**:

1. One entry per host in `flake/host-inventory.nix`: defines `kind` (nixos/darwin/home), `system`, module chain, and host module path
2. `flake/host-projection.nix` projects inventory into per-kind attrsets automatically — no manual output wiring
3. `flake/module-sets.nix` defines the 5 global module chains used as baselines

### Module Chains (defined in `flake/module-sets.nix`)

| Chain                            | What it includes                                                                       | Used by                                                                            |
| -------------------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `globalModulesNixos`             | global + nixos + home-manager-shared + sops + nix-index + dms + dank-greeter (desktop) | poseidon, aristotle, aceofspades, ancientace, eisen, frieren, scratch, stark, fern |
| `globalModulesImpermanence`      | globalModulesNixos + impermanence + disko                                              | schneeeule                                                                         |
| containers + impermanence (ares) | globalModulesContainers + impermanence + disko                                         | ares (Steam kiosk)                                                                 |
| `globalModulesContainers`        | global + noDE + sops + home-manager + nix-index (no dms/niri desktop)                  | mtfuji, kellerbench, applevalley, minyx, sledgehammer, guckloch (WSL), deckstation |
| `globalModulesMacos`             | global + macos + nix-homebrew + home-manager + sops                                    | cassini (darwin)                                                                   |
| `globalModulesDemo`              | global + demo + home-manager (no sops)                                                 | demo (NixOS demo VM)                                                               |
| `globalModulesHome`              | standalone HM sharedModules + allowUnfree                                              | penguin, alarm, kali (standalone home-manager)                                     |

### Complete Client OS Fleet Inventory

> **No table here — by design.** The fleet registry has exactly one home:
> [`inventory.toml`](inventory.toml), compiled once by `lib/inventory.nix`. Read it
> with `nix eval --json .#inventory.hosts | jq` (0.15 s, no host eval) or the
> generated catalog in `docs/generated/fleet-inventory.md` (`nix build .#docs`).
> A pasted table is a table that disagrees with itself within a month —
> `.agents/SCHEMA.md` §1, and `docs/docs-pipeline-audit.md` F4.

### Module Layout

```
modules/
  global/          — Global NixOS/Darwin/Home-Manager module chains
    user.nix       — Canonical user constants (user = devji, import this, not hardcode)
    global.nix     — Nix config: experimental features, substituters, GC
    nixos.nix      — NixOS HM embedded: overlays, home-manager-shared, role:heim
    noDE.nix       — Container host HM: role:minimal + shell
    macos.nix      — Darwin HM: role:home
    impermanence.nix — Persistence rules for devji user
    demo.nix       — Demo HM: role:demo, no sops
    home-manager-shared.nix — sharedModules for embedded HM (sops, nixvim, nix-index, niri, dms)
  profiles/        — Reusable host profiles
    base-node.nix  — Common NixOS baseline (kernel, SSH, keyd, networkmanager, sops, user devji)
    boot.nix       — Boot loader profile (systemd-boot/EFI defaults)
    firewall-baseline.nix — Firewall on, only TCP/22 by default
    server-hardening.nix — Journald caps, tmp cleanup, /var bind-mount to data disk
    nas-client.nix — Automount /Volumes/data from the NAS server (frieren)
    steamos.nix — Steam kiosk (greetd autologin + upstream gamescope-session, audio, 32-bit GL, Avahi)
    sunshine.nix — GameStream/Moonlight server (Sunshine on LAN, video/render/input groups)
    nixbuild-client.nix — Optional nixbuild.net remote builder (distributedBuilds, off by default)
  services/        — Service modules
    aria2-daemon.nix  — aria2 RPC + AriaNg web UI via nginx (delegates to native services.aria2)
  roles/           — User role assemblers
    minimal.nix    — Base user stack + AI
    heim.nix       — devji desktop preferences (niri, kitty, dev, zen)
    home.nix       — Desktop-oriented role (MacOS)
    portable-home.nix — Shared HM baseline (shell/base + nixvim)
  user/            — User module domains
    base/          — CLI/editor/env base
    ai/            — AI tools (gemini-cli, mods, opencode, aichat, agents)
    desktop/       — Niri compositor integration
  shell/           — Shell modules (bash, tmux, nu, zsh)
  config/          — Config data (authorized-keys, fetches.json, shells/*.nix)
    shells/        — Dev shell definitions (flaskpy, jekyll, yarn, pdf, yt, kali, pi, etc.)
  hm/              — Home-manager-only modules
  lib/             — Internal library functions
```

### Packages

Custom packages built from the flake:

- (none — the `pkgs/` directory and agent-era packages were removed in 2026-09/10; the `packages` output is `{}`)

---

## Essential Commands

### Taskfile Entrypoints

```bash
task help                        # List all tasks
task --list-all                  # Same, unfiltered
task status                      # git status + hostname
task ops:notes                   # Decisions / queue / design studies (AGENTS.nix)
```

### Host Lifecycle

```bash
task infra:plan:host:<host>      # Build/evaluate host closure (dry run)
task infra:apply:host:<host>     # Apply configuration to remote host
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:rollback:host:<host>  # Roll back to previous generation
task infra:logs:host:<host>      # View remote journald logs
```

### Local Rebuilds

```bash
task infra:rebuild:nixos         # switch IS the build; no pre-flight checks (NOM=1 for TUI)
task infra:rebuild:darwin        # darwin-rebuild switch (local) + refresh ~/Taskfile.yml
task infra:rebuild:home-manager  # home-manager switch (local) + refresh ~/Taskfile.yml
```

### Client OS Maintenance & Debugging Runbooks

#### 1. Dry Run & Evaluation

Before deploying changes to any client OS, evaluate its configuration:

```bash
task infra:plan:host:<host>   # build/substitute the closure (no apply)
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
#   ^ instantiates the WHOLE config — every option type — in seconds.
#     Do NOT use `.config.networking.hostName`: that forces one option and
#     type-checks nothing else (see the Agent Verification Protocol below).
```

#### 2. Deploying Remote Hosts

Apply configurations over SSH:

```bash
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:apply:host:<host>     # Apply closure directly
```

#### 3. Remote Log & Service Inspection

Diagnose failing units or check live output:

```bash
task infra:logs:host:<host> UNIT=<unit>   # Tail journald for UNIT (defaults to go-backend)
ssh <host> systemctl status <unit>        # Inspect unit status on remote host
ssh <host> journalctl -b -p err           # View system errors from current boot
```

#### 4. Rollback Runbook

If a deployment degrades a host:

```bash
task infra:rollback:host:<host>           # Roll back remote host generation
# For local recovery:
sudo nixos-rebuild --rollback switch      # Local NixOS rollback
```

#### 5. NAS Client Automount Recovery (fern & clients)

If `/Volumes/data` fails to mount due to early-boot network timing (causing `StartLimitBurst` hit):

```bash
nas-recover                               # Canonical recovery tool
# Or manually restart the automount unit:
sudo systemctl restart Volumes-data.automount
```

#### 6. SOPS Secrets & Key Verification

Verify decryption across all hosts and rotate recipient keys:

```bash
scripts/task/sops-drift-check.sh          # Verify all encrypted files decrypt cleanly
task infra:sops:update-keys               # Rekey all files when .sops.yaml changes
```

#### 7. frieren (NAS) Rebuild Topology — read this before rebuilding this host

frieren is a laptop-class NAS (11 GiB RAM, 8 threads, btrfs). Its nightly
window is already load-saturated; a rebuild started blind will look "stuck"
and tempt you into a retry loop, which is the failure mode this section exists
to prevent.

**Nightly job matrix (all timers `Persistent = true`):**

| Time                    | Unit                                   | Source of truth                                                |
| ----------------------- | -------------------------------------- | -------------------------------------------------------------- |
| 03:00                   | `agy-nightly-handoff` (user)           | Action-gated `~/HANDOFF.md` via Julia-1; executes cascade only on promotion candidates or on-demand (`task checks:audit:handoff`) |
| 03:00                   | `postgresqlBackup-immich`              | local                                                          |
| 03:28                   | `restic-backups-frieren-burgernas`     | daily SFTP push within DSM 03:25–04:00 power window            |
| 03:30 (+10m jitter)     | `restic-backups-frieren-local`         | local                                                          |
| Sun 01:30 (+30m jitter) | `fleet-warm-cache`                     | **`github:shaoyanji/nixconfig`** — builds 7 active host closures |
| 04:00                   | `nixos-upgrade` (`system.autoUpgrade`) | **`github:shaoyanji/nixconfig#frieren`**                       |
| 05:00 (Daily) / Sun     | `agy-nightly-system` (user)            | Trigger-gated `~/SYSTEM.md`: Mon-Sat quiet reflex (bypasses LLM if nominal), Sunday comprehensive scorecard, or on-demand (`task checks:audit:system`) |
| Sun 06:00               | `nix-optimise`                         | weekly hardlink deduplication across live store paths          |

**The origin-vs-local trap (this is the one that bites):**
`system.autoUpgrade` builds from the **pushed GitHub flake**, not
`/Volumes/data/projects/nixconfig`. Any local `nixos-rebuild switch` from a
dirty tree is therefore **silently reverted by the next 04:00 run** unless the
change is committed **and pushed**. A local switch that produced no new
generation usually means exactly this. Confirm what the 04:00 run used:

```bash
journalctl -u nixos-upgrade -n 40 --no-pager | grep -E 'unpacking|new configuration'
git -C /Volumes/data/projects/nixconfig rev-parse HEAD     # must match the unpacked rev
```

**Rebuild rules:**

1. **At most one `nixos-rebuild` at a time.** Never retry-loop it — six
   concurrent attempts is what caused the 2026-10-07 06:46 incident. If it
   seems slow, _measure_ progress (next point) before touching anything.
2. **After a dirty `flake.lock` bump the closure is re-fetched, not rebuilt.**
   A nixpkgs rev change invalidates every store hash, so expect a multi-GB
   download (tens of minutes on this host). It is not hung. Watch it:
   ```bash
   find /nix/store -maxdepth 1 -newermt '-2 minutes' | wc -l   # >0 = progressing
   ls -l /nix/var/nix/temproots/<nix-pid>                      # mtime advances
   ```
   Fat tail to expect: frieren's closure contains **`paperless-ngx` →
   `python3.14-torch` + `triton-llvm` + `wandb` + `google-cloud-cpp`**
   (`nix why-depends /run/current-system <torch-path>` to re-verify). Cheap
   slimming levers here are worth more than any build tuning.
3. **Do not rebuild in the 03:00–05:30 window** on this host. Also avoid
   Sunday mornings while `fleet-warm-cache` is running.
4. **Load average lies here.** It is dominated by D-state btrfs kworkers and
   `kswapd0`, not CPU. Judge pressure with `free -h` + `vmstat 1 3` (look at
   `si/so`, `wa`, and idle%) — CPU is often 60–90% idle at loadavg 8+.
5. **A killed `nixos-rebuild` leaves an orphaned root `nix build`** that can
   never switch anything but keeps ~2 GB resident. Before retrying:
   ```bash
   pgrep -af 'nix build .*nixosConfigurations'    # kill it if it is an orphan
   ```
6. **After a successful switch, verify state, not vibes:**
   ```bash
   readlink -f /run/current-system
   nixos-rebuild list-generations | tail -3
   systemctl --failed; systemctl --user --failed
   ```

### frieren wiki stack & cache-warm workflow (2026-10-08)

- **Kiwix is declarative** (`hosts/frieren/kiwix.nix`, native
  `services.kiwix-serve`): ZIMs are store paths / `fetchurl` entries, served on
  8088 and reverse-proxied at `http://wiki.frieren.lan`. Data lives in
  `/var/lib/kiwix` (NOT `$HOME` — DynamicUser + ProtectHome can't read
  `/home`); the big ZIMs live only as GC-rooted `/nix/store` paths and
  `library.xml` is force-synced from the declarative copy by the
  `kiwix-library` activation script (tmpfiles `C+` never overwrites — it left
  a stale library until 2026-10-08). Add a new wiki by adding a `fetchurl`
  entry (use `nurl <url>` for
  the hash) + a book entry in `kiwixLibrary`. Never hand-run `kiwix-manage`
  and never hand-roll units under `~/.config/systemd/user/` — they shadow the
  declarative ones (that shadowing broke the gateway on 2026-10-08).
- **Uncached fleet builds (NVIDIA 580 etc. are unfree, never upstream-cached):**
  run `task infra:update:fleet` — flake update → `infra:warm:cache` (build all
  host closures on frieren) → `infra:apply:fleet`. Closures built elsewhere:
  `task infra:cache:push:host:<host>` pushes them into harmonia.
- **hermes-gateway:** never run `hermes gateway install` on frieren; edit the
  unit in `modules/user/ai/hermes-user.nix`. Full checklist in
  `.agents/deploy/hosts/frieren.md`.
- **SSH CA:** every host (incl. frieren) can sign certs — `ssh.ca.enableClient`
  - `rotate-ssh-cert` (1-week user certs, CA key via sops-nix at
    `~/.ssh/user_ca_key`).

### Git & Flake

```bash
task dev:git:quick-push          # Stage tracked, AI-commit, push
task dev:git:ai-commit           # Stage + interactive AI commit
task dev:git:ai-commit-push      # Stage + AI commit + push
task dev:git:build-push          # AI commit after successful build
task dev:git:quick-pull          # Pull with submodules
task dev:flake:update-complete   # Full flake update workflow
task dev:flake:update:bountystash # Update single input
task dev:flake:update-transitive # Update transitive inputs a root update misses
task dev:nixbuild:plan           # Report build/fetch gaps per host vs substituters
task dev:nixbuild:warm           # Build gaps on remote builder + cachix push (budget!)
task dev:closure:menu            # Traversable closure explorer (gum TUI; subcommand after --)
task dev:closure:reduce          # Closure reduction report: duplicate groups + every concrete copy
task dev:closure:attribution     # Attribute closure bytes to owners (services, package farms)
task dev:qmd:refresh             # (Re)index markdown docs (repo docs + personal vault) into qmd
task dev:qmd:vault:refresh       # (Re)index personal Obsidian vault into qmd
```

### Data & Storage Lifecycle

```bash
task data:audit                  # Audit NAS storage taxonomy, permissions, media hygiene
task data:clean:metadata         # Scan and remove macOS metadata artifacts (._*, .DS_Store)
task data:clean:downloads        # Cleanup orphaned control files and empty staging dirs
task data:protect:private        # Enforce 0700 permissions and .nomedia shields
task data:index:refresh          # Refresh qmd docs and vault search indices
```

### Closure Analysis (store-DB, no eval)

Cheap "what is actually in this system" analysis: it reads the store database via
`nix path-info` instead of evaluating Nix — the fix for `checks:quick` having
stopped being quick. Targets the local `/run/current-system` by default,
`HOST=<name>` (SSH-resolves a remote host and reads *its* store DB), or an
explicit store path.

```bash
task dev:closure:size HOST=<name>          # total size + path count
task dev:closure HOST=<name>               # subsystem breakdown
task dev:closure:top N=20 HOST=<name>      # biggest contributors by own size
task dev:closure:graph HOST=<name>         # terminal ASCII graph (Graphviz -> graph-easy)
task dev:closure:toml HOST=<name> OUT=...  # 3-level tree for handoff / agent reports
task dev:closure:tui                       # interactive host + view picker
task dev:closure:diff FROM=<old> TO=<new>  # closure deltas (module-reduction scoreboard)
task dev:closure:native                    # same breakdown, computed natively by Nix (prototype)
task dev:closure:native:diff               # [gate] Nix-native output == shell output, byte-for-byte
```

Backed by `scripts/task/closure-analysis.sh`. Generated report trees are **not
tracked** (`docs/closures/` is gitignored) — they are point-in-time and stale
after any rebuild. Regenerate on demand; use `dev:closure:diff` to compare
generations.

**Nix-native prototype.** `lib/closure-graph.nix` computes the same five views
from Nix's own store graph (`pkgs.closureInfo` → `exportReferencesGraph`) instead
of the store DB, and `scripts/task/closure-graph-diff.sh` proves parity — on
frieren all five views are byte-identical for a 3949-path system closure, an
older generation, and a 141-path package closure. Two things to know if you
touch it:

- `closureInfo` needs its roots *declared*. `builtins.storePath "/nix/store/…"`
  for a live path, or a derivation attribute; a bare `/run/current-system`
  symlink is not in the input closure and `exportReferencesGraph` refuses it.
- It is **local-store only** (no `HOST=<name>`): `closureInfo` builds locally.

Rationale and the eval-speed trade-off: `docs/control-plane-vision.md` §4/§6.

### Validation

```bash
task checks:quick                # Bounded: cheap inventory checks, one host eval each, lint
task checks:host:HOST=<host>     # [gate] ONE host (name required): module system + assertions + registry
task checks:hosts:HOSTS="a b"    # [gate] a NAMED set, one at a time — no default, never the fleet
task checks:flake                # [gate] run `nix flake check` only on a machine that can hold it
task checks:flake:transitive     # Sweep transitive flake pins vs upstream (read-only)
task checks:qmd:docs             # qmd repo-docs collection registered + index fresh
task checks:qmd:vault            # qmd Obsidian vault collection registered + index fresh
nix build .#hostChecks.x86_64-linux.<host> -L                     # ONE host gate (~13 s, ~700 MiB)
nix eval .#inventory.hosts.<host>.role                            # Compiled registry (0.15 s, no host eval)
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath  # full-config check, ONE host
#   ^ this one instantiates the whole system derivation graph (>120 s here, and the
#     reason the old fleet-wide host-eval checks were fatal). ONE host per invocation.
task checks:nix:lint             # deadnix (fail) + statix (advisory)
```

#### HARD RULE: never run `nix flake check` on a small host

`nix flake check` evaluates **every flake output**, not just `checks.<system>` — its own
progress output says so:

```
checking flake output 'nixosConfigurations'...
checking NixOS configuration 'nixosConfigurations.ares'...
checking NixOS configuration 'nixosConfigurations.testvm'...
```

On frieren (11 GiB RAM, ~5 GiB already swapped) that is 23 NixOS evaluations inside **one**
process. Measured 2026-10-15:

| command | wall | peak RSS | result |
| :--- | ---: | ---: | :--- |
| `nix flake check` | **339.78 s** | **6078.5 MiB** | SIGKILL, exit **137** |
| `nix build .#hostChecks.x86_64-linux.frieren` | 13.16 s | 720.0 MiB | ok, 2035 assertions |
| `nix build .#hostChecks.x86_64-linux.mtfuji` | 11.42 s | 645.5 MiB | ok, 1620 assertions |
| `nix eval .#inventory.hosts.fern.role` | 0.15 s | 47.1 MiB | ok (no host eval) |

After the kill the host sat at **62 % sustained IO-stall** (PSI `full avg10`) with 5.4 GiB
swapped. A crashed agent cannot repair the host it crashed, so:

- **Memory is O(hosts forced in one process).** One host per invocation, always.
- `nix flake check` is gated behind `task checks:flake`, which **refuses below 16384 MiB
  of `MemTotal`** and points at the bounded gates.
- **No task in this repo defaults to the fleet, and that is a rule, not a gap.**
  `checks:host:HOST=<host>` takes exactly one host and the name is required;
  `checks:hosts:HOSTS="a b"` takes a named set and **refuses to run without one**.
  An earlier revision of this work shipped a `checks:hosts` defaulting to all 21 x86_64
  hosts and a `checks:hosts:all` that swept 27 — the same footgun, serialized, and handed
  to every agent that reads the contract. A default is what an agent runs. Do not
  reintroduce a default host set.
- **The fleet is CI's job.** `.github/workflows/nixcachix.yml` maps affected hosts to
  runners, so each host gets its own machine: `nix build .#nixosConfigurations.<host>`
  plus `.#hostChecks.<arch>.<host>`. That is where "check every host" belongs.
- `MODE=eval` makes `checks:host` **arch-independent** (it evaluates the config instead
  of building it), which is the only way to check an aarch64 or darwin host from an
  x86_64 machine: `task checks:host HOST=penguin MODE=eval` (2.7 s, 452 MiB).

**Both former gate failures now pass** (`task checks:host HOST=minyx MODE=eval` → 1689
assertions, `HOST=cassini MODE=eval` → 352, both rc=0). They failed on *priority and
availability*, which only a whole-config eval catches: `boot.kernelPackages` and
`home.homeDirectory` each had two equal-priority definitions (a conflict, not a pick),
and three shared home modules set Linux-only options on darwin. Fixes live where the
fact does — `base-node.nix` uses `lib.mkOverride 1500`, weaker than `mkDefault` so a
hardware module always wins; `homeDirectory` is `mkDefault`; the `xdg` blocks in
`freebuff-remote`/`mainframe-remotes` are `mkIf isLinux`; and `niri.nix` gates its own
body, because a `pkgs`-dependent `imports` entry reads `config` and recurses.
- Every bounded run goes through `scripts/task/oom-guard.sh`, which polls
  `/proc/vmstat oom_kill`, memory/io PSI and `MemAvailable` **every 10 s** and kills the
  run on pressure instead of letting it take the host down. It measures the whole
  **process group**: sampling only the direct child reported a 4.9 MiB peak for a run
  that actually took a 6 GiB grandchild to the OOM killer.

#### Agent Verification Protocol (compute discipline)

Verification is **phased, and each phase has exactly one job.** Confusing the
phases is what produces both failure modes at once: cheap per-option evals run as
ritual (proving nothing) while the build that would have caught the error is
never run.

**Phase 1 — Pre-build: one bounded gate, not a toplevel force.**
`nix eval .#nixosConfigurations.<host>.config.networking.hostName` proves nothing
(one option, no type checking). `nix build .#hostChecks.<system>.<host>` runs the
module system and every assertion — 13.16 s / 720 MiB on frieren — and is the
normal pre-build gate.

The whole-toplevel force (`…toplevel.drvPath`) instantiates the entire derivation
graph: **>120 s with swap on frieren**, O(hosts) in memory. It is a **CI / operator
instrument**, never a per-edit or pre-rebuild step. `nixos-rebuild switch` forces
the same graph, so a `.drvPath` eval first is duplicate work for no extra proof.
On a local rebuild, run **no** check first — the switch is the check.

- **Cheaper first.** `hostChecks` catches the option-conflict / bad-value / policy
  class without instantiating the closure. Reach for `.drvPath` only when the
  change is derivation-level wiring and CI cannot cover it.
- **Budget it, and run it under the guard.**
  `bash scripts/task/oom-guard.sh --timeout 180 -- nix eval --raw …` kills the run on
  10 s OOM/PSI polling instead of dragging the host into swap death. Use
  `--timeout 3` for the leaf registry reads (`.#inventory.*`), which cost 0.15 s.
- **Preserved hosts are not check targets.** `status = "preserved"` is dormant,
  and some are *known-broken* (cassini's `homeDirectory` conflict predates this
  tree). `warm-host.sh --check`, `infra:deploy:*` and `infra:apply:*` warn and
  exit 0 **before any eval, cache query, ssh or validate** — a dormant failure
  is not this run's regression. Revive with `ALLOW_PRESERVED=1`; never sweep
  preserved hosts into a fleet check.
- **Scope to what the change reaches, never the fleet:** host-local edit → that
  host; chain module (`modules/global/*`, `modules/profiles/*`, `modules/roles/*`)
  → one representative host per chain affected; `flake/` wiring → one host per
  kind (nixos, darwin, home) — **active** hosts only.
- **Batch into ONE bash loop**, not one tool call per host.
- **A whole-system sweep is for wiring changes, not a habit.** Eval a whole system
  sparingly; eval the closure you changed often.
- **Keyless environments (Codespaces, CI sandboxes, fresh clones).** Evaluation
  never needs sops keys, age keys or secret values — sops-nix only declares file
  paths at eval time. Safe: `nix eval`, `alejandra --check`, `deadnix`,
  `statix check`. NOT keyless: `task checks:quick` (sops drift step), any
  `infra:*` secret/deploy task.

**Phase 2 — Build: the build IS the test.** Once a change alters the closure,
evaluation is no longer evidence. Build it — never on the target host:

```bash
task infra:warm:host:<host>      # build on the builder; verify the cache serves it
task infra:deploy:host:<host>    # ONE intended host: gate → plan → apply → validate
# checks:build:route is CI/operator-only: it forces the toplevel. Do not chain
# it in front of a rebuild; invoke it deliberately when routing is in doubt.
```

Fleet-wide building is a **schedule**, not an ad-hoc action (`fleet-warm-cache`
runs weekly on `frieren`). A host that is needed now is deployed out of schedule
with `infra:deploy:host:<host>` — one intended host, never the fleet.

**Phase 3 — Size/shape analysis is build preparation, not verification.**
`dev:closure:top`, `dev:closure:size`, `dev:closure:reduce` answer *"what is big,
what will be fetched, what is duplicated"* — questions you ask to decide **how** to
build. They read the store DB and verify nothing. Use them before a build; never
in place of one.

> **eval to catch a config error · build to prove a closure · size to plan a
> build.** Never build without cause — but never mistake an eval for one.

**A check must not be able to spend build budget.** `frieren` configures
`eu.nixbuild.net` as a distributed builder (`/etc/nix/machines`), and nixbuild.net
bills **per build-second** against a 25 h/month free tier — so any `nix build`
that reaches a missing derivation spends money, wherever it is run from. Two
rules follow:

- **Never call `nix build` in a check/gate path.** `nix build --dry-run` does not
  build, but it is one edit away from not being a dry run — on 2026-10-15 a
  `--check` that used `nix build --print-out-paths` dispatched full closures (incl.
  stark's NVIDIA closure) to the remote builder and consumed the month's budget.
  Prefer `nix eval --raw "<attr>.outPath"` (forces the path, builds nothing) plus
  `nix path-info --store <cache> <path>` (asks the cache).
- **If a check must shell out to nix build, pass `--builders ""`** so it cannot
  dispatch even if the dry-run flag is lost. `scripts/task/warm-host.sh` does this
  in `pending_count()`.

Budget is spent deliberately, by `task dev:nixbuild:warm` — never as a side effect
of looking.

**Never put ssh in an unattended path.** A pre-switch hook that opens ssh can
block on an interactive auth prompt: Tailscale SSH added a browser check on `fern`
and silently hung an unattended run for 5 minutes. Use the LAN address
(`TARGET=user@<lan-ip>`) or, better, ask a question the binary cache can answer
over plain HTTP with a timeout (`scripts/task/warm-host.sh` does exactly this).

**When a build IS needed, never run it *on* the target host — warm it
elsewhere first.** A `nixos-rebuild build --flake .#<host>` executed on a
   lightweight host saturates it (measured: load ~9.4 on fern's 2c/4t, killed
   after 30 min), while the same closure built on a CI runner and pushed to
   cachix took **6m53s** and left the host a substitution-only rebuild. The
   constraint is already declared per host in `inventory.toml`
   (`compute_tier`, `allowed_tasks`) — e.g. fern: *"15W dual-core processor and
   8GB RAM; avoid heavy compilation loops"*. Burn CPU on builders, not on the
   machine that asked for the config.
   - **Preferred — CI** (free, already wired, maps host→runner arch from
     `inventory.toml` and pushes to the `shaoyanji` cache):
     `task dev:ci:trigger:<host>` (= `gh workflow run nixcachix.yml -f host=<host>`).
   - **Or the remote builder** (nixbuild.net free tier = 25 build-hours/month,
     so budget it): `task dev:nixbuild:plan` to report the gaps, then
     `task dev:nixbuild:warm` (builds with `--max-jobs 0`, pushing to cachix).
   - **Verify the warm landed** before touching the host:
     `task checks:build:route` must report READY (it asks the cache directly,
     over HTTP, with no ssh) — `task dev:nixbuild:plan` is the nixbuild.net view.
   - This is `exp-107`/`exp-113` in `AGENTS.nix`; the enforcement gate is
     `task checks:build:route`, implemented by `scripts/task/warm-host.sh`.

````
### Secrets & SOPS

```bash
task infra:secrets:edit:secrets  # Edit sops secrets file
task infra:secrets:edit:apikeys  # Edit API keys env file
task infra:secrets:edit:taskfile # Edit encrypted Taskfile
task infra:sops:get:*            # Query a secret value
task infra:sops:fzf              # Select env entries interactively
task infra:sops:update-keys      # Rotate SOPS recipient keys
````

### SMTP Auth

```bash
task infra:smtp:auth             # Interactive SMTP auth for hosts (using app passwords)
# Prompts for: host, username, app-password; outputs MSMTP/MUTT config for the host
```

### Site (`docs-site/` retired 2026-10-19; the site is `.#fleet-docs-site`)

Nix-native `lib/aki-site.nix` served by frieren; nav from the knowledge graph, so
no page list, no Python renderer and no repo copy (`docs/docs-pipeline-audit.md`).
The publisher site (`dev:site:*`) is separate.

```bash
task docs:build   # markdown tree (nix build .#docs)   ·   task docs:site   # rendered site
```

### TOTP (cloak)

```bash
task dev:cloak:view              # Pick TOTP from list (gum filter)
task dev:cloak:view:github       # Direct by name
task dev:cloak:edit              # Edit TOTP accounts file
task dev:cloak:sync-bw -- ./export.json  # Import from Bitwarden export
```

### Operator Helpers

```bash
task agents:menu                 # Interactive operator control plane
```

### Nix Raw Commands

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel          # Build host closure
nix build .?submodules=1#nixosConfigurations.<host>.config.system.build.toplevel  # With submodules (CI)
nix build .#hostChecks.x86_64-linux.frieren                                  # ONE host eval gate (~700 MiB)
bash scripts/task/oom-guard.sh --timeout 3 -- nix eval --raw .#inventory.hosts.fern.role  # leaf read, no host eval
nix build .#devShells.x86_64-linux.default                                   # Enter dev shell
alejandra <file>                                                             # Format Nix file
alejandra --check <file>                                                     # Check formatting
```

---

## Network Storage Taxonomy & Media Server Architecture

The persistent network storage is hosted on the primary 24/7 server `frieren` at `/srv/data` and mounted across the fleet at `/Volumes/data` via NFS (`modules/profiles/nas-client.nix`).

### Canonical Storage Layout

| Path (`/srv/data/` / `/Volumes/data/`)    | Role & Purpose                                       | Indexing & Access Policy                                                                                                                                                  |
| ----------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `arr/`                                    | Movies and TV series                                 | **Indexed by Jellyfin & Plex**. Strictly clean video containers (`.mkv`, `.mp4`). No archives, software installers, or ISOs.                                              |
| `media/`                                  | Primary media library mirror                         | Legacy and direct media storage.                                                                                                                                          |
| `software/`                               | Software installers, desktop utilities, fonts, tools | **Unindexed**. Contains `software/torrents/` (software downloads moved out of `arr/`) shielded with `.nomedia` and `.plexignore` to prevent media scanner probe failures. |
| `books/`                                  | Books, papers, theses, comics                        | Unindexed by video media servers; indexed by document search (`qmd`). Organized into `programming/`, `philosophy/`, `ai/`, `science/`, `comics/`.                         |
| `isos/`                                   | Operating system images and installers               | Linux (`arch`, `nixos`, `ubuntu`, `fedora`), appliances (`opnsense`, `openwrt`), and Raspberry Pi images.                                                                 |
| `german/`                                 | Language learning materials                          | Organized into `books/`, `audio/`, and `notes/`.                                                                                                                          |
| `devices/`                                | Device firmwares and recovery ROMs                   | Hardware payloads (e.g. OnePlus 6 recovery tools).                                                                                                                        |
| `projects/`                               | Cloned git repositories and source projects          | Active code checkouts (e.g. `nixconfig`, `bountystash-web`, `gpt2099.nu`).                                                                                                |
| `bin-x86/`, `bin-aarch64/`, `bin-script/` | Lazily served standalone binaries & scripts          | Accessible directly across the fleet over NFS/HTTP without building Nix derivations.                                                                                      |
| `appimages/`                              | Lazily served AppImages                              | Portable Linux applications served across the network.                                                                                                                    |
| `downloads/`                              | Active aria2 RPC staging directory                   | Permissions `0775 aria2:users`. Kept clean as an ephemeral staging area; finished downloads are sorted to their target taxonomy folder.                                   |
| `p/zhuomin`                               | User's archives                                      | **Private**: Permissions strictly enforced at `0700 devji:users`. Preserved intact for private review. Shielded with `.nomedia`.                                          |
| `p/ppp`                                   | User's private stash                                 | **Private**: Permissions `0700 devji:users`. Fully shielded with `.nomedia` and `.plexignore` so Jellyfin/Plex do not scan it.                                            |
| `p/web`                                   | Backward-compatibility symlink                       | Symlink pointing to `/srv/data/projects/bountystash-web`.                                                                                                                 |
| `security/`                               | Credentials, recovery keys, certificates             | **Restricted**: Permissions strictly `0700 devji:users` (`0600` for private files). Never exposed to network guests.                                                      |
| `storage/`                                | Backward-compatibility symlink                       | Points to `.` (the data root) so legacy paths like `/Volumes/data/storage/...` resolve seamlessly.                                                                        |

### Media Server Isolation Rules

- **Jellyfin and Plex libraries**: Point to `/srv/data/arr` and `/srv/data/media`.
- **The Probe Failure Trap**: Media scanners invoke `ffprobe` on all files within indexed trees. When non-media files (e.g., Windows ISOs, Mathematica binaries, zip archives) exist in `arr/`, the scanner crashes with recurring probe exceptions.
- **Enforcement**:
  1. Only video and subtitle files (`.mkv`, `.mp4`, `.srt`, etc.) belong in `arr/`.
  2. Software torrents and non-media data are isolated in `software/torrents/` or `books/`.
  3. Directories that should never be indexed must contain `.nomedia` and `.plexignore` sentinel files.
  4. Run `task data:audit` to verify media hygiene.

### Security Directory & Key Fallback Architecture

- **SOPS as Canonical Truth**: All primary secrets, API tokens, and user credentials reside in `modules/secrets.yaml` (and `modules/secrets/apikeys.yaml`).
- **Cloak (TOTP)**: Fully integrated into `modules/secrets.yaml` under `.cloak`. Managed with `task dev:cloak:*`.
- **Master Key (`id_ed25519`)**: Kept at `0600` inside `security/` (protected by `0700` directory permissions) and encrypted as `id_ed25519.age` using fleet age keys (`frieren`, `devji`, `poseidon`).
- **Universal NuShell Fallback (`gist.nu`)**:
  - Dynamically searches for `apikeys.yaml` in standard workspace locations (`~/Documents/nixconfig`, `/srv/data/nixconfig`) and decrypts via `sops`.
  - Automatically discovers age identities (`~/.config/sops/age/keys.txt`, `~/.ssh/id_ed25519`, or local security keys) for transparent decryption.

---

## Secrets Architecture

Two separate encrypted files, decrypted via `sops-nix` using host age keys:

| File                      | Decryptors                                                                         | Contents                                      |
| ------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------- |
| `modules/secrets.yaml`    | All hosts (via `ssh_host_ed25519_key`)                                             | App secrets, `hashedPassword`, API keys, TOTP |
| `modules/ssh-ca-key.yaml` | Full fleet (all age recipients in `.sops.yaml`; includes frieren since 2026-10-08) | SSH User CA private key                       |

**Key locations**:

- `.sops.yaml` — age key registrations (each host maps its `ssh_host_ed25519_key` age pubkey)
- `modules/secrets/` — **git submodule** pointing to private `shaoyanji/secrets` repo (contains actual encrypted files)
- `modules/secrets.yaml` — local symlink/mirror of the submodule's secrets.yaml

**SSH CA workflow**:

- Servers trust a single CA public key (`modules/ssh-ca.nix`)
- Workstations sign 1-week certs via `rotate-ssh-cert` (uses `~/.ssh/user_ca_key` from sops-nix)
- No `authorized_keys` management needed after CA setup

**Bootstrap**: First connection to bare metal is outside CA model (USB ISO/temp password).

---

## CI Pipeline & Control Plane

GitHub Actions in `.github/workflows/`:

- `nixcachix.yml` — Unified multi-architecture dynamic change-detection pipeline (`scripts/ci/detect-affected-hosts.py`):
  - Single canonical workflow replacing old separate Darwin/ARM files.
  - Automatically maps fleet host metadata from `inventory.toml`:
    - `arch` -> Runner OS (`x86_64-linux` -> `ubuntu-latest`, `aarch64-linux` -> `ubuntu-24.04-arm`, `aarch64-darwin` -> `macos-latest`).
    - `kind` -> Flake attribute (`nixosConfigurations.*`, `darwinConfigurations.*`, `homeConfigurations.*`).
  - Documentation/meta changes (`*.md`, `docs/`, `taskfiles/`) skip runner allocation (0 builds).
  - Host-specific changes (`hosts/<host>/**`) build only the affected host on its target architecture.
  - Shared Nix modules (`modules/**`, `flake.lock`) anchor to `frieren` by default.
  - Policy enforcement: Hosts with `ci = false` (e.g. unfree NVIDIA on `stark`/`kellerbench`) and dormant `status = "preserved"` hosts are automatically excluded.
  - Commit message overrides: `[skip ci]`, `[ci all]`, `[ci <host1,host2>]`.
  - Manual dispatch: `task dev:ci:trigger:<host>` or via GitHub Actions UI.

Operator control tasks:
- `task dev:ci:plan` — Evaluate CI impact of unpushed commits against `origin/main`
- `task dev:ci:plan:worktree` — Evaluate CI impact of current working tree changes
- `task dev:ci:trigger:<host>` — Manually trigger CI build for `<host>` (or `all`)

CI uses `nix build -L .?submodules=1#...` (note `?submodules=1` for git submodule support).

---

## Nix Patterns & Gotchas

### HARD RULE: never hand-edit TOML — edit through a format-aware tool

**TOML is edited with a TOML AST editor, never by text substitution.** This is not
style: hand-editing `inventory.toml` in this repo produced unparseable TOML (a
stray-indent anchor silently merged two lines), and it is not caught until
something else reads the file.

**yq chooses the parser from the PATH'S EXTENSION, and that is the real trap.**
`yq -i '<expr>' some.toml` is correct. Hand the same expression a path that does
not end in `.toml` — a temp copy called `/tmp/inv.test` — and yq falls back to
YAML, reads `[metadata]` as a YAML flow sequence, and dies with
`Error: cannot index array with 'metadata'` while writing nothing. Verified both
ways on this repo's file. Keep the `.toml` extension on every path you give yq,
or pass `-p toml -o toml` explicitly (as `scripts/task/modules-menu.sh` does).

> A previous revision of this section claimed `yq -i` was simply broken on TOML.
> That was a bad test using a non-`.toml` temp filename, **not** a yq defect —
> `scripts/task/inventory-menu.sh`'s `yq -i` writes work correctly. Do not
> "fix" it again on that basis.

Separately: yq's TOML *output* collapses multi-line arrays, so **any** yq write
reformats `inventory.toml` (expect a large cosmetic diff). That is formatting,
not data loss; the values survive.

**A second silent no-op, found 2026-10-15: `yq -i -f script.yq file.toml` ignores
the script.** It exits 0, rewrites the file — so `git diff` shows a big diff — and
applies *nothing*: the script is dropped, leaving the identity transform, which is
exactly why it looks like it worked. The identical program with the flags in the
other order, `yq --from-file script.yq -i file.toml`, applies correctly. Both
verified on `inventory.toml` with yq v4.54.1. Prefer an inline expression; if you
need a script file, put `--from-file` **before** `-i`, and then verify the *effect*
— `git diff` is not proof, because the array collapse above produces diff noise even
when nothing was applied. The evidence that counts is the compiled result:
`nix eval --raw .#inventory.json` before and after, diffed.

```bash
# Read (safe; exits 1 on a parse error)
yq '.hosts | to_entries | length' inventory.toml

# Value write (AST-level). The path MUST end in .toml:
yq -i '.hosts.eisen.managed = true' inventory.toml

# Explicit about the format — use this in scripts, where a path may be a temp file:
yq -p toml -o toml -i '.hosts.eisen.managed = true' inventory.toml

# Surgical, format- AND comment-preserving (no array reflow) via tomlkit:
nix shell --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs").outPath {}; in pkgs.python3.withPackages (ps: [ps.tomlkit])' \
  -c python3 -c 'import tomlkit; d=tomlkit.parse(open("inventory.toml").read()); d["hosts"]["eisen"]["managed"]=True; open("inventory.toml","w").write(tomlkit.dumps(d))'

task checks:toml:lint                                 # prove EVERY tracked .toml parses
```

- Keep the `.toml` extension on yq paths, or pass `-p toml -o toml`. Never
  `sed -i`, never an editor-style string replace.
- After any TOML change — including one the tools cannot express — run
  `task checks:toml:lint`. It exits non-zero and names the offending file.
- The same applies to JSON (`jq`) and YAML (`yq -p yaml -o yaml`); the rule is
  "edit through a format-aware tool", not "edit text that happens to be data".
- **Better: do not edit at all.** `inventory.toml` is compiled to typed data by
  `lib/inventory.nix`; read it with `task dev:inventory:json` (or
  `nix eval .#inventory…`) instead of re-parsing TOML with yq. See
  `docs/inventory-schema.md`.

### Non-obvious patterns

- **User constants**: `modules/global/user.nix` is the single source of truth for the primary user (`devji`). Import it with `let user = import ../global/user.nix;` — never hardcode user paths or the username.
- **Attrset merging**: `//` is **shallow, right-biased** — `{ a.x = 1; } // { a.y = 2; }` loses `a.x`. Use `lib.recursiveUpdate` for deep merge.
- **`lib.mkIf` / `lib.mkMerge`**: the standard conditional patterns. Also `lib.optionalAttrs` for conditional attrsets and `lib.optionals` for conditional list items.
- **Option priorities**: `lib.mkDefault` vs `lib.mkForce` vs `lib.mkOverride` are used for option priority layering.
- **`profiles.boot` module**: boot options are accessed via `config.profiles.boot.systemd-boot` and `config.profiles.boot.efi` (not direct `boot.loader.*`).

### Build-avoidance traps

Some packages build from source (Maven, Go, etc.) with no cached variant for overridden configurations:

| Module                                 | Issue                                                      | Mitigation                                                |
| -------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------- |
| `services.tika` (`search/tika.nix`)    | `cfg.package.override { enableGui = false }` → Maven build | Inline systemd unit with stock `pkgs.tika`                |
| `services.gotenberg` (`paperless.nix`) | Chromium stub at module level keeps ~300 MiB chromium      | Configure `services.gotenberg.chromium.package` with stub |

Before deploying a host referencing Java (Maven/Gradle), Go, or Rust packages, run `nix build --dry-run` to verify the closure is cached.

### Service module conventions

- **Option namespaces**: `services.<name>` for system services, `profiles.<name>` for composable profiles
- **`lib.types.nullOr lib.types.path`**: optional file path patterns use this type
- **Secret injection**: uses `systemd LoadCredential` (never on command line). Example: `rpcSecretFile` in aria2-daemon module.

### CI quirk

CI commands use `nix build -L .?submodules=1#...` — the `?submodules=1` is critical for accessing the `modules/secrets` submodule. Local `nix build` without that flag works fine since the submodule is already checked out.

### Autonomous Agent Operational Rules & Nix Environment Gotchas (Field Notes)

When autonomous agents (`agy`, `hermes`, subagents) execute tool calls across NixOS hosts and WSL2, the pure/declarative nature of Nix introduces specific failure modes that do not exist in conventional FHS Linux distributions:

#### 1. Non-Login SSH Shells Lack Ambient Profile PATH
* **Failure Mode**: Running `ssh host 'python3 ...'` or `ssh host 'simplex-chat ...'` fails with `bash: line 1: command: not found` (exit code 127), even though the package is installed in `environment.systemPackages` or `home.packages`.
* **Root Cause**: Non-interactive, non-login SSH sessions do not execute `/etc/profile` or Home Manager session scripts, so Nix store binaries in `/run/current-system/sw/bin` and `~/.nix-profile/bin` are absent from `PATH`.
* **Fix**: Force a login shell via `ssh host 'bash -l -c "command"'`, invoke via full path (e.g. `/etc/profiles/per-user/<user>/bin/<binary>`), or run dynamically via `ssh host 'nix shell nixpkgs#<pkg> -c <bin>'`.

#### 2. Python Package Composition in `nix shell` (`python3.withPackages`)
* **Failure Mode**: Calling `nix shell nixpkgs#python3 nixpkgs#python3Packages.websockets -c python3 script.py` fails with `ModuleNotFoundError: No module named 'websockets'`.
* **Root Cause**: In Nix, Python modules are not ambiently placed in a global `site-packages`. Providing `python3` and `python3Packages.foo` as separate packages in `nix shell` produces two distinct store paths; the Python interpreter does not know about the library.
* **Fix**: Always compose dependencies explicitly via `withPackages`:
  ```bash
  nix shell --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.python3.withPackages (ps: with ps; [ websockets requests ])' -c python3 script.py
  ```
  Declaratively, specify `(python3.withPackages (ps: with ps; [ ... ]))`.

#### 3. Flakes Ignore Untracked Files (`git add -N` Trap)
* **Failure Mode**: After creating a new Nix module or overlay (e.g. `modules/services/smp-server.nix`), running `nix build`, `nix eval`, or `nixos-rebuild` errors with `file does not exist` or evaluates stale code.
* **Root Cause**: Nix Flakes evaluate strictly against the git staging index / tracked tree. Untracked working tree files are completely invisible to the Nix evaluator.
* **Fix**: Always stage newly created files before invoking Nix:
  ```bash
  git add -N <path/to/new/file.nix>
  ```

#### 4. Stale SSH ControlMaster Multiplexing Sockets
* **Failure Mode**: Remote `ssh <host>` commands hang indefinitely without output until cancelled or timed out.
* **Root Cause**: `~/.ssh/config` enables `ControlMaster auto` with socket paths under `~/.ssh/sockets/%r@%h:%p`. If a previous SSH process or subagent terminated abruptly, a dead Unix socket remains, causing subsequent SSH calls to wait on a non-responsive master multiplexer.
* **Fix**: For non-interactive agent commands, bypass ControlMaster by passing `-o ControlMaster=no`:
  ```bash
  ssh -o ControlMaster=no host 'command'
  ```
  Or purge stale master sockets: `rm -f ~/.ssh/sockets/*`.

#### 5. Cross-Device Link / Permission Denied on Symlinked Secrets (`atomic_replace`)
* **Failure Mode**: Application setup wizards (e.g. `hermes gateway setup`) crash with:
  `OSError: [Errno 18] Invalid cross-device link: '/home/user/.app/.env.tmp' -> '/run/secrets/rendered/app.env'`
  followed by `PermissionError: [Errno 13] Permission denied: '/run/secrets/rendered/app.env'`.
* **Root Cause**: Tools like Python's `atomic_replace` write to a temporary file on disk (`/home/user/`) and execute `os.replace` to replace the target. If `target` is a symlink pointing to `/run/secrets/` (rendered on a `tmpfs` RAM disk with `0400` mode), `os.replace` fails across filesystem boundaries, and fallback copy fails due to read-only `0400` file permissions.
* **Fix**: Never symlink mutable application configuration files (where self-managing CLIs write runtime tokens) directly into read-only `tmpfs` secrets. Decouple into an independent `0600` standalone file populated with secrets, or inject credentials via systemd `EnvironmentFile` directly.

#### 6. Upstream FHS Binaries on NixOS (Dynamic Linker & Missing Subprocess Tools)
* **Failure Mode**: Running raw upstream Linux binaries directly yields `/lib64/ld-linux-x86-64.so.2: No such file or directory`. Even with `autoPatchelfHook`, subprocess calls during `init` (e.g. calling `openssl` or `/bin/sh`) fail with exit code 127.
* **Root Cause**: NixOS does not conform to the FHS filesystem layout (no `/lib64` or ambient `/bin/sh`).
* **Fix**:
  1. Package upstream binaries in overlays with `autoPatchelfHook` and complete `buildInputs` (`[ zlib openssl gmp stdenv.cc.cc.lib ]`).
  2. For systemd services, explicitly provide runtime CLI dependencies via `systemd.services.<name>.path = with pkgs; [ openssl coreutils gnused bash ];`.

#### 7. Strict Firewall Scoping Overrides Global `allowedTCPPorts`
* **Failure Mode**: A service declares `networking.firewall.allowedTCPPorts = [ port ];` (or `openFirewall = true`), but the port remains unreachable and packets are silently dropped.
* **Root Cause**: Hardened hosts (e.g. `hosts/frieren/firewall-scope.nix`) use `lib.mkForce` to clear global allowed ports and enforce strict per-interface scoping (`enp1s0`, `wlp2s0`, `tailscale0`) to prevent container bridge leaks (`docker0`).
* **Fix**: On scoped hosts, always add new service ports to `scopedTCP` in `hosts/<host>/firewall-scope.nix` in addition to the service module's `openFirewall`.

#### 8. Haskell / Haskeline Piped Stdin Crash (`System.Terminal.Platform: undefined`)
* **Failure Mode**: Piping commands into terminal-oriented CLIs (like `simplex-chat`) via `printf "cmd\n" | simplex-chat` terminates immediately with `simplex-chat: Prelude.undefined ... System.Terminal.Platform`.
* **Root Cause**: Interactive terminal frameworks expect a pseudo-terminal (TTY). Passing piped stdin into interactive loops invokes unhandled code paths in the terminal driver.
* **Fix**: Use dedicated non-interactive execution flags (e.g. `simplex-chat -e "<cmd>"`) or communicate via daemon WebSocket / JSON-RPC APIs (`simplex-rpc.py`).

#### 9. Remote Heredoc Backtick / Variable Expansion
* **Failure Mode**: Running `ssh host 'bash -c "cat << EOF ... \`backticks\` ... $var ... EOF"'` produces syntax errors on remote or evaluates variables locally on the caller machine.
* **Root Cause**: Double-quoted SSH strings and unquoted heredoc tags (`<< EOF`) expand variables and command substitutions before transmission.
* **Fix**: Always quote heredocs (`<< 'EOF'`), write scripts to shared storage (`/Volumes/data/projects/...`), or pipe scripts into remote interpreters via stdin (`ssh host 'python3' < script.py`).

#### 10. Negative Narinfo Cache Makes a Freshly Warmed Cache Look Empty
* **Failure Mode**: A target stuck pulling from harmonia before its closure was warmed keeps failing with `path is not valid` / `don't know how to build these paths` even *after* the builder finishes `infra:warm:cache` — a raw HTTP fetch of the `.narinfo` returns 200 (signed), yet every `nix path-info --store` / `nix copy --from` still reports the path missing. `warm-host.sh`'s post-build verification can false-fail the same way.
* **Root Cause**: Nix caches negative (404) narinfo lookups for **1 hour** (`narinfo-cache-negative-ttl`, in-process plus the user's on-disk `~/.cache/nix/binary-cache-v6.sqlite`). Any query that ran during the gap — the target's stuck pull, the builder's own pre-build gate — poisons the answer for the full TTL, on both the target and the builder.
* **Fix**: Disable the negative cache on every cache-serving check and every pull of a just-warmed path: `--option narinfo-cache-negative-ttl 0`. `scripts/task/activate-host.sh` (gate + remote `nix copy`) and `scripts/task/warm-host.sh` (`served_by_cache`) already do this. One-off: `nix path-info --store http://192.168.3.25:5000 --option narinfo-cache-negative-ttl 0 <path>`.

---

## Adding a New Host

1. Create host module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix` for simple cases)
2. Add hardware/storage as needed (e.g., `hardware-configuration.nix`, `disko.nix`, or profile imports)
3. Register in `flake/host-inventory.nix` with:
   - `kind` (`nixos`, `darwin`, or `home`)
   - `system` (e.g., `"x86_64-linux"`)
   - Module chain (`globalModulesNixos`, `globalModulesImpermanence`, `globalModulesContainers`, etc.)
   - Host module path(s)
   - `specialArgs` or `extraSpecialArgs` as needed
4. Output assembly is automatic via `flake/host-projection.nix`
5. Build: `task infra:plan:host:<name>` or `nix build .#nixosConfigurations.<name>.config.system.build.toplevel`

For provisioning a new server:

- The host's age key (from `ssh_host_ed25519_key`) must already be in `.sops.yaml` for `hashedPassword` decryption
- `ssh.ca.enable = true` is inherited from `base-node.nix`
- SSH in using a cert from your workstation

---

## Task Namespace Summary

See [Task Control Plane](docs/task-control-plane.md) for full namespace definitions and workflow examples.

| Namespace       | What                                                                                                         | Skill                                  |
| --------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| `infra:*`       | Host lifecycle, secrets, SOPS                                                                                | `.agents/skills/infra/SKILL.md`        |
| `agents:*`      | Operator menu, xs, OAuth                                                                                     | `.agents/skills/agents/SKILL.md`       |
| `checks:*`      | Validation, smoke checks, nix lint                                                                           | `.agents/skills/checks/SKILL.md`       |
| `dev:*`         | Git, flake, site, PRs, packages                                                                              | `.agents/skills/dev/SKILL.md`          |
| `data:*`        | NAS storage taxonomy, hygiene, permissions, media unindexing                                                 | `.agents/skills/data/SKILL.md`         |
| `moto:*`        | Motorola Android (Termux) shell, file push/pull, Wish/Gum menu                                               | `.agents/skills/moto/SKILL.md`         |
| `serv00:*`      | Serv00 FreeBSD hosting, Devil CLI, webserver lifecycle                                                       | `.agents/skills/serv00/SKILL.md`       |
| `dragoncourt:*` | Alwaysdata Debian hosting, PHP/Wasm webserver                                                                | `.agents/skills/dragoncourt/SKILL.md`  |
| `envs:*`        | Envs.net Debian hosting, public_html / Gemini / Gopher, build pipeline                                       | `.agents/skills/envs/SKILL.md`         |
| `bountystash:*` | Bountystash Console (<14KB TCP budget), preview & Cloudflare Pages deployment                                | `.agents/skills/bountystash/SKILL.md`  |
| `apps:*`        | Job application workflow (appflow): status updates, email flow, sync, builds                                 | `.agents/skills/apps/SKILL.md`         |
| `services:*`    | Legacy wrappers (canonical: `infra:*`)                                                                       | `.agents/skills/services/SKILL.md`     |
| `google-drive`  | Google Drive OAuth setup, rclone, tailscale funnel                                                           | `.agents/skills/google-drive/SKILL.md` |
| `antigravity`   | Delegate coding to Antigravity CLI (Google's agent) with `--dangerously-skip-permissions` and `--jsonschema` | `.agents/skills/antigravity/SKILL.md`  |
| `crush`         | Delegate coding to Crush CLI (Charm's agent) with `--yolo` and structured output                             | `.agents/skills/crush/SKILL.md`        |

---## Taskfile as the Agent Contract

`task --list-all --json` is the discovery API (`desc`, `summary`, aliases); the
`summary` field carries the variable/exit-code contract, and no task may use
`internal: true` (it hides the task from JSON too). Wildcards are not invocable —
call the concrete name. Full authoring rules: `docs/task-control-plane.md` and the
`task-plane` skill. New observation tasks belong in `taskfiles/ops.yml`.


## Memory hierarchy (jev decides escalation)

| Layer              | Role                                          | When used                                      |
| ------------------ | --------------------------------------------- | ---------------------------------------------- |
| MEMORY.md          | Boot — persists across sessions               | Always loaded                                  |
| Vault              | Fast working memory — offline, personal       | First stop for context                         |
| qmd wiki           | Resource — docs, runbooks, codebase           | Concept/location queries                       |
| mem0 / supermemory | Deep consult — when vault + wiki insufficient | Decided by jev (min-prob 0.8, min-margin 0.15) |

Search order: vault → wiki (qmd BM25) → graph (`task ops:kg:*`) → mem0/supermemory (jev-decided) → web. Skills: `qmd search "<topic>" -c skills --format json`.

---

## qmd Search Operations

Local hybrid search over markdown docs and notes via `qmd` (`pkgs.llm-agents.qmd`, installed fleet-wide). Three canonical collections:

| Collection  | Target Path                                              | Content                                                                                 |
| ----------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `nixconfig` | `/srv/data/projects/nixconfig` (`~/Documents/nixconfig`) | This repo's documentation: README, AGENTS.md, runbooks, `docs/*`, `taskfiles/README.md` |
| `vault`     | `/Volumes/data/Obsidian-Git-Sync` (`~/vaults/personal`)  | Personal Obsidian vault: zettels, schematics, notes                                     |
| `skills`    | `~/.hermes/skills/`                                      | Agent skills indexed for BM25 search                                                    |

### Index lifecycle

```bash
task dev:qmd:refresh             # Register (if missing) and reindex both collections
task dev:qmd:vault:refresh       # Reindex the Obsidian vault only
task dev:qmd:docs:refresh        # Reindex nixconfig docs only
task checks:qmd:docs             # Verify nixconfig collection registered + index fresh
task checks:qmd:vault            # Verify vault collection registered + index fresh
```

The `checks:qmd:*` tasks exit 1 when a collection is missing or any `.md` file is newer than the index; run them after doc edits.

### Querying

```bash
qmd search "impermanence disko" -c nixconfig   # repo docs only
qmd search "zettel topic" -c vault             # vault only
qmd search "query"                             # all collections
qmd search "query" --json                      # agent-friendly output
qmd get "#docid"                               # fetch a full document from search results
qmd status                                     # index health and file counts
qmd update                                     # incremental reindex (fast, BM25)
```

Prefer BM25 `qmd search` (instant); `qmd embed` (semantic vectors) is optional and slower. Prefer qmd over raw `grep` when locating concepts or runbooks across repo docs and the vault — it is ranked and collection-scoped.

**Structural queries are the graph, not `grep`.** `.#knowledgeGraph` compiles hosts × skills × docs; `task ops:kg:*` are the six fixed traversals for "what touches X". The Elixir sidecar is the DEFAULT path: `kg-query.sh` answers from its socket when live (28 ms vs ~476 ms on a dirty tree), falls back to jq byte-identically, and `checks:kg:sidecar` proves both agree — it starts at login (`programs.kgSidecar`) from the COMPILED graph. `--native` is the parity experiment (`checks:kg:native`, part of `checks:quick`), not the query path; `ops:kg:blast` is the reverse closure that jq has no one-liner for.

---

## Key Operator Helpers

- `agents:menu` is the interactive operator control plane
- `task menu` is the whole-Taskfile gum TUI; `menu:list` / `menu:json` are its
  machine surfaces. Never mark a task `internal: true` to hide it — that removes
  it from `--list-all --json` too and breaks the agent endpoint.
- NAS client recovery logic lives under `modules/profiles/nas-client.nix`

## Deployment Guidance

Host deployment flows use `infra:*` tasks directly. See `.agents/deploy/README.md` for host-specific deployment notes. Per-host quirks live in `.agents/deploy/hosts/*.md`.

## Git Hooks Setup

Pre-commit hooks in `.githooks/` run deadnix (hard gate), statix (advisory), and a formatting check accepting either alejandra or nixpkgs-fmt (hard gate). Tools missing from PATH are fetched via nix from the nixpkgs revision pinned in `flake.lock`, so the checks are machine-independent. Enable with:

```bash
bash .git-hooks-setup.sh    # sets core.hooksPath to .githooks/
```

## Nixpkgs Formatting

**alejandra is the canonical formatter** — every tracked `.nix` file is
aljandra-clean, and `dev:fmt`, `checks:nix:fix` and the pre-commit hook all run
it. The hook is a thin wrapper over `scripts/task/nix-fmt.sh`, so it uses the same
versions and the same cache as the tasks and no longer accepts `nixpkgs-fmt`.
**Never run `nixpkgs-fmt` repo-wide — it would rewrite ~170 of 187 files**, and it
is no longer installed: `base-node.nix` ships `alejandra`, `deadnix` and `statix`
instead, which also lets `nix-fmt.sh` take its PATH branch and skip the first-run
`nix build`. `task checks:nix:lint` is the deadnix/statix pass, not a formatter
check.

`scripts/task/nix-fmt.sh` is the **single implementation** behind every Nix
format/lint path, so the watcher can never use different tool versions than the
gate that judges the commit:

| Task | What |
| :--- | :--- |
| `task checks:nix:fix` | one-shot fix — the hard gates (deadnix + alejandra), all paths |
| `task dev:fmt` | alias of `checks:nix:fix` |
| `task checks:nix:lint` | **read-only gate** — deadnix (fails) + statix (advisory) |
| `task checks:nix:format` | **read-only gate** — `alejandra --check` |
| `task checks:nix:watch` | **the watch hook** — auto-formats on every save |
| `task checks:toml:lint` | every tracked `.toml` parses (the `yq` rule's guard) |

The script takes `--tools LIST` (a comma-separated subset of
`deadnix,statix,alejandra`), which is how the read-only gates keep their exact
tool sets — `checks:nix:lint` is deadnix+statix and `checks:nix:format` is
aljandra — **without** introducing a second place that resolves tool versions.
Add a new Nix tool task by passing `--tools`, never by calling
`nix-shell -p alejandra` (or deadnix/statix) directly.

The default tool set is the **hard gates, `deadnix` and `alejandra`** — the ones
that make the commit fail. **statix is never auto-applied**: it is advisory here
(its W20 warning fires on the house style, and the pre-commit hook never fixes
with it), so it is only *reported* by `checks:nix:lint`. To write its suggestions
deliberately, pass it by name:
`bash scripts/task/nix-fmt.sh --fix --all --tools deadnix,statix,alejandra`.

The toolchain resolves from the **nixpkgs revision pinned in `flake.lock`** — the
same versions `.githooks/pre-commit` uses — and is cached as GC-rooted out-links
under `~/.cache/nixconfig-nixfmt/`, so a save costs ~70 ms instead of re-resolving
a shell. The pin is re-resolved when `flake.lock` changes.

**Auto-format hook (no manual tool calls).** Start it once and leave it:

```bash
task checks:nix:watch
```

It watches `**/*.nix` via task's `watch` flag and formats only the files git
reports as dirty, so a save touches one file. It writes only when a file actually
changes — deadnix/statix/alejandra are idempotent (verified) — so it cannot
re-trigger itself into a loop. Verified end to end: a misformatted file is fixed
in under 1 s, and a pure indentation change is restored byte-identical.

One caveat it reports rather than hides: **deadnix will not strip the last lambda
argument**, so `{pkgs}: …` with an unused `pkgs` stays flagged. `--fix` re-verifies
after writing and exits non-zero on residue the tools cannot rewrite, instead of
claiming success on a tree the commit gate would still reject.

#### Operating the watcher (read this before backgrounding it)

| | |
| :--- | :--- |
| Start | `task checks:nix:watch` |
| Status | `task checks:nix:watch:status` — pid + elapsed, or "not running" |
| Stop | **`task checks:nix:watch:stop`** — signals the watcher by pid and verifies it exited (or Ctrl+C in the foreground) |
| Watch interval | `interval: '500ms'` at the root of `Taskfile.yml` — coalesces a multi-file save into one run (task's default is 100ms and duplicate events were observed) |

Three behaviours that bit us, all confirmed against
[task's watch docs](https://taskfile.dev/docs/guide/watch):

- **Stopping it is not "kill the shell that started it".** Watch mode is known to
  leave children running, and the watcher is a *grandchild* of whatever launched
  it — killing the launching shell left a live `task checks:nix:watch` formatting
  the repo for ~8 minutes, and it looked stopped because the parent PID was gone.
  Use `task checks:nix:watch:stop`: it matches the watcher cmdline exactly (so it
  can never signal the shell that launched it, or its own shell), signals it,
  waits, and **verifies** it is gone rather than assuming the signal landed. If
  you must do it by hand, `pkill -x task` then check `pgrep -x task`.
- **A task's `cmds` run in task's own restricted shell, not bash.** `kill` is an
  "unsupported builtin" there and silently does nothing — the stop task looked
  like it succeeded while the watcher kept running. Any builtin that is not plain
  POSIX may be missing, so drop to a real shell for it:
  `bash -c 'kill "$1"' _ "$pid"`.
- **`--dry` does not suppress `watch: true`.** `task --dry checks:nix:watch` starts
  a real watcher and blocks; it timed out a probe here. There is no dry run for a
  watch task.
- **`watch: true` only applies to CLI invocations.** Called from another task's
  `cmds`/`deps` it does *not* start a watcher, so it cannot be pulled in as a
  dependency and quietly hang a pipeline.

`sources` drives both change detection *and* the up-to-date check. This task has
no `generates`, so it re-runs on every change — correct for a formatter, and it
writes nothing when there is nothing to change, which is what keeps it stable.

## External Package Registry

External fetched dependencies are registered in `modules/config/fetches.json` and resolved through `lib/fetches-extra.nix`. Update hashes with:

```bash
task dev:config:hash-update    # runs nix-hash-update.sh
```

## Documentation & Site Compilation

Documentation is markdown or data that Nix compiles into a store path; the store
path is the artifact. Nothing derived is committed, and no second renderer is
allowed beside the first.

| Layer | Owner | Rule |
| :--- | :--- | :--- |
| content | `*.md`, `AGENTS.nix`, `inventory.toml`, `modules.toml` | hand-written only, never generated |
| projection | `lib/inventory.nix`, `lib/docs.nix`, `lib/knowledge-graph.nix`, `lib/skills.nix` | one pure Nix compiler per projection |
| artifact | `.#docs` (generated markdown), `.#fleet-docs-site` (the rendered site) | store paths, never repo copies |
| serving | `hosts/frieren/reverse-proxy.nix`, `modules/services/uds-static-bridge.nix` | serve the path; never re-derive content in a host module |

- **Never commit a derivative.** `docs/generated/` is `nix build .#docs`. A
  tracked copy can drift, so it needs `checks:docs:sync` — a gate that exists
  because the artifact is duplicated is proof the duplication is wrong.
- **Content is not code.** CSS/JS/HTML go in files the derivation reads, not `''`
  literals in a `.nix` file (90 % of `lib/aki-site.nix` is such literals): literals
  cannot be linted or reviewed, and every byte re-evaluates a module that imports
  the knowledge graph.
- **One instantiation.** Build the site once (`.#fleet-docs-site`) and pass the
  path to every vhost/socket; three `import`s with identical args are three evals.
- **Publishing must not need a system switch.** If a `.md` edit lands inside a
  host's closure, the docs are as live as the last `nixos-rebuild`.
- **Eval-time `builtins.readFile` is flake-scoped.** An untracked `.md` does not
  exist to the evaluator — `git add` before you eval or serve.

Audit, evidence and remediation order: `docs/docs-pipeline-audit.md`.

## Documentation Map

| File                                 | Content                                                                |
| ------------------------------------ | ---------------------------------------------------------------------- |
| `README.md`                          | Full repo documentation, architecture, all workflows                   |
| `AGENTS.md`                          | This file — canonical agent routing and codebase manual                |
| `inventory.toml`                     | Canonical fleet device registry; compiled by `lib/inventory.nix` (counts derived, not written) |
| `docs/inventory-schema.md`           | Inventory schema, compiled artifacts, and the automatic checks          |
| `docs/fleet-inventory.md`            | Pointer page — the catalog itself is `.#docs` (`nix build .#docs`), never committed |
| `docs/modules-registry.md`           | Pointer page — the knob registry is built from `modules.toml` at build time |
| `lib/aki-site.nix`                   | The rendered site (`.#fleet-docs-site`): nav comes from the knowledge graph |
| `docs/docs-pipeline-audit.md`        | Docs/site pipeline audit: duplicated artifacts, content-in-Nix, remediation order |
| `docs/closure-reduction.md`          | Closure size levers, evidence chains, and the runtime/interactive/one-shot tiers |
| `docs/closure-debloat.md`            | Tiered debloat plan: exclusive/shared/core attribution and a realistic floor |
| `.agents/fleet-matrix.md`            | Compact fleet context matrix for LLMs and agent prompts                |
| `docs/task-control-plane.md`         | Task namespace policy and workflow examples                            |
| `docs/frieren-access.md`             | frieren service-access runbook (LAN/tailnet matrix, DNS, direct ports) |
| `docs/userland-package-ownership.md` | Package ownership and role wiring                                      |
| `taskfiles/README.md`                | Taskfile ownership map and shard reference                             |
| `hosts/sledgehammer/USB.md`          | Sledgehammer live USB creation guide                                   |
| `AGENTS.nix`                         | Decisions, proposals, open work and design studies as queryable notes |
| `ARCHITECTURE.md` / `TODO.md`        | Stubs — content moved to `AGENTS.nix` (`task ops:notes`)               |
| `MANUAL.md`                          | Operator manual: services, ports, closed loop, DMS integration         |
| `.agents/SCHEMA.md`                  | Documentation/skill contract: budgets, status vocabulary, one fact one home |
| `docs/history/`                      | Superseded narrative (audit/TODO/HANDOFF) — never linked as current    |
| `AUDIT.md`                           | Current state + dated change ledger                                    |
