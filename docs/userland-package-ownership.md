# Userland Package Ownership

Who guarantees what, so a host does not re-declare a package its role already
owns. The path is the module that owns the property; hosts are consumers.

## Owners

- `modules/shell/base.nix` — `bash` (plus `.bash_aliases`, Wayland/X11 socket
  autodetect, the secret-cache loader) and `tmux`. One leaf, consumed by
  `shell/default.nix`, `user/base/default.nix` and `roles/demo.nix`.
- `modules/shell/default.nix` — `shell/base.nix` plus zoxide, direnv, fzf,
  ripgrep, jq, fd, bat, eza, starship and nushell.
- `modules/user/base/default.nix` — general CLI/runtime utilities, and the
  `shell/base.nix` import that makes a shell exist at all.
- `modules/user/ai/default.nix` — aichat, antigravity-cli, skills,
  freebuff-remote, mainframe-remotes, zed-mcp; tier-gated by
  `profiles.ai.enable`.
- `modules/env.nix` — git/env workflow (lazygit).

## Roles

| Role | Is | Consumed by |
| :--- | :--- | :--- |
| `roles/minimal.nix` | `user/base` + `user/ai` | `alarm`, `kali`, `global/noDE.nix` |
| `roles/home.nix` | shell base + niri desktop + dev tooling | the NixOS desktop chain |
| `roles/demo.nix` | shell base + niri + demo package list | `demo` |

`penguin` has no role file: it imports `modules/shell` and sets
`programs.nixvim.enable` itself, because one host is not a shared property.

## Rule

A package belongs in the lowest module every consumer already imports. A host
keeps only what is true of that host alone — driver, GPU, session choice. Two
hosts duplicating an entry means the entry is owned one level up, not two.

A host's own userland can lag this rule: `netbook` still installs `mako`, `fuzzel`,
`alacritty` and `swaylock` because alice's dotfiles invoke them, so the profile
cannot own the desktop until they are ported —
[`./netbook-rice-port.md`](./netbook-rice-port.md) is that plan.
