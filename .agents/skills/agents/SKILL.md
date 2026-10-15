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

## Verification discipline (always-on)

When identity, host, or runtime state is questioned — verify with concrete commands before asserting anything. Never speculate about which host you are on, which user runs the session, or which environment applies.

- Run `hostname`, `fastfetch`, `whoami`, or equivalent live probes first.
- Confirm evidence (command output) before stating identity/state.
- If wrong: state plainly what was missed, name it, fix course — no theatrical apology, no defensive preamble. The user corrected style directly ("this is a total shitshow"); honor that by being brief and factual.

Pitfall: asserting host/persona without running the probe produces a trust-break; the user will force verification and treat the session as unreliable. The command output is the ground truth — treat it as binding.
