# AGENTS.md

**Nixconfig** — Personal Nix flake managing NixOS, nix-darwin, and Home Manager across ~20 hosts.

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `taskfiles/README.md` for ownership and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth. Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md` — see `.agents/README.md` for the full index.

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
  └── docsSite/docs-site  ← docs-site/default.nix
```

**Host registration flow**:

1. One entry per host in `flake/host-inventory.nix`: defines `kind` (nixos/darwin/home), `system`, module chain, and host module path
2. `flake/host-projection.nix` projects inventory into per-kind attrsets automatically — no manual output wiring
3. `flake/module-sets.nix` defines the 5 global module chains used as baselines

### Module Chains (defined in `flake/module-sets.nix`)

| Chain | What it includes | Used by |
|-------|-----------------|---------|
| `globalModulesNixos` | global + nixos + home-manager-shared + sops + nix-index + dms (desktop) | poseidon, aristotle, aceofspades, ancientace |
| `globalModulesImpermanence` | globalModulesNixos + impermanence + disko | schneeeule |
| containers + impermanence (ares) | globalModulesContainers + impermanence + disko | ares (Steam kiosk) |
| `globalModulesContainers` | global + noDE + sops + home-manager + nix-index (no dms/niri desktop) | thinsandy, mtfuji, kellerbench, applevalley, minyx, sledgehammer, guckloch (WSL), netbook, deckstation |
| `globalModulesMacos` | global + macos + nix-homebrew + home-manager + sops | cassini (darwin) |
| `globalModulesDemo` | global + demo + home-manager (no sops) | demo (NixOS demo VM) |
| `globalModulesHome` | standalone HM sharedModules only | penguin, alarm, kali (standalone home-manager) |

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
    steamos.nix — Steam kiosk (greetd+tuigreet+gamescope-session, audio, 32-bit GL, Avahi)
    sunshine.nix — GameStream/Moonlight server (Sunshine on LAN, video/render/input groups)
  services/        — Service modules
    aria2-daemon.nix  — aria2 RPC + AriaNg web UI via nginx (delegates to native services.aria2)
    nullclaw-deployment.nix — nullclaw fleet deployment wrapper
    zeroclaw-deployment.nix — zeroclaw fleet deployment wrapper
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

### Packages (`pkgs/`)

Custom packages built from the flake:
- `nullclaw` — Pre-built binary fetch of nullclaw (Zig AI assistant)
- `xs` — xs runtime
- `xs-helper` — Shell-first operator wrapper (wraps xs + xs-materializer)
- `xs-materializer` — Go context-pack materializer
- `pancakes-harness` — Test harness
- `qwen-code` — Qwen code assistant

---

## Essential Commands

### Taskfile Entrypoints

```bash
task help                        # List all tasks
task --list-all                  # Same, unfiltered
task status                      # git status + hostname
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
task infra:rebuild:nixos         # sudo nixos-rebuild switch (local)
task infra:rebuild:darwin        # darwin-rebuild switch (local)
task infra:rebuild:home-manager  # home-manager switch (local)
```

### Git & Flake

```bash
task dev:git:quick-push          # Stage tracked, AI-commit, push
task dev:git:ai-commit           # Stage + interactive AI commit
task dev:git:ai-commit-push      # Stage + AI commit + push
task dev:git:build-push          # AI commit after successful build
task dev:git:quick-pull          # Pull with submodules, reload taskfile
task dev:flake:update-complete   # Full flake update workflow
task dev:flake:update:bountystash # Update single input
```

**Git pre/post hooks auto-run** — `dev:git:prehook` refreshes Taskfile.yml from encrypted secrets; `dev:git:posthook` pushes.

### Validation

```bash
task checks:quick                # Quick eval + host-architecture check + nix lint
nix eval .#nixosConfigurations.<host>.config.networking.hostName  # Quick eval check
nix build .#checks.x86_64-linux.host-architecture -L              # Host architecture validation
nix flake check                  # Full evaluation (slower, catches everything)
task checks:nix:lint             # nixpkgs-fmt --check
```

