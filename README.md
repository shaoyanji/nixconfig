# nixconfig

Multi-host Nix flake for NixOS, nix-darwin, Home Manager, and WSL-style container hosts.

## Layout

- `flake/*`: flake outputs and wiring.
- `hosts/*`: host entrypoints plus local identity, storage, and networking.
- `modules/profiles/*` and `modules/services/*`: canonical reusable host and service logic.
- `modules/user/*`, `modules/roles/*`, and `modules/shell/*`: user and role commitments.
- `pkgs/*`: package definitions.
- `docs/*`: operator and architecture references.

## Flake outputs

- `nixosConfigurations`
- `darwinConfigurations`
- `homeConfigurations`
- `packages`
- `checks`
- `devShells`

Canonically assembled from [`flake/outputs.nix`](/home/devji/nixconfig/flake/outputs.nix) and [`lib/mk-nixos-host.nix`](/home/devji/nixconfig/lib/mk-nixos-host.nix).

## Docs

- `AGENTS.md` + `.agents/README.md` for routing helpers.
- `docs/task-control-plane.md` for namespace policy.
- `taskfiles/README.md` for the Taskfile ownership map.
- `docs/codex-handoff.md` for Codex session guidance.
- Manage site targets with `task dev:site:list`; build/preview/deploy the default target with `task dev:site:build`, `task dev:site:preview`, and `task dev:site:deploy`.
