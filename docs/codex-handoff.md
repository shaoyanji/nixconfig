# Codex Handoff

## Purpose
This file rehydrates the current repo refactor state for a fresh Codex session after context loss or session reset.

## Repository goals
- Refactor the NixOS flake into a more maintainable structure.
- Preserve existing host behavior.
- Make AI-related services reusable across hosts.
- Keep Garnix host operation explicit and minimal.
- Package non-flake projects cleanly under `pkgs/`.

## Architectural target
- `modules/services/*` contains reusable service modules
- `modules/profiles/*` contains composition profiles
- `hosts/*` keeps host-only decisions:
  - storage
  - secrets
  - overlays
  - networking
  - enablement
- `pkgs/*` contains package build logic only
- `flake.nix` should be thin orchestration

## Refactors already implemented

### 1. Reusable AI service modules
Implemented:
- `modules/services/nullclaw.nix`
- `modules/services/nullclaw-deployment.nix`
- `modules/services/openclaw-gateway.nix`
- `modules/services/hermes-agent.nix`

Pattern:
- option-driven
- reusable across hosts
- optional `environmentFile` where appropriate
- optional `configJsonSource` staging for hosts that keep nullclaw config as a separate runtime file
- host-specific bind mounts and storage remain host-local

### 2. AI composition profile
Implemented:
- `modules/profiles/ai-host.nix`

Intent:
- compose reusable AI-related services
- hosts import the profile and set host-specific values
- no unrelated desktop/networking/server reshuffle

### 3. Host constructor helper
Implemented:
- `lib/mk-nixos-host.nix`

Intent:
- reduce repeated `nixosSystem` boilerplate
- preserve all `nixosConfigurations.*` names and behavior

### 4. Packaging extraction
Implemented:
- `pkgs/go-backend.nix`
- `modules/services/go-backend.nix`

Intent:
- package first
- service second
- no auto-enable on hosts

### 5. Eval-time architecture checks
Implemented in:
- `flake.nix`

Checks include:
- `thinsandy`:
  - nullclaw enabled
  - expected workspace root
  - expected environment file
  - openclaw enabled with expected environment file and Telegram token file
  - hermes enabled with expected environment file
- `garnixMachine`:
  - nullclaw enabled
  - nullclaw deployment wrapper enabled with `listenHost = 127.0.0.1`, `listenPort = 3001`, `workspaceRoot = /var/lib/nullclaw`
  - nullclaw config staged from `/run/secrets/nullclaw-config` to `/var/lib/nullclaw/.nullclaw/config.json`
  - nginx default proxy to `http://127.0.0.1:3000/`
  - no required nullclaw `environmentFile`
- `mtfuji`:
  - nullclaw enabled with deployment wrapper and host-specific environment file
- no host unexpectedly enables `go-backend`

## Behavior that must remain preserved

### thinsandy
Must keep existing effective AI host behavior:
- nullclaw enabled
- openclaw enabled
- hermes enabled
- existing secret paths preserved
- existing workspace roots preserved
- existing host-local bind mounts preserved

### garnixMachine
Must remain a minimal nullclaw host:
- nullclaw on `127.0.0.1:3001`
- nullclaw config staged from secret file to `/var/lib/nullclaw/.nullclaw/config.json`
- nginx currently proxies port 80 to bountystash on `127.0.0.1:3000`
- no accidental sops requirement
- local state treated as ephemeral unless persistence is explicitly added

### mtfuji
Must keep its existing host-specific nullclaw env-file/secret behavior.

## Warning cleanup already applied
Applied only as narrow warning cleanup:
- renamed Anki HM options in `modules/global/heim.nix`
- added `microvm.vsock.cid = 10;` for testvm microvm definitions in:
  - `hosts/poseidon/configuration.nix`
  - `hosts/ancientace/configuration.nix`

No unrelated reshuffling was done in that cleanup.

## Validation lessons learned
- Flake evaluation failed multiple times because newly created files were not tracked by Git.
- Nix flakes only see Git-tracked files.
- Always stage new files before evaluating.
- `nix flake check -L` may pull in unrelated systems/configurations and produce warning noise.
- Prefer narrow validation first.

## Recommended validation flow
Run these first:

```bash
git status --short
nix eval .#nixosConfigurations.thinsandy.config.networking.hostName
nix eval .#nixosConfigurations.garnixMachine.config.networking.hostName
nix eval .#packages.x86_64-linux.backend.meta.mainProgram
nix build .#checks.x86_64-linux.host-architecture -L --show-trace
