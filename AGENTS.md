# AGENTS.md

## Goals
- Improve maintainability of this Nix flake.
- Preserve runtime behavior unless a task explicitly changes behavior.
- Prefer small, reviewable diffs over broad rewrites.

## Current architecture intent
- `modules/services/*` = reusable daemon/service logic
- `modules/profiles/*` = composition of services/profiles
- `hosts/*` = host-specific identity, storage, networking, overlays, secrets
- `pkgs/*` = packaging only
- `lib/*` = small helpers for flake/module construction
- `flake.nix` = thin orchestration and output wiring only

## Hard constraints
- Do not edit secrets or encrypted payloads.
- Do not rename flake outputs unless explicitly asked.
- Do not do broad rewrites when a focused patch will do.
- Package first, module second, host enablement last.
- Keep Garnix assumptions explicit; do not assume persistence.
- Keep bind mounts and host-local storage layout host-specific unless clearly reusable.
- Do not silently widen system support or evaluation scope.

## Refactor style
- Preserve behavior first.
- One concern per patch.
- Show exact files changed.
- Explain why behavior is preserved.
- List any newly created files that must be `git add`ed for flake evaluation.

## Validation workflow
After edits:
1. `git status --short`
2. `git add` any newly created files needed by flakes
3. Run narrow validations first:
   - `nix eval .#nixosConfigurations.thinsandy.config.networking.hostName`
   - `nix eval .#nixosConfigurations.garnixMachine.config.networking.hostName`
   - `nix eval .#packages.x86_64-linux.backend.meta.mainProgram`
   - `nix build .#checks.x86_64-linux.host-architecture -L`
4. Only run broader checks after narrow checks are green.

## Important note about flakes
Nix flakes only see Git-tracked files. If a new file is created and not tracked, evaluation may fail with “Path ... is not tracked by Git”.

## Current preferences
- Prefer explicit system lists over broad `eachDefaultSystem` expansion where practical.
- Keep evaluation scope as narrow as possible.
- Avoid unrelated cleanup during structural refactors.
