---
name: agents
description: "Operator menus, xs runtime, OAuth/session management."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['agents', 'operators', 'xs']
    related_skills: []
---

# agents — Operator Helpers

Interactive operator control plane, xs runtime wrappers, and OAuth management.

## Menu

| Task | Description |
|------|-------------|
| `agents:menu` | Interactive operator control plane menu |

Sub-commands accessible from menu: `rebuild`, `edit-config`, `update`, `load`, `browse`, `new`, `incus`, `sudologinssh`, `help`, `status`, `check`, `deploy`, `logs`, `exit`.

## Legacy browse helpers

| Task | Description |
|------|-------------|
| `browse` | Deprecated browse menu |
| `browse-notes` | Open quick notes in $EDITOR |
| `browse-internet` | Open DuckDuckGo in zen browser |
| `browse-projects` | Open projects page |
| `projects` | Alias for browse-projects |

## Legacy edit-config helpers

| Task | Description |
|------|-------------|
| `edit-config` | Deprecated edit menu |
| `edit-global` | Edit `modules/global/global.nix` |
| `edit-sops` | Edit `.sops.yaml` + update keys |
| `edit-sops-config` | Edit `modules/sops.nix` |
| `edit-home-manager` | Edit `modules/roles/home.nix` |
| `edit-shell-config` | Edit `modules/shell/default.nix` |

## Legacy helpers

| Task | Description |
|------|-------------|
| `update` | Deprecated update menu |
| `new` | Deprecated bootstrap menu |
| `incus` | Launch temporary NixOS Incus container |
| `sudologinssh` | Run sudo-login from encrypted command list |

All OAuth tasks run `scripts/task/service-oauth.sh`.
