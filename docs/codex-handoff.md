# Codex Handoff

## Purpose

This file is the detailed handoff note for a fresh Codex session. It explains the current architectural direction, what has already been cleaned up, what behavior must remain stable, and what work is still open.

## Repository Goals

- Improve maintainability of the flake without broad rewrites.
- Preserve runtime behavior unless a task explicitly changes behavior.
- Keep reusable service logic out of host files where possible.
- Keep host-specific storage, secrets, overlays, networking, and final enablement in `hosts/*`.
- Keep Garnix behavior explicit and minimal.

## Current Architecture

Canonical structure:

- `flake/*`: flake output wiring
- `lib/*`: small construction helpers
- `pkgs/*`: package definitions only
- `modules/services/*`: reusable daemon/service modules
- `modules/profiles/*`: reusable composition profiles
- `modules/user/*`: Home Manager domains
- `modules/roles/*`: higher-level user role composition
- `hosts/*`: host entrypoints and host-local decisions

Practical interpretation:

- shared system composition belongs in `modules/profiles/*`
- shared service behavior belongs in `modules/services/*`
- host-local bridge names, storage paths, bind mounts, secrets, overlays, and network policy stay in host files

## Refactors Already Landed

### Flake Wiring Split

The flake is already decomposed out of `flake.nix` into:

- `flake/outputs.nix`
- `flake/nixos-configurations.nix`
- `flake/home-configurations.nix`
- `flake/darwin-configurations.nix`
- `flake/module-sets.nix`
- `flake/packages.nix`
- `flake/checks.nix`

`flake.nix` is now mostly inputs plus a thin handoff to `flake/outputs.nix`.

### Reusable AI Service Modules

Implemented under `modules/services/*`:

- `nullclaw.nix`
- `nullclaw-deployment.nix`
- `openclaw-gateway.nix`
- `hermes-agent.nix`
- `go-backend.nix`

The core pattern is:

- package first
- reusable module second
- host enablement last

### AI Host Profile

Implemented:

- `modules/profiles/ai-host.nix`

Used to compose reusable AI services while keeping host-specific secret paths, bind mounts, reverse proxy policy, and persistence local to the host.

### Host Constructor Helper

Implemented:

- `lib/mk-nixos-host.nix`

This reduces repeated `nixosSystem` boilerplate while preserving flake output names.

### Shared Profile Extraction

Canonical shared profiles now live under `modules/profiles/*`, including:

- `minimal-desktop.nix`
- `base-desktop-environment.nix`
- `laptop.nix`
- `steam.nix`
- `nvidia.nix`
- `impermanence.nix`

The corresponding `hosts/common/*` files are now compatibility wrappers.

Active hosts have been switched over to canonical `modules/profiles/*` imports.

### Historical Host Entry Cleanup

For `poseidon` and `ancientace`:

- active flake wiring now points directly at `configuration.nix`
- `configuration2.nix` and `configuration3.nix` were reduced to explicit legacy wrappers

This means the numbered files no longer carry live configuration deltas.

### TestVM Consolidation

`hosts/microvms/testvm.nix` now acts as the shared guest baseline for `testvm`-style microVM usage.

Current pattern:

- standalone `testvm` flake output imports `hosts/microvms/testvm.nix` with defaults
- embedded `testvm` guests in `poseidon` and `ancientace` import the same file with host-specific arguments
- host-local bridge/NAT wiring remains in the host
- guest-specific common logic moved into the shared module

Shared `testvm` baseline now covers:

- guest VM shape (`vcpu`, `mem`, TAP interface, base shares, `/var` volume)
- base guest user and SSH enablement
- optional guest networkd configuration
- optional writable store overlay and dev-oriented Nix defaults
- optional authorized keys

Host-local guest deltas remain where they should:

- guest extra packages
- host bridge/NAT policy
- host external interface choice

## Behavior That Must Remain Preserved

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
- config staged from `/run/secrets/nullclaw-config`
- nginx default proxy to `http://127.0.0.1:3000/`
- no accidental sops requirement
- no accidental persistence assumptions

### mtfuji

Must keep its existing host-specific nullclaw env-file behavior.

### poseidon and ancientace

Must keep:

- their current active canonical host entrypoints at `configuration.nix`
- their embedded `testvm` guests
- their current host-local bridge/NAT wiring

## Validation Lessons

- Flakes only see Git-tracked files.
- Newly created files must be staged before flake evaluation.
- Prefer narrow validation first.
- `nix flake check -L` is broader and often noisier than needed for structural work.

## Recommended Validation Flow

```bash
git status --short
nix eval .#nixosConfigurations.thinsandy.config.networking.hostName
nix eval .#nixosConfigurations.garnixMachine.config.networking.hostName
nix eval .#packages.x86_64-linux.backend.meta.mainProgram
nix build .#checks.x86_64-linux.host-architecture -L
```

## Current Known Notes

- `garnixMachine` currently evaluates `networking.hostName` to `"nixos"`. This appears to be pre-existing and not introduced by the maintainability refactor.
- `hosts/common/hydenix.nix` remains a legacy exception and has not yet been normalized into the newer architecture.
- `hosts/common/disko.nix` is still host-adjacent and may be better left there unless reuse becomes clearer.

## Good Next Tasks

1. Reconcile the remaining legacy docs so they match the extracted profile structure.
2. Decide whether the legacy wrapper files should remain indefinitely or be removed after an observation window.
3. Extend shared `testvm` usage to any additional hosts that should consume the common guest baseline.
4. Review whether any remaining `hosts/common/*` modules are truly canonicalizable or should stay host-local.
