# nixconfig

Multi-host Nix flake for NixOS, nix-darwin, Home Manager, and WSL-style container hosts.

## Layout

- `flake/*`: flake outputs and wiring.
- `hosts/*`: host entrypoints plus local identity, storage, and networking.
- `modules/profiles/*` and `modules/services/*`: canonical reusable host and service logic.
- `modules/user/*`, `modules/roles/*`, and `modules/shell/*`: user and role commitments.
- `pkgs/*`: package definitions.
- `docs/*`: operator and architecture references.

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

## Pinning and updates

`nixpkgs` and all inputs are pinned via `flake.lock`. Update intentionally with lockfile bumps (for example `nix flake update` or targeted input updates), then review and commit `flake.lock` with the corresponding config changes.

## Flake outputs

- `nixosConfigurations`
- `darwinConfigurations`
- `homeConfigurations`
- `packages`
- `checks`
- `devShells`

Canonically assembled from [`flake/outputs.nix`](/home/devji/nixconfig/flake/outputs.nix) and [`lib/mk-nixos-host.nix`](/home/devji/nixconfig/lib/mk-nixos-host.nix).

## Runtime helpers

- The NAS client recovery profile now lives in `modules/profiles/nas-client.nix`, which automounts `/Volumes/data` from `thinsandy` for non-`thinsandy` hosts so the compatibility path stays available without relying on `hosts/common/localmounts.nix`.
- The `xs` runtime, `xs-helper` CLI, and `xs-materializer` binary are packaged via the flake (`packages.*.xs`, `packages.*.xs-helper`, and `packages.*.xs-materializer`). Fleet members should consume those packaged outputs rather than ad-hoc `go build` from the repo.
- `xs-helper` remains the shell-first operator wrapper, while `xs-materializer` is the Go implementation used for `task_view` context-pack materialization. They are versioned in lockstep inside this repo: `pkgs/xs-helper.nix` wires the wrapper to the packaged `pkgs/xs-materializer.nix` output, and `scripts/task/xs-helper.sh materialize` now hydrates CAS-backed xs envelopes before piping normalized events into the materializer.
- Direct `xs` usage is still the source-of-truth debugging path when validating stream shape or CAS retrieval behavior, but normal operator/fleet flows should go through the packaged wrapper/tasks instead of bespoke local build steps.
- Service-user OAuth/session management uses `task agents:oauth:*` wrappers (e.g., `agents:oauth:login:nullclaw:codex`, `agents:oauth:exec:nullclaw:codex -- whoami`). The helper sets `HOME` and `XDG_*` correctly for each service user, so you do not need to remember raw `sudo -u ...` incantations.
- The experimental devcontainer configuration was reverted; there is no current repo-provided devcontainer image, so use the Taskfiles, flake outputs, and hosted workflows directly.

## Docs

- `AGENTS.md` + `.agents/README.md` for routing helpers.
- `docs/task-control-plane.md` for namespace policy.
- `taskfiles/README.md` for the Taskfile ownership map.
- `docs/codex-handoff.md` for Codex session guidance.
- Manage site targets with `task dev:site:list`; build/preview/deploy the default target with `task dev:site:build`, `task dev:site:preview`, and `task dev:site:deploy`.
