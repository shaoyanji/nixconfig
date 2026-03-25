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

## Compatibility Wrappers
Old import paths remain valid and now forward to the new locations:
- `modules/global/minimal.nix` -> `modules/roles/minimal.nix`
- `modules/global/home.nix` -> `modules/roles/home.nix`
- `modules/global/heim.nix` -> `modules/roles/heim.nix`
- `modules/goodies.nix` -> `modules/user/ai/default.nix`
- `modules/niri.nix` -> `modules/user/desktop/niri.nix`

This keeps existing host/module imports stable during migration.

Canonical role graph lives under `modules/roles/*`; `modules/global/{minimal,home,heim}.nix` are compatibility shims only.

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
