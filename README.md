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

## Runtime helpers

- The NAS client recovery profile now lives in `modules/profiles/nas-client.nix`, which automounts `/Volumes/data` from `thinsandy` for non-`thinsandy` hosts so the compatibility path stays available without relying on `hosts/common/localmounts.nix`.
- The `xs` runtime and `xs-helper` CLI are packaged via the flake (`packages.*.xs` and `packages.*.xs-helper`) and surfaced through `scripts/task/xs-helper.sh` plus the `task agents:xs:*` wrappers for local/service mode interaction, artifact promotion/retrieval, and the contract/record/trace frames being captured in this repo.
- Service-user OAuth/session management uses `task agents:oauth:*` wrappers (e.g., `agents:oauth:login:nullclaw:codex`, `agents:oauth:exec:nullclaw:codex -- whoami`). The helper sets `HOME` and `XDG_*` correctly for each service user, so you do not need to remember raw `sudo -u ...` incantations.
- The experimental devcontainer configuration was reverted; there is no current repo-provided devcontainer image, so use the Taskfiles, flake outputs, and hosted workflows directly.

## Docs

- `AGENTS.md` + `.agents/README.md` for routing helpers.
- `docs/task-control-plane.md` for namespace policy.
- `taskfiles/README.md` for the Taskfile ownership map.
- `docs/codex-handoff.md` for Codex session guidance.
- Manage site targets with `task dev:site:list`; build/preview/deploy the default target with `task dev:site:build`, `task dev:site:preview`, and `task dev:site:deploy`.