### Secrets & SOPS

```bash
task infra:secrets:edit:secrets  # Edit sops secrets file
task infra:secrets:edit:apikeys  # Edit API keys env file
task infra:secrets:edit:taskfile # Edit encrypted Taskfile
task infra:sops:get:*            # Query a secret value
task infra:sops:fzf              # Select env entries interactively
task infra:sops:update-keys      # Rotate SOPS recipient keys
```

### SMTP Auth

```bash
task infra:smtp:auth             # Interactive SMTP auth for hosts (using app passwords)
# Prompts for: host, username, app-password; outputs MSMTP/MUTT config for the host
```

### Site (docs-site/)

```bash
task dev:site:build              # Build documentation site
task dev:site:preview            # Live preview
task dev:site:deploy             # Deploy to target
task dev:site:list               # List deployment targets (from taskfiles/site-manifest.json)
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
task agents:xs:status            # xs-helper status
task agents:oauth:list           # List OAuth services
task agents:oauth:login:<svc>:<user>  # OAuth login for service user
task agents:oauth:exec:<svc>:<user> -- <cmd>  # Execute as service user
```

### Nix Raw Commands

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel          # Build host closure
nix build .?submodules=1#nixosConfigurations.<host>.config.system.build.toplevel  # With submodules (CI)
nix build .#checks.x86_64-linux.host-architecture -L                         # Run host checks
nix build .#packages.x86_64-linux.nullclaw                                   # Build single package
nix build .#devShells.x86_64-linux.default                                   # Enter dev shell
nixpkgs-fmt <file>                                                           # Format Nix file
nixpkgs-fmt --check <file>                                                   # Check formatting
```

---

## Secrets Architecture

Two separate encrypted files, decrypted via `sops-nix` using host age keys:

| File | Decryptors | Contents |
|------|------------|----------|
| `modules/secrets.yaml` | All hosts (via `ssh_host_ed25519_key`) | App secrets, `hashedPassword`, API keys, TOTP |
| `modules/ssh-ca-key.yaml` | Workstations only (`*devji`, `*sopsposeidon`) | SSH User CA private key |

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

## CI Pipeline

GitHub Actions in `.github/workflows/`:
- `nixcachix.yml` — Builds `frieren` NixOS + `penguin` home-manager on `ubuntu-latest` via Cachix (`shaoyanji` cache)
- `nixcachix-darwin.yml` — macOS builds
- `nixcachix-aarch64.yml` — ARM builds

CI uses `nix build -L .?submodules=1#...` (note `?submodules=1` for git submodule support).

**garnix.io** config (`garnix.yaml`): currently only deploys the `garnixMachine` host, all builds commented out.

---

## Nix Patterns & Gotchas

### Non-obvious patterns

- **User constants**: `modules/global/user.nix` is the single source of truth for the primary user (`devji`). Import it with `let user = import ../global/user.nix;` — never hardcode `/home/devji` or the username.
- **Attrset merging**: `//` is **shallow, right-biased** — `{ a.x = 1; } // { a.y = 2; }` loses `a.x`. Use `lib.recursiveUpdate` for deep merge. See `NIX-REFERENCE.md` for more.
- **`lib.mkIf` / `lib.mkMerge`**: the standard conditional patterns. Also `lib.optionalAttrs` for conditional attrsets and `lib.optionals` for conditional list items.
- **Option priorities**: `lib.mkDefault` vs `lib.mkForce` vs `lib.mkOverride` are used for option priority layering.
- **`profiles.boot` module**: boot options are accessed via `config.profiles.boot.systemd-boot` and `config.profiles.boot.efi` (not direct `boot.loader.*`).

### Build-avoidance traps

Some packages build from source (Maven, Go, etc.) with no cached variant for overridden configurations:

