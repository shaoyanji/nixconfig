# Userland Package Ownership

## Current Owners
- Portable shared baseline: `modules/roles/portable-home.nix`
  - guarantees `shell/base` and `programs.nixvim.enable` for `penguin`, `alarm`, `kali`.
- Base: `modules/user/base/default.nix`
  - General CLI/runtime utilities.
- Shell base contract: `modules/shell/base.nix`
  - `bash` + `tmux` module ownership shared across minimal and full-shell stacks.
- Shell core: `modules/shell/default.nix`
  - `zoxide`, `direnv`, `fzf`, `ripgrep`, `jq`, `fd`, `bat`, `eza`.
- AI: `modules/user/ai/default.nix`
  - `tgpt`, `aichat`, `mods`.
- Env/git workflow: `modules/env.nix`
  - `lazygit`.

## Role Wiring
- `penguin` imports `modules/roles/portable-home.nix`.
- `alarm` and `kali` import `modules/roles/minimal.nix` directly (canonical path).
- `modules/roles/minimal.nix` imports:
  - base
  - ai
  - shell base contract is pulled through base (`modules/user/base/default.nix` -> `modules/shell/base.nix`)
- No experimental package bucket is imported in the default role stack.

## Host Overlay Dedupe Applied
- `hosts/alarm.nix`: removed duplicate role import now subsumed by `roles/minimal`:
  - `roles/portable-home`
- `hosts/kali.nix`: removed shared-role duplicates now owned by base/ai:
  - `graph-easy`, `graphviz`, `tgpt`, `comrak`, `pandoc`, `zoxide`
  - removed duplicate imports now subsumed by `roles/minimal`:
    - `roles/portable-home`, `env.nix`, `shell/tmux.nix`, `helix.nix`
  - retained as intentionally host-local (not guaranteed by `roles/minimal`):
    - `programs.direnv` (host integration choices)
    - `programs.zoxide` (host integration/options)
    - `programs.fzf` (host shell UX settings)
    - host package intent list (`lolcat`, `figlet`, `jp2a`, `go`, `gobuster`, `steghide`, `powershell`, `secretscanner`, `yt-dlp`, `ytfzf`, `mpv`)

## Deferred
- No aggressive package removals.
- No changes to host-specific packages that are not clear duplicates in the effective stack.
- `pkg.txt` remains in repo as a legacy reference file but is no longer ingested by base.
- Observation-window result: experimental bucket removed with no re-homing required during eval validation.
