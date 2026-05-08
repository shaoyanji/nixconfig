# nixconfig

Multi-host Nix flake for NixOS, nix-darwin, Home Manager, and WSL-style container hosts.

## Layout

- `flake/*`: flake outputs and wiring.
- `hosts/*`: host entrypoints plus local identity, storage, and networking.
- `modules/profiles/*` and `modules/services/*`: canonical reusable host and service logic.
- `modules/user/*`, `modules/roles/*`, and `modules/shell/*`: user and role commitments.
- `pkgs/*`: package definitions.
- `docs/*`: operator and architecture references.

## Quick Start

1. **Prerequisites**: NixOS/Darwin system with flakes enabled
2. **Clone repo**: `git clone <repo-url> && cd nixconfig`
3. **List tasks**: `task --list-all` to see all available tasks
4. **Build a host**: `task infra:plan:host:thinsandy`
5. **Deploy**: `task infra:deploy:host:thinsandy` (plan + apply + validate)

## Module chains

Module chains compose as follows:

```
globalModulesNixos      → global → nixos → home-manager-shared → role:heim
globalModulesImpermanence → globalModulesNixos → +impermanence module
globalModulesContainers  → global → noDE (lean home-manager, no dms/niri)
globalModulesMacos       → global → macos (nix-darwin, no dms/niri)
```

`base-node.nix` (profile) provides the common NixOS baseline: kernel packages, SSH, keyd, networkmanager, console, sops, user `devji`, common dev packages, and boot loader defaults (systemd-boot + EFI). Container and desktop hosts import it via `globalModulesContainers` or `desktop-client.nix`.
`base-node.nix` also imports `modules/profiles/firewall-baseline.nix`, which enables the firewall and only opens TCP/22 by default. Hosts should add service/interface-specific allowances explicitly.

## Add a host

1. Add a host module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix` for simple cases).
2. Add hardware/storage modules as needed (for example `hardware-configuration.nix`, `disko.nix`, or profile imports).
3. Register the host entry in `flake/host-inventory.nix` with:
   - target platform (`system`)
   - module chain (`globalModulesNixos`, `globalModulesImpermanence`, `globalModulesContainers`, etc.)
   - host module path(s)
4. Let `flake/host-projection.nix` project inventory data into outputs (no manual output wiring needed).
5. Build/check through the Task control plane (`Taskfile.yml` + `taskfiles/*`) and then switch on the target host.

## Supported Hosts

| Host          | nullclaw | hermes-agent | ollama | xs | pancakes-harness |
|---------------|----------|--------------|--------|-----|------------------|
| thinsandy     | yes      | yes          | yes    | yes | yes              |
| mtfuji        | yes      | no           | yes    | no  | no               |
| garnixMachine | yes      | no           | no     | no  | no               |
| kellerbench   | no       | no           | yes    | no  | no               |

Per-host quirks and exceptions: `.agents/deploy/hosts/*.md`

## Pinning and updates

`nixpkgs` and all inputs are pinned via `flake.lock`. Update intentionally with lockfile bumps (for example `nix flake update` or targeted input updates), then review and commit `flake.lock` with the corresponding config changes.

## Flake outputs

- `nixosConfigurations`
- `darwinConfigurations`
- `homeConfigurations`
- `packages`
- `checks`
- `devShells`

Canonically assembled from [`flake/outputs.nix`](flake/outputs.nix) and [`lib/mk-nixos-host.nix`](lib/mk-nixos-host.nix).

## Runtime helpers

- The NAS client recovery profile now lives in `modules/profiles/nas-client.nix`, which automounts `/Volumes/data` from `thinsandy` for non-`thinsandy` hosts so the compatibility path stays available without relying on `hosts/common/localmounts.nix`.
- The `xs` runtime, `xs-helper` CLI, and `xs-materializer` binary are packaged via the flake (`packages.*.xs`, `packages.*.xs-helper`, and `packages.*.xs-materializer`). Fleet members should consume those packaged outputs rather than ad-hoc `go build` from the repo.
- `xs-helper` remains the shell-first operator wrapper, while `xs-materializer` is the Go implementation used for `task_view` context-pack materialization. They are versioned in lockstep inside this repo: `pkgs/xs-helper.nix` wires the wrapper to the packaged `pkgs/xs-materializer.nix` output, and `scripts/task/xs-helper.sh materialize` now hydrates CAS-backed xs envelopes before piping normalized events into the materializer.
- Direct `xs` usage is still the source-of-truth debugging path when validating stream shape or CAS retrieval behavior, but normal operator/fleet flows should go through the packaged wrapper/tasks instead of bespoke local build steps.
- Service-user OAuth/session management uses `task agents:oauth:*` wrappers (e.g., `agents:oauth:login:nullclaw:codex`, `agents:oauth:exec:nullclaw:codex -- whoami`). The helper sets `HOME` and `XDG_*` correctly for each service user, so you do not need to remember raw `sudo -u ...` incantations.
- The experimental devcontainer configuration was reverted; there is no current repo-provided devcontainer image, so use the Taskfiles, flake outputs, and hosted workflows directly.

## Recent changes

**Last updated: 2026-05-08**

**2026-04-30 — Task system consolidation.** Deprecated legacy task aliases and menus, directing users to new `infra:` and `dev:` prefixed tasks. Simplified `checks:nullclaw:smoke` tasks and enhanced `dev:git` tasks with AI commit integration.

**2026-04-23 — Manifest and dead-code cleanup.** The AI-host manifest system (`taskfiles/ai-host-manifest.json`, `scripts/task/ai-host-*.sh`, and `taskfiles/services-ai-hosts.yml`) was removed. Host menus and validation tasks now use static host lists and direct smoke checks. The `modules/user/ai/` directory and `modules/goodies.nix` were also removed; nothing in active host configs imported them. See `AUDIT.md` for the full decision log.

## Documentation

### Quick Reference
- `AGENTS.md` - Agent routing helpers and task namespace summary
- `docs/task-control-plane.md` - Task namespace policy and workflow examples
- `taskfiles/README.md` - Taskfile ownership map and shard reference

### Deployment
- `.agents/deploy/README.md` - Deploy routing and guardrails
- `.agents/deploy/hosts/*.md` - Per-host deployment exceptions
- `docs/nullclaw-fleet-pattern.md` - Nullclaw deployment standardization
- `USB.md` - Sledgehammer live USB creation guide

### Development
- `docs/codex-handoff.md` - Codex session orientation
- `NIX-REFERENCE.md` - Nix patterns and gotchas used in this repo
- `docs/userland-module-map.md` - Userland module structure and ownership
- `docs/userland-package-ownership.md` - Package ownership and role wiring

### Historical
- `AUDIT.md` - AI module cleanup audit (April 2026)
- `HANDOFF-REFACTOR.md` - Refactoring progress (April 2026)
- `TODO.md` - Current work tracking and completed tasks

### Site Management
Manage site targets with `task dev:site:list`; build/preview/deploy the default target with `task dev:site:build`, `task dev:site:preview`, and `task dev:site:deploy`.