| Module | Issue | Mitigation |
|--------|-------|------------|
| `services.tika` (`search/tika.nix`) | `cfg.package.override { enableGui = false }` → Maven build | Inline systemd unit with stock `pkgs.tika` |
| `services.gotenberg` (`paperless.nix`) | Chromium stub at module level keeps ~300 MiB chromium | Configure `services.gotenberg.chromium.package` with stub |

Before deploying a host referencing Java (Maven/Gradle), Go, or Rust packages, run `nix build --dry-run` to verify the closure is cached.

### Service module conventions

- **Option namespaces**: `services.<name>` for system services, `profiles.<name>` for composable profiles
- **`lib.types.nullOr lib.types.path`**: optional file path patterns use this type
- **Secret injection**: uses `systemd LoadCredential` (never on command line). Example: `rpcSecretFile` in aria2-daemon module.

### CI quirk

CI commands use `nix build -L .?submodules=1#...` — the `?submodules=1` is critical for accessing the `modules/secrets` submodule. Local `nix build` without that flag works fine since the submodule is already checked out.

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

| Namespace | What | Skill |
|-----------|------|-------|
| `infra:*` | Host lifecycle, secrets, SOPS | `.agents/skills/infra/SKILL.md` |
| `agents:*` | Operator menu, xs, OAuth | `.agents/skills/agents/SKILL.md` |
| `checks:*` | Validation, smoke checks, nix lint | `.agents/skills/checks/SKILL.md` |
| `dev:*` | Git, flake, site, PRs, packages | `.agents/skills/dev/SKILL.md` |
| `services:*` | Legacy wrappers (canonical: `infra:*`) | `.agents/skills/services/SKILL.md` |

---

## Key Operator Helpers

- `agents:xs:*` wrappers run `scripts/task/xs-helper.sh` against local and service stores for artifact, contract, record, and trace work
- `agents:oauth:*` wrappers run `scripts/task/service-oauth.sh` with correct `HOME` and `XDG_*` environment for each service user
- NAS client recovery logic lives under `modules/profiles/nas-client.nix`

## Deployment Guidance

Host deployment flows use `infra:*` tasks directly. See `.agents/deploy/README.md` for host-specific deployment notes. Per-host quirks live in `.agents/deploy/hosts/*.md`.

## Git Hooks Setup

Pre-commit hooks in `.githooks/` catch broken documentation paths. Enable with:
```bash
bash .git-hooks-setup.sh    # sets core.hooksPath to .githooks/
```

## Nixpkgs Formatting

Nix files use `nixpkgs-fmt`. The formatter is included in `base-node.nix` system packages and dev shells. CI checks formatting via `task checks:nix:lint`.

## External Package Registry

External fetched dependencies are registered in `modules/config/fetches.json` and resolved through `lib/fetches-extra.nix`. Update hashes with:
```bash
task dev:config:hash-update    # runs nix-hash-update.sh
```

## Documentation Map

| File | Content |
|------|---------|
| `README.md` | Full repo documentation, architecture, all workflows |
| `AGENTS.md` | This file — agent routing and codebase guide |
| `NIX-REFERENCE.md` | Nix patterns and gotchas used in this repo |
| `docs/task-control-plane.md` | Task namespace policy and workflow examples |
| `docs/codex-handoff.md` | Codex session orientation |
| `docs/nullclaw-fleet-pattern.md` | Nullclaw deployment standardization |
| `docs/zeroclaw-fleet-pattern.md` | Zeroclaw deployment standardization |
| `docs/userland-module-map.md` | Userland module structure |
| `docs/userland-package-ownership.md` | Package ownership and role wiring |
| `taskfiles/README.md` | Taskfile ownership map |
| `USB.md` | Sledgehammer live USB creation |
| `AUDIT.md` | AI module cleanup audit |
| `HANDOFF-REFACTOR.md` | Refactoring progress |
| `TODO.md` | Current work tracking |
