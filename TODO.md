# TODO / Handoff

This file is the current short-form handoff document for the repository root. It is meant to give the next person enough context to continue the maintainability refactor without having to reconstruct the repo state from scratch.

## Current Repo State

- The flake output wiring is already split into `flake/*`.
- Reusable host profiles now live under `modules/profiles/*`.
- Reusable AI and service logic lives under `modules/services/*`.
- Active hosts have largely been moved off `hosts/common/*` profile paths and onto canonical `modules/profiles/*` imports.
- Historical `configuration2.nix` and `configuration3.nix` files for `poseidon` and `ancientace` have been reduced to legacy wrappers.
- Eval-time architectural checks already exist and should be treated as the main narrow validation gate.

## Refactor Principles

- Preserve behavior first.
- Keep diffs small and reviewable.
- Do not edit secrets or encrypted payloads.
- Keep host identity, storage, networking, overlays, and secret wiring in `hosts/*`.
- Prefer extracting shared logic into `modules/profiles/*` or `modules/services/*`.
- Stage newly created flake-visible files before evaluation.

## Validation Routine

Run these first after structural changes:

```bash
git status --short
nix eval .#nixosConfigurations.thinsandy.config.networking.hostName
nix eval .#nixosConfigurations.garnixMachine.config.networking.hostName
nix eval .#packages.x86_64-linux.backend.meta.mainProgram
nix build .#checks.x86_64-linux.host-architecture -L
```

Notes:

- flakes only see Git-tracked files
- `nix flake check -L` is broader and noisier
- narrow checks are the preferred first gate

## Recently Completed

- Extracted canonical profiles into `modules/profiles/*` for:
  - `minimal-desktop`
  - `base-desktop-environment`
  - `laptop`
  - `steam`
  - `nvidia`
  - `impermanence`
- Converted corresponding `hosts/common/*` files into compatibility wrappers.
- Updated active hosts to import canonical profile paths directly.
- Collapsed active `poseidon` and `ancientace` host entrypoints back to `configuration.nix`.
- Reduced `configuration2.nix` and `configuration3.nix` host files to explicit legacy wrappers.
- Consolidated shared `testvm` guest behavior into [hosts/microvms/testvm.nix](/home/devji/nixconfig/hosts/microvms/testvm.nix).
- Refreshed `README.md` to describe the repo as an architecture-first fleet/config repo rather than a one-off bootstrap guide.

## Current Open Work

1. Decide whether the remaining `hosts/common/*` files should stay host-local or move into canonical modules.
2. Decide whether legacy wrapper files like `hosts/poseidon/configuration2.nix` and `configuration3.nix` should remain indefinitely or be removed after an observation window.
3. Review whether `hosts/common/hydenix.nix` should remain a legacy exception or be isolated more explicitly.
4. Consider whether `hosts/common/disko.nix` belongs under a more canonical module path, or whether it should stay host-adjacent because of storage sensitivity.
5. Review `garnixMachine` host naming. The narrow eval currently returns `networking.hostName = "nixos"`, which appears to be pre-existing and not caused by the refactor.

## TestVM Follow-Up

The first `testvm` consolidation pass is now done.

Current situation:

- [hosts/microvms/testvm.nix](/home/devji/nixconfig/hosts/microvms/testvm.nix) now acts as the shared guest baseline.
- `poseidon` and `ancientace` now import that shared guest baseline for their embedded `testvm` guests.
- Some hosts may still want to adopt the shared `testvm` pattern in the future.
- You noted that `testvm.nix` is intended as a common point for hosts such as `poseidon`, `schneeeule`, and `applevalley`.
- The recent change removing `neofetch` from `testvm.nix` was user-driven because it failed to build on Garnix and was not materially used.

Recommended next pass:

1. Inventory every host that embeds or intends to embed `testvm`-style microVM wiring.
2. Extend the shared guest baseline to those hosts only if the host-local bridge/share differences are small enough.
3. Keep host-local network bridge names, bind mounts, persistence, and external interface choices in host files.
4. Decide whether the standalone `testvm` output should eventually move to a more canonical `modules/profiles/*` path or remain under `hosts/microvms/*`.

## Things To Avoid

- Do not do a broad host rewrite in one pass.
- Do not move secrets or encrypted data.
- Do not silently widen system support.
- Do not assume Garnix persistence.
- Do not merge host-local storage layout into shared modules unless the reuse is clearly real.

## Immediate Next Reasonable Tasks

1. Observation-window decision on keeping or deleting legacy wrapper files.
2. Review `hydenix` and `disko` as the remaining architecture exceptions.
3. Extend the shared `testvm` baseline only if another host genuinely needs it.
