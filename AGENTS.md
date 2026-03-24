# AGENTS.md

## Repository goals

- Improve maintainability of this Nix flake.
- Prefer extraction and normalization over rewrites.
- Preserve current behavior unless the task explicitly changes behavior.

## Hard constraints

- Do not edit secrets or encrypted sops payloads.
- Do not change host names in flake outputs unless asked.
- Do not merge unrelated concerns into a single patch.
- Do not move service runtime wiring into tools packages.
- Do not break current thinsandy AI host behavior.

## Architecture preferences

- flake.nix should be thin.
- Reusable logic belongs in modules/ or lib/.
- Host files should mostly declare identity, hardware, storage, networking, and profile selection.
- Custom software packaging belongs in pkgs/.
- Service modules should expose enable options and own their users/systemd/tmpfiles/secrets.

## Review guidelines

- Flag duplicated nixosSystem boilerplate.
- Flag host-specific code that should be a reusable module.
- Flag assumptions that break on ephemeral Garnix servers.
- Flag packages installed globally when they only belong in a service path.
