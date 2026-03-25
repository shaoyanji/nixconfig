# nixconfig

Multi-host Nix flake for:

- NixOS
- nix-darwin
- Home Manager
- WSL-style container hosts

This repository is no longer just a bootstrap guide for adding a device. It is an actively structured fleet/configuration repo with reusable host profiles, reusable service modules, explicit host wiring, and narrow eval-time checks.

## Current Direction

The architecture intent is:

- `modules/services/*`: reusable daemon and service logic
- `modules/profiles/*`: reusable composition profiles
- `hosts/*`: host identity, storage, secrets, overlays, networking, and final enablement
- `pkgs/*`: package definitions only
- `lib/*`: small flake/module helpers
- `flake/*`: output wiring and flake orchestration

The main refactor trend is to move shared logic out of `hosts/common/*` and into canonical modules under `modules/profiles/*` and `modules/services/*`, while keeping host-specific behavior in host files.

## Flake Outputs

Primary outputs:

- `nixosConfigurations`
- `darwinConfigurations`
- `homeConfigurations`
- `packages`
- `checks`
- `devShells`

Current NixOS wiring is split out of `flake.nix` and assembled through [flake/outputs.nix](/home/devji/nixconfig/flake/outputs.nix), [flake/nixos-configurations.nix](/home/devji/nixconfig/flake/nixos-configurations.nix), and [flake/module-sets.nix](/home/devji/nixconfig/flake/module-sets.nix).

## Repository Layout

Important paths:

- `flake.nix`: top-level flake inputs and output handoff
- `flake/*`: output wiring
- `hosts/*`: host entrypoints and host-local modules
- `hosts/common/*`: mostly compatibility wrappers and host-local leftovers
- `modules/profiles/*`: canonical reusable system profiles
- `modules/services/*`: reusable service modules
- `modules/user/*`: Home Manager domain modules
- `modules/roles/*`: higher-level user role composition
- `pkgs/*`: package build definitions
- `docs/*`: architecture notes, fleet docs, and operator guidance

## Notable Current Patterns

### Shared Profiles

Canonical reusable profiles now live under `modules/profiles/*`, including:

- `minimal-desktop.nix`
- `base-desktop-environment.nix`
- `laptop.nix`
- `steam.nix`
- `nvidia.nix`
- `impermanence.nix`
- `ai-host.nix`

Some legacy `hosts/common/*` files still exist, but the active hosts have been moved toward canonical profile imports.

### AI Host Services

Reusable AI service modules live under `modules/services/*`, including:

- `nullclaw.nix`
- `nullclaw-deployment.nix`
- `openclaw-gateway.nix`
- `hermes-agent.nix`
- `go-backend.nix`

The AI fleet pattern is documented in [docs/nullclaw-fleet-pattern.md](/home/devji/nixconfig/docs/nullclaw-fleet-pattern.md).

### Host Constructor

NixOS hosts are assembled through [lib/mk-nixos-host.nix](/home/devji/nixconfig/lib/mk-nixos-host.nix) to keep flake output wiring small and consistent.

### Historical Host Files

Some hosts still have older `configuration2.nix` and `configuration3.nix` paths. These are treated as legacy wrappers, not canonical active entrypoints.

### Shared TestVM Guest

[hosts/microvms/testvm.nix](/home/devji/nixconfig/hosts/microvms/testvm.nix) now acts as a shared `testvm` guest baseline.

It is used in two ways:

- as the standalone `testvm` flake output guest definition
- as a shared guest import for embedded `testvm` microVMs inside larger hosts

Host-local bridge, NAT, and external interface policy still stay in the host files.

## Working With The Repo

### Narrow Validation First

Use the narrow validation flow before wider checks:

```bash
git status --short
nix eval .#nixosConfigurations.thinsandy.config.networking.hostName
nix eval .#nixosConfigurations.garnixMachine.config.networking.hostName
nix eval .#packages.x86_64-linux.backend.meta.mainProgram
nix build .#checks.x86_64-linux.host-architecture -L
```

Why this matters:

- flakes only see Git-tracked files
- narrow evals catch structural breakage faster than `nix flake check`
- wider checks may pull in unrelated systems and produce noise

### Common Operations

Inspect outputs:

```bash
nix flake show
```

Switch local NixOS host:

```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```

Build a NixOS system without switching:

```bash
nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel
```

Switch Darwin host:

```bash
nix run nix-darwin -- switch --flake .#cassini
```

Switch Home Manager standalone host:

```bash
home-manager switch --flake .#penguin
```

### Git and Flakes

If you create a new file that is referenced by the flake, it must be Git-tracked before evaluation. Otherwise Nix flakes will fail with a path-not-tracked error.

## Documentation

Useful docs:

- [docs/codex-handoff.md](/home/devji/nixconfig/docs/codex-handoff.md)
- [docs/nullclaw-fleet-pattern.md](/home/devji/nixconfig/docs/nullclaw-fleet-pattern.md)
- [docs/task-control-plane.md](/home/devji/nixconfig/docs/task-control-plane.md)
- [docs/userland-module-map.md](/home/devji/nixconfig/docs/userland-module-map.md)
- [docs/userland-package-ownership.md](/home/devji/nixconfig/docs/userland-package-ownership.md)

## Constraints

When refactoring:

- preserve runtime behavior first
- avoid broad rewrites
- do not edit secrets or encrypted payloads
- package first, module second, host enablement last
- keep host-local persistence, bind mounts, and storage layout host-specific unless reuse is obvious
- keep Garnix assumptions explicit

## Current Status

The repo is in the middle of a conservative maintainability pass:

- shared desktop-style host logic has been extracted into `modules/profiles/*`
- active hosts are being pointed at canonical module paths
- older numbered host entrypoints have been reduced to legacy wrappers
- shared `testvm` guest logic has been consolidated into `hosts/microvms/testvm.nix`
- AI service composition is already more mature than the older host-common structure

For active next steps and handoff context, see [TODO.md](/home/devji/nixconfig/TODO.md).
