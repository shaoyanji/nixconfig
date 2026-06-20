---
name: agents
description: Operator helpers — interactive menus, xs runtime wrappers (artifact/contract/record/trace), and OAuth/session management for service users. Derived from taskfiles/agents.yml.
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

## xs runtime wrappers

| Task | Description |
|------|-------------|
| `agents:xs:status` | Show xs-helper status (local store) |
| `agents:xs:doctor` | Run xs-helper doctor check |
| `agents:xs:topics` | List recent xs topics |
| `agents:xs:show:<topic>` | Show recent frames for a topic |
| `agents:xs:tail:<topic>` | Follow topic stream locally |
| `agents:xs:get-artifact:<id>` | Lookup artifact metadata |
| `agents:xs:cat-artifact:<id>` | Stream artifact body |
| `agents:xs:service:status` | Inspect xs systemd service |
| `agents:xs:service:show:<topic>` | Show frames from service store |
| `agents:xs:service:tail:<topic>` | Tail service topic stream |
| `agents:xs:materialize:<topic>:<target>` | Build task_view context from local frames |
| `agents:xs:service:materialize:<topic>:<target>` | Build task_view context from service frames |

All xs tasks run `scripts/task/xs-helper.sh`.

## OAuth / session management

| Task | Description |
|------|-------------|
| `agents:oauth:list` | List known services and tools |
| `agents:oauth:paths:<service>` | Show auth file paths |
| `agents:oauth:status:<service>:<tool>` | Check OAuth status |
| `agents:oauth:login:<service>:<tool>` | Interactive OAuth login |
| `agents:oauth:exec:<service>:<tool>` | Run tool as service user |

All OAuth tasks run `scripts/task/service-oauth.sh`.
