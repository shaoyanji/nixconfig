# Userland Module Map

## Scope
This map documents userland refactoring only (roles and Home Manager domains).
System/service modules and AI fleet operator workflows are unchanged in this pass.

## New Structure
- `modules/roles/`
  - `portable-home.nix`: shared portable baseline for HM hosts (`shell/base` + `nixvim`)
  - `minimal.nix`: thin role assembler for base + AI domains
  - `home.nix`: desktop-oriented role layer on top of `minimal`
  - `heim.nix`: persona layer for `devji` desktop/user preferences
- `modules/user/base/default.nix`
  - base CLI/editor/env ownership previously concentrated in `global/minimal.nix`
- `modules/shell/base.nix`
  - explicit shell base contract (`bash` + `tmux`) used by minimal/base stacks
- `modules/user/ai/`
  - `default.nix` aggregator
  - `gemini-cli.nix`
  - `mods.nix`
  - `opencode.nix`
  - `aichat.nix`
  - `agents.nix`
- `modules/user/desktop/niri.nix`
  - compositor + shell integration settings for Niri/DMS

## Removed Modules

- `modules/global/home-manager-base.nix`: dead code — never imported; `home-manager-shared.nix` serves the same purpose more narrowly
- `modules/global/unfree.nix`: predicate whitelist overridden by `allowUnfree = true` in `global.nix`; removed the file and the import from `global.nix`
- `modules/profiles/base-desktop.nix`: pointless 3-line wrapper that only imported `desktop-client.nix`; no host referenced it directly
- `flake/module-sets.nix` `hmSharedModules`: exported but never consumed; removed

## `base-node.nix` Boot Loader Defaults

`modules/profiles/base-node.nix` now includes boot loader defaults:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
```

Hosts that import `base-node.nix` no longer need to repeat these settings. This removed the duplicated block from `mtfuji`, `thinsandy`, and `kellerbench`. Hosts with non-standard boot loaders (`aceofspades`, `ancientace` via `grub-boot.nix`) are unaffected.

## Compatibility Wrappers
- `modules/goodies.nix` -> `modules/user/ai/default.nix`
- `modules/niri.nix` -> `modules/user/desktop/niri.nix`

Canonical role graph now lives only under `modules/roles/*`.
The temporary role wrappers at `modules/global/{minimal,home,heim}.nix` were removed after all in-repo imports were migrated.

## Ownership Summary
- Shell/core CLI base stack:
  - primary owner: `modules/user/base/default.nix`
  - shell base contract owner: `modules/shell/base.nix`
  - full shell behavior owner: `modules/shell/default.nix` and `modules/shell/*.nix`
- Dev/programming user tools:
  - `modules/dev.nix`
- AI/LLM user tooling:
  - `modules/user/ai/*`
- Desktop compositor/UI integration:
  - `modules/user/desktop/niri.nix`
- Role assembly:
  - `modules/roles/*`

## Portable Home Baseline
Used by:
- `hosts/penguin.nix`

Guarantees:
- shell base contract via `modules/shell/base.nix` (`bash` + `tmux`)
- `programs.nixvim.enable = true`

Host-local overlays still own host-specific packages, app/tool choices, and extra shell layers.

Role usage on portable HM hosts:
- `penguin`: `roles/portable-home` + host-local overlays (does not import `roles/minimal`)
- `alarm`: `roles/minimal` only (portable guarantees are subsumed by minimal)
- `kali`: `roles/minimal` + host-local overlays (portable guarantees are subsumed by minimal)

## Package Ownership Cleanup in This Pass
- Moved AI CLI package ownership (`tgpt`, `aichat`, `mods`) from old minimal sink into `modules/user/ai/default.nix`.
- Kept package behavior otherwise conservative; no broad package pruning.

## Intentionally Deferred
- Aggressive package deduplication/pruning across role/domain stacks.
- Wider host-level import cleanup to switch hosts directly to new paths.
- Any AI fleet/task/evidence/promotion workflow changes.
- Package observation-window decisions are tracked in `docs/userland-package-ownership.md`.
- `pkg.txt` is kept as a legacy reference only and is no longer part of base package ingress.

## Host Cleanup Notes

- `kellerbench` now imports `base-node.nix` — removed duplicated SSH config, user declaration (with `mkForce`), boot loader boilerplate, and redundant `sops`/`self` arguments
- `penguin.nix` — ~114 lines of commented-out imports, programs, services, and helix config removed
- `applevalley/configuration.nix` — redundant `base-node.nix` import removed (already inherited via `desktop-client.nix`); commented-out GRUB, k3s, docker, and firewall blocks removed
- `minyx/configuration.nix` — ~119 lines of commented-out boilerplate removed
- `thinsandy/hardware-configuration.nix` — commented-out samba `force user`/`force group` lines removed
- Empty `environment.systemPackages = with pkgs; []` blocks removed from `aceofspades` and `schneeeule`
