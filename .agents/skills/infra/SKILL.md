---
name: infra
description: Host lifecycle operations — plan, apply, deploy, rollback, logs, secrets, SOPS, store maintenance, and local rebuilds. Derived from taskfiles/infra.yml.
---

# infra — Host Lifecycle

Canonical surface for all host lifecycle, secrets, and store operations.

## Host deployment

| Task | Description |
|------|-------------|
| `infra:deploy:host:<host>` | Plan + apply + validate |
| `infra:plan:host:<host>` | Build/evaluate closure (no apply) |
| `infra:apply:host:<host>` | Apply config to remote host |
| `infra:rollback:host:<host>` | Roll back to previous generation |
| `infra:rollback:apply:host:<host>` | Rollback apply step only |
| `infra:logs:host:<host>` | Tail journal logs via ssh (unit: `go-backend`) |

## Local rebuilds

| Task | Description |
|------|-------------|
| `infra:rebuild:nixos` | Rebuild local NixOS host |
| `infra:rebuild:darwin` | Rebuild local Darwin host |
| `infra:rebuild:home-manager` | Rebuild Home Manager profile |
| `infra:rebuild:wsl` | Rebuild WSL host (guckloch) |
| `infra:rebuild:orb` | Rebuild OrbStack host |
| `infra:switch:<os>` | Switch host using nixos/darwin-rebuild |
| `infra:boot:<os>` | Boot into next generation |

## Store maintenance

| Task | Description |
|------|-------------|
| `infra:store:clean` | Full cleanup — gc + optimise |
| `infra:store:gc` | `nix store gc` |
| `infra:store:optimise` | Deduplicate store paths |
| `infra:store:collect-garbage` | Remove old generations |
| `infra:store:menu` | Interactive store chooser |

## Secrets / SOPS

| Task | Description |
|------|-------------|
| `infra:secrets:edit:apikeys` | Edit encrypted API keys |
| `infra:secrets:edit:taskfile` | Edit encrypted Taskfile |
| `infra:secrets:edit:detaskfile` | Edit encrypted DE Taskfile |
| `infra:secrets:edit:secrets` | Edit encrypted secrets |
| `infra:secrets:new:generate` | Generate SSH + AGE keys |
| `infra:secrets:new:copy-nas` | Copy AGE key from NAS |
| `infra:secrets:decrypt:detaskfile-home` | Decrypt DE Taskfile to ~/ |
| `infra:sops:get:<query>` | Query secrets file |
| `infra:sops:fzf` | Select env entries via fzf |
| `infra:sops:update-keys` | Rotate SOPS recipient keys |
| `infra:api:get:<key>` | Print API key line from encrypted env |
| `infra:load:env` | Load API env lines |
| `infra:load:taskfile` | Decrypt operator Taskfile |

## Known hosts

`minyx` (PI, default deploy target), `garnixMachine`, `mtfuji`, `thinsandy`, `kellerbench`, `guckloch` (WSL).

## Menus

- `infra:deploy:menu` — Choose deployment target
- `infra:logs:menu` — Choose logs target
- `infra:store:menu` — Choose store action
- `infra:load:menu` — Choose load action
